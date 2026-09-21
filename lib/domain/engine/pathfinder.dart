import 'dart:collection';

import '../models/cell.dart';
import '../models/wall.dart';
import 'blocked_edges.dart';

/// BFS pathfinder for reachability checks.
///
/// Mirrors spec §3.7: pawns are ignored; only walls, board edges, and
/// cell adjacency define the graph.
class Pathfinder {
  /// Returns true if [from] can reach [goalRow] via orthogonal moves,
  /// respecting [walls] on the board.
  static bool canReachGoal({
    required Cell from,
    required int goalRow,
    required List<Wall> walls,
    required int size,
  }) {
    return shortestRouteLength(
          from: from,
          goalRow: goalRow,
          walls: walls,
          size: size,
        ) !=
        null;
  }

  /// Returns the shortest route length from [from] to any cell on [goalRow],
  /// or null if no route exists.
  static int? shortestRouteLength({
    required Cell from,
    required int goalRow,
    required List<Wall> walls,
    required int size,
  }) {
    if (from.row == goalRow) return 0;

    final board = BlockedEdges.fromWalls(walls, size);
    final visited = <Cell>{from};
    // BFS frontier: (cell, distance). A FIFO queue gives amortised O(1)
    // removal, unlike `List.removeAt(0)` which shifts every element.
    final queue = ListQueue<(Cell, int)>()..add((from, 0));

    while (queue.isNotEmpty) {
      final (current, dist) = queue.removeFirst();
      for (final neighbor in board.neighborsOf(current)) {
        if (visited.contains(neighbor)) continue;
        if (board.isBlocked(current, neighbor)) continue;
        final newDist = dist + 1;
        if (neighbor.row == goalRow) return newDist;
        visited.add(neighbor);
        queue.add((neighbor, newDist));
      }
    }
    return null;
  }

  /// DFS version for path-preservation independence test (T-PATH-006).
  static bool canReachGoalDfs({
    required Cell from,
    required int goalRow,
    required List<Wall> walls,
    required int size,
  }) {
    if (from.row == goalRow) return true;
    final board = BlockedEdges.fromWalls(walls, size);
    return _dfsVisit(from, goalRow, board, <Cell>{});
  }

  static bool _dfsVisit(
    Cell current,
    int goalRow,
    BlockedEdges board,
    Set<Cell> visited,
  ) {
    if (visited.contains(current)) return false;
    if (current.row == goalRow) return true;
    visited.add(current);
    for (final neighbor in board.neighborsOf(current)) {
      if (board.isBlocked(current, neighbor)) continue;
      if (_dfsVisit(neighbor, goalRow, board, visited)) return true;
    }
    return false;
  }
}
