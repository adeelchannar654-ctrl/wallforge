import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('Generator ≡ Validator consistency', () {
    test('every generated action passes validation', () {
      final state = GameState.initial();
      final actions = MoveGenerator.generate(state);
      for (final action in actions) {
        final failure = ActionValidator.validate(state, action);
        expect(
          failure,
          isNull,
          reason: 'Generated action $action should be valid but got $failure',
        );
      }
    });

    test('generator never returns invalid actions', () {
      // Test several states
      final states = [
        GameState.initial(),
        GameState.initial().copyWith(
          bluePawn: const Cell(col: 5, row: 1),
          redPawn: const Cell(col: 5, row: 2),
          activePlayer: PlayerId.blue,
        ),
      ];
      for (final state in states) {
        final actions = MoveGenerator.generate(state);
        for (final action in actions) {
          final failure = ActionValidator.validate(state, action);
          expect(
            failure,
            isNull,
            reason: 'Action $action should be valid in state $state',
          );
        }
      }
    });
  });

  group('Invariants', () {
    test('moveCount increases by 1 per action', () {
      var state = GameState.initial();
      expect(state.moveCount, 0);

      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      );
      expect(result.state.moveCount, 1);
    });

    test('walls remaining decreases by 1 on wall placement', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 0, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(result.state.blueWallsRemaining, 4);
      expect(result.state.redWallsRemaining, 5);
    });

    test('active player switches after each action', () {
      var state = GameState.initial();
      expect(state.activePlayer, PlayerId.blue);

      state = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      ).state;
      expect(state.activePlayer, PlayerId.red);

      state = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 8)),
      ).state;
      expect(state.activePlayer, PlayerId.blue);
    });

    test('total walls on board + remaining = 10', () {
      var state = GameState.initial();
      expect(
        state.walls.length + state.blueWallsRemaining + state.redWallsRemaining,
        10,
      );

      state = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 0, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      ).state;
      expect(
        state.walls.length + state.blueWallsRemaining + state.redWallsRemaining,
        10,
      );
    });

    test('pawns never overlap', () {
      var state = GameState.initial();
      // Apply several moves
      final moves = [
        const MoveAction(target: Cell(col: 5, row: 1)),
        const MoveAction(target: Cell(col: 5, row: 8)),
        const MoveAction(target: Cell(col: 4, row: 1)),
        const MoveAction(target: Cell(col: 4, row: 8)),
      ];
      for (final move in moves) {
        state = GameEngine.applyAction(state, move).state;
        expect(
          state.bluePawn == state.redPawn,
          isFalse,
          reason: 'Pawns overlap at ${state.bluePawn}',
        );
      }
    });
  });

  group('R-NOLEGAL-001: every non-terminal state has ≥1 legal action', () {
    test('initial state has legal actions', () {
      final state = GameState.initial();
      final actions = MoveGenerator.generate(state);
      expect(actions, isNotEmpty);
    });

    test('mid-game state has legal actions', () {
      var state = GameState.initial();
      // Make a few moves
      state = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      ).state;
      state = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 8)),
      ).state;

      final actions = MoveGenerator.generate(state);
      expect(actions, isNotEmpty);
    });
  });

  group('Wall blocking invariant', () {
    test('after wall placement, both players can still reach goal', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 0, row: 5),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(result.failure, isNull);
      // Both should still be able to reach goals
      expect(
        Pathfinder.canReachGoal(
          from: result.state.bluePawn,
          goalRow: 9,
          walls: result.state.walls,
          cols: 10,
          rows: 10,
        ),
        isTrue,
      );
      expect(
        Pathfinder.canReachGoal(
          from: result.state.redPawn,
          goalRow: 0,
          walls: result.state.walls,
          cols: 10,
          rows: 10,
        ),
        isTrue,
      );
    });
  });

  group('Serialization round-trip properties', () {
    test('toJson/fromJson preserves equality', () {
      final original = GameState.initial();
      final json = GameStateJson.toJson(original);
      final restored = GameStateJson.fromJson(json);
      expect(restored, equals(original));
    });

    test('action notation parse/serialize is identity', () {
      final actions = <GameAction>[
        const MoveAction(target: Cell(col: 3, row: 4)),
        const JumpAction(target: Cell(col: 5, row: 3)),
        const PlaceWallAction(
          origin: Cell(col: 2, row: 3),
          orientation: WallOrientation.horizontal,
        ),
        const PlaceWallAction(
          origin: Cell(col: 4, row: 5),
          orientation: WallOrientation.vertical,
        ),
      ];
      for (final action in actions) {
        final notation = ActionNotation.serialize(action);
        final parsed = ActionNotation.parse(notation);
        expect(
          parsed,
          equals(action),
          reason: 'Round-trip failed for $action (notation: $notation)',
        );
      }
    });
  });
}
