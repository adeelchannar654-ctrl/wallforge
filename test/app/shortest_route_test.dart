// Phase 16 C.2: shortestRoute (the movement-assistance route) had
// zero coverage despite shipping in both game screens. It must
// always agree with the domain Pathfinder: same length, legal steps,
// ending on the goal row.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/shortest_path.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void expectRouteConsistent(GameState state, PlayerId player) {
  final route = shortestRoute(state, player);
  final expectedLength = Pathfinder.shortestRouteLength(
    from: state.pawnPosition(player),
    goalRow: player == PlayerId.blue
        ? state.boardConfig.blueGoalRow
        : state.boardConfig.redGoalRow,
    walls: state.walls,
    size: state.boardConfig.size,
  );
  expect(route.length, expectedLength, reason: 'length must match BFS');
  if (route.isEmpty) return;
  final board = BlockedEdges.fromWalls(state.walls, state.boardConfig.size);
  var at = state.pawnPosition(player);
  for (final step in route) {
    expect(
      (step.row - at.row).abs() + (step.column - at.column).abs(),
      1,
      reason: 'steps are orthogonal neighbours',
    );
    expect(
      board.isBlocked(at, step),
      isFalse,
      reason: 'steps never cross walls',
    );
    at = step;
  }
  final goalRow = player == PlayerId.blue
      ? state.boardConfig.blueGoalRow
      : state.boardConfig.redGoalRow;
  expect(at.row, goalRow, reason: 'the route ends on the goal row');
}

void main() {
  test('empty when already on the goal row', () {
    final state = GameState.initial(const BoardConfig(size: 5)).copyWith(
      pawnPositions: const {
        PlayerId.blue: Cell(row: 0, column: 2),
        PlayerId.red: Cell(row: 4, column: 2),
      },
    );
    expect(shortestRoute(state, PlayerId.blue), isEmpty);
  });

  test('a clear board routes straight up the pawn\u2019s column', () {
    final state = GameState.initial(const BoardConfig(size: 5));
    final route = shortestRoute(state, PlayerId.blue);
    expect(route.length, 4);
    expect(route.last, const Cell(row: 0, column: 2));
  });

  test('routes detour around walls and agree with Pathfinder on '
      'seeded positions', () {
    final rng = Random(1607);
    for (var game = 0; game < 40; game++) {
      var state = GameState.initial();
      final plies = 10 + rng.nextInt(30);
      for (var ply = 0; ply < plies; ply++) {
        if (state.status == GameStatus.finished) break;
        final legals = GameEngine.legalActions(state);
        if (legals.isEmpty) break;
        final result = GameEngine.apply(
          state,
          state.currentPlayer,
          legals[rng.nextInt(legals.length)],
        );
        if (result is SuccessResult) state = result.state;
        expectRouteConsistent(state, PlayerId.blue);
        expectRouteConsistent(state, PlayerId.red);
      }
    }
  });
}
