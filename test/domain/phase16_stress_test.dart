// Phase 16 C.3: engine stress on the largest board. The existing
// property suite (cross_checks_test) plays seeded random games on
// 5x5/7x7/9x9; this file adds 11x11 and asserts, after EVERY applied
// action, the full invariant battery including a serialization
// round-trip of the live state — the combination the Phase 16 brief
// asks for (per-state, not just at scripted checkpoints).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  test('11x11: 60 seeded random games keep every invariant per ply', () {
    final rng = Random(16011);
    var gamesFinished = 0;
    var pliesChecked = 0;
    for (var seed = 0; seed < 60; seed++) {
      var state = GameState.initial(const BoardConfig(size: 11));
      var guard = 0;
      while (state.status == GameStatus.inProgress && guard < 484) {
        guard++;
        final before = state;
        final legals = GameEngine.legalActions(state);
        expect(
          legals,
          isNotEmpty,
          reason: 'R-NOLEGAL-01: seed $seed ply $guard has no legal action',
        );
        final action = legals[rng.nextInt(legals.length)];
        final result = GameEngine.apply(state, state.currentPlayer, action);
        expect(result, isA<SuccessResult>(), reason: 'seed $seed: $action');
        state = (result as SuccessResult).state;
        pliesChecked++;

        // Exactly one action per turn, players strictly alternate.
        expect(state.turnNumber, before.turnNumber + 1);
        expect(state.currentPlayer, before.currentPlayer.opponent);

        // R-PATH-01: both players keep a route after every wall.
        for (final player in PlayerId.values) {
          expect(
            Pathfinder.shortestRouteLength(
              from: state.pawnPosition(player),
              goalRow: player == PlayerId.blue
                  ? state.boardConfig.blueGoalRow
                  : state.boardConfig.redGoalRow,
              walls: state.walls,
              size: state.boardConfig.size,
            ),
            isNotNull,
            reason: 'seed $seed ply $guard: $player lost their route',
          );
          // R-STATE-02: wall accounting never goes negative or over.
          final spent = state.walls.where((w) => w.owner == player).length;
          expect(spent, inInclusiveRange(0, state.boardConfig.wallsPerPlayer));
          expect(
            state.wallsRemaining(player),
            state.boardConfig.wallsPerPlayer - spent,
          );
        }

        // Every live state survives a serialization round-trip.
        final decoded = GameStateSerializer.fromJson(
          GameStateSerializer.toJson(state),
        );
        expect(decoded, isA<DeserializationSuccess>(), reason: 'seed $seed');
        expect((decoded as DeserializationSuccess).state, state);
      }
      if (state.status == GameStatus.finished) {
        gamesFinished++;
        expect(state.winner, isNotNull);
        // A finished match refuses every further action.
        final refused = GameEngine.apply(
          state,
          state.currentPlayer,
          GameEngine.legalActions(GameState.initial(state.boardConfig)).first,
        );
        expect(refused, isA<FailureResult>());
        expect((refused as FailureResult).failure, ActionFailure.matchFinished);
      }
    }
    // Random play on 11x11 must actually reach endings, not only caps.
    expect(gamesFinished, greaterThan(30));
    expect(pliesChecked, greaterThan(1000));
  });
}
