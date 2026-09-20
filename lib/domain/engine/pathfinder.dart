import '../models/cell.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';

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
    ) != null;
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

    final blocked = _buildBlockedEdges(walls, size);
    final visited = <_CellKey>{_CellKey(from.row, from.column)};
    // BFS queue: (cell, distance)
    final queue = [(from, 0)];

    while (queue.isNotEmpty) {
      final (current, dist) = queue.removeAt(0);
      for (final neighbor in _orthogonalNeighbors(current, size)) {
        final nk = _CellKey(neighbor.row, neighbor.column);
        if (visited.contains(nk)) continue;
        if (_isEdgeBlocked(current, neighbor, blocked)) continue;
        final newDist = dist + 1;
        if (neighbor.row == goalRow) return newDist;
        visited.add(nk);
        queue.add((neighbor, newDist));
      }
    }
    return null;
  }

  /// Builds the set of blocked edges from [walls].
  ///
  /// Each wall blocks 2 edges. The blocked set stores both directions
  /// (a,b) and (b,a) for efficient lookup.
  static Set<(_CellKey, _CellKey)> _buildBlockedEdges(
    List<Wall> walls,
    int size,
  ) {
    final blocked = <(_CellKey, _CellKey)>{};
    for (final wall in walls) {
      final r = wall.anchorRow;
      final c = wall.anchorColumn;
      if (wall.orientation == WallOrientation.h) {
        // H(r,c): blocks edges (r,c)-(r+1,c) and (r,c+1)-(r+1,c+1)
        _addEdge(blocked, r, c, r + 1, c);
        _addEdge(blocked, r, c + 1, r + 1, c + 1);
      } else {
        // V(r,c): blocks edges (r,c)-(r,c+1) and (r+1,c)-(r+1,c+1)
        _addEdge(blocked, r, c, r, c + 1);
        _addEdge(blocked, r + 1, c, r + 1, c + 1);
      }
    }
    return blocked;
  }

  static void _addEdge(
    Set<(_CellKey, _CellKey)> blocked,
    int r1,
    int c1,
    int r2,
    int c2,
  ) {
    final a = _CellKey(r1, c1);
    final b = _CellKey(r2, c2);
    blocked.add((a, b));
    blocked.add((b, a));
  }

  static bool _isEdgeBlocked(
    Cell a,
    Cell b,
    Set<(_CellKey, _CellKey)> blocked,
  ) {
    return blocked.contains((_CellKey(a.row, a.column), _CellKey(b.row, b.column)));
  }

  static List<Cell> _orthogonalNeighbors(Cell cell, int size) {
    const offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    final neighbors = <Cell>[];
    for (final (dr, dc) in offsets) {
      final nr = cell.row + dr;
      final nc = cell.column + dc;
      if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
        neighbors.add(Cell(row: nr, column: nc));
      }
    }
    return neighbors;
  }

  /// DFS version for path-preservation independence test (T-PATH-006).
  static bool canReachGoalDfs({
    required Cell from,
    required int goalRow,
    required List<Wall> walls,
    required int size,
  }) {
    if (from.row == goalRow) return true;
    final blocked = _buildBlockedEdges(walls, size);
    final visited = <_CellKey>{};
    return _dfsVisit(from, goalRow, blocked, visited, size);
  }

  static bool _dfsVisit(
    Cell current,
    int goalRow,
    Set<(_CellKey, _CellKey)> blocked,
    Set<_CellKey> visited,
    int size,
  ) {
    final ck = _CellKey(current.row, current.column);
    if (visited.contains(ck)) return false;
    if (current.row == goalRow) return true;
    visited.add(ck);
    for (final neighbor in _orthogonalNeighbors(current, size)) {
      if (_isEdgeBlocked(current, neighbor, blocked)) continue;
      if (_dfsVisit(neighbor, goalRow, blocked, visited, size)) return true;
    }
    return false;
  }
}

/// Hashable cell key for set-based edge lookup.
class _CellKey {
  const _CellKey(this.row, this.column);
  final int row;
  final int column;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CellKey &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          column == other.column;

  @override
  int get hashCode => Object.hash(row, column);
}
