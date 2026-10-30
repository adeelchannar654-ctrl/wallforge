// ignore_for_file: avoid_print
// Phase 16 A.2: time-to-move benchmark. For seeded early/mid/dense
// positions at every size, reports p50/p95/max of the synchronous
// search, of chooseActionAsync wall-clock, and of the experienced
// think time (kAiThinkDelay + async). Print-only; tests never assert
// these numbers. Run under JIT (`dart run`) and AOT
// (`dart compile exe`) to bracket debug-like vs release-like speed.
import 'dart:math';

import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/game_status.dart';

// Mirrors LocalGameController.kAiThinkDelay (300 ms) — duplicated here
// because importing the controller would pull Flutter into a pure-Dart
// bench. If the controller's delay changes, change this too.
const int kThinkDelayMs = 300;

GameState playSeeded(
  int size,
  int seed, {
  required int plies,
  required double moveBias,
  required int wallCapPerPlayer,
}) {
  var state = GameState.initial(BoardConfig(size: size));
  final random = Random(seed);
  for (var i = 0; i < plies && state.status != GameStatus.finished; i++) {
    final actions = GameEngine.legalActions(state);
    if (actions.isEmpty) break;
    final moves = actions.whereType<MoveAction>().toList();
    final spent = state.walls
        .where((w) => w.owner == state.currentPlayer)
        .length;
    final walls = spent >= wallCapPerPlayer
        ? const <GameAction>[]
        : actions.whereType<WallAction>().toList();
    final pool = (walls.isEmpty || random.nextDouble() < moveBias)
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

(String, int) stats(List<int> ms) {
  ms.sort();
  final p50 = ms[ms.length ~/ 2];
  final p95 = ms[(ms.length * 95) ~/ 100];
  return ('p50 $p50 ms, p95 $p95 ms, max ${ms.last} ms', ms.length);
}

Future<void> main() async {
  // Warm-up so JIT numbers are not first-call outliers.
  final warm = playSeeded(9, 1, plies: 10, moveBias: 0.75, wallCapPerPlayer: 6);
  AiOpponent.chooseAction(warm, AiDifficulty.easy, warm.currentPlayer);

  for (final kind in ['early', 'mid', 'dense']) {
    for (final size in [7, 9, 11]) {
      final positions = <GameState>[];
      for (var s = 0; s < 4; s++) {
        final seed = 51000 + size * 1000 + kind.hashCode % 100 + s;
        final state = switch (kind) {
          'early' => playSeeded(
            size,
            seed,
            plies: 4,
            moveBias: 0.75,
            wallCapPerPlayer: 6,
          ),
          'mid' => playSeeded(
            size,
            seed,
            plies: 30,
            moveBias: 0.75,
            wallCapPerPlayer: 6,
          ),
          _ => playSeeded(
            size,
            seed,
            plies: 44,
            moveBias: 0.35,
            wallCapPerPlayer: 10,
          ),
        };
        if (state.status != GameStatus.finished) positions.add(state);
      }
      for (final difficulty in AiDifficulty.values) {
        final sync = <int>[];
        final async = <int>[];
        for (final state in positions) {
          var sw = Stopwatch()..start();
          AiOpponent.chooseAction(state, difficulty, state.currentPlayer);
          sync.add(sw.elapsedMilliseconds);
          sw = Stopwatch()..start();
          await AiOpponent.chooseActionAsync(
            state,
            difficulty,
            state.currentPlayer,
          );
          async.add(sw.elapsedMilliseconds);
        }
        final (syncStats, _) = stats(sync);
        final (asyncStats, n) = stats(async);
        final asyncP95 = async[(async.length * 95) ~/ 100];
        print(
          '$kind ${size}x$size ${difficulty.name} (n=$n): sync $syncStats | '
          'async $asyncStats | experienced p95 '
          '${kThinkDelayMs + asyncP95} ms',
        );
      }
    }
  }
}
