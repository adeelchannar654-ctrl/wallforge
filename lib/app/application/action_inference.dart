import '../../domain/models/cell.dart';
import '../../domain/models/game_action.dart';
import '../../domain/models/game_state.dart';

/// Infers the single action that took [before] to [after], or
/// null when the transition is not exactly one ply (Phase 16.5).
///
/// One ply changes exactly one thing: the mover's pawn moved,
/// or one wall of the mover's appeared. Finish states change
/// nothing else about the board, so the inference is exact for
/// every legal single-ply transition and safely null for
/// anything else (a multi-ply jump, a reconnect gap, an
/// app-layer finish like a resign, which is not a move at all).
///
/// Both game controllers use this to build a match's move list
/// from observed states alone — locally from the state before
/// each applied action, online from consecutive snapshots —
/// so neither needs the engine to grow a history, and no extra
/// online reads or writes are involved.
GameAction? inferAction(GameState before, GameState after) {
  if (after.turnNumber != before.turnNumber + 1) return null;
  final mover = before.currentPlayer;
  final destination = after.pawnPosition(mover);
  if (destination != before.pawnPosition(mover)) {
    return GameAction.move(destination);
  }
  for (final wall in after.walls) {
    final existed = before.walls.any(
      (w) =>
          w.anchorRow == wall.anchorRow &&
          w.anchorColumn == wall.anchorColumn &&
          w.orientation == wall.orientation &&
          w.owner == wall.owner,
    );
    if (!existed) {
      return GameAction.wall(
        orientation: wall.orientation,
        anchor: Cell(row: wall.anchorRow, column: wall.anchorColumn),
      );
    }
  }
  return null;
}
