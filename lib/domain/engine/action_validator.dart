import '../models/action_failure.dart';
import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';
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

    // §5.2.2/3: dispatch by action type
    if (action is MoveAction) {
      return _validateMove(state, player, action.destination);
    } else if (action is WallAction) {
      return _validateWall(state, player, action);
    }
    return null;
  }

  static ActionFailure? _validateMove(
    GameState state,
    PlayerId player,
    Cell destination,
  ) {
    final me = state.pawnPosition(player);
    final op = state.pawnPosition(player.opponent);
    final size = state.boardConfig.size;
    final b = _blockedEdges(state.walls);

    // Off-board check
    if (destination.row < 0 ||
        destination.row >= size ||
        destination.column < 0 ||
        destination.column >= size) {
      return ActionFailure.moveOutOfBoard;
    }

    // Step: destination is one of 4 neighbours
    final isStep = _neighbors(me, size).contains(destination);
    if (isStep) {
      if (_isEdgeBlocked(me, destination, b)) {
        return ActionFailure.moveBlockedByWall;
      }
      if (destination == op) {
        return ActionFailure.moveOntoPawn;
      }
      return null; // legal step
    }

    // Jump-shaped check (matching generator logic exactly)
    final opAdjacent = _neighbors(me, size).contains(op) &&
        !_isEdgeBlocked(me, op, b);

    if (opAdjacent) {
      final straightTarget = Cell(
        row: op.row + (op.row - me.row),
        column: op.column + (op.column - me.column),
      );

      // Generator's jump_shaped: destination == straightTarget OR
      // (manhattan distance to opponent == 1 AND destination != me)
      final isJumpShaped = destination == straightTarget ||
          (destination.row >= 0 &&
              destination.row < size &&
              destination.column >= 0 &&
              destination.column < size &&
              _manhattanDistance(destination, op) == 1 &&
              destination != me);

      if (isJumpShaped) {
        final validTargets = _jumpTargets(me, op, state.walls, size);
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

    // §5.2.3: noWallsRemaining → wallOutOfBounds → wallOverlaps → wallCrosses → wallBlocksPath
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

    // Check crossing: same anchor, different orientation
    for (final existing in state.walls) {
      if (existing.anchorRow == anchor.row &&
          existing.anchorColumn == anchor.column &&
          existing.orientation != orient) {
        return ActionFailure.wallCrosses;
      }
    }

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

  /// Computes blocked edges from wall placements.
  static Set<(_CK, _CK)> _blockedEdges(List<Wall> walls) {
    final blocked = <(_CK, _CK)>{};
    for (final wall in walls) {
      final r = wall.anchorRow;
      final c = wall.anchorColumn;
      if (wall.orientation == WallOrientation.h) {
        _addEdge(blocked, r, c, r + 1, c);
        _addEdge(blocked, r, c + 1, r + 1, c + 1);
      } else {
        _addEdge(blocked, r, c, r, c + 1);
        _addEdge(blocked, r + 1, c, r + 1, c + 1);
      }
    }
    return blocked;
  }

  static void _addEdge(
    Set<(_CK, _CK)> blocked,
    int r1,
    int c1,
    int r2,
    int c2,
  ) {
    blocked.add((_CK(r1, c1), _CK(r2, c2)));
    blocked.add((_CK(r2, c2), _CK(r1, c1)));
  }

  static bool _isEdgeBlocked(Cell a, Cell b, Set<(_CK, _CK)> blocked) {
    return blocked.contains((_CK(a.row, a.column), _CK(b.row, b.column)));
  }

  static List<Cell> _neighbors(Cell cell, int size) {
    const offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    final result = <Cell>[];
    for (final (dr, dc) in offsets) {
      final nr = cell.row + dr;
      final nc = cell.column + dc;
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        result.add(Cell(row: nr, column: nc));
      }
    }
    return result;
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
    List<Wall> walls,
    int size,
  ) {
    final b = _blockedEdges(walls);
    final dr = op.row - me.row;
    final dc = op.column - me.column;

    // Straight jump
    final straight = Cell(row: op.row + dr, column: op.column + dc);
    final straightAvailable = straight.row >= 0 &&
        straight.row < size &&
        straight.column >= 0 &&
        straight.column < size &&
        !_isEdgeBlocked(op, straight, b);

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
          !_isEdgeBlocked(op, diag, b)) {
        targets.add(diag);
      }
    }
    return targets;
  }
}

class _CK {
  const _CK(this.r, this.c);
  final int r;
  final int c;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CK &&
          runtimeType == other.runtimeType &&
          r == other.r &&
          c == other.c;

  @override
  int get hashCode => Object.hash(r, c);
}
