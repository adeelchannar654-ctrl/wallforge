import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('walls sharing an anchor (R-WALL-08, spec v2.0.0)', () {
    // H(2,0) then V(2,0) on a 5x5: the permissive "+".
    GameState plus() {
      const config = BoardConfig(size: 5, wallsPerPlayer: 2);
      var state = GameState.initial(config);
      for (final action in <GameAction>[
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 2, column: 0),
        ),
        const GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 2, column: 0),
        ),
      ]) {
        final result = GameEngine.apply(state, state.currentPlayer, action);
        expect(result, isA<SuccessResult>(), reason: '$action must be legal');
        state = (result as SuccessResult).state;
      }
      return state;
    }

    test('the engine accepts both walls', () {
      expect(
        plus().walls,
        hasLength(2),
        reason: 'R-WALL-08 makes a same-anchor "+" legal',
      );
    });

    test('the resulting state survives serialization', () {
      final state = plus();

      final decoded = GameStateSerializer.fromJson(
        GameStateSerializer.toJson(state),
      );

      expect(
        decoded.stateOrNull,
        state,
        reason:
            'a position the rules allow must be storable, or the shared '
            'document becomes unreadable and the match is wedged for good',
      );
    });

    test('same-orientation overlap is still rejected', () {
      const config = BoardConfig(size: 5, wallsPerPlayer: 2);
      final state = (GameEngine.apply(
        GameState.initial(config),
        PlayerId.blue,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 2, column: 0),
        ),
      ) as SuccessResult).state;

      final result = GameEngine.apply(
        state,
        state.currentPlayer,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 2, column: 1),
        ),
      );

      expect(result, isA<FailureResult>());
      expect(
        (result as FailureResult).failure,
        ActionFailure.wallOverlaps,
        reason: 'removing the crossing check must not weaken overlap detection',
      );
    });

    test('a wall still cannot be placed on top of another', () {
      final encoded = GameStateSerializer.toJson(plus());
      final tampered = <String, dynamic>{
        ...encoded,
        'walls': [
          {
            'owner': 'blue',
            'orientation': 'h',
            'anchor': const {'row': 2, 'column': 0},
          },
          {
            'owner': 'blue',
            'orientation': 'h',
            'anchor': const {'row': 2, 'column': 0},
          },
          {
            'owner': 'blue',
            'orientation': 'v',
            'anchor': const {'row': 2, 'column': 0},
          },
        ],
      };

      expect(
        GameStateSerializer.fromJson(tampered).stateOrNull,
        isNull,
        reason: 'stacked same-orientation walls remain an invariant violation',
      );
    });
  });
}
