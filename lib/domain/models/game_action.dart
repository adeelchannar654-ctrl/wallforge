import 'dart:convert';

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
      final orient = orientStr == 'H' ? WallOrientation.h : WallOrientation.v;
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

  /// Parses an action from its spec §7.2 JSON object.
  ///
  /// Never throws: malformed input yields an [ActionParseFailure].
  static ActionParseResult fromJson(Map<String, dynamic> json) {
    try {
      final type = json['type'];

      if (type == 'move') {
        final problem = _unknownKeys(json, const {'type', 'destination'});
        if (problem != null) return ActionParseFailure(problem);
        final destination = json['destination'];
        final (cell, cellProblem) = _readCell(destination, 'destination');
        if (cellProblem != null) return ActionParseFailure(cellProblem);
        return ActionParseResult.success(GameAction.move(cell!));
      }

      if (type == 'wall') {
        final problem = _unknownKeys(json, const {
          'type',
          'orientation',
          'anchor',
        });
        if (problem != null) return ActionParseFailure(problem);
        final orientStr = json['orientation'];
        if (orientStr is! String) {
          return const ActionParseFailure('wall.orientation must be a string');
        }
        final upper = orientStr.toUpperCase();
        if (upper != 'H' && upper != 'V') {
          return const ActionParseFailure(
            'wall.orientation must be "H" or "V"',
          );
        }
        final (anchor, anchorProblem) = _readCell(json['anchor'], 'anchor');
        if (anchorProblem != null) return ActionParseFailure(anchorProblem);
        return ActionParseResult.success(
          GameAction.wall(
            orientation: upper == 'H' ? WallOrientation.h : WallOrientation.v,
            anchor: anchor!,
          ),
        );
      }

      return const ActionParseFailure('type must be "move" or "wall"');
    } catch (error) {
      return ActionParseFailure('malformed action JSON: $error');
    }
  }

  /// Parses an action from a JSON string.
  static ActionParseResult decode(String jsonStr) {
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is! Map<String, dynamic>) {
        return const ActionParseFailure('action JSON must be an object');
      }
      return fromJson(parsed);
    } catch (error) {
      return ActionParseFailure('malformed action JSON: $error');
    }
  }

  /// Serializes this action to its spec §7.2 JSON object.
  Map<String, dynamic> toJson() => switch (this) {
    MoveAction(:final destination) => {
      'type': 'move',
      'destination': {'row': destination.row, 'column': destination.column},
    },
    WallAction(:final orientation, :final anchor) => {
      'type': 'wall',
      'orientation': orientation.name.toUpperCase(),
      'anchor': {'row': anchor.row, 'column': anchor.column},
    },
  };

  /// Returns the spec notation for this action.
  String toNotation() => switch (this) {
    MoveAction(:final destination) =>
      'M ${destination.row},${destination.column}',
    WallAction(:final orientation, :final anchor) =>
      'W ${orientation.name.toUpperCase()} ${anchor.row},${anchor.column}',
  };
}

/// Result of parsing a [GameAction] from JSON.
sealed class ActionParseResult {
  const ActionParseResult._();

  /// Successful parse.
  factory ActionParseResult.success(GameAction action) = ActionParseSuccess;

  /// Failed parse with a human-readable [detail].
  factory ActionParseResult.failure(String detail) = ActionParseFailure;

  /// The parsed action when successful, otherwise `null`.
  GameAction? get actionOrNull => switch (this) {
    ActionParseSuccess(:final action) => action,
    ActionParseFailure() => null,
  };
}

/// Successful action parse.
class ActionParseSuccess extends ActionParseResult {
  /// Creates a successful parse result.
  const ActionParseSuccess(this.action) : super._();

  /// The parsed action.
  final GameAction action;
}

/// Failed action parse.
class ActionParseFailure extends ActionParseResult {
  /// Creates a failed parse result.
  const ActionParseFailure(this.detail) : super._();

  /// Human-readable explanation of the failure.
  final String detail;

  @override
  String toString() => 'ActionParseFailure($detail)';
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
  const WallAction({required this.orientation, required this.anchor})
    : super._();

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

(Cell?, String?) _readCell(Object? value, String where) {
  if (value is! Map<String, dynamic>) {
    return (null, '$where must be an object');
  }
  final row = value['row'];
  final column = value['column'];
  if (row is! int || column is! int) {
    return (null, '$where requires integer row and column');
  }
  return (Cell(row: row, column: column), null);
}

String? _unknownKeys(Map<String, dynamic> json, Set<String> allowed) {
  final unknown = json.keys.where((key) => !allowed.contains(key)).toList()
    ..sort();
  if (unknown.isEmpty) return null;
  return 'unknown field(s): $unknown';
}
