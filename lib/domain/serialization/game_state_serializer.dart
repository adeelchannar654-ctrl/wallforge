import 'dart:convert';

import '../models/board_config.dart';
import '../models/cell.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';

/// Serialization helpers for GameState ↔ JSON.
///
/// Mirrors spec §7: JSON schema and R-SERIAL-01..03.
class GameStateSerializer {
  static const _schemaVersion = 1;

  /// Serializes [state] to a JSON-encodable Map.
  static Map<String, dynamic> toJson(GameState state) {
    return {
      'schemaVersion': _schemaVersion,
      'boardConfig': {
        'size': state.boardConfig.size,
        'wallsPerPlayer': state.boardConfig.wallsPerPlayer,
      },
      'players': ['blue', 'red'],
      'currentPlayer': state.currentPlayer.name,
      'pawnPositions': {
        'blue': {
          'row': state.pawnPosition(PlayerId.blue).row,
          'column': state.pawnPosition(PlayerId.blue).column,
        },
        'red': {
          'row': state.pawnPosition(PlayerId.red).row,
          'column': state.pawnPosition(PlayerId.red).column,
        },
      },
      'walls': [
        for (final w in state.walls)
          {
            'owner': w.owner.name,
            'orientation': w.orientation.name.toUpperCase(),
            'anchor': {'row': w.anchorRow, 'column': w.anchorColumn},
          },
      ],
      'remainingWalls': {
        'blue': state.wallsRemaining(PlayerId.blue),
        'red': state.wallsRemaining(PlayerId.red),
      },
      'turnNumber': state.turnNumber,
      'status': state.status == GameStatus.inProgress
          ? 'inProgress'
          : 'finished',
      'winner': state.winner?.name,
    };
  }

  /// Deserializes a JSON Map to a [GameState].
  ///
  /// Returns null on malformed input (R-SERIAL-02).
  /// Rejects unknown schemaVersion (R-SERIAL-01).
  static GameState? fromJson(Map<String, dynamic> json) {
    try {
      final sv = json['schemaVersion'];
      if (sv != _schemaVersion) return null;

      final bc = json['boardConfig'] as Map<String, dynamic>;
      final config = BoardConfig(
        size: bc['size'] as int,
        wallsPerPlayer: bc['wallsPerPlayer'] as int,
      );

      final pp = json['pawnPositions'] as Map<String, dynamic>;
      final bluePos = pp['blue'] as Map<String, dynamic>;
      final redPos = pp['red'] as Map<String, dynamic>;
      final pawnPositions = {
        PlayerId.blue: Cell(
          row: bluePos['row'] as int,
          column: bluePos['column'] as int,
        ),
        PlayerId.red: Cell(
          row: redPos['row'] as int,
          column: redPos['column'] as int,
        ),
      };

      final wallsJson = json['walls'] as List;
      final walls = wallsJson.map((w) {
        final m = w as Map<String, dynamic>;
        final anchor = m['anchor'] as Map<String, dynamic>;
        return Wall(
          owner: PlayerId.values.byName(m['owner'] as String),
          orientation:
              WallOrientation.values.byName((m['orientation'] as String).toLowerCase()),
          anchorRow: anchor['row'] as int,
          anchorColumn: anchor['column'] as int,
        );
      }).toList();

      final rw = json['remainingWalls'] as Map<String, dynamic>;
      final remainingWalls = {
        PlayerId.blue: rw['blue'] as int,
        PlayerId.red: rw['red'] as int,
      };

      final statusStr = json['status'] as String;
      final status = statusStr == 'inProgress'
          ? GameStatus.inProgress
          : GameStatus.finished;

      final winnerStr = json['winner'] as String?;
      final winner =
          winnerStr != null ? PlayerId.values.byName(winnerStr) : null;

      return GameState(
        boardConfig: config,
        pawnPositions: pawnPositions,
        walls: walls,
        remainingWalls: remainingWalls,
        turnNumber: json['turnNumber'] as int,
        status: status,
        winner: winner,
      );
    } catch (_) {
      return null;
    }
  }

  /// Encodes [state] to a JSON string.
  static String encode(GameState state) => jsonEncode(toJson(state));

  /// Decodes a JSON string to a [GameState].
  static GameState? decode(String jsonStr) {
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is! Map<String, dynamic>) return null;
      return fromJson(parsed);
    } catch (_) {
      return null;
    }
  }
}
