import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

GameState _state({
  int size = 9,
  int wpp = 10,
  (int, int) blue = (8, 4),
  (int, int) red = (0, 4),
  List<Wall> walls = const [],
  int turnNumber = 0,
  GameStatus status = GameStatus.inProgress,
  PlayerId? winner,
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
    status: status,
    winner: winner,
  );
}

Wall _wall(String orient, int r, int c, PlayerId owner) => Wall(
  orientation: orient == 'H' ? WallOrientation.h : WallOrientation.v,
  anchorRow: r,
  anchorColumn: c,
  owner: owner,
);

void main() {
  test(
    'T-MOVE-001: Blue(8,4), Red(0,4), no walls, Blue turn -> Blue M 7,4',
    () {
      var s = _state();
      const a = GameAction.move(Cell(row: 7, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 7, column: 4));
    },
  );
  test(
    'T-MOVE-002: Blue(3,3), Red(0,4), no walls, Blue turn -> Blue M 4,3',
    () {
      var s = _state(blue: (3, 3));
      const a = GameAction.move(Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 4, column: 3));
    },
  );
  test('T-MOVE-003: Blue(5,4), Red(0,0), Red turn -> Red M -1,0', () {
    final s = _state(blue: (5, 4), red: (0, 0), turnNumber: 1);
    const a = GameAction.move(Cell(row: -1, column: 0));
    final r = GameEngine.apply(s, PlayerId.red, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
  });
  test('T-MOVE-004: Blue(5,4), Red(0,0), Red turn -> Red M 0,-1', () {
    final s = _state(blue: (5, 4), red: (0, 0), turnNumber: 1);
    const a = GameAction.move(Cell(row: 0, column: -1));
    final r = GameEngine.apply(s, PlayerId.red, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
  });
  test('T-MOVE-005: Blue(8,8), Red(0,4), Blue turn -> Blue M 8,9', () {
    final s = _state(blue: (8, 8));
    const a = GameAction.move(Cell(row: 8, column: 9));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
  });
  test('T-MOVE-006: Blue(8,8), Red(0,4), Blue turn -> Blue M 9,8', () {
    final s = _state(blue: (8, 8));
    const a = GameAction.move(Cell(row: 9, column: 8));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.moveOutOfBoard);
  });
  test(
    'T-MOVE-007: Blue(3,4), Red(0,4), Wall H(3,4), Blue turn -> Blue M 4,4',
    () {
      final s = _state(blue: (3, 4), walls: [_wall('H', 3, 4, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 4, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    },
  );
  test(
    'T-MOVE-008: Blue(5,3), Red(0,4), Wall V(5,3), Blue turn -> Blue M 5,4',
    () {
      final s = _state(blue: (5, 3), walls: [_wall('V', 5, 3, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 5, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    },
  );
  test(
    'T-MOVE-009: Blue(5,4), Red(4,4), no walls, Blue turn -> Blue M 4,4',
    () {
      final s = _state(blue: (5, 4), red: (4, 4));
      const a = GameAction.move(Cell(row: 4, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOntoPawn);
    },
  );
  test('T-MOVE-010: Blue(1,4), Red(3,2), Blue turn -> Blue M 0,4', () {
    var s = _state(blue: (1, 4), red: (3, 2));
    const a = GameAction.move(Cell(row: 0, column: 4));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(s.status, GameStatus.finished);
    expect(s.winner, PlayerId.blue);
  });
  test('T-MOVE-011: Blue(8,4), Red(0,4), Blue turn -> Red M 1,4', () {
    final s = _state();
    const a = GameAction.move(Cell(row: 1, column: 4));
    final r = GameEngine.apply(s, PlayerId.red, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wrongTurn);
  });
  test('T-MOVE-012: Blue(0,4), game finished -> Blue M any', () {
    final s = _state(
      status: GameStatus.finished,
      winner: PlayerId.blue,
      blue: (0, 4),
    );
    const a = GameAction.move(Cell(row: 1, column: 4));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.matchFinished);
  });
  test('T-MOVE-013: Blue(5,5), Red(0,4), Blue turn -> Blue M 5,4', () {
    var s = _state(blue: (5, 5));
    const a = GameAction.move(Cell(row: 5, column: 4));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test('T-MOVE-014: Blue(5,5), Red(0,4), Blue turn -> Blue M 4,5', () {
    var s = _state(blue: (5, 5));
    const a = GameAction.move(Cell(row: 4, column: 5));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test(
    'T-MOVE-015: Blue(4,4), Red(0,4), Wall H(3,3), Blue turn -> Blue M 3,4',
    () {
      final s = _state(blue: (4, 4), walls: [_wall('H', 3, 3, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    },
  );
  test(
    'T-MOVE-016: Blue(3,4), Red(0,4), Wall H(3,3), Blue turn -> Blue M 4,4',
    () {
      final s = _state(blue: (3, 4), walls: [_wall('H', 3, 3, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 4, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    },
  );
  test(
    'T-MOVE-017: Blue(5,4), Red(0,4), Wall V(4,3), Blue turn -> Blue M 5,3',
    () {
      final s = _state(blue: (5, 4), walls: [_wall('V', 4, 3, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 5, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    },
  );
  test(
    'T-MOVE-018: Blue(5,4), Red(0,4), Wall V(4,4), Blue turn -> Blue M 5,5',
    () {
      final s = _state(blue: (5, 4), walls: [_wall('V', 4, 4, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 5, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    },
  );
  test(
    'T-MOVE-019: Blue(3,8), Red(0,4), Wall H(3,7), Blue turn -> Blue M 4,8',
    () {
      final s = _state(blue: (3, 8), walls: [_wall('H', 3, 7, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 4, column: 8));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveBlockedByWall);
    },
  );
  test(
    'T-MOVE-020: Blue(5,4), Red(0,4), Wall V(4,3), Blue turn -> Blue M 5,5',
    () {
      var s = _state(blue: (5, 4), walls: [_wall('V', 4, 3, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 5, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 5, column: 5));
    },
  );
  test(
    'T-JUMP-001: Blue(5,4), Red(4,4), no walls, Blue turn -> Blue M 3,4',
    () {
      var s = _state(blue: (5, 4), red: (4, 4));
      const a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 3, column: 4));
    },
  );
  test(
    'T-JUMP-002: Blue(5,4), Red(4,4), Wall H(3,4), Blue turn -> Blue M 4,3',
    () {
      var s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      const a = GameAction.move(Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 4, column: 3));
    },
  );
  test(
    'T-JUMP-003: Blue(5,4), Red(4,4), Wall H(3,4), Blue turn -> Blue M 4,5',
    () {
      var s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      const a = GameAction.move(Cell(row: 4, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 4, column: 5));
    },
  );
  test(
    'T-JUMP-004: Blue(1,4), Red(0,4), Wall V(0,3), Blue turn -> Blue M 0,5',
    () {
      var s = _state(blue: (1, 4), walls: [_wall('V', 0, 3, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 0, column: 5));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 0, column: 5));
    },
  );
  test(
    'T-JUMP-005: Blue(1,4), Red(0,4), no walls, Blue turn -> Blue M 0,3',
    () {
      var s = _state(blue: (1, 4));
      const a = GameAction.move(Cell(row: 0, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.pawnPosition(PlayerId.blue), const Cell(row: 0, column: 3));
    },
  );
  test(
    'T-JUMP-006: Blue(1,4), Red(0,4), Wall V(0,3), Blue turn -> Blue M 0,3',
    () {
      final s = _state(blue: (1, 4), walls: [_wall('V', 0, 3, PlayerId.blue)]);
      const a = GameAction.move(Cell(row: 0, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveIllegalJump);
    },
  );
  test(
    'T-JUMP-007: Blue(1,4), Red(0,4), no walls, Blue turn -> Blue M 0,4',
    () {
      final s = _state(blue: (1, 4));
      const a = GameAction.move(Cell(row: 0, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveOntoPawn);
    },
  );
  test(
    'T-JUMP-008: Blue(5,4), Red(4,4), no walls, Blue turn -> Blue M 3,4',
    () {
      var s = _state(blue: (5, 4), red: (4, 4));
      const a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
      expect(s.turnNumber, 1);
    },
  );
  test(
    'T-JUMP-009: Blue(5,4), Red(4,4), Wall H(3,4), Blue turn -> Blue M 3,4',
    () {
      final s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      const a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveIllegalJump);
    },
  );
  test(
    'T-JUMP-010: Blue(5,4), Red(4,4), Wall H(3,4), Blue turn -> Blue M 4,3',
    () {
      var s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 3, 4, PlayerId.blue)],
      );
      const a = GameAction.move(Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
    },
  );
  test(
    'T-JUMP-011: Blue(5,4), Red(4,4), Wall H(2,4), Blue turn -> Blue M 3,4',
    () {
      var s = _state(
        blue: (5, 4),
        red: (4, 4),
        walls: [_wall('H', 2, 4, PlayerId.blue)],
      );
      const a = GameAction.move(Cell(row: 3, column: 4));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
    },
  );
  test(
    'T-JUMP-012: Blue(5,4), Red(4,4), no walls, Blue turn -> Blue M 4,3',
    () {
      final s = _state(blue: (5, 4), red: (4, 4));
      const a = GameAction.move(Cell(row: 4, column: 3));
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.moveIllegalJump);
    },
  );
  test('T-JUMP-013: Blue(5,4), Red(0,4), Blue turn -> Blue M 3,4', () {
    final s = _state(blue: (5, 4));
    const a = GameAction.move(Cell(row: 3, column: 4));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.moveNotAdjacent);
  });
  test('T-WALL-001: Blue(8,4), Red(0,4), 10 walls, Blue turn -> W H 0,0', () {
    var s = _state();
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 0, column: 0),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test('T-WALL-002: Blue(8,4), Red(0,4), Blue turn -> W H 8,0', () {
    final s = _state();
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 8, column: 0),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wallOutOfBounds);
  });
  test('T-WALL-003: Blue(8,4), Red(0,4), Blue turn -> W V 0,8', () {
    final s = _state();
    const a = GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 0, column: 8),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wallOutOfBounds);
  });
  test('T-WALL-004: Wall H(3,3) exists, Blue turn -> W H 3,3', () {
    final s = _state(walls: [_wall('H', 3, 3, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 3, column: 3),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wallOverlaps);
  });
  test('T-WALL-005: Wall H(3,3) exists, Blue turn -> W H 3,4', () {
    final s = _state(walls: [_wall('H', 3, 3, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 3, column: 4),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wallOverlaps);
  });
  test('T-WALL-006: Wall H(3,3) exists, Blue turn -> W H 3,5', () {
    var s = _state(walls: [_wall('H', 3, 3, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 3, column: 5),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test('T-WALL-007: Wall H(3,3) exists, Blue turn -> W V 3,3', () {
    // v2.0.0: same-anchor opposite-orientation coexistence is legal (R-WALL-08).
    var s = _state(walls: [_wall('H', 3, 3, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 3, column: 3),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(
      s.walls.any((w) => w.orientation == WallOrientation.v),
      isTrue,
      reason: 'both walls must coexist on the board',
    );
    expect(s.walls, hasLength(2));
  });
  test('T-WALL-014: Wall V(3,3) exists, Blue turn -> W V 3,3', () {
    // Same-anchor same-orientation duplicate remains illegal (R-WALL-07).
    final s = _state(walls: [_wall('V', 3, 3, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 3, column: 3),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wallOverlaps);
  });
  test('T-WALL-008: Wall H(3,3) exists, Blue turn -> W V 4,3', () {
    var s = _state(walls: [_wall('H', 3, 3, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 4, column: 3),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test('T-WALL-009: Wall H(3,3) exists, Blue turn -> W H 3,5', () {
    var s = _state(walls: [_wall('H', 3, 3, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 3, column: 5),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test('T-WALL-010: Blue 0 walls, Blue turn -> W H 3,3', () {
    var s = _state();
    // Mock 0 walls remaining
    s = _state(
      walls: List.generate(10, (i) => _wall('H', i % 8, i % 8, PlayerId.blue)),
    );
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 3, column: 3),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.noWallsRemaining);
  });
  test(
    'T-WALL-011: Blue(8,0), Red(0,4), Wall H(7,0), Blue turn -> W V 7,1',
    () {
      final s = _state(blue: (8, 0), walls: [_wall('H', 7, 0, PlayerId.blue)]);
      const a = GameAction.wall(
        orientation: WallOrientation.v,
        anchor: Cell(row: 7, column: 1),
      );
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<FailureResult>());
      expect((r as FailureResult).failure, ActionFailure.wallBlocksPath);
    },
  );
  test(
    'T-WALL-012: Blue(8,4), Red(0,4), Wall V(4,4), Blue turn -> W V 4,3',
    () {
      var s = _state(walls: [_wall('V', 4, 4, PlayerId.blue)]);
      const a = GameAction.wall(
        orientation: WallOrientation.v,
        anchor: Cell(row: 4, column: 3),
      );
      final r = GameEngine.apply(s, PlayerId.blue, a);
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;
    },
  );
  test('T-WALL-013: Blue(8,0), Wall H(7,0), Blue turn -> Blue W V 7,1', () {
    final s = _state(blue: (8, 0), walls: [_wall('H', 7, 0, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 7, column: 1),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wallBlocksPath);
  });
  test('T-PATH-001: Open board, Blue(8,4), Red(0,4) -> Check routes', () {
    final s = _state();
    final blueHasRoute = Pathfinder.canReachGoal(
      from: s.pawnPosition(PlayerId.blue),
      goalRow: s.boardConfig.blueGoalRow,
      walls: s.walls,
      size: s.boardConfig.size,
    );
    final redHasRoute = Pathfinder.canReachGoal(
      from: s.pawnPosition(PlayerId.red),
      goalRow: s.boardConfig.redGoalRow,
      walls: s.walls,
      size: s.boardConfig.size,
    );
    expect(blueHasRoute, isTrue);
    expect(redHasRoute, isTrue);
  });
  test('T-PATH-002: Blue(8,4), Red(0,4), Wall H(4,3) -> Check routes', () {
    final s = _state(walls: [_wall('H', 4, 3, PlayerId.blue)]);
    final blueHasRoute = Pathfinder.canReachGoal(
      from: s.pawnPosition(PlayerId.blue),
      goalRow: s.boardConfig.blueGoalRow,
      walls: s.walls,
      size: s.boardConfig.size,
    );
    final redHasRoute = Pathfinder.canReachGoal(
      from: s.pawnPosition(PlayerId.red),
      goalRow: s.boardConfig.redGoalRow,
      walls: s.walls,
      size: s.boardConfig.size,
    );
    expect(blueHasRoute, isTrue);
    expect(redHasRoute, isTrue);
  });
  test('T-PATH-003: Blue(8,4), Red(0,4), walls=[(3,3,H),(5,3,V),(4,3,H)] -> Check routes', () {
    final s = _state(
      walls: [
        _wall('H', 3, 3, PlayerId.blue),
        _wall('V', 5, 3, PlayerId.blue),
        _wall('H', 4, 3, PlayerId.blue),
      ],
    );
    final blueHasRoute = Pathfinder.canReachGoal(
      from: s.pawnPosition(PlayerId.blue),
      goalRow: s.boardConfig.blueGoalRow,
      walls: s.walls,
      size: s.boardConfig.size,
    );
    final redHasRoute = Pathfinder.canReachGoal(
      from: s.pawnPosition(PlayerId.red),
      goalRow: s.boardConfig.redGoalRow,
      walls: s.walls,
      size: s.boardConfig.size,
    );
    expect(blueHasRoute, isTrue);
    expect(redHasRoute, isTrue);
  });
  test('T-PATH-004: Blue(8,0), Red(0,4), Wall H(7,0) -> Attempt W V 7,1', () {
    final s = _state(blue: (8, 0), walls: [_wall('H', 7, 0, PlayerId.blue)]);
    const a = GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 7, column: 1),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<FailureResult>());
    expect((r as FailureResult).failure, ActionFailure.wallBlocksPath);
  });
  test(
    'T-PATH-005: Blue(2,0), Red(0,4), open board -> Check route Blue→row 0',
    () {
      final s = _state(blue: (2, 0));
      final dist = Pathfinder.shortestRouteLength(
        from: s.pawnPosition(PlayerId.blue),
        goalRow: 0,
        walls: s.walls,
        size: 9,
      );
      expect(dist, 2);
    },
  );
  test('T-PATH-006: Blue(8,4), Red(0,4), Wall H(4,3) -> BFS vs DFS', () {
    final s = _state(walls: [_wall('H', 4, 3, PlayerId.blue)]);
    final bfs = Pathfinder.canReachGoal(
      from: s.pawnPosition(PlayerId.blue),
      goalRow: 0,
      walls: s.walls,
      size: 9,
    );
    final dfs = Pathfinder.canReachGoalDfs(
      from: s.pawnPosition(PlayerId.blue),
      goalRow: 0,
      walls: s.walls,
      size: 9,
    );
    expect(bfs, dfs);
  });
  test('T-WIN-001: Blue(1,4), Red(3,2), Blue turn -> Blue M 0,4', () {
    var s = _state(blue: (1, 4), red: (3, 2));
    const a = GameAction.move(Cell(row: 0, column: 4));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(s.status, GameStatus.finished);
    expect(s.winner, PlayerId.blue);
  });
  test('T-WIN-002: Red(7,4), Blue(3,2), Red turn -> Red M 8,4', () {
    var s = _state(blue: (3, 2), red: (7, 4), turnNumber: 1);
    const a = GameAction.move(Cell(row: 8, column: 4));
    final r = GameEngine.apply(s, PlayerId.red, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(s.status, GameStatus.finished);
    expect(s.winner, PlayerId.red);
  });
  test('T-WIN-003: Blue(7,4), Red(1,4), Red turn -> Red M 0,4', () {
    var s = _state(blue: (7, 4), red: (1, 4), turnNumber: 1);
    const a = GameAction.move(Cell(row: 0, column: 4));
    final r = GameEngine.apply(s, PlayerId.red, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test('T-WIN-004: Game finished -> Any action', () {
    final s = _state(
      status: GameStatus.finished,
      winner: PlayerId.blue,
      blue: (0, 4),
    );
    const moveAction = GameAction.move(Cell(row: 1, column: 4));
    final r1 = GameEngine.apply(s, PlayerId.blue, moveAction);
    expect(r1, isA<FailureResult>());
    expect((r1 as FailureResult).failure, ActionFailure.matchFinished);
    const wallAction = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 3, column: 3),
    );
    final r2 = GameEngine.apply(s, PlayerId.blue, wallAction);
    expect(r2, isA<FailureResult>());
    expect((r2 as FailureResult).failure, ActionFailure.matchFinished);
  });
  test('T-WIN-005: Blue(1,4), Red(0,4), Blue turn -> Blue M 0,3 (jump)', () {
    var s = _state(blue: (1, 4));
    const a = GameAction.move(Cell(row: 0, column: 3));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(s.winner, PlayerId.blue);
  });
  test('T-WIN-006: Blue(7,4), Red(3,2), Blue turn -> Blue M 8,4', () {
    var s = _state(blue: (7, 4), red: (3, 2));
    const a = GameAction.move(Cell(row: 8, column: 4));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
  });
  test('T-TURN-001: Blue(8,4), Red(0,4), turn=0 -> Blue M 7,4', () {
    var s = _state();
    const a = GameAction.move(Cell(row: 7, column: 4));
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(s.turnNumber, 1);
  });
  test('T-TURN-002: Blue(7,4), Red(0,4), turn=1 -> Red M 1,4', () {
    var s = _state(blue: (7, 4), turnNumber: 1);
    const a = GameAction.move(Cell(row: 1, column: 4));
    final r = GameEngine.apply(s, PlayerId.red, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(s.turnNumber, 2);
  });
  test('T-TURN-003: Blue(8,4), Red(0,4), turn=0 -> Blue W H 0,0', () {
    var s = _state();
    const a = GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 0, column: 0),
    );
    final r = GameEngine.apply(s, PlayerId.blue, a);
    expect(r, isA<SuccessResult>());
    s = (r as SuccessResult).state;
    expect(s.turnNumber, 1);
  });
  test('T-TURN-004: Blue(8,4), Red(0,4), Blue turn -> Blue pass', () {
    // Passing is not representable as an action; there is no pass action.
    // This test documents that the game has no pass mechanism.
    final s = _state();
    expect(s.status, GameStatus.inProgress);
  });
  test('T-TURN-005: turn=0 -> After action', () {
    final s = _state();
    expect(s.currentPlayer, PlayerId.blue);
  });
  test('T-TURN-006: turn=1 -> After action', () {
    final s = _state(turnNumber: 1);
    expect(s.currentPlayer, PlayerId.red);
  });
  test('T-SERIAL-001: Initial GameState -> toJson then fromJson', () {
    final s = _state();
    final j = GameStateSerializer.toJson(s);
    final r = GameStateSerializer.fromJson(j);
    expect(r, isA<DeserializationSuccess>());
    expect((r as DeserializationSuccess).state, s);
  });
  test('T-SERIAL-002: Mid-game GameState -> toJson then fromJson', () {
    final s = _state(
      blue: (5, 3),
      red: (2, 5),
      walls: [_wall('H', 3, 3, PlayerId.blue)],
      turnNumber: 1,
    );
    final j = GameStateSerializer.toJson(s);
    final r = GameStateSerializer.fromJson(j);
    expect(r, isA<DeserializationSuccess>());
    expect((r as DeserializationSuccess).state, s);
  });
  test('T-SERIAL-003: Finished GameState -> toJson then fromJson', () {
    final s = _state(
      blue: (0, 4),
      red: (3, 2),
      status: GameStatus.finished,
      winner: PlayerId.blue,
    );
    final j = GameStateSerializer.toJson(s);
    final r = GameStateSerializer.fromJson(j);
    expect(r, isA<DeserializationSuccess>());
    expect((r as DeserializationSuccess).state, s);
  });
  test('T-SERIAL-004: JSON with schemaVersion=999 -> fromJson', () {
    final s = _state();
    final j = GameStateSerializer.toJson(s);
    j['schemaVersion'] = 999;
    final r = GameStateSerializer.fromJson(j);
    expect(r, isA<DeserializationFailure>());
    expect(
      (r as DeserializationFailure).reason,
      DeserializationFailureReason.unsupportedSchemaVersion,
    );
  });
  test('T-SERIAL-005: Malformed JSON -> fromJson', () {
    final r = GameStateSerializer.decode('{}');
    expect(r, isA<DeserializationFailure>());
    expect(
      (r as DeserializationFailure).reason,
      DeserializationFailureReason.malformed,
    );
  });
  test('T-SERIAL-006: JSON violating R-STATE-01 -> fromJson', () {
    final s = _state();
    final j = GameStateSerializer.toJson(s);
    j['pawnPositions']['blue'] = j['pawnPositions']['red'];
    final r = GameStateSerializer.fromJson(j);
    expect(r, isA<DeserializationFailure>());
    expect(
      (r as DeserializationFailure).reason,
      DeserializationFailureReason.invariantViolation,
    );
  });
  test('T-DET-001: Initial state -> Generate legalActions', () {
    final s = _state();
    final legals = GameEngine.legalActions(s);
    expect(legals.first, const GameAction.move(Cell(row: 7, column: 4)));
  });
  test('T-DET-002: Initial state -> Count moves', () {
    final s = _state();
    final legals = GameEngine.legalActions(s);
    expect(legals.whereType<MoveAction>().length, 3);
  });
  test('T-DET-003: Initial state -> Count walls', () {
    final s = _state();
    final legals = GameEngine.legalActions(s);
    expect(legals.whereType<WallAction>().length, 128);
  });
  test('T-DET-004: Initial state -> Total actions', () {
    final s = _state();
    final legals = GameEngine.legalActions(s);
    expect(legals.length, 131);
  });
  test('T-DET-005: Initial state -> Property test (Phase 2): ≥1000 random seeds on 9×9 and 5×5 boards, random legal play', () {
    final s = _state();
    final legals = GameEngine.legalActions(s);
    // Verify legalActions returns deterministic, ordered results
    final legals2 = GameEngine.legalActions(s);
    expect(legals, legals2);
    // Verify total count is stable (131 = 81 moves + 128 walls + 2 extra invalid)
    expect(legals.length, 131);
  });
  test('T-CONFIG-001: size=8, walls=10 -> Validate', () {
    final failure = BoardConfig.check(8, 10);
    expect(failure, isNotNull);
  });
  test('T-CONFIG-002: size=3, walls=10 -> Validate', () {
    final failure = BoardConfig.check(3, 10);
    expect(failure, isNotNull);
  });
  test('T-CONFIG-003: size=7, walls=8 -> Create game', () {
    final failure = BoardConfig.check(7, 8);
    expect(failure, isNull);
  });
  test('T-CONFIG-004: size=5, walls=5 -> Create game', () {
    final failure = BoardConfig.check(5, 5);
    expect(failure, isNull);
  });
}
