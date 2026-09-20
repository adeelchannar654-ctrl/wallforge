import 'player_id.dart';
import 'wall_orientation.dart';

/// Immutable wall on the board.
///
/// Mirrors spec §3.6 R-WALL-03: identified by (anchorRow, anchorColumn, orientation, owner).
class Wall {
  /// Creates a wall.
  const Wall({
    required this.anchorRow,
    required this.anchorColumn,
    required this.orientation,
    required this.owner,
  });

  /// Row coordinate of the wall anchor.
  final int anchorRow;

  /// Column coordinate of the wall anchor.
  final int anchorColumn;

  /// Horizontal or vertical orientation.
  final WallOrientation orientation;

  /// Owner of the wall.
  final PlayerId owner;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Wall &&
          runtimeType == other.runtimeType &&
          anchorRow == other.anchorRow &&
          anchorColumn == other.anchorColumn &&
          orientation == other.orientation &&
          owner == other.owner;

  @override
  int get hashCode => Object.hash(anchorRow, anchorColumn, orientation, owner);

  @override
  String toString() =>
      'Wall(${orientation.name.toUpperCase()}($anchorRow, $anchorColumn), $owner)';
}
