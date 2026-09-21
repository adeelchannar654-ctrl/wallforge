import 'dart:convert';

import '../engine/pathfinder.dart';
import '../models/board_config.dart';
import '../models/cell.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';
import 'deserialization_result.dart';

/// Serialization helpers for GameState ↔ JSON.
///
/// Mirrors spec §7: JSON schema and R-SERIAL-01..03.
///
/// [toJson] key order is fixed and documented by [_expectedKeys]; [fromJson]
/// rejects unknown or missing keys, invalid enums, invalid board config and any
/// violation of the state invariants (R-STATE-01..05). Failures are returned as
/// a [DeserializationResult]; no exception escapes.
class GameStateSerializer {
  static const int _schemaVersion = 1;

  /// Exact key set expected in a serialized game state.
  static const Set<String> _expectedKeys = {
    'schemaVersion',
    'boardConfig',
    'players',
    'currentPlayer',
    'pawnPositions',
    'walls',
    'remainingWalls',
    'turnNumber',
    'status',
    'winner',
  };

  /// Serializes [state] to a JSON-encodable Map.
  ///
  /// Key order (stable): schemaVersion, boardConfig{size, wallsPerPlayer},
  /// players, currentPlayer, pawnPositions{blue,red}, walls,
  /// remainingWalls{blue,red}, turnNumber, status, winner.
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
  /// Returns a [DeserializationSuccess] or a [DeserializationFailure]; never
  /// returns `null` and never throws.
  static DeserializationResult fromJson(Map<String, dynamic> json) {
    try {
      final keys = json.keys.toSet();

      final unknown = keys.difference(_expectedKeys).toList()..sort();
      if (unknown.isNotEmpty) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'unknown field(s): $unknown',
        );
      }

      // schemaVersion is checked before the remaining fields so that an
      // unsupported but otherwise well-formed payload is reported as
      // unsupportedSchemaVersion (R-SERIAL-01), not as a missing-field error.
      final schemaVersion = json['schemaVersion'];
      if (schemaVersion is! int) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'schemaVersion must be an integer',
        );
      }
      if (schemaVersion != _schemaVersion) {
        return DeserializationResult.failure(
          DeserializationFailureReason.unsupportedSchemaVersion,
          'schemaVersion $schemaVersion is not supported '
          '(expected $_schemaVersion)',
        );
      }

      final missing = _expectedKeys.difference(keys).toList()..sort();
      if (missing.isNotEmpty) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'missing field(s): $missing',
        );
      }

      // --- boardConfig -----------------------------------------------------
      final bc = json['boardConfig'];
      if (bc is! Map<String, dynamic>) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'boardConfig must be an object',
        );
      }
      final size = bc['size'];
      final wallsPerPlayer = bc['wallsPerPlayer'];
      if (size is! int || wallsPerPlayer is! int) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'boardConfig.size and boardConfig.wallsPerPlayer must be integers',
        );
      }
      final configFailure = BoardConfig.check(size, wallsPerPlayer);
      if (configFailure != null) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invalidConfig,
          configFailure.message,
        );
      }
      final config = BoardConfig(size: size, wallsPerPlayer: wallsPerPlayer);

      // --- players ---------------------------------------------------------
      final players = json['players'];
      if (players is! List<Object?> ||
          players.length != 2 ||
          players[0] != 'blue' ||
          players[1] != 'red') {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'players must be exactly ["blue", "red"]',
        );
      }

      // --- turnNumber ------------------------------------------------------
      final turnNumber = json['turnNumber'];
      if (turnNumber is! int || turnNumber < 0) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'turnNumber must be a non-negative integer',
        );
      }

      // --- status ----------------------------------------------------------
      final statusStr = json['status'];
      final GameStatus status;
      if (statusStr == 'inProgress') {
        status = GameStatus.inProgress;
      } else if (statusStr == 'finished') {
        status = GameStatus.finished;
      } else {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'status must be "inProgress" or "finished"',
        );
      }

      // --- winner ----------------------------------------------------------
      final winnerStr = json['winner'];
      final PlayerId? winner;
      if (winnerStr == null) {
        winner = null;
      } else if (winnerStr == 'blue') {
        winner = PlayerId.blue;
      } else if (winnerStr == 'red') {
        winner = PlayerId.red;
      } else {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'winner must be "blue", "red" or null',
        );
      }

      // --- currentPlayer (R-STATE-05) --------------------------------------
      final currentStr = json['currentPlayer'];
      if (currentStr is! String ||
          (currentStr != 'blue' && currentStr != 'red')) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'currentPlayer must be "blue" or "red"',
        );
      }
      final current = currentStr == 'blue' ? PlayerId.blue : PlayerId.red;
      final expectedCurrent = turnNumber.isEven ? PlayerId.blue : PlayerId.red;
      if (current != expectedCurrent) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'currentPlayer $currentStr does not match turnNumber parity '
          '(${expectedCurrent.name})',
        );
      }

      // --- pawnPositions ---------------------------------------------------
      final pp = json['pawnPositions'];
      if (pp is! Map<String, dynamic>) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'pawnPositions must be an object',
        );
      }
      final (blueCell, blueProblem) = _readCell(
        pp['blue'],
        'pawnPositions.blue',
      );
      if (blueProblem != null) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          blueProblem,
        );
      }
      final (redCell, redProblem) = _readCell(pp['red'], 'pawnPositions.red');
      if (redProblem != null) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          redProblem,
        );
      }
      final bluePos = blueCell!;
      final redPos = redCell!;

      if (!_onBoard(bluePos, size) || !_onBoard(redPos, size)) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'pawn position is off the board',
        );
      }
      if (bluePos == redPos) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'both pawns occupy the same cell',
        );
      }

      // --- walls -----------------------------------------------------------
      final wallsJson = json['walls'];
      if (wallsJson is! List<Object?>) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'walls must be an array',
        );
      }
      final walls = <Wall>[];
      for (var i = 0; i < wallsJson.length; i++) {
        final entry = wallsJson[i];
        if (entry is! Map<String, dynamic>) {
          return DeserializationResult.failure(
            DeserializationFailureReason.malformed,
            'walls[$i] must be an object',
          );
        }
        final ownerStr = entry['owner'];
        final PlayerId owner;
        if (ownerStr == 'blue') {
          owner = PlayerId.blue;
        } else if (ownerStr == 'red') {
          owner = PlayerId.red;
        } else {
          return DeserializationResult.failure(
            DeserializationFailureReason.malformed,
            'walls[$i].owner must be "blue" or "red"',
          );
        }

        final orientStr = entry['orientation'];
        if (orientStr is! String) {
          return DeserializationResult.failure(
            DeserializationFailureReason.malformed,
            'walls[$i].orientation must be a string',
          );
        }
        final orientUpper = orientStr.toUpperCase();
        final WallOrientation orientation;
        if (orientUpper == 'H') {
          orientation = WallOrientation.h;
        } else if (orientUpper == 'V') {
          orientation = WallOrientation.v;
        } else {
          return DeserializationResult.failure(
            DeserializationFailureReason.malformed,
            'walls[$i].orientation must be "H" or "V"',
          );
        }

        final (anchor, anchorProblem) = _readCell(
          entry['anchor'],
          'walls[$i].anchor',
        );
        if (anchorProblem != null) {
          return DeserializationResult.failure(
            DeserializationFailureReason.malformed,
            anchorProblem,
          );
        }
        final a = anchor!;
        if (a.row < 0 ||
            a.row > config.maxAnchor ||
            a.column < 0 ||
            a.column > config.maxAnchor) {
          return DeserializationResult.failure(
            DeserializationFailureReason.invariantViolation,
            'walls[$i] anchor is out of bounds',
          );
        }
        walls.add(
          Wall(
            anchorRow: a.row,
            anchorColumn: a.column,
            orientation: orientation,
            owner: owner,
          ),
        );
      }

      final geometryProblem = _checkWallGeometry(walls);
      if (geometryProblem != null) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          geometryProblem,
        );
      }

      // --- remainingWalls --------------------------------------------------
      final rw = json['remainingWalls'];
      if (rw is! Map<String, dynamic>) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'remainingWalls must be an object',
        );
      }
      final blueRemaining = rw['blue'];
      final redRemaining = rw['red'];
      if (blueRemaining is! int || redRemaining is! int) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'remainingWalls.blue and remainingWalls.red must be integers',
        );
      }
      if (blueRemaining < 0 || redRemaining < 0) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'remaining walls must be non-negative',
        );
      }
      final bluePlaced = walls.where((w) => w.owner == PlayerId.blue).length;
      final redPlaced = walls.where((w) => w.owner == PlayerId.red).length;
      if (blueRemaining + bluePlaced != config.wallsPerPlayer) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'blue inventory inconsistent: $blueRemaining remaining + '
          '$bluePlaced placed != ${config.wallsPerPlayer}',
        );
      }
      if (redRemaining + redPlaced != config.wallsPerPlayer) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'red inventory inconsistent: $redRemaining remaining + '
          '$redPlaced placed != ${config.wallsPerPlayer}',
        );
      }

      // --- status <-> winner ----------------------------------------------
      if (status == GameStatus.inProgress && winner != null) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'winner set while status is inProgress',
        );
      }
      if (status == GameStatus.finished && winner == null) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'status finished requires a winner',
        );
      }

      // --- goal-row invariants (R-WIN-01/05) -------------------------------
      if (bluePos.row == config.blueGoalRow &&
          (status != GameStatus.finished || winner != PlayerId.blue)) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'blue pawn is on its goal row but the match is not finished with '
          'blue as winner',
        );
      }
      if (redPos.row == config.redGoalRow &&
          (status != GameStatus.finished || winner != PlayerId.red)) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'red pawn is on its goal row but the match is not finished with '
          'red as winner',
        );
      }

      // --- both players must still have a route (R-PATH-01) -----------------
      if (!Pathfinder.canReachGoal(
        from: bluePos,
        goalRow: config.blueGoalRow,
        walls: walls,
        size: size,
      )) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'blue has no route to its goal',
        );
      }
      if (!Pathfinder.canReachGoal(
        from: redPos,
        goalRow: config.redGoalRow,
        walls: walls,
        size: size,
      )) {
        return DeserializationResult.failure(
          DeserializationFailureReason.invariantViolation,
          'red has no route to its goal',
        );
      }

      final state = GameState(
        boardConfig: config,
        pawnPositions: {PlayerId.blue: bluePos, PlayerId.red: redPos},
        walls: walls,
        remainingWalls: {
          PlayerId.blue: blueRemaining,
          PlayerId.red: redRemaining,
        },
        turnNumber: turnNumber,
        status: status,
        winner: winner,
      );
      return DeserializationResult.success(state);
    } catch (error) {
      return DeserializationResult.failure(
        DeserializationFailureReason.malformed,
        'malformed game state JSON: $error',
      );
    }
  }

  /// Encodes [state] to a JSON string.
  static String encode(GameState state) => jsonEncode(toJson(state));

  /// Decodes a JSON string to a [DeserializationResult].
  static DeserializationResult decode(String jsonStr) {
    try {
      final parsed = jsonDecode(jsonStr);
      if (parsed is! Map<String, dynamic>) {
        return DeserializationResult.failure(
          DeserializationFailureReason.malformed,
          'top-level JSON value must be an object',
        );
      }
      return fromJson(parsed);
    } catch (error) {
      return DeserializationResult.failure(
        DeserializationFailureReason.malformed,
        'malformed JSON: $error',
      );
    }
  }

  static bool _onBoard(Cell cell, int size) =>
      cell.row >= 0 &&
      cell.row < size &&
      cell.column >= 0 &&
      cell.column < size;

  static (Cell?, String?) _readCell(Object? value, String where) {
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

  /// Returns a problem description if any two walls overlap or cross.
  static String? _checkWallGeometry(Iterable<Wall> walls) {
    final list = walls.toList(growable: false);
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i];
        final b = list[j];
        if (a.orientation == b.orientation) {
          if (a.orientation == WallOrientation.h) {
            if (a.anchorRow == b.anchorRow &&
                (a.anchorColumn - b.anchorColumn).abs() <= 1) {
              return 'walls[$i] and walls[$j] overlap';
            }
          } else {
            if (a.anchorColumn == b.anchorColumn &&
                (a.anchorRow - b.anchorRow).abs() <= 1) {
              return 'walls[$i] and walls[$j] overlap';
            }
          }
        } else if (a.anchorRow == b.anchorRow &&
            a.anchorColumn == b.anchorColumn) {
          return 'walls[$i] and walls[$j] cross';
        }
      }
    }
    return null;
  }
}
