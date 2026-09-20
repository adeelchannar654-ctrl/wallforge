import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/wall_orientation.dart';

/// Parses and serializes actions using the spec §16 action notation.
///
/// Format examples: "m3,4" "j3,5" "wh2,3" "wv3,4"
class ActionNotation {
  /// Parses an action string into a [GameAction].
  static GameAction? parse(String notation) {
    if (notation.isEmpty) return null;

    final first = notation[0];
    final rest = notation.substring(1);

    switch (first) {
      case 'm':
        final cell = _parseCell(rest);
        if (cell == null) return null;
        return MoveAction(target: cell);
      case 'j':
        final cell = _parseCell(rest);
        if (cell == null) return null;
        return JumpAction(target: cell);
      case 'w':
        if (rest.isEmpty) return null;
        final orientChar = rest[0];
        final cellStr = rest.substring(1);
        final cell = _parseCell(cellStr);
        if (cell == null) return null;
        final orientation = orientChar == 'h'
            ? WallOrientation.horizontal
            : orientChar == 'v'
            ? WallOrientation.vertical
            : null;
        if (orientation == null) return null;
        return PlaceWallAction(origin: cell, orientation: orientation);
      default:
        return null;
    }
  }

  /// Serializes a [GameAction] to its notation string.
  static String serialize(GameAction action) {
    if (action is MoveAction) {
      return 'm${action.target.col},${action.target.row}';
    } else if (action is JumpAction) {
      return 'j${action.target.col},${action.target.row}';
    } else if (action is PlaceWallAction) {
      final orientChar = action.orientation == WallOrientation.horizontal
          ? 'h'
          : 'v';
      return 'w$orientChar${action.origin.col},${action.origin.row}';
    }
    return '';
  }

  static Cell? _parseCell(String s) {
    final parts = s.split(',');
    if (parts.length != 2) return null;
    final col = int.tryParse(parts[0]);
    final row = int.tryParse(parts[1]);
    if (col == null || row == null) return null;
    return Cell(col: col, row: row);
  }
}
