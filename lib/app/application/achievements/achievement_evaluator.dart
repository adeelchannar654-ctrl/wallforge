import '../../../domain/engine/game_engine.dart';
import '../../../domain/models/board_config.dart';
import '../../../domain/models/finish_reason.dart';
import '../../../domain/models/game_action.dart';
import '../../../domain/models/game_state.dart';
import '../../../domain/models/match_record.dart';
import '../../../domain/models/player_id.dart';
import '../../../domain/repositories/match_statistics.dart';
import '../shortest_path.dart';

/// The pure achievement predicates (Phase 16.5, Part F).
///
/// Every rule is a function of the recorded history plus the
/// legacy statistics snapshot — no clocks, no randomness, no
/// I/O — so evaluation is deterministic, idempotent, and
/// testable against crafted records. Re-evaluating can only
/// ever return the same set for the same inputs.
///
/// Whose win counts: a record "was won" when it has a winner
/// and either it is an online/vs-AI record the winner is this
/// device's player, or it is a pass-and-play record and the
/// winner is Blue — the legacy statistics' keying, since a
/// shared-screen match belongs to no single player.
class AchievementEvaluator {
  const AchievementEvaluator._();

  /// The fast-win threshold, in total plies.
  static const int fastWinMaxPlies = 25;

  /// The comeback deficit, in goal-distance steps.
  static const int comebackDeficit = 3;

  /// The board sizes "Every Board" spans (the sizes the app
  /// offers in Game Modes).
  static const List<int> allBoardSizes = <int>[5, 7, 9, 11];

  /// Whether [record] counts as a win for this device's player.
  static bool wasWon(MatchRecord record) {
    final winner = record.winnerSide;
    if (winner == null) return false;
    final mine = record.mySide;
    if (mine == null) return winner == PlayerId.blue;
    return winner == mine;
  }

  /// The ids of every record-derived achievement the inputs
  /// satisfy. The external (leaderboard) achievement is never
  /// returned here.
  static Set<String> evaluate(
    List<MatchRecord> records,
    MatchStatistics stats,
  ) {
    final unlocked = <String>{};
    for (final id in _predicates.keys) {
      if (_predicates[id]!(records, stats)) unlocked.add(id);
    }
    return unlocked;
  }

  /// Progress toward [id] as (current, target), for the
  /// achievements that have a meaningful count; null otherwise.
  static (int, int)? progress(
    String id,
    List<MatchRecord> records,
    MatchStatistics stats,
  ) {
    switch (id) {
      case 'streak-3':
        return (_bestStreak(records), 3);
      case 'streak-5':
        return (_bestStreak(records), 5);
      case 'streak-10':
        return (_bestStreak(records), 10);
      case 'all-boards':
        return (_wonBoardSizes(records, stats).length, allBoardSizes.length);
      default:
        return null;
    }
  }

  static final Map<String, bool Function(List<MatchRecord>, MatchStatistics)>
  _predicates = {
    'first-win': (records, stats) => stats.humanWins > 0 || records.any(wasWon),
    'streak-3': (records, _) => _bestStreak(records) >= 3,
    'streak-5': (records, _) => _bestStreak(records) >= 5,
    'streak-10': (records, _) => _bestStreak(records) >= 10,
    'beat-easy': (records, stats) => _beatAi(records, stats, 'Easy'),
    'beat-medium': (records, stats) => _beatAi(records, stats, 'Medium'),
    'beat-hard': (records, stats) => _beatAi(records, stats, 'Hard'),
    'beat-expert': (records, stats) => _beatAi(records, stats, 'Expert'),
    'all-boards': (records, stats) =>
        allBoardSizes.every(_wonBoardSizes(records, stats).contains),
    'no-walls-win': (records, _) => records.any(
      (r) =>
          wasWon(r) &&
          r.movesComplete &&
          r.wallsPerPlayer > 0 &&
          _winnerWallCount(r) == 0,
    ),
    'fully-walled': (records, _) => records.any(
      (r) =>
          wasWon(r) &&
          r.movesComplete &&
          r.wallsPerPlayer > 0 &&
          _winnerWallCount(r) == r.wallsPerPlayer,
    ),
    'fast-win': (records, _) =>
        records.any((r) => wasWon(r) && r.plies <= fastWinMaxPlies),
    'comeback': (records, _) =>
        records.any((r) => wasWon(r) && r.movesComplete && _isComeback(r)),
    'timeout-win': (records, _) =>
        records.any((r) => wasWon(r) && r.finishReason == FinishReason.timeout),
    'online-win': (records, _) =>
        records.any((r) => wasWon(r) && r.mode == MatchMode.online),
    'rematch-win': (records, _) =>
        records.any((r) => wasWon(r) && r.rematchOf != null),
  };

  /// The longest run of consecutive wins in chronological
  /// order (records are stored newest first). A loss — or an
  /// abandonment, which is nobody's win — ends a run.
  static int _bestStreak(List<MatchRecord> records) {
    var best = 0;
    var current = 0;
    for (final record in records.reversed) {
      if (wasWon(record)) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  static bool _beatAi(
    List<MatchRecord> records,
    MatchStatistics stats,
    String label,
  ) {
    if ((stats.byDifficulty[label.toLowerCase()]?.wins ?? 0) > 0) {
      return true;
    }
    return records.any(
      (r) =>
          wasWon(r) &&
          r.mode == MatchMode.versusAi &&
          r.opponentLabel == 'AI · $label',
    );
  }

  static Set<int> _wonBoardSizes(
    List<MatchRecord> records,
    MatchStatistics stats,
  ) {
    final sizes = <int>{
      for (final r in records)
        if (wasWon(r)) r.boardSize,
    };
    for (final entry in stats.byBoardSize.entries) {
      final size = int.tryParse(entry.key);
      if (size != null && entry.value.wins > 0) sizes.add(size);
    }
    return sizes;
  }

  /// Walls the winner placed, from the move list. Blue moves
  /// first in every match (R-PLAYER-07), so plies alternate
  /// Blue, Red, Blue… from index 0.
  static int _winnerWallCount(MatchRecord record) {
    final winner = record.winnerSide;
    if (winner == null) return 0;
    var count = 0;
    for (var i = 0; i < record.moves.length; i++) {
      final mover = i.isEven ? PlayerId.blue : PlayerId.red;
      if (mover == winner && record.moves[i].startsWith('W ')) count++;
    }
    return count;
  }

  /// Replays the move list through the engine and checks
  /// whether the winner ever trailed by [comebackDeficit] or
  /// more goal-distance steps. Any replay failure (a notation
  /// that does not parse, a move the engine refuses) means
  /// "not provable" — false, never a crash.
  static bool _isComeback(MatchRecord record) {
    final winner = record.winnerSide;
    if (winner == null) return false;
    var state = GameState.initial(
      BoardConfig(
        size: record.boardSize,
        wallsPerPlayer: record.wallsPerPlayer,
      ),
    );
    for (final notation in record.moves) {
      final action = GameAction.parse(notation);
      if (action == null) return false;
      final result = GameEngine.apply(state, state.currentPlayer, action);
      if (result is! SuccessResult) return false;
      state = result.state;
      final winnerDistance = shortestRoute(state, winner).length;
      final opponentDistance = shortestRoute(state, winner.opponent).length;
      if (winnerDistance - opponentDistance >= comebackDeficit) return true;
    }
    return false;
  }
}
