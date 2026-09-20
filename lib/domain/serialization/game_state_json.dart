import '../models/board_config.dart';
import '../models/cell.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';

/// JSON serialization for [GameState].
///
/// Mirrors spec §16 (serialization format).
class GameStateJson {
  /// Deserializes a [GameState] from a JSON map.
  static GameState fromJson(Map<String, dynamic> json) {
    final boardJson = json['board'] as Map<String, dynamic>;
    final config = BoardConfig(
      rows: boardJson['rows'] as int,
      cols: boardJson['cols'] as int,
      totalWalls: boardJson['totalWalls'] as int,
      maxWallsPerPlayer: boardJson['maxWallsPerPlayer'] as int,
    );

    final blueJson = json['blue'] as Map<String, dynamic>;
    final redJson = json['red'] as Map<String, dynamic>;

    final bluePawn = _cellFromJson(blueJson['pawn'] as Map<String, dynamic>);
    final redPawn = _cellFromJson(redJson['pawn'] as Map<String, dynamic>);

    final wallsJson = json['walls'] as List<dynamic>;
    final walls = wallsJson
        .map((w) => _wallFromJson(w as Map<String, dynamic>))
        .toList();

    final blueWallsRemaining = blueJson['wallsRemaining'] as int;
    final redWallsRemaining = redJson['wallsRemaining'] as int;

    final activePlayerName = json['activePlayer'] as String;
    final activePlayer = activePlayerName == 'blue'
        ? PlayerId.blue
        : PlayerId.red;

    final statusName = json['status'] as String;
    final status = GameStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => GameStatus.active,
    );

    final moveCount = json['moveCount'] as int;

    return GameState(
      config: config,
      bluePawn: bluePawn,
      redPawn: redPawn,
      walls: walls,
      blueWallsRemaining: blueWallsRemaining,
      redWallsRemaining: redWallsRemaining,
      activePlayer: activePlayer,
      status: status,
      moveCount: moveCount,
    );
  }

  /// Serializes a [GameState] to a JSON map.
  static Map<String, dynamic> toJson(GameState state) {
    return {
      'board': {
        'rows': state.config.rows,
        'cols': state.config.cols,
        'totalWalls': state.config.totalWalls,
        'maxWallsPerPlayer': state.config.maxWallsPerPlayer,
      },
      'blue': {
        'pawn': _cellToJson(state.bluePawn),
        'wallsRemaining': state.blueWallsRemaining,
      },
      'red': {
        'pawn': _cellToJson(state.redPawn),
        'wallsRemaining': state.redWallsRemaining,
      },
      'walls': state.walls.map(_wallToJson).toList(),
      'activePlayer': state.activePlayer.name,
      'status': state.status.name,
      'moveCount': state.moveCount,
    };
  }

  static Cell _cellFromJson(Map<String, dynamic> json) {
    return Cell(col: json['col'] as int, row: json['row'] as int);
  }

  static Map<String, dynamic> _cellToJson(Cell cell) {
    return {'col': cell.col, 'row': cell.row};
  }

  static Wall _wallFromJson(Map<String, dynamic> json) {
    final origin = _cellFromJson(json['origin'] as Map<String, dynamic>);
    final orientationName = json['orientation'] as String;
    final orientation = orientationName == 'horizontal'
        ? WallOrientation.horizontal
        : WallOrientation.vertical;
    return Wall(origin: origin, orientation: orientation);
  }

  static Map<String, dynamic> _wallToJson(Wall wall) {
    return {
      'origin': _cellToJson(wall.origin),
      'orientation': wall.orientation.name,
    };
  }
}
