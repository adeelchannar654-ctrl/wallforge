/// Immutable grid coordinate: (row, column).
///
/// Mirrors spec §3.1 R-BOARD-02: zero-based, row 0 is top, column 0 is left.
class Cell {
  /// Creates a cell at [row], [column].
  const Cell({required this.row, required this.column});

  /// Row index (y). 0 = top edge.
  final int row;

  /// Column index (x). 0 = left edge.
  final int column;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          column == other.column;

  @override
  int get hashCode => Object.hash(row, column);

  @override
  String toString() => '($row, $column)';
}
