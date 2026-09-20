import 'cell.dart';
import 'wall_orientation.dart';

/// Discriminated union of all player actions.
///
/// Mirrors spec §4.7.
abstract class GameAction {
  const GameAction._();
}

/// Move pawn to an adjacent cell.
class MoveAction extends GameAction {
  /// Creates a move action to [target].
  const MoveAction({required this.target}) : super._();

  /// Destination cell.
  final Cell target;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveAction &&
          runtimeType == other.runtimeType &&
          target == other.target;

  @override
  int get hashCode => Object.hash(runtimeType, target);

  @override
  String toString() => 'MoveAction($target)';
}

/// Jump over opponent onto the cell beyond them.
class JumpAction extends GameAction {
  /// Creates a jump action to [target].
  const JumpAction({required this.target}) : super._();

  /// Destination cell.
  final Cell target;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JumpAction &&
          runtimeType == other.runtimeType &&
          target == other.target;

  @override
  int get hashCode => Object.hash(runtimeType, target);

  @override
  String toString() => 'JumpAction($target)';
}

/// Place a wall on the board.
class PlaceWallAction extends GameAction {
  /// Creates a wall placement action.
  const PlaceWallAction({required this.origin, required this.orientation})
    : super._();

  /// Top-left cell of the wall footprint.
  final Cell origin;

  /// Wall orientation.
  final WallOrientation orientation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceWallAction &&
          runtimeType == other.runtimeType &&
          origin == other.origin &&
          orientation == other.orientation;

  @override
  int get hashCode => Object.hash(runtimeType, origin, orientation);

  @override
  String toString() => 'PlaceWallAction($origin, $orientation)';
}
