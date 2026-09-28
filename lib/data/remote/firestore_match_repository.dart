import 'dart:async';

import '../../core/logging/app_logger.dart';
import '../../domain/engine/game_engine.dart';
import '../../domain/models/action_failure.dart';
import '../../domain/models/game_action.dart';
import '../../domain/models/game_status.dart';
import '../../domain/repositories/match.dart';
import '../../domain/repositories/repositories.dart';
import 'firestore_client.dart';
import 'firestore_settings_repository.dart' show UserIdResolver;

/// Firestore-backed [MatchRepository].
///
/// ## Document layout
///
/// ```text
/// matches/{code}                     the match document (one per game)
/// matches/{code}/moves/{NNNNNN}      one immutable record per accepted action
/// ```
///
/// Exactly `architecture.md` §11's "compact authoritative snapshot plus a move
/// sequence for audit/recovery": the snapshot on the match document is what both
/// clients read on every change, and the `moves` sub-collection is never read in
/// steady state.
///
/// ## Why the write is one transaction
///
/// Two clients can submit for the same turn. The transaction is what makes the
/// pair of writes (match document + move record) indivisible, and what re-runs the
/// loser: on re-run it reads the advanced `turnNumber` and refuses with
/// `notYourTurn`. Concretely, with A and B both submitting ply 4:
///
/// * Both transactions read the match at `turnNumber: 4` and stage their writes.
/// * A commits. B's commit conflicts on the same document, so Firestore aborts and
///   re-runs B's callback.
/// * On the re-run B reads `turnNumber: 5`, so `expectedTurnNumber` (4) no longer
///   matches, and B is rejected with `staleTurn` — never with a write.
/// *
/// B can therefore never make A's move, and the engine re-validates against the
/// *stored* state rather than B's cache.
///
/// ## Duplicate protection
///
/// The move document id is the (zero-padded) turn number, so a retry for a turn
/// that already landed addresses the same document. The idempotency check runs
/// *before* the staleness check, because a retry after a lost acknowledgement
/// necessarily arrives with an already-advanced `turnNumber` and would otherwise be
/// misreported as a conflict.
///
/// ## Limits, stated plainly
///
/// This is client-side enforcement. `architecture.md` §12 is explicit that
/// Firestore Security Rules cannot enforce pathfinding or the win condition, so a
/// hostile client bypasses all of it. Rules and authorization are Phase 10
/// (`Q-8.7`); nothing here should be read as a security boundary.
class FirestoreMatchRepository implements MatchRepository {
  FirestoreMatchRepository({
    required this.client,
    required this.userId,
    this.roomCollection = 'matches',
    this.movesCollection = 'moves',
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Document transport.
  final FirestoreClient client;

  /// Resolves the caller — the same Phase 6/7/8 `UserIdResolver` seam.
  final UserIdResolver userId;

  /// Where match documents live; matches `FirestoreRoomRepository`.
  final String roomCollection;

  /// The moves sub-collection name, per `architecture.md` §11.
  final String movesCollection;

  final DateTime Function() _clock;

  static const AppLogger _log = AppLogger('match_sync');

  int get _nowMs => _clock().millisecondsSinceEpoch;

  String _matchPath(String code) => '$roomCollection/$code';

  String _movePath(String code, int turnNumber) =>
      '${_matchPath(code)}/$movesCollection/${MatchMove.documentIdFor(turnNumber)}';

  @override
  Stream<SharedMatchDocument> watchMatch({required String code}) => client
      .watchWithMetadata(_matchPath(code))
      .map(
        (snapshot) => SharedMatchDocument(
          code: code,
          fields: snapshot.data ?? const <String, dynamic>{},
          fromCache: snapshot.fromCache,
        ),
      );

  @override
  Future<SharedMatchDocument?> loadMatch({required String code}) async {
    try {
      final data = await client.read(_matchPath(code));
      if (data == null) return null;
      return SharedMatchDocument(code: code, fields: data);
    } on Object {
      return null;
    }
  }

  @override
  Future<MoveSubmission> submitAction({
    required String code,
    required int expectedTurnNumber,
    required GameAction action,
    int? expectedVersion,
  }) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) {
      return const MoveSubmission.rejected(
        MatchSyncFailure(
          MatchSyncFailureReason.notAuthenticated,
          message: 'Sign in to play online.',
        ),
      );
    }

    final matchPath = _matchPath(code);
    final movePath = _movePath(code, expectedTurnNumber);

    try {
      return await client.runTransaction<MoveSubmission>((txn) async {
        // --- reads first: Firestore requires all reads before all writes ----
        final rawRoom = await txn.get(matchPath);
        if (rawRoom == null) {
          return _reject(MatchSyncFailureReason.roomNotFound);
        }
        final room = Room.fromJson(rawRoom);
        if (room == null) {
          return _reject(MatchSyncFailureReason.invalidRemoteData);
        }
        if (!room.isMember(uid)) {
          return _reject(MatchSyncFailureReason.notAMember);
        }
        if (room.status == RoomStatus.finished) {
          return _reject(MatchSyncFailureReason.matchFinished);
        }
        if (room.status != RoomStatus.started) {
          return _reject(MatchSyncFailureReason.roomNotStarted);
        }

        // --- idempotency, before staleness -----------------------------------
        final existingMove = await txn.get(movePath);
        if (existingMove != null) {
          if (_isSameAction(existingMove, uid, action)) {
            // Non-null: a `started` room with a missing snapshot was already
            // refused below, and this path is reached only for started rooms.
            return MoveSubmission.alreadyApplied(room, room.boardState!);
          }
          // Something is already recorded for this turn. If the match has moved
          // on, this submission is simply stale; if it has not, two different
          // actions are competing for the same ply, which is a real conflict.
          return _reject(
            room.turnNumber > expectedTurnNumber
                ? MatchSyncFailureReason.staleTurn
                : MatchSyncFailureReason.conflictingDuplicate,
          );
        }

        // --- staleness and consistency ---------------------------------------
        final state = room.boardState;
        if (state == null) {
          return _reject(MatchSyncFailureReason.invalidRemoteData);
        }
        if (expectedVersion != null && room.version != expectedVersion) {
          return _reject(MatchSyncFailureReason.staleTurn);
        }
        if (state.turnNumber != expectedTurnNumber) {
          return _reject(MatchSyncFailureReason.staleTurn);
        }
        // The denormalised field and the snapshot must agree, or one of them is
        // corrupt and neither can be trusted.
        if (room.turnNumber != state.turnNumber) {
          return _reject(MatchSyncFailureReason.invalidRemoteData);
        }

        // --- turn ownership --------------------------------------------------
        final seating = MatchSeating(room: room, uid: uid);
        final mySide = seating.mySide;
        if (mySide == null) return _reject(MatchSyncFailureReason.notAMember);
        if (state.currentPlayer != mySide) {
          return _reject(MatchSyncFailureReason.notYourTurn);
        }
        if (room.currentPlayerId != null && room.currentPlayerId != uid) {
          return _reject(MatchSyncFailureReason.notYourTurn);
        }

        // --- the engine decides, against the stored state --------------------
        // `rules.md` §3.6 and `architecture.md` §12: the client is not trusted, so
        // validation runs on the authoritative snapshot inside the transaction,
        // never on a cached copy. The engine's own reason is surfaced verbatim.
        final result = GameEngine.apply(state, mySide, action);
        if (result is FailureResult) {
          return MoveSubmission.rejected(
            MatchSyncFailure(
              MatchSyncFailureReason.invalidAction,
              message: _actionMessage(result.failure),
              actionFailure: result.failure,
            ),
          );
        }
        final next = (result as SuccessResult).state;

        // --- stage both writes atomically -----------------------------------
        final isFinished = next.status == GameStatus.finished;
        final updated = room.copyWith(
          // Only the engine decides the room is over; nothing else may.
          status: isFinished ? RoomStatus.finished : RoomStatus.started,
          boardState: next,
          turnNumber: next.turnNumber,
          currentPlayerId: isFinished
              ? null
              : room.seatFor(next.currentPlayer).playerId,
          // Derived from the engine's winner, never declared by a client.
          winnerId: isFinished ? room.seatFor(next.winner!).playerId : null,
          updatedAtMs: _nowMs,
          version: room.version + 1,
        );

        txn.set(matchPath, updated.toJson());
        txn.set(movePath, <String, dynamic>{
          'turnNumber': expectedTurnNumber,
          'playerId': uid,
          'action': action.toJson(),
          'notation': action.toNotation(),
          'createdAt': _nowMs,
          'resultingVersion': updated.version,
        });

        return MoveSubmission.applied(updated, next);
      });
    } on Object {
      // A transaction does not queue while offline, so a transport failure here
      // is a normal, recoverable condition rather than an exceptional one. The
      // controller holds the action as pending and resubmits it.
      return _reject(MatchSyncFailureReason.networkUnavailable);
    }
  }

  @override
  Future<List<MatchMove>> readMoves({
    required String code,
    int limit = defaultRecoveryPageSize,
  }) async {
    try {
      // Paged, not truncated. Reading one page and returning it would hand the
      // caller a *prefix* of the log that looks exactly like a complete one, and
      // a caller rebuilding state from a prefix concludes it is up to date. That
      // failure is silent and wrong, so pages are followed to the end.
      final moves = <MatchMove>[];
      String? cursor;
      var pages = 0;
      while (true) {
        final docs = await client.query(
          collectionPath: '${_matchPath(code)}/$movesCollection',
          orderBy: 'turnNumber',
          limit: limit,
          startAfterDocumentId: cursor,
        );
        moves.addAll(
          docs
              .map(
                (doc) => MatchMove.fromJson(
                  doc.data['turnNumber'] is int
                      ? doc.data['turnNumber'] as int
                      : 0,
                  doc.data,
                ),
              )
              .whereType<MatchMove>(),
        );
        if (docs.length < limit) break;
        pages++;
        if (pages >= maxRecoveryPages) {
          // A log this long cannot be a legal game, so it is corrupt or
          // hostile. Stopping quietly would be the silent-prefix bug again.
          _log.log(
            'move log exceeded $maxRecoveryPages pages of $limit; '
            'treating the match as unrecoverable',
          );
          return const <MatchMove>[];
        }
        cursor = docs.last.path.split('/').last;
      }
      moves.sort((a, b) => a.turnNumber.compareTo(b.turnNumber));
      return moves;
    } on Object {
      return const <MatchMove>[];
    }
  }

  /// Whether a stored move record describes exactly this submission.
  ///
  /// Idempotency rests on this, so it compares the *action*, not just the turn: a
  /// different action for the same ply is a conflict, not a retry.
  static bool _isSameAction(
    Map<String, dynamic> move,
    String uid,
    GameAction action,
  ) {
    if (move['playerId'] != uid) return false;
    final stored = move['action'];
    if (stored is! Map) return false;
    return _actionEquals(stored.cast<String, dynamic>(), action);
  }

  /// Compares a stored action map with a live action.
  ///
  /// A structural comparison rather than `==` on the action, because the stored
  /// form is JSON and must not depend on the action type's own equality. Encoding
  /// both sides through `toJson` and comparing maps keeps this in step with the
  /// engine's own serialisation contract (`game_spec.md` §7.2).
  static bool _actionEquals(Map<String, dynamic> stored, GameAction action) {
    final mine = action.toJson();
    if (stored.length != mine.length) return false;
    for (final entry in mine.entries) {
      final other = stored[entry.key];
      final value = entry.value;
      if (value is Map) {
        if (other is! Map) return false;
        if (!_deepEquals(
          value.cast<String, dynamic>(),
          other.cast<String, dynamic>(),
        )) {
          return false;
        }
      } else if (other != value) {
        return false;
      }
    }
    return true;
  }

  static bool _deepEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final value = entry.value;
      final other = b[entry.key];
      if (value is Map) {
        if (other is! Map) return false;
        if (!_deepEquals(
          value.cast<String, dynamic>(),
          other.cast<String, dynamic>(),
        )) {
          return false;
        }
      } else if (other != value) {
        return false;
      }
    }
    return true;
  }

  static MoveSubmission _reject(MatchSyncFailureReason reason) =>
      MoveSubmission.rejected(
        MatchSyncFailure(reason, message: messageFor(reason)),
      );

  /// Player-facing wording for each rejection.
  ///
  /// `rules.md` §7 requires a clear message rather than a raw error, and Phase 8
  /// added a test asserting no message leaks "Exception"; the same check runs over
  /// this map. None of these blame the player for a race they did not cause.
  static String messageFor(MatchSyncFailureReason reason) => switch (reason) {
    MatchSyncFailureReason.notAuthenticated => 'Sign in to play online.',
    MatchSyncFailureReason.notAMember => 'You are not in this match.',
    MatchSyncFailureReason.roomNotFound => 'That match is no longer available.',
    MatchSyncFailureReason.roomNotStarted => 'The match has not started yet.',
    MatchSyncFailureReason.matchFinished => 'This match is already over.',
    MatchSyncFailureReason.notYourTurn => "It is your opponent's turn.",
    MatchSyncFailureReason.staleTurn =>
      'Your opponent has moved. The board is being updated.',
    MatchSyncFailureReason.invalidAction => 'That move is not legal.',
    MatchSyncFailureReason.invalidRemoteData =>
      'The shared match data could not be read. Reconnecting.',
    MatchSyncFailureReason.conflictingDuplicate =>
      'A different move was already played on that turn.',
    MatchSyncFailureReason.networkUnavailable =>
      'Could not reach your opponent. Check your connection.',
  };

  /// A player-facing message for an engine rejection.
  ///
  /// The engine's own [ActionFailure] is the source; the wording avoids naming the
  /// internal enum so a player sees an instruction rather than a constant.
  static String _actionMessage(ActionFailure failure) => switch (failure.name) {
    'matchFinished' => 'This match is already over.',
    'wrongTurn' => "It is your opponent's turn.",
    'moveOutOfBoard' => 'That is off the board.',
    'moveNotAdjacent' => 'You can only move one square.',
    'moveBlockedByWall' => 'A wall is in the way.',
    'moveOntoPawn' => 'Your opponent is on that square.',
    'moveIllegalJump' => 'That jump is not allowed.',
    'noWallsRemaining' => 'You have no walls left.',
    'wallOutOfBounds' => 'That wall does not fit there.',
    'wallOverlaps' => 'A wall is already there.',
    'wallCrosses' => 'That wall crosses another.',
    'wallBlocksPath' =>
      'That wall would leave a pawn with no route to its goal.',
    _ => 'That move is not legal.',
  };

  /// How many move records one page of a recovery read may return.
  ///
  /// A page size, not a cap: [readMoves] follows the cursor to the end of the
  /// log, so this only decides how many records cost one round trip.
  static const int defaultRecoveryPageSize = 200;

  /// Hard ceiling on pages in one recovery read.
  ///
  /// A safety bound against a corrupt or hostile log, not a claim about how long
  /// a game can be. Random-play testing produced a 501-ply game, which already
  /// exceeded the original single-page bound of 500 — so a bound presented as
  /// "longer than any legal game" was not one. Reaching this ceiling means the
  /// log cannot be a legal game, and [readMoves] reports an empty log rather than
  /// a truncated prefix. Recorded as Q-9.4.
  static const int maxRecoveryPages = 25;
}
