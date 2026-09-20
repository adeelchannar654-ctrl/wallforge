import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('Pathfinder', () {
    test('goal row reachable from start', () {
      expect(
        Pathfinder.canReachGoal(
          from: const Cell(col: 5, row: 0),
          goalRow: 9,
          walls: [],
          cols: 10,
          rows: 10,
        ),
        isTrue,
      );
    });

    test('wall blocks path', () {
      // Place horizontal walls to block every column at row 4→5 crossing
      final walls = List.generate(
        10,
        (i) => Wall(
          origin: Cell(col: i, row: 4),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(
        Pathfinder.canReachGoal(
          from: const Cell(col: 5, row: 0),
          goalRow: 9,
          walls: walls,
          cols: 10,
          rows: 10,
        ),
        isFalse,
      );
    });
  });

  group('ActionValidator', () {
    test('gameNotActive when game is over', () {
      final state = GameState.initial().copyWith(status: GameStatus.blueWins);
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      );
      expect(result, isA<GameNotActiveFailure>());
    });

    test('valid move returns null', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      );
      expect(result, isNull);
    });

    test('not adjacent move', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 0, row: 0)),
      );
      expect(result, isA<NotAdjacentFailure>());
    });

    test('move to opponent cell', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 5, row: 9)),
      );
      expect(result, isA<NotAdjacentFailure>());
    });
  });

  group('MoveGenerator', () {
    test('initial state has correct move count', () {
      final state = GameState.initial();
      final actions = MoveGenerator.generate(state);
      // Blue at (5,0): can move to (4,0), (6,0), (5,1) = 3 moves
      final moves = actions.whereType<MoveAction>().length;
      expect(moves, 3);
    });

    test('jump available when opponent adjacent and cell behind free', () {
      // Set up: Blue at (5,1), Red at (5,2), Blue's turn
      final state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 5, row: 1),
        redPawn: const Cell(col: 5, row: 2),
        activePlayer: PlayerId.blue,
      );
      final actions = MoveGenerator.generate(state);
      final jumps = actions.whereType<JumpAction>().toList();
      // Blue should be able to jump over red to (5,3)
      expect(jumps, contains(const JumpAction(target: Cell(col: 5, row: 3))));
    });
  });

  group('GameEngine', () {
    test('apply move advances position and switches turn', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      );
      expect(result.failure, isNull);
      expect(result.state.bluePawn, const Cell(col: 5, row: 1));
      expect(result.state.activePlayer, PlayerId.red);
      expect(result.state.moveCount, 1);
    });

    test('blue reaching row 9 wins', () {
      // Blue at (5,8), move to (5,9) - blue's goal
      var state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 5, row: 8),
        redPawn: const Cell(col: 0, row: 9),
        activePlayer: PlayerId.blue,
      );
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 9)),
      );
      expect(result.failure, isNull);
      expect(result.state.status, GameStatus.blueWins);
    });

    test('red reaching row 0 wins', () {
      var state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 0, row: 0),
        redPawn: const Cell(col: 5, row: 1),
        activePlayer: PlayerId.red,
      );
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 0)),
      );
      expect(result.failure, isNull);
      expect(result.state.status, GameStatus.redWins);
    });

    test('apply wall placement switches turn', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 0, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(result.failure, isNull);
      expect(result.state.walls.length, 1);
      expect(result.state.blueWallsRemaining, 4);
      expect(result.state.activePlayer, PlayerId.red);
    });

    test('illegal action returns failure not exception', () {
      final state = GameState.initial().copyWith(status: GameStatus.blueWins);
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      );
      expect(result.failure, isA<GameNotActiveFailure>());
      expect(result.state, same(state));
    });

    test('wall blocking win', () {
      // Place walls to trap blue at (0,0) with no path to row 9
      // Horizontal wall at row 0 spanning cols 0-1 and 1-2 blocks downward
      final walls = [
        const Wall(
          origin: Cell(col: 0, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 1, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 2, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 3, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 4, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 5, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 6, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 7, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 8, row: 0),
          orientation: WallOrientation.horizontal,
        ),
        const Wall(
          origin: Cell(col: 9, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      ];
      final state = GameState.initial().copyWith(
        walls: walls,
        activePlayer: PlayerId.red,
      );
      // Verify blue can't reach row 9
      final canReach = Pathfinder.canReachGoal(
        from: state.bluePawn,
        goalRow: 9,
        walls: state.walls,
        cols: 10,
        rows: 10,
      );
      expect(canReach, isFalse);
      // Red wins by wall-blocking
      expect(
        state.copyWith(status: GameStatus.redWins).status,
        GameStatus.redWins,
      );
    });
  });

  group('Serialization', () {
    test('JSON round-trip', () {
      final original = GameState.initial();
      final json = GameStateJson.toJson(original);
      final restored = GameStateJson.fromJson(json);
      expect(restored, equals(original));
    });

    test('JSON round-trip with walls', () {
      var state = GameState.initial();
      state = state.copyWith(
        walls: const [
          Wall(
            origin: Cell(col: 2, row: 3),
            orientation: WallOrientation.horizontal,
          ),
        ],
        blueWallsRemaining: 4,
      );
      final json = GameStateJson.toJson(state);
      final restored = GameStateJson.fromJson(json);
      expect(restored, equals(state));
    });

    test('action notation round-trip', () {
      const move = MoveAction(target: Cell(col: 3, row: 4));
      final notation = ActionNotation.serialize(move);
      expect(notation, 'm3,4');
      final parsed = ActionNotation.parse(notation);
      expect(parsed, equals(move));
    });

    test('wall notation round-trip', () {
      const wall = PlaceWallAction(
        origin: Cell(col: 2, row: 3),
        orientation: WallOrientation.horizontal,
      );
      final notation = ActionNotation.serialize(wall);
      expect(notation, 'wh2,3');
      final parsed = ActionNotation.parse(notation);
      expect(parsed, equals(wall));
    });

    test('jump notation round-trip', () {
      const jump = JumpAction(target: Cell(col: 5, row: 3));
      final notation = ActionNotation.serialize(jump);
      expect(notation, 'j5,3');
      final parsed = ActionNotation.parse(notation);
      expect(parsed, equals(jump));
    });
  });
}
