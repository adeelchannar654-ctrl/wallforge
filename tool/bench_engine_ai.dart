// ignore_for_file: avoid_print
// Phase 15 benchmark harness (not a test): prints CPU timings for the
// engine hot paths and the AI search, on seeded mid-game positions.
// Run with: dart run tool/bench_engine_ai.dart
//
// Positions are built by seeded self-play (Random with a fixed seed,
// 24 plies of uniformly random legal actions), so the numbers are
// reproducible run to run on the same machine. Nothing here asserts;
// the numbers are quoted into memory.md §13y by hand.
import 'dart:math';

import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/app/application/ai/ai_evaluator.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/game_status.dart';

/// A representative mid-game position. Uniformly random play is NOT
/// representative: wall actions outnumber moves ~30:1, so it spends
/// every wall within a few plies and collapses the branching factor to
/// the ~4 pawn moves — measuring that would flatter the search by two
/// orders of magnitude. Real mid-games still hold most walls, so this
/// policy is move-biased (75% moves) and caps each side at 6 walls
/// spent, leaving the full move+wall candidate set the search faces.
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
    final action = pool[random.nextInt(pool.length)];
    final result = GameEngine.apply(state, state.currentPlayer, action);
    if (result is SuccessResult) state = result.state;
  }
  return state;
}

double timeMs(void Function() body, int iterations) {
  final watch = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    body();
  }
  watch.stop();
  return watch.elapsedMicroseconds / 1000.0 / iterations;
}

Future<void> main() async {
  print('== Engine hot paths (per call, averaged) ==');
  for (final size in [9, 11]) {
    for (final seed in [7, 99]) {
      final state = midGamePosition(size, seed);
      final legal = timeMs(() => GameEngine.legalActions(state), 2000);
      final route = timeMs(() {
        AiEvaluator.ownRouteLength(state, state.currentPlayer);
        AiEvaluator.opponentRouteLength(state, state.currentPlayer);
      }, 2000);
      print(
        'size $size seed $seed (turn ${state.turnNumber}, '
        'walls ${state.walls.length}): '
        'legalActions ${legal.toStringAsFixed(3)} ms, '
        'routeLengths x2 ${route.toStringAsFixed(3)} ms',
      );
    }
  }

  print('');
  print('== AI chooseAction per difficulty x size (per call) ==');
  for (final size in [7, 9, 11]) {
    final positions = [
      for (var s = 0; s < 3; s++) midGamePosition(size, 1000 + size * 10 + s),
    ];
    for (final difficulty in AiDifficulty.values) {
      final times = <double>[];
      for (final state in positions) {
        if (state.status == GameStatus.finished) continue;
        final watch = Stopwatch()..start();
        final action = AiOpponent.chooseAction(
          state,
          difficulty,
          state.currentPlayer,
        );
        watch.stop();
        if (action == null) continue;
        times.add(watch.elapsedMicroseconds / 1000.0);
      }
      if (times.isEmpty) continue;
      times.sort();
      final max = times.last;
      final p50 = times[times.length ~/ 2];
      print(
        'size $size ${difficulty.label.padRight(6)}: '
        'p50 ${p50.toStringAsFixed(1)} ms, max ${max.toStringAsFixed(1)} ms '
        '(n=${times.length})',
      );
    }
  }

  print('');
  print('== Worst event-loop block while the AI thinks (Expert) ==');
  print('(a probe task re-queues itself on the event loop and records');
  print(' the longest gap between its turns: that gap is the longest');
  print(' the UI thread would have been frozen)');
  for (final size in [9, 11]) {
    final state = midGamePosition(size, 4242);
    for (final asyncMode in [false, true]) {
      var maxGapMs = 0.0;
      var probeTurns = 0;
      var probing = true;
      final watch = Stopwatch()..start();
      var lastTurn = 0;
      Future<void> probe() async {
        while (probing) {
          await Future<void>.delayed(Duration.zero);
          probeTurns++;
          final now = watch.elapsedMicroseconds;
          final gap = (now - lastTurn) / 1000.0;
          if (gap > maxGapMs) maxGapMs = gap;
          lastTurn = now;
        }
      }

      final probeFuture = probe();
      if (asyncMode) {
        await AiOpponent.chooseActionAsync(
          state,
          AiDifficulty.expert,
          state.currentPlayer,
        );
      } else {
        AiOpponent.chooseAction(
          state,
          AiDifficulty.expert,
          state.currentPlayer,
        );
      }
      probing = false;
      await probeFuture;
      print(
        'size $size ${asyncMode ? 'async' : 'sync '} search: worst '
        'event-loop block ${maxGapMs.toStringAsFixed(1)} ms '
        '(probe turns: $probeTurns)',
      );
    }
  }
}
