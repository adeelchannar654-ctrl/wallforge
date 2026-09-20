import '../models/cell.dart';
import '../models/wall.dart';

/// BFS pathfinder for reachability checks.
///
/// Mirrors spec §6: adjacency graph traversal.
class Pathfinder {
  /// Returns true if [from] can reach [goalRow] via orthogonal moves,
  /// respecting [walls] on the board.
  static bool canReachGoal({
    required Cell from,
    required int goalRow,
    required List<Wall> walls,
    required int cols,
    required int rows,
  }) {
    if (from.row == goalRow) return true;

    final blocked = buildBlockedEdges(walls);
    final visited = <Cell>{from};
    final queue = [from];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final neighbor in _orthogonalNeighbors(current, cols, rows)) {
        if (visited.contains(neighbor)) continue;
        if (_isEdgeBlocked(current, neighbor, blocked)) continue;
        if (neighbor.row == goalRow) return true;
        visited.add(neighbor);
        queue.add(neighbor);
      }
    }
    return false;
  }

  /// Builds the set of blocked edges from [walls].
  static Set<(Cell, Cell)> buildBlockedEdges(List<Wall> walls) {
    final blocked = <(Cell, Cell)>{};
    for (final wall in walls) {
      for (final (a, b) in wall.blockedEdges) {
        blocked.add((a, b));
        blocked.add((b, a));
      }
    }
    return blocked;
  }

  /// Checks if the edge between [a] and [b] is blocked.
  static bool _isEdgeBlocked(Cell a, Cell b, Set<(Cell, Cell)> blocked) {
    return blocked.contains((a, b));
  }

  /// Returns orthogonal neighbors of [cell] within bounds.
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
}
