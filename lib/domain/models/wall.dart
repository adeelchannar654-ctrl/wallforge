import 'cell.dart';
import 'wall_orientation.dart';

/// Immutable wall on the board.
///
/// Mirrors spec §4.4: walls span 2 tiles and block adjacency between 4 cells.
class Wall {
  /// Creates a wall at [origin] with the given [orientation].
  const Wall({required this.origin, required this.orientation});

  /// Anchor cell of the wall footprint.
  final Cell origin;

  /// Horizontal or vertical orientation.
  final WallOrientation orientation;

  /// Returns the two cells under the wall footprint.
  List<Cell> get footprint => switch (orientation) {
    WallOrientation.horizontal => [
      origin,
      Cell(col: origin.col + 1, row: origin.row),
    ],
    WallOrientation.vertical => [
      origin,
      Cell(col: origin.col, row: origin.row + 1),
    ],
  };

  /// Returns the two adjacency-pairs this wall blocks.
  ///
  /// A vertical wall at (col, row) blocks horizontal movement between:
  /// - (col, row) ↔ (col+1, row)
  /// - (col, row+1) ↔ (col+1, row+1)
  ///
  /// A horizontal wall at (col, row) blocks vertical movement between:
  /// - (col, row) ↔ (col, row+1)
  /// - (col+1, row) ↔ (col+1, row+1)
  List<(Cell, Cell)> get blockedEdges => switch (orientation) {
    WallOrientation.horizontal => [
      (
        Cell(col: origin.col, row: origin.row),
        Cell(col: origin.col, row: origin.row + 1),
      ),
      (
        Cell(col: origin.col + 1, row: origin.row),
        Cell(col: origin.col + 1, row: origin.row + 1),
      ),
    ],
    WallOrientation.vertical => [
      (
        Cell(col: origin.col, row: origin.row),
        Cell(col: origin.col + 1, row: origin.row),
      ),
      (
        Cell(col: origin.col, row: origin.row + 1),
        Cell(col: origin.col + 1, row: origin.row + 1),
      ),
    ],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wall &&
          runtimeType == other.runtimeType &&
          origin == other.origin &&
          orientation == other.orientation;

  @override
  int get hashCode => Object.hash(origin, orientation);

  @override
  String toString() => 'Wall($origin, $orientation)';
}
