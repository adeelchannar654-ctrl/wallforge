import '../models/cell.dart';

/// Immutable hashable edge between two cells, used for wall-blocked-edge sets.
class BoardEdge {
  /// Creates an edge between [a] and [b].
  const BoardEdge(this.a, this.b);

  /// First endpoint.
  final Cell a;

  /// Second endpoint.
  final Cell b;

  /// The canonical (sorted) representation for deduplication.
  (Cell, Cell) get canonical {
    if (a.row < b.row || (a.row == b.row && a.col < b.col)) {
      return (a, b);
    }
    return (b, a);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardEdge &&
          runtimeType == other.runtimeType &&
          a == other.a &&
          b == other.b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => 'BoardEdge($a, $b)';
}
