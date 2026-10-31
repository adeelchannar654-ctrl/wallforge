import '../../domain/repositories/leaderboard.dart';
import 'firestore_client.dart';
import 'firestore_settings_repository.dart' show UserIdResolver;

/// The weekly leaderboard against Firestore (Phase 16.5,
/// Part H), with the in-memory client as its test double —
/// the same arrangement as every other remote repository.
///
/// Reads: [fetchTop] is one query (≤ 50 documents),
/// [fetchEntry] one document. Writes: [recordResult] is one
/// transaction (read own entry, write it) plus the Security
/// Rules' own `get()` of the finished match — 2 reads + 1
/// write per counted match, counted in the Phase 16.5
/// Firestore recount.
///
/// Nothing here throws: transport failures and rule denials
/// come back as [LeaderboardSubmitOutcome.failed] or empty
/// reads, because a leaderboard must never break the game.
class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository({
    required this.client,
    required this.userId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The Firestore client (real or in-memory double).
  final FirestoreClient client;

  /// Resolves the signed-in player's uid.
  final UserIdResolver userId;

  final DateTime Function() _clock;

  static String _entriesPath(int weekStart) =>
      'leaderboards/$weekStart/entries';
  static String _entryPath(int weekStart, String uid) =>
      '${_entriesPath(weekStart)}/$uid';

  @override
  Future<List<LeaderboardEntry>> fetchTop(
    int weekStart, {
    int limit = kLeaderboardTopLimit,
  }) async {
    // Deliberately NOT error-swallowing (unlike recordResult):
    // the controller needs a throw to tell "unavailable" from
    // "empty". Through today's cloud client a failure already
    // degraded to an empty list one layer down (the Phase 7
    // client discipline), so on a real device an undeployed
    // ruleset reads as an empty board — a limit stated in the
    // Phase 16.5 ledger, not hidden.
    final docs = await client.query(
      collectionPath: _entriesPath(weekStart),
      orderBys: const [
        QueryOrder('points', descending: true),
        QueryOrder('wins', descending: true),
        QueryOrder('uid'),
      ],
      limit: limit,
    );
    final entries = <LeaderboardEntry>[];
    for (final doc in docs) {
      final entry = LeaderboardEntry.fromJson(doc.data);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  @override
  Future<LeaderboardEntry?> fetchEntry(int weekStart, String uid) async {
    final data = await client.read(_entryPath(weekStart, uid));
    return data == null ? null : LeaderboardEntry.fromJson(data);
  }

  @override
  Future<LeaderboardSubmitOutcome> recordResult({
    required String matchId,
    required String opponentUid,
    required bool won,
    required int plies,
    required int matchEndedAtMs,
    required String displayName,
  }) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) {
      return LeaderboardSubmitOutcome.failed;
    }
    // Local eligibility (the rules re-validate server-side):
    // a decisive result at 10+ plies, against a distinct
    // opponent, in the week the match ended — which must be
    // the current week for the write to be accepted at all.
    if (opponentUid == uid || plies < kMinCountedPlies) {
      return LeaderboardSubmitOutcome.notCounted;
    }
    final weekStart = weekStartMs(matchEndedAtMs);
    if (weekStart != weekStartMs(_clock().millisecondsSinceEpoch)) {
      // The match ended in a week that has closed (or has not
      // opened): its bucket is not writable any more.
      return LeaderboardSubmitOutcome.notCounted;
    }
    try {
      final outcome = await client.runTransaction<LeaderboardSubmitOutcome>((
        txn,
      ) async {
        final path = _entryPath(weekStart, uid);
        final existing = await txn.get(path);
        final entry = existing == null
            ? LeaderboardEntry.empty(uid, displayName)
            : (LeaderboardEntry.fromJson(existing) ??
                  LeaderboardEntry.empty(uid, displayName));
        if (entry.countedMatches.containsKey(matchId)) {
          return LeaderboardSubmitOutcome.notCounted;
        }
        if (entry.countedMatches.length >= kMaxCountedPerWeek) {
          return LeaderboardSubmitOutcome.notCounted;
        }
        final againstOpponent = entry.opponentCounts[opponentUid] ?? 0;
        if (againstOpponent >= kMaxCountedPerOpponent) {
          return LeaderboardSubmitOutcome.notCounted;
        }
        final updated = LeaderboardEntry(
          uid: uid,
          displayName: displayName,
          points: entry.points + (won ? kWinPoints : kLossPoints),
          wins: entry.wins + (won ? 1 : 0),
          losses: entry.losses + (won ? 0 : 1),
          countedMatches: {...entry.countedMatches, matchId: opponentUid},
          opponentCounts: {
            ...entry.opponentCounts,
            opponentUid: againstOpponent + 1,
          },
        );
        // weekStartMs and lastCountedMatch are the fields the
        // rules verify the increment against: the week's
        // Monday start (containing request.time) and the one
        // match this write counts.
        txn.set(path, {
          ...updated.toJson(),
          'weekStartMs': weekStart,
          'lastCountedMatch': matchId,
        });
        return LeaderboardSubmitOutcome.counted;
      });
      return outcome;
    } on Object {
      return LeaderboardSubmitOutcome.failed;
    }
  }

  @override
  Future<bool> renameCurrentEntry({required String displayName}) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return false;
    final weekStart = weekStartMs(_clock().millisecondsSinceEpoch);
    final path = _entryPath(weekStart, uid);
    try {
      return await client.runTransaction<bool>((txn) async {
        final existing = await txn.get(path);
        if (existing == null) return false;
        if (existing['displayName'] == displayName) return true;
        txn.set(path, {...existing, 'displayName': displayName});
        return true;
      });
    } on Object {
      return false;
    }
  }
}
