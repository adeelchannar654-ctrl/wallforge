import '../../domain/engine/game_engine.dart';
import '../../domain/models/board_config.dart';
import '../../domain/models/game_action.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/match_record.dart';

/// Replays a record's move list to the final board state
/// (Phase 16.5, Part G), for the shareable result card.
///
/// Returns null when the list cannot be replayed faithfully:
/// it is marked incomplete, a notation does not parse, or the
/// engine refuses a move. A card must never show a board the
/// match did not actually reach, so every doubt resolves to
/// "no board" and the caller falls back to a text share.
GameState? replayFinalState(MatchRecord record) {
  if (!record.movesComplete) return null;
  var state = GameState.initial(
    BoardConfig(size: record.boardSize, wallsPerPlayer: record.wallsPerPlayer),
  );
  for (final notation in record.moves) {
    final action = GameAction.parse(notation);
    if (action == null) return null;
    final result = GameEngine.apply(state, state.currentPlayer, action);
    if (result is! SuccessResult) return null;
    state = result.state;
  }
  return state;
}
