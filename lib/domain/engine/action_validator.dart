import '../models/action_failure.dart';
import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';
import 'blocked_edges.dart';
import 'pathfinder.dart';

/// Validates whether a specific action is legal in the given state.
///
/// Mirrors spec §5.2: deterministic validation precedence.
class ActionValidator {
  /// Validates [action] for [player] in [state].
  ///
  /// Returns null if valid, or the failure reason.
  static ActionFailure? validate(
    GameState state,
    PlayerId player,
    GameAction action,
  ) {
    // §5.2.1: matchFinished → wrongTurn
    if (state.status == GameStatus.finished) {
      return ActionFailure.matchFinished;
    }
    if (state.currentPlayer != player) {
      return ActionFailure.wrongTurn;
    }

    // §5.2.2/3: dispatch by action type. The union is sealed, so the switch is
    // exhaustive; no default branch is required.
    return switch (action) {
      MoveAction(:final destination) => _validateMove(
        state,
        player,
        destination,
      ),
      final WallAction wall => _validateWall(state, player, wall),
    };
  }

  static ActionFailure? _validateMove(
    GameState state,
    PlayerId player,
    Cell destination,
  ) {
    final me = state.pawnPosition(player);
    final op = state.pawnPosition(player.opponent);
    final size = state.boardConfig.size;
    final board = BlockedEdges.fromWalls(state.walls, size);

    // Off-board check
    if (destination.row < 0 ||
        destination.row >= size ||
        destination.column < 0 ||
        destination.column >= size) {
      return ActionFailure.moveOutOfBoard;
    }

    // Step: destination is one of 4 neighbours
    if (board.neighborsOf(me).contains(destination)) {
      if (board.isBlocked(me, destination)) {
        return ActionFailure.moveBlockedByWall;
      }
      if (destination == op) {
        return ActionFailure.moveOntoPawn;
      }
      return null; // legal step
    }

    // Jump-shaped check (matching generator logic exactly)
    final opAdjacent =
        board.neighborsOf(me).contains(op) && !board.isBlocked(me, op);

    if (opAdjacent) {
      final straightTarget = Cell(
        row: op.row + (op.row - me.row),
        column: op.column + (op.column - me.column),
      );

      // Generator's jump_shaped: destination == straightTarget OR
      // (manhattan distance to opponent == 1 AND destination != me)
      final isJumpShaped =
          destination == straightTarget ||
          (destination.row >= 0 &&
              destination.row < size &&
              destination.column >= 0 &&
              destination.column < size &&
              _manhattanDistance(destination, op) == 1 &&
              destination != me);

      if (isJumpShaped) {
        final validTargets = _jumpTargets(me, op, board, size);
        if (validTargets.contains(destination)) {
          return null; // legal jump
        }
        return ActionFailure.moveIllegalJump;
      }
    }

    return ActionFailure.moveNotAdjacent;
  }

  static ActionFailure? _validateWall(
    GameState state,
    PlayerId player,
    WallAction action,
  ) {
    final anchor = action.anchor;
    final orient = action.orientation;
    final size = state.boardConfig.size;
    final maxAnchor = size - 2;

    // §5.2.3: noWallsRemaining → wallOutOfBounds → wallOverlaps → wallBlocksPath
    // (`wallCrosses` was removed from this chain in spec v2.0.0: same-anchor,
    // opposite-orientation walls are legal, so it is unreachable.)
    if (state.wallsRemaining(player) <= 0) {
      return ActionFailure.noWallsRemaining;
    }

    if (anchor.row < 0 ||
        anchor.row > maxAnchor ||
        anchor.column < 0 ||
        anchor.column > maxAnchor) {
      return ActionFailure.wallOutOfBounds;
    }

    // Check overlap with existing walls of same orientation
    for (final existing in state.walls) {
      if (existing.orientation != orient) continue;
      if (orient == WallOrientation.h) {
        if (existing.anchorRow == anchor.row &&
            (existing.anchorColumn - anchor.column).abs() <= 1) {
          return ActionFailure.wallOverlaps;
        }
      } else {
        if (existing.anchorColumn == anchor.column &&
            (existing.anchorRow - anchor.row).abs() <= 1) {
          return ActionFailure.wallOverlaps;
        }
      }
    }

    // Same-orientation overlap is the only remaining shape conflict (R-WALL-07).
    // A same-anchor wall of the *other* orientation is legal as of spec v2.0.0
    // (R-WALL-08): the pair forms a "+" and each still blocks only its own two
    // edges, so no check is needed here.
    //
    // Check path preservation
    final testWall = Wall(
      anchorRow: anchor.row,
      anchorColumn: anchor.column,
      orientation: orient,
      owner: player,
    );
    final newWalls = [...state.walls, testWall];

    if (!Pathfinder.canReachGoal(
      from: state.pawnPosition(PlayerId.blue),
      goalRow: state.boardConfig.blueGoalRow,
      walls: newWalls,
      size: size,
    )) {
      return ActionFailure.wallBlocksPath;
    }
    if (!Pathfinder.canReachGoal(
      from: state.pawnPosition(PlayerId.red),
      goalRow: state.boardConfig.redGoalRow,
      walls: newWalls,
      size: size,
    )) {
      return ActionFailure.wallBlocksPath;
    }

    return null;
  }

  static int _manhattanDistance(Cell a, Cell b) =>
      (a.row - b.row).abs() + (a.column - b.column).abs();

  /// All valid jump targets from [me] through [op].
  ///
  /// Straight is the only target when available; diagonals only when straight
  /// is unavailable (off-board or wall-blocked). Matches R-JUMP-02/03.
  static List<Cell> _jumpTargets(
    Cell me,
    Cell op,
    BlockedEdges board,
    int size,
  ) {
    final dr = op.row - me.row;
    final dc = op.column - me.column;

    // Straight jump
    final straight = Cell(row: op.row + dr, column: op.column + dc);
    final straightAvailable =
        straight.row >= 0 &&
        straight.row < size &&
        straight.column >= 0 &&
        straight.column < size &&
        !board.isBlocked(op, straight);

    if (straightAvailable) {
      return [straight];
    }

    // Diagonal jumps only when straight is unavailable
    final targets = <Cell>[];
    for (final (pdr, pdc) in [(-dc, dr), (dc, -dr)]) {
      final diag = Cell(row: op.row + pdr, column: op.column + pdc);
      if (diag.row >= 0 &&
          diag.row < size &&
          diag.column >= 0 &&
          diag.column < size &&
          !board.isBlocked(op, diag)) {
        targets.add(diag);
      }
    }
    return targets;
  }
}
