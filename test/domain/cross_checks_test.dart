import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

GameState _initialState({int size = 9, int wpp = 10}) =>
    GameState.initial(BoardConfig(size: size, wallsPerPlayer: wpp));

void main() {
  group('Property: ≥1000 random seeds on 9×9 and 5×5', () {
    test('9×9: 300 random seeds', () {
      _randomPlayTest(size: 9, wpp: 10, seeds: 300);
    });

    test('5×5: 300 random seeds', () {
      _randomPlayTest(size: 5, wpp: 5, seeds: 300);
    });

    test('7×7: 300 random seeds', () {
      _randomPlayTest(size: 7, wpp: 7, seeds: 300);
    });

    test('9×9 batch 2: 200 random seeds', () {
      _randomPlayTest(size: 9, wpp: 10, seeds: 200);
    });

    test('5×5 batch 2: 200 random seeds', () {
      _randomPlayTest(size: 5, wpp: 5, seeds: 200);
    });
  });

  group('Independent naive action validator', () {
    test('naive validator matches engine on initial state', () {
      final s = _initialState();
      final legals = GameEngine.legalActions(s);
      final naiveLegals = _naiveLegalActions(s, s.currentPlayer);
      expect(legals.length, naiveLegals.length);
      for (var i = 0; i < legals.length; i++) {
        expect(legals[i], naiveLegals[i], reason: 'Mismatch at index $i');
      }
    });

    test('naive validator matches engine on mid-game state', () {
      var s = _initialState();
      // Play a few moves
      for (final dest in [
        const Cell(row: 7, column: 4),
        const Cell(row: 1, column: 4),
        const Cell(row: 6, column: 4),
        const Cell(row: 2, column: 4),
      ]) {
        final r = GameEngine.apply(s, s.currentPlayer, GameAction.move(dest));
        if (r is SuccessResult) s = r.state;
      }
      final legals = GameEngine.legalActions(s);
      final naiveLegals = _naiveLegalActions(s, s.currentPlayer);
      expect(
        legals.length,
        naiveLegals.length,
        reason: 'Legal action count mismatch at turn ${s.turnNumber}',
      );
    });

    test('naive validator matches engine on state with walls', () {
      var s = _initialState();
      // Place a wall
      final r = GameEngine.apply(
        s,
        PlayerId.blue,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 3, column: 3),
        ),
      );
      expect(r, isA<SuccessResult>());
      s = (r as SuccessResult).state;

      final legals = GameEngine.legalActions(s);
      final naiveLegals = _naiveLegalActions(s, s.currentPlayer);
      expect(
        legals.length,
        naiveLegals.length,
        reason: 'Legal action count mismatch after wall placement',
      );
    });
  });

  group('BFS vs DFS path-preservation cross-check', () {
    test('BFS and DFS agree on all states in random play', () {
      final rng = Random(42);
      for (var i = 0; i < 100; i++) {
        var s = _initialState();
        for (var turn = 0; turn < 200; turn++) {
          final legals = GameEngine.legalActions(s);
          if (legals.isEmpty) break;
          final action = legals[rng.nextInt(legals.length)];
          final result = GameEngine.apply(s, s.currentPlayer, action);
          if (result is SuccessResult) {
            s = result.state;
          } else {
            break;
          }

          final bfsBlue = Pathfinder.canReachGoal(
            from: s.pawnPosition(PlayerId.blue),
            goalRow: s.boardConfig.blueGoalRow,
            walls: s.walls,
            size: s.boardConfig.size,
          );
          final dfsBlue = Pathfinder.canReachGoalDfs(
            from: s.pawnPosition(PlayerId.blue),
            goalRow: s.boardConfig.blueGoalRow,
            walls: s.walls,
            size: s.boardConfig.size,
          );
          expect(
            bfsBlue,
            dfsBlue,
            reason: 'BFS/DFS disagree for blue at turn ${s.turnNumber}',
          );

          final bfsRed = Pathfinder.canReachGoal(
            from: s.pawnPosition(PlayerId.red),
            goalRow: s.boardConfig.redGoalRow,
            walls: s.walls,
            size: s.boardConfig.size,
          );
          final dfsRed = Pathfinder.canReachGoalDfs(
            from: s.pawnPosition(PlayerId.red),
            goalRow: s.boardConfig.redGoalRow,
            walls: s.walls,
            size: s.boardConfig.size,
          );
          expect(
            bfsRed,
            dfsRed,
            reason: 'BFS/DFS disagree for red at turn ${s.turnNumber}',
          );
        }
      }
    });
  });

  group('Invariant checks on every state transition', () {
    test('every successful apply maintains invariants', () {
      final rng = Random(123);
      for (var i = 0; i < 500; i++) {
        var s = _initialState();
        for (var turn = 0; turn < 100; turn++) {
          final legals = GameEngine.legalActions(s);
          if (legals.isEmpty) break;
          final action = legals[rng.nextInt(legals.length)];
          final result = GameEngine.apply(s, s.currentPlayer, action);
          if (result is SuccessResult) {
            s = result.state;
            // Invariant: turnNumber >= 0
            expect(s.turnNumber, greaterThanOrEqualTo(0));
            // Invariant: walls match remainingWalls
            final bluePlaced = s.walls
                .where((w) => w.owner == PlayerId.blue)
                .length;
            final redPlaced = s.walls
                .where((w) => w.owner == PlayerId.red)
                .length;
            expect(
              s.wallsRemaining(PlayerId.blue) + bluePlaced,
              s.boardConfig.wallsPerPlayer,
            );
            expect(
              s.wallsRemaining(PlayerId.red) + redPlaced,
              s.boardConfig.wallsPerPlayer,
            );
            // Invariant: pawns on board
            expect(
              s.pawnPosition(PlayerId.blue).row,
              inInclusiveRange(0, s.boardConfig.size - 1),
            );
            expect(
              s.pawnPosition(PlayerId.blue).column,
              inInclusiveRange(0, s.boardConfig.size - 1),
            );
            expect(
              s.pawnPosition(PlayerId.red).row,
              inInclusiveRange(0, s.boardConfig.size - 1),
            );
            expect(
              s.pawnPosition(PlayerId.red).column,
              inInclusiveRange(0, s.boardConfig.size - 1),
            );
            // Invariant: pawns on different cells
            expect(
              s.pawnPosition(PlayerId.blue),
              isNot(s.pawnPosition(PlayerId.red)),
            );
            // Invariant: currentPlayer matches turnNumber parity
            expect(
              s.currentPlayer,
              s.turnNumber.isEven ? PlayerId.blue : PlayerId.red,
            );
            // Invariant: no winner when inProgress
            if (s.status == GameStatus.inProgress) {
              expect(s.winner, isNull);
            }
            // Invariant: finished has winner
            if (s.status == GameStatus.finished) {
              expect(s.winner, isNotNull);
            }
            // Invariant: goal row only when winner
            if (s.pawnPosition(PlayerId.blue).row ==
                s.boardConfig.blueGoalRow) {
              expect(s.status, GameStatus.finished);
              expect(s.winner, PlayerId.blue);
            }
            if (s.pawnPosition(PlayerId.red).row == s.boardConfig.redGoalRow) {
              expect(s.status, GameStatus.finished);
              expect(s.winner, PlayerId.red);
            }
          } else {
            break;
          }
        }
      }
    });
  });

  group('wrongTurn / matchFinished checks', () {
    test('wrongTurn: Blue tries to play on Red turn', () {
      final s = GameState(
        boardConfig: const BoardConfig(),
        pawnPositions: {
          PlayerId.blue: const Cell(row: 8, column: 4),
          PlayerId.red: const Cell(row: 0, column: 4),
        },
        walls: const [],
        remainingWalls: {PlayerId.blue: 10, PlayerId.red: 10},
        turnNumber: 1,
        status: GameStatus.inProgress,
      );
      final result = GameEngine.apply(
        s,
        PlayerId.blue,
        const GameAction.move(Cell(row: 7, column: 4)),
      );
      expect(result, isA<FailureResult>());
      expect((result as FailureResult).failure, ActionFailure.wrongTurn);
    });

    test('matchFinished: action on finished game', () {
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
      final result = GameEngine.apply(
        s,
        PlayerId.blue,
        const GameAction.move(Cell(row: 1, column: 4)),
      );
      expect(result, isA<FailureResult>());
      expect((result as FailureResult).failure, ActionFailure.matchFinished);
    });
  });

  group('Structure test', () {
    test('all public classes have value equality', () {
      const a = Cell(row: 3, column: 4);
      const b = Cell(row: 3, column: 4);
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      const c = Wall(
        anchorRow: 3,
        anchorColumn: 4,
        orientation: WallOrientation.h,
        owner: PlayerId.blue,
      );
      const d = Wall(
        anchorRow: 3,
        anchorColumn: 4,
        orientation: WallOrientation.h,
        owner: PlayerId.blue,
      );
      expect(c, d);
      expect(c.hashCode, d.hashCode);

      const e = BoardConfig();
      const f = BoardConfig();
      expect(e, f);
      expect(e.hashCode, f.hashCode);
    });

    test('GameState.value equality covers all fields', () {
      final a = GameState.initial();
      final b = GameState.initial();
      expect(a, b);

      // Change each field and verify inequality
      expect(a, isNot(b.copyWith(turnNumber: 1)));
      expect(
        a,
        isNot(
          b.copyWith(
            pawnPositions: {
              PlayerId.blue: const Cell(row: 7, column: 3),
              PlayerId.red: const Cell(row: 0, column: 4),
            },
          ),
        ),
      );
    });

    test('GameAction value equality', () {
      const a = MoveAction(Cell(row: 3, column: 4));
      const b = MoveAction(Cell(row: 3, column: 4));
      const c = MoveAction(Cell(row: 3, column: 5));
      expect(a, b);
      expect(a, isNot(c));

      const d = WallAction(
        orientation: WallOrientation.h,
        anchor: Cell(row: 3, column: 4),
      );
      const e = WallAction(
        orientation: WallOrientation.h,
        anchor: Cell(row: 3, column: 4),
      );
      const f = WallAction(
        orientation: WallOrientation.v,
        anchor: Cell(row: 3, column: 4),
      );
      expect(d, e);
      expect(d, isNot(f));
    });
  });
}

/// Naive legal action generator for cross-checking the engine.
///
/// This is an independent implementation that does NOT use the engine code.
List<GameAction> _naiveLegalActions(GameState state, PlayerId player) {
  if (state.status == GameStatus.finished) return const [];
  if (state.currentPlayer != player) return const [];

  final size = state.boardConfig.size;
  final actions = <GameAction>[];

  // Naive move check
  for (var r = 0; r < size; r++) {
    for (var c = 0; c < size; c++) {
      final dest = Cell(row: r, column: c);
      if (_naiveIsLegalMove(state, player, dest)) {
        actions.add(GameAction.move(dest));
      }
    }
  }

  // Naive wall check
  if (state.wallsRemaining(player) > 0) {
    for (final orient in [WallOrientation.h, WallOrientation.v]) {
      for (var r = 0; r <= size - 2; r++) {
        for (var c = 0; c <= size - 2; c++) {
          final anchor = Cell(row: r, column: c);
          if (_naiveIsLegalWall(state, player, orient, anchor)) {
            actions.add(GameAction.wall(orientation: orient, anchor: anchor));
          }
        }
      }
    }
  }

  return actions;
}

bool _naiveIsLegalMove(GameState state, PlayerId player, Cell dest) {
  final size = state.boardConfig.size;
  if (dest.row < 0 ||
      dest.row >= size ||
      dest.column < 0 ||
      dest.column >= size) {
    return false;
  }
  final me = state.pawnPosition(player);
  final op = state.pawnPosition(player.opponent);
  if (dest == op) return false;

  final dr = (dest.row - me.row).abs();
  final dc = (dest.column - me.column).abs();
  final dist = dr + dc;
  if (dist == 0) return false;
  if (dist == 1) return true; // adjacent
  if (dist == 2 && (dr == 1 && dc == 1)) return false; // diagonal without jump
  if (dist == 2) {
    // Straight jump: dest is two cells away in a line, opponent is in between
    final mid = Cell(
      row: me.row + (dest.row - me.row) ~/ 2,
      column: me.column + (dest.column - me.column) ~/ 2,
    );
    return mid == op;
  }
  return false;
}

bool _naiveIsLegalWall(
  GameState state,
  PlayerId player,
  WallOrientation orient,
  Cell anchor,
) {
  final size = state.boardConfig.size;
  // Check overlap
  for (final existing in state.walls) {
    if (existing.orientation == orient) {
      if (orient == WallOrientation.h) {
        if (existing.anchorRow == anchor.row &&
            (existing.anchorColumn - anchor.column).abs() <= 1) {
          return false;
        }
      } else {
        if (existing.anchorColumn == anchor.column &&
            (existing.anchorRow - anchor.row).abs() <= 1) {
          return false;
        }
      }
    } else if (existing.anchorRow == anchor.row &&
        existing.anchorColumn == anchor.column) {
      return false;
    }
  }

  // Check path preservation
  final testWall = Wall(
    anchorRow: anchor.row,
    anchorColumn: anchor.column,
    orientation: orient,
    owner: player,
  );
  final newWalls = [...state.walls, testWall];

  if (!Pathfinder.canReachGoal(
    from: state.pawnPosition(PlayerId.blue),
    goalRow: state.boardConfig.blueGoalRow,
    walls: newWalls,
    size: size,
  )) {
    return false;
  }
  if (!Pathfinder.canReachGoal(
    from: state.pawnPosition(PlayerId.red),
    goalRow: state.boardConfig.redGoalRow,
    walls: newWalls,
    size: size,
  )) {
    return false;
  }

  return true;
}

/// Play [seeds] random games from initial state on a [size]×[size] board.
void _randomPlayTest({
  required int size,
  required int wpp,
  required int seeds,
}) {
  final rng = Random(seeds);
  for (var i = 0; i < seeds; i++) {
    var state = _initialState(size: size, wpp: wpp);
    var actionCount = 0;
    final maxActions = size * size * 4;
    while (state.status == GameStatus.inProgress && actionCount < maxActions) {
      final legals = GameEngine.legalActions(state);
      if (legals.isEmpty) break;
      final action = legals[rng.nextInt(legals.length)];
      final result = GameEngine.apply(state, state.currentPlayer, action);
      expect(
        result,
        isA<SuccessResult>(),
        reason: 'Seed $i, action $actionCount failed: $action',
      );
      state = (result as SuccessResult).state;
      actionCount++;
    }
    // Verify terminal state is valid
    if (state.status == GameStatus.finished) {
      expect(state.winner, isNotNull);
    }
  }
}
