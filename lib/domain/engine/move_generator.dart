import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';
import 'pathfinder.dart';

/// Generates all legal actions for the current player.
///
/// Mirrors spec §14 (pseudo-code) and §4.7.
class MoveGenerator {
  /// Returns all legal actions for [state.activePlayer] in [state].
  static List<GameAction> generate(GameState state) {
    if (state.status != GameStatus.active) return [];

    final pos = state.pawnPosition(state.activePlayer);
    final opponentPos = state.pawnPosition(state.activePlayer.opponent);
    final blocked = Pathfinder.buildBlockedEdges(state.walls);
    final actions = <GameAction>[];

    // Check for mandatory jump (spec §4.7.2)
    final jumpTargets = _findJumpTargets(
      pos: pos,
      opponentPos: opponentPos,
      cols: state.config.cols,
      rows: state.config.rows,
      blocked: blocked,
    );

    if (jumpTargets.isNotEmpty) {
      for (final target in jumpTargets) {
        actions.add(JumpAction(target: target));
      }
      return actions;
    }

    // Normal moves
    for (final neighbor in _orthogonalNeighbors(
      pos,
      state.config.cols,
      state.config.rows,
    )) {
      if (!_isEdgeBlocked(pos, neighbor, blocked) && neighbor != opponentPos) {
        actions.add(MoveAction(target: neighbor));
      }
    }

    // Wall placement
    if (state.wallsRemaining(state.activePlayer) > 0) {
      actions.addAll(_generateWallPlacements(state));
    }

    return actions;
  }

  /// Finds all valid jump targets from [pos] over [opponentPos].
  static List<Cell> _findJumpTargets({
    required Cell pos,
    required Cell opponentPos,
    required int cols,
    required int rows,
    required Set<(Cell, Cell)> blocked,
  }) {
    final targets = <Cell>[];
    final dx = opponentPos.col - pos.col;
    final dy = opponentPos.row - pos.row;

    if (dx.abs() + dy.abs() != 1) return targets;

    // Direct jump
    final direct = Cell(col: opponentPos.col + dx, row: opponentPos.row + dy);
    if (_isValidCell(direct, cols, rows) &&
        !_isEdgeBlocked(opponentPos, direct, blocked)) {
      targets.add(direct);
    }

    // Diagonal escapes
    if (dx.abs() == 1) {
      for (final diagDy in [-1, 1]) {
        final diag = Cell(col: opponentPos.col, row: opponentPos.row + diagDy);
        final diagFrom = Cell(col: pos.col, row: pos.row + diagDy);
        if (_isValidCell(diag, cols, rows) &&
            _isValidCell(diagFrom, cols, rows) &&
            !_isEdgeBlocked(pos, diagFrom, blocked) &&
            !_isEdgeBlocked(diagFrom, diag, blocked)) {
          targets.add(diag);
        }
      }
    } else if (dy.abs() == 1) {
      for (final diagDx in [-1, 1]) {
        final diag = Cell(col: opponentPos.col + diagDx, row: opponentPos.row);
        final diagFrom = Cell(col: pos.col + diagDx, row: pos.row);
        if (_isValidCell(diag, cols, rows) &&
            _isValidCell(diagFrom, cols, rows) &&
            !_isEdgeBlocked(pos, diagFrom, blocked) &&
            !_isEdgeBlocked(diagFrom, diag, blocked)) {
          targets.add(diag);
        }
      }
    }

    return targets;
  }

  /// Generates all legal wall placement actions.
  static List<PlaceWallAction> _generateWallPlacements(GameState state) {
    final actions = <PlaceWallAction>[];
    final occupied = {state.bluePawn, state.redPawn};

    for (final orientation in WallOrientation.values) {
      final maxCol = orientation == WallOrientation.horizontal
          ? state.config.cols - 2
          : state.config.cols - 1;
      final maxRow = orientation == WallOrientation.horizontal
          ? state.config.rows - 1
          : state.config.rows - 2;

      for (var row = 0; row <= maxRow; row++) {
        for (var col = 0; col <= maxCol; col++) {
          final origin = Cell(col: col, row: row);
          if (_isValidWallPlacement(origin, orientation, state, occupied)) {
            actions.add(
              PlaceWallAction(origin: origin, orientation: orientation),
            );
          }
        }
      }
    }
    return actions;
  }

  /// Checks if placing a wall at [origin] with [orientation] is valid.
  static bool _isValidWallPlacement(
    Cell origin,
    WallOrientation orientation,
    GameState state,
    Set<Cell> occupied,
  ) {
    final footprint = _wallFootprint(origin, orientation);

    // Overlap check with existing walls
    for (final existing in state.walls) {
      if (_footprintsOverlap(footprint, existing.footprint)) return false;
    }

    // Pawn overlap check
    for (final cell in footprint) {
      if (occupied.contains(cell)) return false;
    }

    // Path-blocking check
    final newWall = Wall(origin: origin, orientation: orientation);
    final newWalls = [...state.walls, newWall];
    if (!Pathfinder.canReachGoal(
      from: state.bluePawn,
      goalRow: state.config.rows - 1,
      walls: newWalls,
      cols: state.config.cols,
      rows: state.config.rows,
    )) {
      return false;
    }
    if (!Pathfinder.canReachGoal(
      from: state.redPawn,
      goalRow: 0,
      walls: newWalls,
      cols: state.config.cols,
      rows: state.config.rows,
    )) {
      return false;
    }

    return true;
  }

  static List<Cell> _wallFootprint(Cell origin, WallOrientation orientation) {
    return switch (orientation) {
      WallOrientation.horizontal => [
        origin,
        Cell(col: origin.col + 1, row: origin.row),
      ],
      WallOrientation.vertical => [
        origin,
        Cell(col: origin.col, row: origin.row + 1),
      ],
    };
  }

  static bool _footprintsOverlap(List<Cell> a, List<Cell> b) {
    final aSet = a.toSet();
    for (final cell in b) {
      if (aSet.contains(cell)) return true;
    }
    return false;
  }

  static List<Cell> _orthogonalNeighbors(Cell cell, int cols, int rows) {
    const offsets = [(0, -1), (0, 1), (-1, 0), (1, 0)];
    final neighbors = <Cell>[];
    for (final (dx, dy) in offsets) {
      final nx = cell.col + dx;
      final ny = cell.row + dy;
      if (nx >= 0 && nx < cols && ny >= 0 && ny < rows) {
        neighbors.add(Cell(col: nx, row: ny));
      }
    }
    return neighbors;
  }

  static bool _isValidCell(Cell cell, int cols, int rows) =>
      cell.col >= 0 && cell.col < cols && cell.row >= 0 && cell.row < rows;

  static bool _isEdgeBlocked(Cell a, Cell b, Set<(Cell, Cell)> blocked) {
    return blocked.contains((a, b));
  }
}
