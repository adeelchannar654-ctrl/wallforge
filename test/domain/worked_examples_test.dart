import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// §8 worked examples from game_spec.md v1.0.4.
///
/// Each test corresponds to one example in the spec.
void main() {
  group('§8 worked examples', () {
    test('Example 1: Blue opening move (8,4)→(7,4)', () {
      final s = GameState.initial();
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 8, column: 4));
      expect(s.pawnPosition(PlayerId.red), const Cell(row: 0, column: 4));
      expect(s.currentPlayer, PlayerId.blue);

      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 7, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      final after = (r as SuccessResult).state;
      expect(after.pawnPosition(PlayerId.blue), const Cell(row: 7, column: 4));
      expect(after.pawnPosition(PlayerId.red), const Cell(row: 0, column: 4));
      expect(after.currentPlayer, PlayerId.red);
      expect(after.turnNumber, 1);
    });

    test('Example 2: Move blocked by H(3,4)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 3, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 4,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 4, column: 4)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('Example 3: Move blocked by V(5,3)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 5, column: 3),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 5,
            anchorColumn: 3,
            orientation: WallOrientation.v,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 5, column: 4)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('Example 3a: Move blocked by second anchor of H(3,3)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 3, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 3,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 4, column: 4)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('Example 3b: Move blocked by second anchor of V(4,3)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 5, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 4,
            anchorColumn: 3,
            orientation: WallOrientation.v,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 5, column: 3)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('Example 3c: Move blocked at board edge by H(3,7)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 3, column: 8),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 7,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 4, column: 8)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('Example 3d: Move right blocked by second anchor of V(4,4)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 5, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 4,
            anchorColumn: 4,
            orientation: WallOrientation.v,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 5, column: 5)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('Example 4: Move off board edge (-1,4)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 5, column: 4),
          PlayerId.red: const Cell(row: 3, column: 2),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 10, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: -1, column: 4)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
    });

    test('Example 5: Legal wall at corner W H 0,0', () {
      final s = GameState.initial();
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.h,
          anchor: const Cell(row: 0, column: 0),
        ),
      );
      expect(r, isA<SuccessResult>());
      final after = (r as SuccessResult).state;
      expect(after.walls.length, 1);
      expect(after.wallsRemaining(PlayerId.blue), 9);
      expect(after.currentPlayer, PlayerId.red);
      expect(after.turnNumber, 1);
    });

    test('Example 6: Wall out of bounds W H 8,0', () {
      final s = GameState.initial();
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.h,
          anchor: const Cell(row: 8, column: 0),
        ),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallOutOfBounds);
    });

    test('Example 7: Overlap identical position', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 8, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 3,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.h,
          anchor: const Cell(row: 3, column: 3),
        ),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallOverlaps);
    });

    test('Example 8: Overlap offset by one', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 8, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 3,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.h,
          anchor: const Cell(row: 3, column: 4),
        ),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallOverlaps);
    });

    test('Example 9: Legal offset by two', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 8, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 3,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.h,
          anchor: const Cell(row: 3, column: 5),
        ),
      );
      expect(r, isA<SuccessResult>());
    });

    test('Example 10: Crossing at same anchor', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 8, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 3,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.v,
          anchor: const Cell(row: 3, column: 3),
        ),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallCrosses);
    });

    test('Example 11: Legal T-junction V(4,3) after H(3,3)', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 8, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 3,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.v,
          anchor: const Cell(row: 4, column: 3),
        ),
      );
      expect(r, isA<SuccessResult>());
    });

    test('Example 12: Straight jump', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 5, column: 4),
          PlayerId.red: const Cell(row: 4, column: 4),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 10, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 3, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      final after = (r as SuccessResult).state;
      expect(after.pawnPosition(PlayerId.blue), const Cell(row: 3, column: 4));
      expect(after.pawnPosition(PlayerId.red), const Cell(row: 4, column: 4));
      expect(after.currentPlayer, PlayerId.red);
      expect(after.turnNumber, 1);
    });

    test('Example 13: Diagonal jump (straight blocked by H(3,4))', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 5, column: 4),
          PlayerId.red: const Cell(row: 4, column: 4),
        },
        walls: const [
          Wall(
            anchorRow: 3,
            anchorColumn: 4,
            orientation: WallOrientation.h,
            owner: PlayerId.blue,
          ),
        ],
        remainingWalls: {PlayerId.blue: 9, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      // Straight jump blocked, try diagonal
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 4, column: 3)),
      );
      expect(r, isA<SuccessResult>());
      final after = (r as SuccessResult).state;
      expect(after.pawnPosition(PlayerId.blue), const Cell(row: 4, column: 3));
    });

    test('Example 14: Win - Blue reaches row 0', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 1, column: 4),
          PlayerId.red: const Cell(row: 3, column: 2),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 10, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.move(const Cell(row: 0, column: 4)),
      );
      expect(r, isA<SuccessResult>());
      final after = (r as SuccessResult).state;
      expect(after.status, GameStatus.finished);
      expect(after.winner, PlayerId.blue);

      // Any further action fails
      final r2 = GameEngine.apply(
        after,
        PlayerId.red,
        GameAction.move(const Cell(row: 4, column: 2)),
      );
      expect(r2, isA<FailureResult>());
      expect((r2 as FailureResult).failure, ActionFailure.matchFinished);
    });

    test('Example 15: Wrong turn', () {
      final s = GameState.initial();
      expect(s.currentPlayer, PlayerId.blue);
      final r = GameEngine.apply(
        s,
        PlayerId.red,
        GameAction.move(const Cell(row: 1, column: 4)),
      );
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wrongTurn);
    });

    test('Example 16: Last wall placement -> noWallsRemaining', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 8, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 1, PlayerId.red: 10},
        turnNumber: 0,
        status: GameStatus.inProgress,
      );
      final r1 = GameEngine.apply(
        s,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.h,
          anchor: const Cell(row: 5, column: 5),
        ),
      );
      expect(r1, isA<SuccessResult>());
      final afterWall = (r1 as SuccessResult).state;
      expect(afterWall.wallsRemaining(PlayerId.blue), 0);

      // Play Red's turn so it becomes Blue's turn again
      final rRed = GameEngine.apply(
        afterWall,
        PlayerId.red,
        GameAction.move(const Cell(row: 1, column: 4)),
      );
      expect(rRed, isA<SuccessResult>());
      final afterRed = (rRed as SuccessResult).state;
      expect(afterRed.currentPlayer, PlayerId.blue);

      // Blue has no walls left - next wall attempt fails
      final r2 = GameEngine.apply(
        afterRed,
        PlayerId.blue,
        GameAction.wall(
          orientation: WallOrientation.h,
          anchor: const Cell(row: 0, column: 0),
        ),
      );
      expect(r2, isA<FailureResult>());
      expect((r2 as FailureResult).failure, ActionFailure.noWallsRemaining);
    });
  });
}
