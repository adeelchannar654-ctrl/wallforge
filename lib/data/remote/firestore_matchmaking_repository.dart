import 'dart:async';

import '../../domain/models/board_config.dart';
import '../../domain/repositories/matchmaking.dart';
import '../../domain/repositories/repositories.dart';
import 'firestore_client.dart';
import 'firestore_settings_repository.dart' show UserIdResolver;
import 'room_code_generator.dart';

/// Firestore-backed [MatchmakingRepository].
///
/// ## Document layout
///
/// ```text
/// matchmaking/{boardKey}/waiting/{uid}    a player waiting; the doc id is the uid
/// matchmaking/{boardKey}/matched/{uid}    "you have been matched"; the value is the room
/// matches/{code}                         the Phase 8 room, written by the claimer
/// ```
///
/// The waiting entry's document id *is* the uid, so a player can hold at most one
/// queue entry per board and re-queuing is idempotent.
///
/// ## Why pairing is race-free
///
/// Two clients can reach [findMatch] at the same instant. The dangerous case is
/// both claiming the same waiting entry, which would seat one player in two
/// different rooms. Two mechanisms prevent it:
///
/// 1. **The claim is a transaction.** Claiming candidate `X` re-reads `X` *inside*
///    the transaction, so if another client already claimed it, `X` is gone and
///    this claim aborts. The loser retries with a different candidate.
/// 2. **One transaction writes both participants' `matched` documents.** Those
///    shared documents are the mutual-exclusion token. If A claims B while B
///    simultaneously claims A, both transactions write `matched/A` and
///    `matched/B`, so Firestore detects a write-write conflict, aborts one, and
///    re-runs it. The re-run sees its own `matched` document already present and
///    backs off. A player cannot end up in two rooms.
///
/// The two-simultaneous-requests case, concretely, starting from an empty queue:
///
/// * A and B each write their own `waiting` entry (different documents, so no
///   conflict), then each queries and finds the other.
/// * A's claim transaction and B's claim transaction both run. Both write
///   `matched/A` and `matched/B`, so they conflict; one commits, one retries.
/// * The winner returns its room directly. The loser, on retry, finds
///   `matched/{self}` already present, abandons the claim, re-reads its own
///   matched document and returns **the same room**.
////
/// Exactly one room exists and both players are seated in it. Neither is
/// double-booked and neither is left waiting.
///
/// ## Why candidate discovery sits outside the transaction
///
/// `cloud_firestore`'s `Transaction.get` accepts only a `DocumentReference`; it
/// cannot run a query. That is an SDK limitation, not a shortcut. Candidates are
/// therefore found with a plain query and the transaction re-reads the single
/// chosen candidate to confirm it is still claimable. The commit — the part that
/// has to be atomic — still is.
///
/// ## Free-tier discipline
///
/// One query per attempt returning at most [candidateLimit] documents, billed as
/// ordinary document reads. No polling and no periodic write: a waiting player is
/// notified by a listener on its own `matched` document.
class FirestoreMatchmakingRepository implements MatchmakingRepository {
  FirestoreMatchmakingRepository({
    required this.client,
    required this.userId,
    RoomCodeGenerator? codeGenerator,
    this.collection = 'matchmaking',
    this.roomCollection = 'matches',
    this.candidateLimit = 10,
    this.claimAttempts = 3,
    this.staleAfter = const Duration(seconds: 60),
    DateTime Function()? clock,
  }) : codeGenerator = codeGenerator ?? RandomRoomCodeGenerator(),
       _clock = clock ?? DateTime.now;

  /// Document transport.
  final FirestoreClient client;

  /// Resolves the caller — the same Phase 6/7/8 `UserIdResolver` seam.
  final UserIdResolver userId;

  /// Candidate room-code source, injectable so collisions stay testable.
  final RoomCodeGenerator codeGenerator;

  /// Queue collection root.
  final String collection;

  /// Where rooms live; matches `FirestoreRoomRepository`'s collection.
  final String roomCollection;

  /// How many waiting entries one attempt considers.
  final int candidateLimit;

  /// How many times to retry claiming after losing a race.
  final int claimAttempts;

  /// A waiting entry older than this is treated as abandoned.
  ///
  /// A player who closes the app mid-wait leaves an entry nothing will ever
  /// clear. Without a staleness rule that entry would eventually be claimed into a
  /// room whose opponent never appears, stranding the claimer in a lobby forever.
  /// Sixty seconds is a reasoned default rather than a documented figure: someone
  /// unpaired for a minute has almost certainly left. No source document specifies
  /// one. Recorded as Q-8.10.
  final Duration staleAfter;

  final DateTime Function() _clock;

  int get _nowMs => _clock().millisecondsSinceEpoch;

  String _waitingCollection(BoardConfig config) =>
      '$collection/${matchmakingBoardKey(config)}/waiting';

  String _waitingPath(BoardConfig config, String uid) =>
      '${_waitingCollection(config)}/$uid';

  String _matchedPath(BoardConfig config, String uid) =>
      '$collection/${matchmakingBoardKey(config)}/matched/$uid';

  @override
  Future<MatchmakingResult> findMatch({required BoardConfig config}) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) {
      return const MatchmakingResult.rejected(
        MatchmakingFailure(
          MatchmakingFailureReason.notAuthenticated,
          'Sign in to play online.',
        ),
      );
    }
    if (!config.isValid) {
      return const MatchmakingResult.rejected(
        MatchmakingFailure(
          MatchmakingFailureReason.pairingFailed,
          'That board size is not playable.',
        ),
      );
    }

    // Already matched, e.g. a reconnect: report the existing room rather than
    // queueing for a second one.
    final already = await _matchedRoom(config, uid);
    if (already != null) return MatchmakingResult.matched(already);

    // Announce ourselves *and* then try to claim someone. Doing both — rather
    // than only claiming on arrival — is what makes the genuinely simultaneous
    // case resolve instead of leaving two players waiting, each having seen an
    // empty queue.
    await _write(_waitingPath(config, uid), <String, dynamic>{
      'uid': uid,
      'queuedAt': _nowMs,
    });

    var sawFreshCandidate = false;
    for (var attempt = 0; attempt < claimAttempts; attempt++) {
      // Re-check first: an earlier attempt may have been won by the other player
      // while this one was being retried.
      final mine = await _matchedRoom(config, uid);
      if (mine != null) return MatchmakingResult.matched(mine);

      final candidates = await client.query(
        collectionPath: _waitingCollection(config),
        orderBy: 'queuedAt',
        limit: candidateLimit,
      );
      final fresh = await _reapStale(candidates, uid);
      if (fresh.isEmpty) break;
      sawFreshCandidate = true;

      final room = await _claim(config, uid, fresh.first);
      if (room != null) return MatchmakingResult.matched(room);
      // Lost this candidate to a competing claim; look again.
    }

    // One last look: a claim we lost may still have matched us.
    final settled = await _matchedRoom(config, uid);
    if (settled != null) return MatchmakingResult.matched(settled);

    // The deciding question is not "did I see a partner" but "am I actually
    // waiting". Losing a race leaves this client's own queue entry in place, so
    // the truthful answer is "still searching" — reporting a failure there would
    // tell a perfectly well-queued player that matchmaking is broken. Only when
    // the entry is genuinely absent — the announcement never landed — is this a
    // failure worth surfacing.
    if (await _read(_waitingPath(config, uid)) != null) {
      return const MatchmakingResult.queued();
    }
    return MatchmakingResult.rejected(
      MatchmakingFailure(
        MatchmakingFailureReason.pairingFailed,
        sawFreshCandidate
            ? 'Could not enter the matchmaking queue. Please try again.'
            : 'Could not reach the matchmaking queue. Check your connection.',
      ),
    );
  }

  /// Drops abandoned entries and returns the usable ones, oldest first.
  ///
  /// Sweeping is a plain write rather than a transaction: the worst case is two
  /// clients both deleting the same stale entry, which is harmless.
  Future<List<FirestoreDocument>> _reapStale(
    List<FirestoreDocument> candidates,
    String selfUid,
  ) async {
    final cutoff = _nowMs - staleAfter.inMilliseconds;
    final fresh = <FirestoreDocument>[];
    for (final doc in candidates) {
      final other = doc.data['uid'];
      if (other is! String || other.isEmpty) {
        // Malformed entry: remove it rather than let it block the queue.
        await _delete(doc.path);
        continue;
      }
      if (other == selfUid) continue;
      final queuedAt = doc.data['queuedAt'];
      if (queuedAt is! int || queuedAt < cutoff) {
        await _delete(doc.path);
        continue;
      }
      fresh.add(doc);
    }
    return fresh;
  }

  /// Atomically claims [candidate] into a new room, or returns null.
  ///
  /// Null means "could not claim": the candidate was gone, this player is already
  /// matched, or the transaction never committed. All are normal outcomes to
  /// retry, not errors.
  Future<Room?> _claim(
    BoardConfig config,
    String uid,
    FirestoreDocument candidate,
  ) async {
    final otherUid = candidate.data['uid'];
    if (otherUid is! String || otherUid.isEmpty) return null;
    final room = _buildRoom(config, uid, otherUid);
    if (room == null) return null;

    try {
      return await client.runTransaction<Room?>((txn) async {
        // Every read happens before any write, as Firestore requires.
        //
        // 1. Am I already matched? Reading this outside the transaction is
        //    precisely the race being guarded against.
        if (await txn.get(_matchedPath(config, uid)) != null) return null;

        // 2. Is the candidate still waiting? Gone means someone else won it.
        final stillWaiting = await txn.get(candidate.path);
        if (stillWaiting == null) return null;
        if (stillWaiting['uid'] != otherUid) return null; // entry was replaced

        // 3. Is the candidate already in another match? A player who matched
        //    earlier can still have a leftover queue entry — from an earlier
        //    session, or written before their own claim succeeded. Claiming
        //    such an entry would seat one player in two rooms.
        if (await txn.get(_matchedPath(config, otherUid)) != null) return null;

        // 4. Claim it: consume *both* queue entries and seat both players.
        //    Forgetting the claimer's own entry leaves it queued while seated,
        //    so a third player could pair with someone already in a match —
        //    found by the "nobody is left stranded" test.
        txn.delete(candidate.path);
        txn.delete(_waitingPath(config, uid));
        final payload = room.toJson();
        txn.set('$roomCollection/${room.code}', payload);
        txn.set(_matchedPath(config, uid), payload);
        txn.set(_matchedPath(config, otherUid), payload);
        return room;
      });
    } on Object {
      return null;
    }
  }

  /// The room for a successful pairing, or null if no code could be produced.
  ///
  /// The player who was *already waiting* becomes the host in Blue, matching the
  /// convention of a code room: whoever set the room up is Blue, and Blue moves
  /// first (`game_spec.md` R-PLAYER-07).
  Room? _buildRoom(BoardConfig config, String uid, String waitingUid) {
    final code = RoomCode.tryParse(codeGenerator.generate());
    if (code == null) return null;
    final now = _nowMs;
    return Room(
      code: code.value,
      status: RoomStatus.waiting,
      boardConfig: config,
      hostId: waitingUid,
      blue: RoomSeat(playerId: waitingUid),
      red: RoomSeat(playerId: uid),
      createdAtMs: now,
      updatedAtMs: now,
    );
  }

  Future<Room?> _matchedRoom(BoardConfig config, String uid) async =>
      Room.fromJson(await _read(_matchedPath(config, uid)));

  @override
  Future<void> cancel({required BoardConfig config}) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return;
    // Only the queue entry is removed. A `matched` document is left alone: it
    // records a match already agreed, and deleting it would strand the opponent
    // walking into the room. A later findMatch for the same board overwrites it.
    await _delete(_waitingPath(config, uid));
  }

  @override
  Stream<Room?> watchForMatch({
    required BoardConfig config,
    required String uid,
  }) => client.watch(_matchedPath(config, uid)).map(Room.fromJson);

  // --- Transport, total like every other repository ---------------------------

  Future<Map<String, dynamic>?> _read(String path) async {
    try {
      return await client.read(path);
    } on Object {
      return null;
    }
  }

  Future<void> _write(String path, Map<String, dynamic> data) async {
    try {
      await client.write(path, data);
    } on Object {
      // Losing a queue announcement costs at most a wait. The claim path still
      // works, and the `matched` listener means a later pairing still lands.
    }
  }

  Future<void> _delete(String path) async {
    try {
      await client.delete(path);
    } on Object {
      // A failed delete leaves a stale entry, which [staleAfter] reaps later.
    }
  }
}
