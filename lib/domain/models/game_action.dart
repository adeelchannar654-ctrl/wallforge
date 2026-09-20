import 'cell.dart';
import 'wall_orientation.dart';

/// Discriminated union of all player actions.
///
/// Mirrors spec §4: exactly two types — move or wall.
sealed class GameAction {
  const GameAction._();

  /// Creates a move action to [destination].
  const factory GameAction.move(Cell destination) = MoveAction;

  /// Creates a wall action with [orientation] at [anchor].
  const factory GameAction.wall({
    required WallOrientation orientation,
    required Cell anchor,
  }) = WallAction;

  /// Parses an action from spec notation.
  ///
  /// Format: "M r,c" or "W H r,c" or "W V r,c".
  /// Returns null if the string is malformed.
  static GameAction? parse(String notation) {
    final parts = notation.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;

    if (parts[0] == 'M' && parts.length == 2) {
      final coords = parts[1].split(',');
      if (coords.length != 2) return null;
      final row = int.tryParse(coords[0]);
      final col = int.tryParse(coords[1]);
      if (row == null || col == null) return null;
      return GameAction.move(Cell(row: row, column: col));
    }

    if (parts[0] == 'W' && parts.length == 3) {
      final orientStr = parts[1].toUpperCase();
      if (orientStr != 'H' && orientStr != 'V') return null;
      final orient = orientStr == 'H'
          ? WallOrientation.h
          : WallOrientation.v;
      final coords = parts[2].split(',');
      if (coords.length != 2) return null;
      final row = int.tryParse(coords[0]);
      final col = int.tryParse(coords[1]);
      if (row == null || col == null) return null;
      return GameAction.wall(
        orientation: orient,
        anchor: Cell(row: row, column: col),
      );
    }

    return null;
  }

  /// Returns the spec notation for this action.
  String toNotation() => switch (this) {
    MoveAction(:final destination) => 'M ${destination.row},${destination.column}',
    WallAction(:final orientation, :final anchor) =>
      'W ${orientation.name.toUpperCase()} ${anchor.row},${anchor.column}',
  };
}

/// Move action: pawn moves to a destination cell.
class MoveAction extends GameAction {
  /// Creates a move action to [destination].
  const MoveAction(this.destination) : super._();

  /// Destination cell.
  final Cell destination;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoveAction &&
          runtimeType == other.runtimeType &&
          destination == other.destination;

  @override
  int get hashCode => Object.hash(runtimeType, destination);

  @override
  String toString() => 'MoveAction($destination)';
}

/// Wall action: place a wall at an anchor with given orientation.
class WallAction extends GameAction {
  /// Creates a wall action.
  const WallAction({
    required this.orientation,
    required this.anchor,
  }) : super._();

  /// Wall orientation.
  final WallOrientation orientation;

  /// Anchor cell.
  final Cell anchor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WallAction &&
          runtimeType == other.runtimeType &&
          orientation == other.orientation &&
          anchor == other.anchor;

  @override
  int get hashCode => Object.hash(runtimeType, orientation, anchor);

  @override
  String toString() => 'WallAction(${orientation.name.toUpperCase()}, $anchor)';
}
