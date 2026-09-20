import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Helper to build a GameState from a minimal description.
GameState _state({
  int size = 9,
  int wpp = 10,
  required (int, int) blue,
  required (int, int) red,
  List<Wall> walls = const [],
  int turnNumber = 0,
  PlayerId? currentPlayer,
}) {
  final config = BoardConfig(size: size, wallsPerPlayer: wpp);
  final blueUsed = walls.where((w) => w.owner == PlayerId.blue).length;
  final redUsed = walls.where((w) => w.owner == PlayerId.red).length;
  return GameState(
    boardConfig: config,
    pawnPositions: {
      PlayerId.blue: Cell(row: blue.$1, column: blue.$2),
      PlayerId.red: Cell(row: red.$1, column: red.$2),
    },
    walls: walls,
    remainingWalls: {
      PlayerId.blue: wpp - blueUsed,
      PlayerId.red: wpp - redUsed,
    },
    turnNumber: turnNumber,
    status: GameStatus.inProgress,
  );
}

Wall _wall(String orient, int r, int c, PlayerId owner) => Wall(
      orientation: orient == 'H' ? WallOrientation.h : WallOrientation.v,
      anchorRow: r,
      anchorColumn: c,
      owner: owner,
    );

void main() {
  group('9.1 Movement tests', () {
    test('T-MOVE-001: basic move Blue(8,4)→(7,4)', () {
      var s = _state(blue: (8, 4), red: (0, 4));
      final a = GameAction.move(Cell(row: 7, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), Cell(row: 7, column: 4));
      expect(s.currentPlayer, PlayerId.red);
      expect(s.turnNumber, 1);
    });

    test('T-MOVE-002: move backward Blue(3,3)→(4,3)', () {
      var s = _state(blue: (3, 3), red: (0, 4));
      final a = GameAction.move(Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      expect((r as SuccessResult).state.pawnPosition(PlayerId.blue),
          Cell(row: 4, column: 3));
    });

    test('T-MOVE-003: out-of-board up', () {
      final s = _state(blue: (5, 4), red: (0, 0), turnNumber: 1);
      final a = GameAction.move(Cell(row: -1, column: 0));
      final r = GameEngine.apply(s, PlayerId.red, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
    });

    test('T-MOVE-004: out-of-board left', () {
      final s = _state(blue: (5, 4), red: (0, 0), turnNumber: 1);
      final a = GameAction.move(Cell(row: 0, column: -1));
      final r = GameEngine.apply(s, PlayerId.red, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
    });

    test('T-MOVE-005: out-of-board right', () {
      final s = _state(blue: (8, 8), red: (0, 4));
      final a = GameAction.move(Cell(row: 8, column: 9));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
    });

    test('T-MOVE-006: out-of-board down', () {
      final s = _state(blue: (8, 8), red: (0, 4));
      final a = GameAction.move(Cell(row: 9, column: 8));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
    });

    test('T-MOVE-007: blocked by H wall (down)', () {
      final s = _state(
        blue: (3, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 4, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('T-MOVE-008: blocked by V wall', () {
      final s = _state(
        blue: (5, 3),
        red: (0, 4),
        walls: [_wall('V', 5, 3, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 5, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('T-MOVE-009: moveOntoPawn', () {
      final s = _state(blue: (5, 4), red: (4, 4));
      final a = GameAction.move(Cell(row: 4, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOntoPawn);
    });

    test('T-MOVE-011: wrongTurn', () {
      final s = _state(blue: (8, 4), red: (0, 4));
      final a = GameAction.move(Cell(row: 1, column: 4));
      final r = GameEngine.apply(s, PlayerId.red, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wrongTurn);
    });

    test('T-MOVE-012: matchFinished', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: Cell(row: 0, column: 4),
          PlayerId.red: Cell(row: 3, column: 2),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 10, PlayerId.red: 10},
        turnNumber: 5,
        status: GameStatus.finished,
        winner: PlayerId.blue,
      );
      final a = GameAction.move(Cell(row: 1, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.matchFinished);
    });

    test('T-MOVE-013: sideways', () {
      var s = _state(blue: (5, 5), red: (0, 4));
      final a = GameAction.move(Cell(row: 5, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      expect((r as SuccessResult).state.pawnPosition(PlayerId.blue),
          Cell(row: 5, column: 4));
    });

    test('T-MOVE-014: backward', () {
      var s = _state(blue: (5, 5), red: (0, 4));
      final a = GameAction.move(Cell(row: 4, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      expect((r as SuccessResult).state.pawnPosition(PlayerId.blue),
          Cell(row: 4, column: 5));
    });

    test('T-MOVE-015: blocked H(3,3) blocks (3,4)→(4,4)', () {
      final s = _state(
        blue: (4, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 3, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('T-MOVE-016: blocked H(3,3) blocks (3,4)→(4,4) from other side', () {
      final s = _state(
        blue: (3, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 3, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 4, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('T-MOVE-017: blocked V(4,3) blocks (5,4)→(5,3)', () {
      final s = _state(
        blue: (5, 4),
        red: (0, 4),
        walls: [_wall('V', 4, 3, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 5, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('T-MOVE-018: blocked V(4,4) blocks (5,4)→(5,5)', () {
      final s = _state(
        blue: (5, 4),
        red: (0, 4),
        walls: [_wall('V', 4, 4, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 5, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('T-MOVE-019: blocked H(3,7) blocks (3,8)→(4,8)', () {
      final s = _state(
        blue: (3, 8),
        red: (0, 4),
        walls: [_wall('H', 3, 7, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 4, column: 8));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    });

    test('T-MOVE-020: V(4,3) does NOT block (5,4)→(5,5)', () {
      final s = _state(
        blue: (5, 4),
        red: (0, 4),
        walls: [_wall('V', 4, 3, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 5, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
    });
  });

  group('9.2 Jump tests', () {
    test('T-JUMP-001: straight jump', () {
      var s = _state(blue: (5, 4), red: (4, 4));
      final a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      expect((r as SuccessResult).state.pawnPosition(PlayerId.blue),
          Cell(row: 3, column: 4));
    });

    test('T-JUMP-002: diagonal jump left (straight blocked)', () {
      var s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      expect((r as SuccessResult).state.pawnPosition(PlayerId.blue),
          Cell(row: 4, column: 3));
    });

    test('T-JUMP-003: diagonal jump right (straight blocked)', () {
      var s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 4, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      expect((r as SuccessResult).state.pawnPosition(PlayerId.blue),
          Cell(row: 4, column: 5));
    });

    test('T-JUMP-005: diagonal jump wins (straight off-board)', () {
      var s = _state(blue: (1, 4), red: (0, 4));
      final a = GameAction.move(Cell(row: 0, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      final ns = (r as SuccessResult).state;
      expect(ns.pawnPosition(PlayerId.blue), Cell(row: 0, column: 3));
      expect(ns.status, GameStatus.finished);
      expect(ns.winner, PlayerId.blue);
    });

    test('T-JUMP-006: diagonal blocked by wall', () {
      final s = _state(
        blue: (1, 4),
        red: (0, 4),
        walls: [_wall('V', 0, 3, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 0, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveIllegalJump);
    });

    test('T-JUMP-007: moveOntoPawn (not a jump)', () {
      final s = _state(blue: (1, 4), red: (0, 4));
      final a = GameAction.move(Cell(row: 0, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOntoPawn);
    });

    test('T-JUMP-008: jump increments turnNumber', () {
      var s = _state(blue: (5, 4), red: (4, 4));
      final a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect((r as SuccessResult).state.turnNumber, 1);
    });

    test('T-JUMP-009: straight jump blocked by wall on edge', () {
      final s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveIllegalJump);
    });

    test('T-JUMP-011: straight jump with wall beyond landing', () {
      var s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 2, 4, PlayerId.blue)],
      );
      final a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      expect((r as SuccessResult).state.pawnPosition(PlayerId.blue),
          Cell(row: 3, column: 4));
    });

    test('T-JUMP-012: diagonal while straight available = illegal', () {
      final s = _state(blue: (5, 4), red: (4, 4));
      final a = GameAction.move(Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveIllegalJump);
    });

    test('T-JUMP-013: moveNotAdjacent (distance 2, no opponent)', () {
      final s = _state(blue: (5, 4), red: (0, 4));
      final a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveNotAdjacent);
    });
  });

  group('9.3 Wall tests', () {
    test('T-WALL-001: place wall', () {
      var s = _state(blue: (8, 4), red: (0, 4));
      final a = GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 0, column: 0));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      final ns = (r as SuccessResult).state;
      expect(ns.wallsRemaining(PlayerId.blue), 9);
      expect(ns.walls.length, 1);
    });

    test('T-WALL-002: wallOutOfBounds row', () {
      final s = _state(blue: (8, 4), red: (0, 4));
      final a = GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 8, column: 0));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallOutOfBounds);
    });

    test('T-WALL-003: wallOutOfBounds col', () {
      final s = _state(blue: (8, 4), red: (0, 4));
      final a = GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 0, column: 8));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallOutOfBounds);
    });

    test('T-WALL-004: wallOverlaps same anchor', () {
      final s = _state(
        blue: (8, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 3, PlayerId.blue)],
      );
      final a = GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 3, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallOverlaps);
    });

    test('T-WALL-005: wallOverlaps adjacent H', () {
      final s = _state(
        blue: (8, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 3, PlayerId.blue)],
      );
      final a = GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallOverlaps);
    });

    test('T-WALL-006: offset by 2 = success', () {
      var s = _state(
        blue: (8, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 3, PlayerId.blue)],
      );
      final a = GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 3, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
    });

    test('T-WALL-007: wallCrosses', () {
      final s = _state(
        blue: (8, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 3, PlayerId.blue)],
      );
      final a = GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 3, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallCrosses);
    });

    test('T-WALL-008: T-junction success', () {
      var s = _state(
        blue: (8, 4),
        red: (0, 4),
        walls: [_wall('H', 3, 3, PlayerId.blue)],
      );
      final a = GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
    });

    test('T-WALL-010: noWallsRemaining', () {
      final s = _state(blue: (8, 4), red: (0, 4), wpp: 0);
      final a = GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 3, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.noWallsRemaining);
    });

    test('T-WALL-011: wallBlocksPath Blue sealed', () {
      final s = _state(
        blue: (8, 0),
        red: (0, 4),
        walls: [_wall('H', 7, 0, PlayerId.blue)],
      );
      final a = GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 7, column: 1));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallBlocksPath);
    });

    test('T-WALL-012: wall does NOT block path', () {
      var s = _state(
        blue: (8, 4),
        red: (0, 4),
        walls: [_wall('V', 4, 4, PlayerId.blue)],
      );
      final a = GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
    });
  });

  group('9.4 Pathfinding tests', () {
    test('T-PATH-001: open board both have routes length=8', () {
      final b = Pathfinder.shortestRouteLength(
          from: Cell(row: 8, column: 4), goalRow: 0, walls: [], size: 9);
      final r = Pathfinder.shortestRouteLength(
          from: Cell(row: 0, column: 4), goalRow: 8, walls: [], size: 9);
      expect(b, 8);
      expect(r, 8);
    });

    test('T-PATH-002: H(4,3) both have routes length=9', () {
      final walls = [_wall('H', 4, 3, PlayerId.blue)];
      final b = Pathfinder.shortestRouteLength(
          from: Cell(row: 8, column: 4), goalRow: 0, walls: walls, size: 9);
      final r = Pathfinder.shortestRouteLength(
          from: Cell(row: 0, column: 4), goalRow: 8, walls: walls, size: 9);
      expect(b, 9);
      expect(r, 9);
    });

    test('T-PATH-005: Blue(2,0)→row 0 length=2', () {
      final len = Pathfinder.shortestRouteLength(
          from: Cell(row: 2, column: 0), goalRow: 0, walls: [], size: 9);
      expect(len, 2);
    });

    test('T-PATH-004: wallBlocksPath for V(7,1)', () {
      final walls = [_wall('H', 7, 0, PlayerId.blue)];
      final b = Pathfinder.canReachGoal(
          from: Cell(row: 8, column: 0),
          goalRow: 0,
          walls: [...walls, _wall('V', 7, 1, PlayerId.blue)],
          size: 9);
      expect(b, isFalse);
    });

    test('T-PATH-006: BFS vs DFS consistency', () {
      final walls = [_wall('H', 4, 3, PlayerId.blue)];
      final bfs = Pathfinder.canReachGoal(
          from: Cell(row: 8, column: 4),
          goalRow: 0,
          walls: walls,
          size: 9);
      final dfs = Pathfinder.canReachGoalDfs(
          from: Cell(row: 8, column: 4),
          goalRow: 0,
          walls: walls,
          size: 9);
      expect(bfs, dfs);
    });
  });

  group('9.5 Win tests', () {
    test('T-WIN-001: Blue reaches row 0 wins', () {
      var s = _state(blue: (1, 4), red: (3, 2), turnNumber: 0);
      final r = GameEngine.apply(
          s, PlayerId.blue, GameAction.move(Cell(row: 0, column: 4)));
      final ns = (r as SuccessResult).state;
      expect(ns.status, GameStatus.finished);
      expect(ns.winner, PlayerId.blue);
    });

    test('T-WIN-002: Red reaches row 8 wins', () {
      var s = _state(
        blue: (3, 2),
        red: (7, 4),
        walls: [],
        turnNumber: 0,
      );
      final r1 = GameEngine.apply(s, PlayerId.blue,
          GameAction.move(Cell(row: 3, column: 3)));
      s = (r1 as SuccessResult).state;
      final r2 = GameEngine.apply(s, PlayerId.red,
          GameAction.move(Cell(row: 8, column: 4)));
      final ns = (r2 as SuccessResult).state;
      expect(ns.status, GameStatus.finished);
      expect(ns.winner, PlayerId.red);
    });

    test('T-WIN-003: Red reaching row 0 does NOT win', () {
      var s = _state(blue: (7, 4), red: (1, 4), turnNumber: 0);
      final r1 = GameEngine.apply(s, PlayerId.blue,
          GameAction.move(Cell(row: 7, column: 3)));
      s = (r1 as SuccessResult).state;
      final r2 = GameEngine.apply(s, PlayerId.red,
          GameAction.move(Cell(row: 0, column: 4)));
      final ns = (r2 as SuccessResult).state;
      expect(ns.status, GameStatus.inProgress);
      expect(ns.winner, isNull);
    });

    test('T-WIN-005: win via jump', () {
      var s = _state(blue: (1, 4), red: (0, 4));
      final a = GameAction.move(Cell(row: 0, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      final ns = (r as SuccessResult).state;
      expect(ns.status, GameStatus.finished);
      expect(ns.winner, PlayerId.blue);
    });

    test('T-WIN-006: Blue reaching row 8 does NOT win', () {
      var s = _state(blue: (7, 4), red: (3, 2));
      final a = GameAction.move(Cell(row: 8, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      final ns = (r as SuccessResult).state;
      expect(ns.status, GameStatus.inProgress);
      expect(ns.winner, isNull);
    });
  });

  group('9.6 Turn handling tests', () {
    test('T-TURN-001: Blue moves → Red turn, turn=1', () {
      var s = _state(blue: (8, 4), red: (0, 4));
      final r = GameEngine.apply(
          s, PlayerId.blue, GameAction.move(Cell(row: 7, column: 4)));
      final ns = (r as SuccessResult).state;
      expect(ns.turnNumber, 1);
      expect(ns.currentPlayer, PlayerId.red);
    });

    test('T-TURN-002: Red moves → Blue turn, turn=2', () {
      var s = _state(blue: (7, 4), red: (0, 4), turnNumber: 1);
      final r = GameEngine.apply(
          s, PlayerId.red, GameAction.move(Cell(row: 1, column: 4)));
      final ns = (r as SuccessResult).state;
      expect(ns.turnNumber, 2);
      expect(ns.currentPlayer, PlayerId.blue);
    });

    test('T-TURN-003: wall placement increments turn', () {
      var s = _state(blue: (8, 4), red: (0, 4));
      final r = GameEngine.apply(
          s,
          PlayerId.blue,
          GameAction.wall(
              orientation: WallOrientation.h,
              anchor: Cell(row: 0, column: 0)));
      expect((r as SuccessResult).state.turnNumber, 1);
    });

    test('T-TURN-005..006: parity', () {
      var s = _state(blue: (8, 4), red: (0, 4));
      expect(s.currentPlayer, PlayerId.blue);
      s = (GameEngine.apply(
              s,
              PlayerId.blue,
              GameAction.move(Cell(row: 7, column: 4)))
          as SuccessResult)
          .state;
      expect(s.currentPlayer, PlayerId.red);
      s = (GameEngine.apply(
              s,
              PlayerId.red,
              GameAction.move(Cell(row: 1, column: 4)))
          as SuccessResult)
          .state;
      expect(s.currentPlayer, PlayerId.blue);
    });
  });

  group('9.7 Serialization tests', () {
    test('T-SERIAL-001: initial state round-trip', () {
      final s = GameState.initial();
      final j = GameStateSerializer.toJson(s);
      final s2 = GameStateSerializer.fromJson(j);
      expect(s2, isNotNull);
      expect(s2!.boardConfig.size, s.boardConfig.size);
      expect(s2.turnNumber, s.turnNumber);
      expect(s2.status, s.status);
      expect(s2.currentPlayer, s.currentPlayer);
    });

    test('T-SERIAL-002: mid-game state round-trip', () {
      var s = _state(
        blue: (5, 4),
        red: (2, 4),
        walls: [_wall('H', 3, 1, PlayerId.red)],
        turnNumber: 5,
        wpp: 10,
      );
      final j = GameStateSerializer.toJson(s);
      final s2 = GameStateSerializer.fromJson(j);
      expect(s2, isNotNull);
      expect(s2!.pawnPosition(PlayerId.blue), Cell(row: 5, column: 4));
      expect(s2.walls.length, 1);
      expect(s2.wallsRemaining(PlayerId.red), 9);
    });

    test('T-SERIAL-003: finished state preserves winner', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: Cell(row: 0, column: 4),
          PlayerId.red: Cell(row: 3, column: 2),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 10, PlayerId.red: 10},
        turnNumber: 10,
        status: GameStatus.finished,
        winner: PlayerId.blue,
      );
      final j = GameStateSerializer.toJson(s);
      final s2 = GameStateSerializer.fromJson(j);
      expect(s2, isNotNull);
      expect(s2!.status, GameStatus.finished);
      expect(s2.winner, PlayerId.blue);
    });

    test('T-SERIAL-004: unknown schemaVersion rejected', () {
      final j = {
        'schemaVersion': 999,
        'boardConfig': {'size': 9, 'wallsPerPlayer': 10},
      };
      expect(GameStateSerializer.fromJson(j), isNull);
    });

    test('T-SERIAL-005: malformed JSON rejected', () {
      expect(GameStateSerializer.decode('{invalid'), isNull);
    });
  });

  group('9.8 Determinism tests', () {
    test('T-DET-001..004: initial state legal actions count and order', () {
      final s = GameState.initial();
      final legal = MoveGenerator.generate(s, PlayerId.blue);
      final moves = legal.whereType<MoveAction>().length;
      final walls = legal.whereType<WallAction>().length;
      expect(moves, 3);
      expect(walls, 128);
      expect(legal.length, 131);
      expect(legal.first.toNotation(), 'M 7,4');
      expect(legal[1].toNotation(), 'M 8,3');
      expect(legal[2].toNotation(), 'M 8,5');
    });

    test('T-DET-005: property test - legalActions never empty while inProgress',
        () {
      final rng = _SeededRandom(42);
      for (final size in [5, 9]) {
        final wpp = size == 9 ? 10 : 5;
        for (var seed = 0; seed < 200; seed++) {
          var s = GameState.initial(
              BoardConfig(size: size, wallsPerPlayer: wpp));
          var moves = 0;
          while (s.status == GameStatus.inProgress && moves < 200) {
            final legal =
                MoveGenerator.generate(s, s.currentPlayer);
            expect(legal, isNotEmpty,
                reason: 'Empty legal actions at seed=$seed, size=$size, '
                    'ply=$moves');
            final idx = rng.nextInt(legal.length);
            final r =
                GameEngine.apply(s, s.currentPlayer, legal[idx]);
            s = (r as SuccessResult).state;
            moves++;
          }
        }
      }
    });
  });

  group('9.9 Config tests', () {
    test('T-CONFIG-001: size=8 invalid', () {
      expect(BoardConfig.validate(8, 10), isNotNull);
    });

    test('T-CONFIG-002: size=3 invalid', () {
      expect(BoardConfig.validate(3, 10), isNotNull);
    });

    test('T-CONFIG-003: size=7 valid', () {
      expect(BoardConfig.validate(7, 8), isNull);
      final s = GameState.initial(BoardConfig(size: 7, wallsPerPlayer: 8));
      expect(s.pawnPosition(PlayerId.blue), Cell(row: 6, column: 3));
      expect(s.pawnPosition(PlayerId.red), Cell(row: 0, column: 3));
      expect(s.boardConfig.blueGoalRow, 0);
      expect(s.boardConfig.redGoalRow, 6);
    });

    test('T-CONFIG-004: size=5 valid', () {
      expect(BoardConfig.validate(5, 5), isNull);
      final s = GameState.initial(BoardConfig(size: 5, wallsPerPlayer: 5));
      expect(s.pawnPosition(PlayerId.blue), Cell(row: 4, column: 2));
      expect(s.pawnPosition(PlayerId.red), Cell(row: 0, column: 2));
    });
  });
}

class _SeededRandom {
  _SeededRandom(this._seed);
  int _seed;

  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed % max;
  }
}
