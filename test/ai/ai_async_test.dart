// Phase 15: the asynchronous AI search.
//
// Two properties are proven here, both structurally (never by
// stopwatch):
//
// 1. Determinism: chooseActionAsync returns exactly the action
//    chooseAction returns, on seeded mid-game positions, for every
//    difficulty — the async path changes WHEN the event loop breathes,
//    never WHAT the AI decides.
// 2. The mechanism: while an Expert search is in flight, other
//    event-loop work runs before the search completes. Under the old
//    synchronous call that was impossible by construction (the probe
//    in tool/bench_engine_ai.dart measured a 1.6–3.3 s event-loop
//    block; the async path bounds it to one root candidate's subtree).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/game_status.dart';

/// The bench harness's representative mid-game position: move-biased
/// seeded self-play (75% moves, at most 6 walls per side), so the
/// position still holds the full move+wall candidate set a real
/// mid-game presents.
GameState midGamePosition(int size, int seed, {int plies = 30}) {
  var state = GameState.initial(BoardConfig(size: size));
  final random = Random(seed);
  for (var i = 0; i < plies && state.status != GameStatus.finished; i++) {
    final actions = GameEngine.legalActions(state);
    if (actions.isEmpty) break;
    final moves = actions.whereType<MoveAction>().toList();
    final wallsSpentByMover = state.walls
        .where((w) => w.owner == state.currentPlayer)
        .length;
    final walls = wallsSpentByMover >= 6
        ? const <GameAction>[]
        : actions.whereType<WallAction>().toList();
    final pool = (walls.isEmpty || random.nextDouble() < 0.75)
        ? (moves.isEmpty ? actions : moves)
        : walls;
    final result = GameEngine.apply(
      state,
      state.currentPlayer,
      pool[random.nextInt(pool.length)],
    );
    if (result is SuccessResult) state = result.state;
  }
  return state;
}

void main() {
  group('chooseActionAsync determinism (== chooseAction)', () {
    for (final size in [7, 9]) {
      for (final difficulty in AiDifficulty.values) {
        test('size $size ${difficulty.label}: async matches sync', () async {
          for (var seed = 0; seed < 3; seed++) {
            final state = midGamePosition(size, 5000 + size * 100 + seed);
            if (state.status == GameStatus.finished) continue;
            final sync = AiOpponent.chooseAction(
              state,
              difficulty,
              state.currentPlayer,
            );
            final async = await AiOpponent.chooseActionAsync(
              state,
              difficulty,
              state.currentPlayer,
            );
            expect(async, sync, reason: 'size $size seed $seed');
          }
        });
      }
    }

    test('size 11 Expert: async matches sync', () async {
      final state = midGamePosition(11, 5111);
      final sync = AiOpponent.chooseAction(
        state,
        AiDifficulty.expert,
        state.currentPlayer,
      );
      final async = await AiOpponent.chooseActionAsync(
        state,
        AiDifficulty.expert,
        state.currentPlayer,
      );
      expect(async, sync);
    });
  });

  group('the event loop breathes during a search', () {
    test('a queued probe completes before an Expert search does', () async {
      final state = midGamePosition(9, 4242);
      var probeTurns = 0;
      var searching = true;
      Future<void> probe() async {
        while (searching) {
          await Future<void>.delayed(Duration.zero);
          probeTurns++;
        }
      }

      final probeFuture = probe();
      final action = await AiOpponent.chooseActionAsync(
        state,
        AiDifficulty.expert,
        state.currentPlayer,
      );
      searching = false;
      await probeFuture;

      expect(action, isNotNull);
      // The search yields once per root candidate (up to 12 for
      // Expert); the probe must have run several times before the
      // search finished. Under a blocking search it could only have
      // run after completion.
      expect(probeTurns, greaterThanOrEqualTo(4));
    });

    test('a search result from before a restart never lands', () async {
      // Default BoardConfig is the 9x9 board this scenario wants.
      final controller = LocalGameController(
        versusAi: true,
        aiDifficulty: AiDifficulty.expert,
      );
      addTearDown(controller.dispose);
      // The human opens; the Expert reply is scheduled (300 ms think
      // delay, then a search that takes far longer than the margins
      // used here on any hardware this suite has run on).
      controller.tapCell(controller.legalMoveTargets.first);
      expect(controller.state.turnNumber, 1);
      // Let the think delay elapse so the search is genuinely in
      // flight, then restart the match underneath it.
      await Future<void>.delayed(const Duration(milliseconds: 450));
      controller.restart();
      expect(controller.state.turnNumber, 0);
      // Wait for the stale search to finish and (not) apply.
      await Future<void>.delayed(const Duration(seconds: 3));
      expect(
        controller.state.turnNumber,
        0,
        reason: 'the pre-restart search result must be dropped',
      );
    });
  });
}
