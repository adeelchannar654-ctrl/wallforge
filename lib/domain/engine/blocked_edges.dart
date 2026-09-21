import 'dart:collection';

import '../models/cell.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';

/// Immutable set of blocked cell-to-cell edges for one board.
///
/// A single [Wall] blocks exactly two unit edges (spec §3.6 / R-WALL-04):
/// * `H(r,c)` blocks `(r,c)-(r+1,c)` and `(r,c+1)-(r+1,c+1)`.
/// * `V(r,c)` blocks `(r,c)-(r,c+1)` and `(r+1,c)-(r+1,c+1)`.
///
/// This is the **single** implementation of wall blocking geometry; the
/// pathfinder, the action validator and the jump logic all use it so the
/// three can never drift apart.
class BlockedEdges {
  BlockedEdges._(this._edges, this._size);

  /// Builds the blocked-edge set for [walls] on a `size x size` board.
  factory BlockedEdges.fromWalls(Iterable<Wall> walls, int size) {
    final edges = HashSet<(Cell, Cell)>();
    for (final wall in walls) {
      final r = wall.anchorRow;
      final c = wall.anchorColumn;
      if (wall.orientation == WallOrientation.h) {
        _add(edges, r, c, r + 1, c);
        _add(edges, r, c + 1, r + 1, c + 1);
      } else {
        _add(edges, r, c, r, c + 1);
        _add(edges, r + 1, c, r + 1, c + 1);
      }
    }
    return BlockedEdges._(edges, size);
  }

  final HashSet<(Cell, Cell)> _edges;
  final int _size;

  /// Whether the unit edge between the orthogonally adjacent cells [a] and [b]
  /// is blocked by a wall.
  bool isBlocked(Cell a, Cell b) => _edges.contains((a, b));

  /// The orthogonal neighbours of [cell] that stay on the board.
  ///
  /// Order is up, down, left, right — matching the original engine so results
  /// are byte-for-byte identical.
  List<Cell> neighborsOf(Cell cell) {
    final result = <Cell>[];
    for (final (dr, dc) in _offsets) {
      final nr = cell.row + dr;
      final nc = cell.column + dc;
      if (nr >= 0 && nr < _size && nc >= 0 && nc < _size) {
        result.add(Cell(row: nr, column: nc));
      }
    }
    return result;
  }

  static const List<(int, int)> _offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)];

  static void _add(
    HashSet<(Cell, Cell)> edges,
    int r1,
    int c1,
    int r2,
    int c2,
  ) {
    final a = Cell(row: r1, column: c1);
    final b = Cell(row: r2, column: c2);
    edges.add((a, b));
    edges.add((b, a));
  }
}
