import '../models/action_failure.dart';
import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';
import 'pathfinder.dart';

/// Validates whether a specific action is legal in the given state.
///
/// Mirrors spec §14 (validation pseudo-code).
class ActionValidator {
  /// Validates [action] for [state]. Returns null if valid, or the failure.
  static ActionFailure? validate(GameState state, GameAction action) {
    if (state.status != GameStatus.active) {
      return const ActionFailure.gameNotActive();
    }

    if (action case MoveAction(:final target)) {
      return _validateMove(state, target);
    } else if (action case JumpAction(:final target)) {
      return _validateJump(state, target);
    } else if (action case PlaceWallAction(:final origin, :final orientation)) {
      return _validatePlaceWall(state, origin, orientation);
    }
    return null;
  }

  static ActionFailure? _validateMove(GameState state, Cell target) {
    final pos = state.pawnPosition(state.activePlayer);
    final opponentPos = state.pawnPosition(state.activePlayer.opponent);

    if (!_isOrthogonalAdjacent(pos, target)) {
      return const ActionFailure.notAdjacent();
    }

    if (target == opponentPos) {
      return const ActionFailure.notAdjacent();
    }

    if (target == pos) {
      return const ActionFailure.notAdjacent();
    }

    final blocked = Pathfinder.buildBlockedEdges(state.walls);
    if (blocked.contains((pos, target))) {
      return const ActionFailure.wallBlocksPath();
    }

    // Mandatory jump check
    final jumpTargets = _findJumpTargets(state);
    if (jumpTargets.isNotEmpty && !jumpTargets.contains(target)) {
      return const ActionFailure.mustJump();
    }

    return null;
  }

  static ActionFailure? _validateJump(GameState state, Cell target) {
    final pos = state.pawnPosition(state.activePlayer);
    final opponentPos = state.pawnPosition(state.activePlayer.opponent);

    if (!_isOrthogonalAdjacent(pos, opponentPos)) {
      return const ActionFailure.noOpponentToJumpOver();
    }

    final jumpTargets = _findJumpTargets(state);
    if (!jumpTargets.contains(target)) {
      return const ActionFailure.jumpTargetNotBehind();
    }

    return null;
  }

  static ActionFailure? _validatePlaceWall(
    GameState state,
    Cell origin,
    WallOrientation orientation,
  ) {
    if (state.wallsRemaining(state.activePlayer) <= 0) {
      return const ActionFailure.noWallsRemaining();
    }

    if (orientation == WallOrientation.horizontal) {
      if (origin.col < 0 ||
          origin.col > state.config.cols - 2 ||
          origin.row < 0 ||
          origin.row > state.config.rows - 1) {
        return const ActionFailure.wallOutOfBounds();
      }
    } else {
      if (origin.col < 0 ||
          origin.col > state.config.cols - 1 ||
          origin.row < 0 ||
          origin.row > state.config.rows - 2) {
        return const ActionFailure.wallOutOfBounds();
      }
    }

    final newWall = Wall(origin: origin, orientation: orientation);
    for (final existing in state.walls) {
      if (_footprintsOverlap(newWall.footprint, existing.footprint)) {
        return const ActionFailure.wallOverlap();
      }
    }

    final occupied = {state.bluePawn, state.redPawn};
    for (final cell in newWall.footprint) {
      if (occupied.contains(cell)) {
        return const ActionFailure.wallOverlapPawn();
      }
    }

    final newWalls = [...state.walls, newWall];
    if (!Pathfinder.canReachGoal(
      from: state.bluePawn,
      goalRow: state.config.rows - 1,
      walls: newWalls,
      cols: state.config.cols,
      rows: state.config.rows,
    )) {
      return const ActionFailure.wallBlocksPath();
    }
    if (!Pathfinder.canReachGoal(
      from: state.redPawn,
      goalRow: 0,
      walls: newWalls,
      cols: state.config.cols,
      rows: state.config.rows,
    )) {
      return const ActionFailure.wallBlocksPath();
    }

    return null;
  }

  static bool _isOrthogonalAdjacent(Cell a, Cell b) {
    final dx = (a.col - b.col).abs();
    final dy = (a.row - b.row).abs();
    return (dx + dy) == 1;
  }

  static List<Cell> _findJumpTargets(GameState state) {
    final pos = state.pawnPosition(state.activePlayer);
    final opponentPos = state.pawnPosition(state.activePlayer.opponent);
    final blocked = Pathfinder.buildBlockedEdges(state.walls);
    final targets = <Cell>[];

    final dx = opponentPos.col - pos.col;
    final dy = opponentPos.row - pos.row;
    if (dx.abs() + dy.abs() != 1) return targets;

    final direct = Cell(col: opponentPos.col + dx, row: opponentPos.row + dy);
    if (_isValidCell(direct, state.config.cols, state.config.rows) &&
        !blocked.contains((opponentPos, direct))) {
      targets.add(direct);
    }

    if (dx.abs() == 1) {
      for (final diagDy in [-1, 1]) {
        final diag = Cell(col: opponentPos.col, row: opponentPos.row + diagDy);
        final diagFrom = Cell(col: pos.col, row: pos.row + diagDy);
        if (_isValidCell(diag, state.config.cols, state.config.rows) &&
            _isValidCell(diagFrom, state.config.cols, state.config.rows) &&
            !blocked.contains((pos, diagFrom)) &&
            !blocked.contains((diagFrom, diag))) {
          targets.add(diag);
        }
      }
    } else if (dy.abs() == 1) {
      for (final diagDx in [-1, 1]) {
        final diag = Cell(col: opponentPos.col + diagDx, row: opponentPos.row);
        final diagFrom = Cell(col: pos.col + diagDx, row: pos.row);
        if (_isValidCell(diag, state.config.cols, state.config.rows) &&
            _isValidCell(diagFrom, state.config.cols, state.config.rows) &&
            !blocked.contains((pos, diagFrom)) &&
            !blocked.contains((diagFrom, diag))) {
          targets.add(diag);
        }
      }
    }

    return targets;
  }

  static bool _isValidCell(Cell cell, int cols, int rows) =>
      cell.col >= 0 && cell.col < cols && cell.row >= 0 && cell.row < rows;

  static bool _footprintsOverlap(List<Cell> a, List<Cell> b) {
    final aSet = a.toSet();
    for (final cell in b) {
      if (aSet.contains(cell)) return true;
    }
    return false;
  }
}
