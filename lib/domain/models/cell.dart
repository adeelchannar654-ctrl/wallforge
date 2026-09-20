/// Immutable grid coordinate.
///
/// Mirrors spec §4.1: (col, row) with (0,0) top-left.
/// Row 0 = Blue start, row H-1 = Red start.
class Cell {
  /// Creates a cell at [col], [row].
  const Cell({required this.col, required this.row});

  /// Column index (x).
  final int col;

  /// Row index (y).
  final int row;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          runtimeType == other.runtimeType &&
          col == other.col &&
          row == other.row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => 'Cell($col,$row)';
}
