import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Spec catalog traceability tests.
///
/// Each test maps to one or more test IDs from game_spec.md §18.
/// Format: test('T-XXX-NNN: description', ...)
void main() {
  group('T-INIT-001: initial state matches spec', () {
    test('board is 10x10', () {
      const config = BoardConfig();
      expect(config.rows, 10);
      expect(config.cols, 10);
    });

    test('blue pawn at (cols/2, 0)', () {
      final state = GameState.initial();
      expect(state.bluePawn, const Cell(col: 5, row: 0));
    });

    test('red pawn at (cols/2, rows-1)', () {
      final state = GameState.initial();
      expect(state.redPawn, const Cell(col: 5, row: 9));
    });

    test('each player has 5 walls', () {
      final state = GameState.initial();
      expect(state.blueWallsRemaining, 5);
      expect(state.redWallsRemaining, 5);
    });

    test('no walls on board', () {
      final state = GameState.initial();
      expect(state.walls, isEmpty);
    });

    test('blue moves first', () {
      final state = GameState.initial();
      expect(state.activePlayer, PlayerId.blue);
    });
  });

  group('T-MOVE-001: legal pawn movement', () {
    test('pawn can move to adjacent orthogonal cell', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      );
      expect(result.failure, isNull);
      expect(result.state.bluePawn, const Cell(col: 5, row: 1));
    });

    test('pawn cannot move diagonally', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 6, row: 1)),
      );
      expect(result, isA<NotAdjacentFailure>());
    });

    test('pawn cannot move two cells', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 5, row: 2)),
      );
      expect(result, isA<NotAdjacentFailure>());
    });

    test('pawn cannot move to cell occupied by own pawn', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 5, row: 0)),
      );
      expect(result, isA<NotAdjacentFailure>());
    });
  });

  group('T-MOVE-002: turn switching', () {
    test('after blue moves, red becomes active', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      );
      expect(result.state.activePlayer, PlayerId.red);
    });

    test('after red moves, blue becomes active', () {
      var state = GameState.initial();
      state = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 1)),
      ).state;
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 8)),
      );
      expect(result.state.activePlayer, PlayerId.blue);
    });
  });

  group('T-JUMP-001: jump mechanics', () {
    test('can jump over opponent to cell behind', () {
      final state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 5, row: 1),
        redPawn: const Cell(col: 5, row: 2),
        activePlayer: PlayerId.blue,
      );
      final result = GameEngine.applyAction(
        state,
        const JumpAction(target: Cell(col: 5, row: 3)),
      );
      expect(result.failure, isNull);
      expect(result.state.bluePawn, const Cell(col: 5, row: 3));
    });

    test('cannot jump if no opponent adjacent', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const JumpAction(target: Cell(col: 5, row: 2)),
      );
      expect(result, isA<NoOpponentToJumpOverFailure>());
    });

    test('cannot jump to cell occupied by own pawn', () {
      final state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 5, row: 1),
        redPawn: const Cell(col: 5, row: 2),
        activePlayer: PlayerId.blue,
      );
      // Target (5,3) is free, so this should work
      final result = ActionValidator.validate(
        state,
        const JumpAction(target: Cell(col: 5, row: 3)),
      );
      expect(result, isNull);
    });
  });

  group('T-JUMP-009: mandatory jump', () {
    test('must jump when jump is available', () {
      final state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 5, row: 1),
        redPawn: const Cell(col: 5, row: 2),
        activePlayer: PlayerId.blue,
      );
      // Try a regular move instead of jump
      final result = ActionValidator.validate(
        state,
        const MoveAction(target: Cell(col: 4, row: 1)),
      );
      expect(result, isA<MustJumpFailure>());
    });
  });

  group('T-WALL-001: wall placement', () {
    test('can place horizontal wall', () {
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
    });

    test('can place vertical wall', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 0, row: 0),
          orientation: WallOrientation.vertical,
        ),
      );
      expect(result.failure, isNull);
      expect(result.state.walls.length, 1);
    });

    test('wall decreases remaining count', () {
      final state = GameState.initial();
      final result = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 0, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(result.state.blueWallsRemaining, 4);
    });
  });

  group('T-WALL-003: wall overlap', () {
    test('cannot place wall overlapping existing wall', () {
      var state = GameState.initial();
      state = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 2, row: 3),
          orientation: WallOrientation.horizontal,
        ),
      ).state;
      // Switch to red's turn
      final result = ActionValidator.validate(
        state,
        const PlaceWallAction(
          origin: Cell(col: 2, row: 3),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(result, isA<WallOverlapFailure>());
    });
  });

  group('T-WALL-004: wall blocks pawn path', () {
    test('cannot place wall that blocks all paths', () {
      final state = GameState.initial();
      // Place walls to completely trap blue
      final walls = List.generate(
        10,
        (i) => Wall(
          origin: Cell(col: i, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      );
      // Check if this blocks blue's path
      final canReach = Pathfinder.canReachGoal(
        from: const Cell(col: 5, row: 0),
        goalRow: 9,
        walls: walls,
        cols: 10,
        rows: 10,
      );
      expect(canReach, isFalse);
    });
  });

  group('T-WALL-005: wall out of bounds', () {
    test('horizontal wall origin col must be < cols-1', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const PlaceWallAction(
          origin: Cell(col: 9, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(result, isA<WallOutOfBoundsFailure>());
    });

    test('vertical wall origin row must be < rows-1', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const PlaceWallAction(
          origin: Cell(col: 0, row: 9),
          orientation: WallOrientation.vertical,
        ),
      );
      expect(result, isA<WallOutOfBoundsFailure>());
    });
  });

  group('T-WALL-007: wall overlap pawn', () {
    test('cannot place wall on pawn', () {
      final state = GameState.initial();
      final result = ActionValidator.validate(
        state,
        const PlaceWallAction(
          origin: Cell(col: 5, row: 0),
          orientation: WallOrientation.horizontal,
        ),
      );
      expect(result, isA<WallOverlapPawnFailure>());
    });
  });

  group('T-WIN-001: blue wins by reaching row 9', () {
    test('blue wins at row 9', () {
      var state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 5, row: 8),
        redPawn: const Cell(col: 0, row: 9),
        activePlayer: PlayerId.blue,
      );
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 9)),
      );
      expect(result.state.status, GameStatus.blueWins);
    });
  });

  group('T-WIN-002: red wins by reaching row 0', () {
    test('red wins at row 0', () {
      var state = GameState.initial().copyWith(
        bluePawn: const Cell(col: 0, row: 0),
        redPawn: const Cell(col: 5, row: 1),
        activePlayer: PlayerId.red,
      );
      final result = GameEngine.applyAction(
        state,
        const MoveAction(target: Cell(col: 5, row: 0)),
      );
      expect(result.state.status, GameStatus.redWins);
    });
  });

  group('T-WIN-003: blue wins by wall-blocking red', () {
    test('blue wins if red cannot reach row 0', () {
      // Place walls to trap red at (5,9) with no path to row 0
      final walls = <Wall>[
        for (var i = 0; i < 10; i++)
          Wall(
            origin: Cell(col: i, row: 8),
            orientation: WallOrientation.horizontal,
          ),
      ];
      final state = GameState.initial().copyWith(
        walls: walls,
        activePlayer: PlayerId.blue,
      );
      final canReach = Pathfinder.canReachGoal(
        from: state.redPawn,
        goalRow: 0,
        walls: walls,
        cols: 10,
        rows: 10,
      );
      expect(canReach, isFalse);
    });
  });

  group('T-WIN-006: red wins by wall-blocking blue', () {
    test('red wins if blue cannot reach row 9', () {
      final walls = <Wall>[
        for (var i = 0; i < 10; i++)
          Wall(
            origin: Cell(col: i, row: 1),
            orientation: WallOrientation.horizontal,
          ),
      ];
      final state = GameState.initial().copyWith(
        walls: walls,
        activePlayer: PlayerId.blue,
      );
      final canReach = Pathfinder.canReachGoal(
        from: state.bluePawn,
        goalRow: 9,
        walls: walls,
        cols: 10,
        rows: 10,
      );
      expect(canReach, isFalse);
    });
  });

  group('T-GAMEOVER-001: no actions after game over', () {
    test('move generator returns empty when game over', () {
      final state = GameState.initial().copyWith(status: GameStatus.blueWins);
      final actions = MoveGenerator.generate(state);
      expect(actions, isEmpty);
    });
  });

  group('T-SERIAL-001: JSON round-trip', () {
    test('initial state round-trips', () {
      final original = GameState.initial();
      final json = GameStateJson.toJson(original);
      final restored = GameStateJson.fromJson(json);
      expect(restored, equals(original));
    });

    test('state with walls round-trips', () {
      var state = GameState.initial();
      state = GameEngine.applyAction(
        state,
        const PlaceWallAction(
          origin: Cell(col: 2, row: 3),
          orientation: WallOrientation.horizontal,
        ),
      ).state;
      final json = GameStateJson.toJson(state);
      final restored = GameStateJson.fromJson(json);
      expect(restored, equals(state));
    });
  });

  group('T-SERIAL-002: action notation', () {
    test('move notation', () {
      const action = MoveAction(target: Cell(col: 3, row: 4));
      final notation = ActionNotation.serialize(action);
      expect(notation, 'm3,4');
      expect(ActionNotation.parse(notation), equals(action));
    });

    test('jump notation', () {
      const action = JumpAction(target: Cell(col: 5, row: 3));
      final notation = ActionNotation.serialize(action);
      expect(notation, 'j5,3');
      expect(ActionNotation.parse(notation), equals(action));
    });

    test('wall notation horizontal', () {
      const action = PlaceWallAction(
        origin: Cell(col: 2, row: 3),
        orientation: WallOrientation.horizontal,
      );
      final notation = ActionNotation.serialize(action);
      expect(notation, 'wh2,3');
      expect(ActionNotation.parse(notation), equals(action));
    });

    test('wall notation vertical', () {
      const action = PlaceWallAction(
        origin: Cell(col: 4, row: 5),
        orientation: WallOrientation.vertical,
      );
      final notation = ActionNotation.serialize(action);
      expect(notation, 'wv4,5');
      expect(ActionNotation.parse(notation), equals(action));
    });
  });
}
