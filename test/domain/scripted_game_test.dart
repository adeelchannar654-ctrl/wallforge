import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Â§15 scripted game from game_spec.md v2.0.0.
///
/// A complete 17-action game demonstrating moves, wall placements, and a Blue win.
void main() {
  group('Â§15 scripted game', () {
    test('complete 17-action game matches spec exactly', () {
      var state = GameState.initial();
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 8, column: 4));
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 0, column: 4));
      expect(state.turnNumber, 0);

      // 1. Blue M 7,4
      var r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 7, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 7, column: 4));
      expect(state.turnNumber, 1);

      // 2. Red M 1,4
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.move(Cell(row: 1, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 1, column: 4));
      expect(state.turnNumber, 2);

      // 3. Blue M 6,4
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 6, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 6, column: 4));
      expect(state.turnNumber, 3);

      // 4. Red M 2,4
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.move(Cell(row: 2, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 2, column: 4));
      expect(state.turnNumber, 4);

      // 5. Blue M 5,4
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 5, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 5, column: 4));
      expect(state.turnNumber, 5);

      // 6. Red W V 6,3
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 6, column: 3),
        ),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.wallsRemaining(PlayerId.red), 9);
      expect(state.turnNumber, 6);

      // 7. Blue W H 6,5
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 6, column: 5),
        ),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.wallsRemaining(PlayerId.blue), 9);
      expect(state.turnNumber, 7);

      // 8. Red M 3,4
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.move(Cell(row: 3, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 3, column: 4));
      expect(state.turnNumber, 8);

      // 9. Blue M 4,4
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 4, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 4, column: 4));
      expect(state.turnNumber, 9);

      // 10. Red W H 1,3
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 1, column: 3),
        ),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.wallsRemaining(PlayerId.red), 8);
      expect(state.turnNumber, 10);

      // 11. Blue M 2,4
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 2, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 2, column: 4));
      expect(state.turnNumber, 11);

      // 12. Red M 4,4
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.move(Cell(row: 4, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 4, column: 4));
      expect(state.turnNumber, 12);

      // 13. Blue M 2,5
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 2, column: 5)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 2, column: 5));
      expect(state.turnNumber, 13);

      // 14. Red M 5,4
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.move(Cell(row: 5, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 5, column: 4));
      expect(state.turnNumber, 14);

      // 15. Blue M 1,5
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 1, column: 5)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 1, column: 5));
      expect(state.turnNumber, 15);

      // 16. Red M 6,4
      r = GameEngine.apply(
        state,
        PlayerId.red,
        const GameAction.move(Cell(row: 6, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 6, column: 4));
      expect(state.turnNumber, 16);

      // 17. Blue M 0,5 (win)
      r = GameEngine.apply(
        state,
        PlayerId.blue,
        const GameAction.move(Cell(row: 0, column: 5)),
      );
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;

      // Final state assertions
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 0, column: 5));
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 6, column: 4));
      expect(state.walls.length, 3);
      expect(state.wallsRemaining(PlayerId.blue), 9);
      expect(state.wallsRemaining(PlayerId.red), 8);
      expect(state.turnNumber, 17);
      expect(state.status, GameStatus.finished);
      expect(state.winner, PlayerId.blue);

      // Verify walls
      final wallOrientations = state.walls
          .map(
            (w) =>
                '${w.orientation.name.toUpperCase()}(${w.anchorRow},${w.anchorColumn})',
          )
          .toList();
      expect(wallOrientations, contains('V(6,3)'));
      expect(wallOrientations, contains('H(6,5)'));
      expect(wallOrientations, contains('H(1,3)'));

      // Verify JSON matches Â§16 finished-state JSON
      final j = GameStateSerializer.toJson(state);
      expect(j['status'], 'finished');
      expect(j['winner'], 'blue');
      expect(j['turnNumber'], 17);
      expect(j['remainingWalls']['blue'], 9);
      expect(j['remainingWalls']['red'], 8);
      expect(j['pawnPositions']['blue']['row'], 0);
      expect(j['pawnPositions']['blue']['column'], 5);
      expect(j['pawnPositions']['red']['row'], 6);
      expect(j['pawnPositions']['red']['column'], 4);
    });

    test('Â§16 finished-state JSON round-trip', () {
      // Build the state from the scripted game
      var state = GameState.initial();

      // Replay all 17 actions
      final actions = [
        (PlayerId.blue, const GameAction.move(Cell(row: 7, column: 4))),
        (PlayerId.red, const GameAction.move(Cell(row: 1, column: 4))),
        (PlayerId.blue, const GameAction.move(Cell(row: 6, column: 4))),
        (PlayerId.red, const GameAction.move(Cell(row: 2, column: 4))),
        (PlayerId.blue, const GameAction.move(Cell(row: 5, column: 4))),
        (
          PlayerId.red,
          const GameAction.wall(
            orientation: WallOrientation.v,
            anchor: Cell(row: 6, column: 3),
          ),
        ),
        (
          PlayerId.blue,
          const GameAction.wall(
            orientation: WallOrientation.h,
            anchor: Cell(row: 6, column: 5),
          ),
        ),
        (PlayerId.red, const GameAction.move(Cell(row: 3, column: 4))),
        (PlayerId.blue, const GameAction.move(Cell(row: 4, column: 4))),
        (
          PlayerId.red,
          const GameAction.wall(
            orientation: WallOrientation.h,
            anchor: Cell(row: 1, column: 3),
          ),
        ),
        (PlayerId.blue, const GameAction.move(Cell(row: 2, column: 4))),
        (PlayerId.red, const GameAction.move(Cell(row: 4, column: 4))),
        (PlayerId.blue, const GameAction.move(Cell(row: 2, column: 5))),
        (PlayerId.red, const GameAction.move(Cell(row: 5, column: 4))),
        (PlayerId.blue, const GameAction.move(Cell(row: 1, column: 5))),
        (PlayerId.red, const GameAction.move(Cell(row: 6, column: 4))),
        (PlayerId.blue, const GameAction.move(Cell(row: 0, column: 5))),
      ];

      for (final (player, action) in actions) {
        final r = GameEngine.apply(state, player, action);
        expect(
          r,
          isA<SuccessResult>(),
          reason: 'Failed at action ${action.toNotation()}',
        );
        state = (r as SuccessResult).state;
      }

      // Serialize and verify against Â§16 expected JSON
      final j = GameStateSerializer.toJson(state);
      expect(j['schemaVersion'], 1);
      expect(j['boardConfig'], {'size': 9, 'wallsPerPlayer': 10});
      expect(j['players'], ['blue', 'red']);
      expect(j['currentPlayer'], 'red');
      expect(j['status'], 'finished');
      expect(j['winner'], 'blue');
      expect(j['turnNumber'], 17);
      expect(j['remainingWalls'], {'blue': 9, 'red': 8});

      // Deserialize back and verify equality
      final deser = GameStateSerializer.fromJson(j);
      expect(deser, isA<DeserializationSuccess>());
      expect((deser as DeserializationSuccess).state, state);
    });
  });
}
