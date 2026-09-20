import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('Cell', () {
    test('equality', () {
      expect(Cell(col: 1, row: 2), equals(Cell(col: 1, row: 2)));
      expect(Cell(col: 1, row: 2), isNot(equals(Cell(col: 2, row: 1))));
    });

    test('hashCode', () {
      final a = Cell(col: 3, row: 4);
      final b = Cell(col: 3, row: 4);
      expect(a.hashCode, equals(b.hashCode));
    });

    test('toString', () {
      expect(Cell(col: 0, row: 1).toString(), 'Cell(0,1)');
    });
  });

  group('BoardConfig', () {
    test('default values', () {
      const config = BoardConfig();
      expect(config.rows, 10);
      expect(config.cols, 10);
      expect(config.totalWalls, 10);
      expect(config.maxWallsPerPlayer, 5);
    });
  });

  group('PlayerId', () {
    test('opponent', () {
      expect(PlayerId.blue.opponent, PlayerId.red);
      expect(PlayerId.red.opponent, PlayerId.blue);
    });
  });

  group('Wall', () {
    test('horizontal footprint', () {
      final wall = Wall(
        origin: const Cell(col: 2, row: 3),
        orientation: WallOrientation.horizontal,
      );
      expect(wall.footprint, [Cell(col: 2, row: 3), Cell(col: 3, row: 3)]);
    });

    test('vertical footprint', () {
      final wall = Wall(
        origin: const Cell(col: 4, row: 5),
        orientation: WallOrientation.vertical,
      );
      expect(wall.footprint, [Cell(col: 4, row: 5), Cell(col: 4, row: 6)]);
    });

    test('equality', () {
      final a = Wall(
        origin: const Cell(col: 1, row: 2),
        orientation: WallOrientation.horizontal,
      );
      final b = Wall(
        origin: const Cell(col: 1, row: 2),
        orientation: WallOrientation.horizontal,
      );
      expect(a, equals(b));
    });
  });

  group('GameState', () {
    test('initial state', () {
      final state = GameState.initial();
      expect(state.status, GameStatus.active);
      expect(state.activePlayer, PlayerId.blue);
      expect(state.bluePawn, const Cell(col: 5, row: 0));
      expect(state.redPawn, const Cell(col: 5, row: 9));
      expect(state.blueWallsRemaining, 5);
      expect(state.redWallsRemaining, 5);
      expect(state.walls, isEmpty);
      expect(state.moveCount, 0);
    });

    test('copyWith preserves unmodified fields', () {
      final initial = GameState.initial();
      final modified = initial.copyWith(bluePawn: const Cell(col: 4, row: 0));
      expect(modified.bluePawn, const Cell(col: 4, row: 0));
      expect(modified.redPawn, initial.redPawn);
      expect(modified.activePlayer, initial.activePlayer);
    });

    test('pawnPosition', () {
      final state = GameState.initial();
      expect(state.pawnPosition(PlayerId.blue), state.bluePawn);
      expect(state.pawnPosition(PlayerId.red), state.redPawn);
    });

    test('wallsRemaining', () {
      final state = GameState.initial();
      expect(state.wallsRemaining(PlayerId.blue), 5);
      expect(state.wallsRemaining(PlayerId.red), 5);
    });
  });

  group('ActionFailure', () {
    test('all subtypes have toString', () {
      const failures = <ActionFailure>[
        ActionFailure.wrongTurn(),
        ActionFailure.gameNotActive(),
        ActionFailure.occupiedByOwnPawn(),
        ActionFailure.notAdjacent(),
        ActionFailure.jumpTargetNotBehind(),
        ActionFailure.noOpponentToJumpOver(),
        ActionFailure.mustJump(),
        ActionFailure.noWallsRemaining(),
        ActionFailure.wallOutOfBounds(),
        ActionFailure.wallOverlap(),
        ActionFailure.wallOverlapPawn(),
        ActionFailure.wallBlocksPath(),
        ActionFailure.wallOnForwardPath(),
        ActionFailure.invalidWallOrientation(),
      ];
      for (final f in failures) {
        expect(f.toString(), isNotEmpty);
      }
    });
  });
}
