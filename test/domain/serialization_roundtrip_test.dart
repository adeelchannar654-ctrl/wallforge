import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('GameAction JSON round-trip', () {
    test('move action toJson/fromJson round-trip', () {
      const action = MoveAction(Cell(row: 5, column: 3));
      final j = action.toJson();
      final r = GameAction.fromJson(j);
      expect(r, isA<ActionParseSuccess>());
      expect((r as ActionParseSuccess).action, action);
    });

    test('wall action H toJson/fromJson round-trip', () {
      const action = WallAction(
        orientation: WallOrientation.h,
        anchor: Cell(row: 3, column: 4),
      );
      final j = action.toJson();
      final r = GameAction.fromJson(j);
      expect(r, isA<ActionParseSuccess>());
      expect((r as ActionParseSuccess).action, action);
    });

    test('wall action V toJson/fromJson round-trip', () {
      const action = WallAction(
        orientation: WallOrientation.v,
        anchor: Cell(row: 0, column: 0),
      );
      final j = action.toJson();
      final r = GameAction.fromJson(j);
      expect(r, isA<ActionParseSuccess>());
      expect((r as ActionParseSuccess).action, action);
    });

    test('move action decode/encode round-trip', () {
      const action = MoveAction(Cell(row: 8, column: 8));
      final jsonStr = jsonEncode(action.toJson());
      final r = GameAction.decode(jsonStr);
      expect(r, isA<ActionParseSuccess>());
      expect((r as ActionParseSuccess).action, action);
    });

    test('move action toJson produces correct keys', () {
      const action = MoveAction(Cell(row: 2, column: 7));
      final j = action.toJson();
      expect(j.keys, containsAll(['type', 'destination']));
      expect(j['type'], 'move');
      expect(j['destination'], {'row': 2, 'column': 7});
    });

    test('wall action toJson produces correct keys', () {
      const action = WallAction(
        orientation: WallOrientation.v,
        anchor: Cell(row: 6, column: 1),
      );
      final j = action.toJson();
      expect(j.keys, containsAll(['type', 'orientation', 'anchor']));
      expect(j['type'], 'wall');
      expect(j['orientation'], 'V');
      expect(j['anchor'], {'row': 6, 'column': 1});
    });

    test('fromJson rejects missing type', () {
      final r = GameAction.fromJson({
        'destination': {'row': 1, 'column': 1},
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects unknown type', () {
      final r = GameAction.fromJson({'type': 'jump'});
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects unknown keys in move', () {
      final r = GameAction.fromJson({
        'type': 'move',
        'destination': {'row': 1, 'column': 1},
        'extra': true,
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects unknown keys in wall', () {
      final r = GameAction.fromJson({
        'type': 'wall',
        'orientation': 'H',
        'anchor': {'row': 1, 'column': 1},
        'extra': true,
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects non-string wall orientation', () {
      final r = GameAction.fromJson({
        'type': 'wall',
        'orientation': 42,
        'anchor': {'row': 1, 'column': 1},
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects invalid wall orientation value', () {
      final r = GameAction.fromJson({
        'type': 'wall',
        'orientation': 'X',
        'anchor': {'row': 1, 'column': 1},
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects non-object destination', () {
      final r = GameAction.fromJson({'type': 'move', 'destination': 'bad'});
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects non-object anchor', () {
      final r = GameAction.fromJson({
        'type': 'wall',
        'orientation': 'H',
        'anchor': 'bad',
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects non-integer row in destination', () {
      final r = GameAction.fromJson({
        'type': 'move',
        'destination': {'row': 'x', 'column': 1},
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('fromJson rejects non-integer column in anchor', () {
      final r = GameAction.fromJson({
        'type': 'wall',
        'orientation': 'H',
        'anchor': {'row': 1, 'column': 'y'},
      });
      expect(r, isA<ActionParseFailure>());
    });

    test('actionOrNull returns action on success', () {
      const action = MoveAction(Cell(row: 0, column: 0));
      final result = ActionParseResult.success(action);
      expect(result.actionOrNull, action);
    });

    test('actionOrNull returns null on failure', () {
      const result = ActionParseFailure('bad');
      expect(result.actionOrNull, isNull);
    });
  });

  group('GameState serialization round-trip', () {
    test('initial state round-trip', () {
      final s = GameState.initial();
      final j = GameStateSerializer.toJson(s);
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationSuccess>());
      expect((r as DeserializationSuccess).state, s);
    });

    test('state with walls round-trip', () {
      const config = BoardConfig();
      final walls = [
        const Wall(
          anchorRow: 3,
          anchorColumn: 3,
          orientation: WallOrientation.h,
          owner: PlayerId.blue,
        ),
        const Wall(
          anchorRow: 5,
          anchorColumn: 2,
          orientation: WallOrientation.v,
          owner: PlayerId.red,
        ),
      ];
      final s = GameState(
        boardConfig: config,
        pawnPositions: {
          PlayerId.blue: const Cell(row: 7, column: 4),
          PlayerId.red: const Cell(row: 1, column: 4),
        },
        walls: walls,
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 9},
        turnNumber: 2,
        status: GameStatus.inProgress,
      );
      final j = GameStateSerializer.toJson(s);
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationSuccess>());
      expect((r as DeserializationSuccess).state, s);
    });

    test('finished state round-trip', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 0, column: 4),
          PlayerId.red: const Cell(row: 3, column: 2),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 10, PlayerId.red: 10},
        turnNumber: 5,
        status: GameStatus.finished,
        winner: PlayerId.blue,
      );
      final j = GameStateSerializer.toJson(s);
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationSuccess>());
      expect((r as DeserializationSuccess).state, s);
    });

    test('encode/decode round-trip', () {
      final s = GameState.initial();
      final encoded = GameStateSerializer.encode(s);
      final r = GameStateSerializer.decode(encoded);
      expect(r, isA<DeserializationSuccess>());
      expect((r as DeserializationSuccess).state, s);
    });

    test('decode rejects non-object JSON', () {
      final r = GameStateSerializer.decode('"just a string"');
      expect(r, isA<DeserializationFailure>());
    });

    test('fromJson rejects top-level list', () {
      final r = GameStateSerializer.fromJson({
        'extra': true,
        'schemaVersion': 1,
      });
      expect(r, isA<DeserializationFailure>());
    });
  });

  group('GameState invariant rejection', () {
    test('R-STATE-01: both pawns on same cell', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['pawnPositions']['red'] = j['pawnPositions']['blue'];
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.invariantViolation,
      );
    });

    test('R-STATE-02: pawn off board', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['pawnPositions']['blue'] = {'row': -1, 'column': 4};
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.invariantViolation,
      );
    });

    test('R-STATE-05: currentPlayer parity mismatch', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['currentPlayer'] = 'red';
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.invariantViolation,
      );
    });

    test('R-SERIAL-01: schemaVersion 999', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['schemaVersion'] = 999;
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.unsupportedSchemaVersion,
      );
    });

    test('missing fields -> malformed', () {
      final r = GameStateSerializer.fromJson({});
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.malformed,
      );
    });

    test('unknown fields -> malformed', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['bogus'] = true;
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.malformed,
      );
    });

    test('invalid board config -> invalidConfig', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['boardConfig'] = {'size': 8, 'wallsPerPlayer': 10};
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.invalidConfig,
      );
    });

    test('inventory arithmetic mismatch -> invariantViolation', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['remainingWalls']['blue'] = 5;
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.invariantViolation,
      );
    });

    test('winner set while inProgress -> invariantViolation', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['winner'] = 'blue';
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.invariantViolation,
      );
    });

    test('status finished without winner -> invariantViolation', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['status'] = 'finished';
      j['winner'] = null;
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.invariantViolation,
      );
    });

    test('walls invalid orientation in JSON -> malformed', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['walls'] = [
        {
          'owner': 'blue',
          'orientation': 'X',
          'anchor': {'row': 0, 'column': 0},
        },
      ];
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.malformed,
      );
    });

    test('walls non-array -> malformed', () {
      final j = GameStateSerializer.toJson(GameState.initial());
      j['walls'] = 'not a list';
      final r = GameStateSerializer.fromJson(j);
      expect(r, isA<DeserializationFailure>());
      expect(
        (r as DeserializationFailure).reason,
        DeserializationFailureReason.malformed,
      );
    });
  });

  group('GameState unmodifiable collections', () {
    test('walls list is unmodifiable', () {
      final s = GameState.initial();
      expect(
        () => s.walls.add(
          const Wall(
            anchorRow: 0,
            anchorColumn: 0,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('pawnPositions map is unmodifiable', () {
      final s = GameState.initial();
      expect(
        () => s.pawnPositions[PlayerId.blue] = const Cell(row: 0, column: 0),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('remainingWalls map is unmodifiable', () {
      final s = GameState.initial();
      expect(
        () => s.remainingWalls[PlayerId.blue] = 99,
        throwsA(isA<UnsupportedError>()),
      );
    });
  });

  group('BoardConfig validation', () {
    test('check returns null for valid config', () {
      expect(BoardConfig.check(9, 10), isNull);
    });

    test('check returns failure for size 8 (even)', () {
      final f = BoardConfig.check(8, 10);
      expect(f, isNotNull);
      expect(f!.reason, ConfigFailureReason.sizeEven);
    });

    test('check returns failure for size 3 (too small)', () {
      final f = BoardConfig.check(3, 10);
      expect(f, isNotNull);
      expect(f!.reason, ConfigFailureReason.sizeTooSmall);
    });

    test('check returns failure for negative walls', () {
      final f = BoardConfig.check(9, -1);
      expect(f, isNotNull);
      expect(f!.reason, ConfigFailureReason.negativeWalls);
    });

    test('validated throws for invalid config', () {
      expect(
        () => BoardConfig.validated(size: 8),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('validated succeeds for valid config', () {
      final c = BoardConfig.validated(size: 7, wallsPerPlayer: 5);
      expect(c.size, 7);
      expect(c.wallsPerPlayer, 5);
    });

    test('isValid getter', () {
      expect(const BoardConfig().isValid, isTrue);
      expect(const BoardConfig(size: 8).isValid, isFalse);
    });

    test('failure getter', () {
      expect(const BoardConfig().failure, isNull);
      expect(const BoardConfig(size: 8).failure, isNotNull);
    });

    test('ConfigFailure toString', () {
      final f = BoardConfig.check(8, 10)!;
      expect(f.toString(), contains('sizeEven'));
    });
  });

  group('GameState equality', () {
    test('equal states are equal', () {
      final a = GameState.initial();
      final b = GameState.initial();
      expect(a, equals(b));
    });

    test('different turnNumber -> not equal', () {
      final a = GameState.initial();
      final b = a.copyWith(turnNumber: 1);
      expect(a, isNot(equals(b)));
    });

    test('same instance is identical', () {
      final a = GameState.initial();
      expect(identical(a, a), isTrue);
    });
  });

  group('Mutation fuzz test', () {
    test('toJson does not mutate the original state', () {
      final s = GameState.initial();
      final beforeWalls = List<Wall>.from(s.walls);
      final beforePositions = Map<PlayerId, Cell>.from(s.pawnPositions);
      final beforeRemaining = Map<PlayerId, int>.from(s.remainingWalls);

      GameStateSerializer.toJson(s);

      expect(s.walls, beforeWalls);
      expect(s.pawnPositions, beforePositions);
      expect(s.remainingWalls, beforeRemaining);
    });

    test('encode does not mutate the original state', () {
      final s = GameState.initial();
      final beforeWalls = List<Wall>.from(s.walls);

      GameStateSerializer.encode(s);

      expect(s.walls, beforeWalls);
    });
  });
}
