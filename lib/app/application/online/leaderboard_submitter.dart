import '../../../domain/repositories/leaderboard.dart';
import '../../../domain/repositories/room.dart';

/// Submits finished online matches to the weekly leaderboard
/// (Phase 16.5, Part H), called by the online game controller
/// when a match it is playing ends.
///
/// Qualification is checked here, before any repository call:
/// a decisive finish (goal / resign / timeout — never an
/// abandonment), two distinct players, and this player
/// actually seated. Ply count and the caps are re-checked by
/// the repository and again by the Security Rules.
///
/// Best-effort by design: a failed submission (offline, rules
/// not yet deployed) is swallowed — the leaderboard must
/// never disturb the match flow, and the result is simply
/// not counted. There is no retry queue in this phase; the
/// limitation is stated in the ledger.
class LeaderboardSubmitter {
  LeaderboardSubmitter({
    required this.repository,
    required this.names,
    required this.myUid,
    this.accountEligible,
  });

  /// The leaderboard store.
  final LeaderboardRepository repository;

  /// The display-name generation store.
  final LeaderboardNameRepository names;

  /// This player's uid.
  final String myUid;

  /// Phase 16.6 (D16.6-10): whether this player may write
  /// leaderboard entries right now — a real account, verified
  /// for email — evaluated at submit time, not at construction.
  /// Null means "no account gate in this build" (the accounts
  /// feature is off) and submission behaves exactly as it did
  /// in Phase 16.5. When it returns false the submission is
  /// skipped entirely, so a guest never spends a write the
  /// Security Rules would certainly deny.
  final bool Function()? accountEligible;

  /// This player's current generated display name.
  Future<String> displayName() async {
    final generation = await names.loadGeneration(myUid);
    return generateDisplayName(myUid, generation);
  }

  /// Regenerates the display name (the next counted match
  /// carries it; the current entry is renamed by the
  /// repository write at the next counted match — or
  /// immediately when the player opens the board and the
  /// controller pushes a rename).
  Future<String> regenerateName() async {
    final generation = await names.loadGeneration(myUid);
    await names.saveGeneration(myUid, generation + 1);
    return generateDisplayName(myUid, generation + 1);
  }

  /// Submits [room]'s finished match, if it qualifies.
  Future<void> submit(Room room) async {
    try {
      final eligible = accountEligible;
      if (eligible != null && !eligible()) return;
      if (room.status != RoomStatus.finished) return;
      final winner = room.winnerId;
      if (winner == null) return; // abandoned: never counts
      final blue = room.blue.playerId;
      final red = room.red.playerId;
      if (blue == null || red == null || blue == red) return;
      if (myUid != blue && myUid != red) return;
      final opponent = myUid == blue ? red : blue;
      await repository.recordResult(
        matchId: room.code,
        opponentUid: opponent,
        won: winner == myUid,
        plies: room.boardState?.turnNumber ?? 0,
        matchEndedAtMs: room.serverUpdatedAtMs ?? room.updatedAtMs,
        displayName: await displayName(),
      );
    } on Object {
      // Best-effort: see the class doc.
    }
  }
}
