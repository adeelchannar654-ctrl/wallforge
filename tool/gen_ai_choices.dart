// ignore_for_file: avoid_print
// Phase 16 fixture generator (run once at the pre-optimization HEAD):
// records AiOpponent.chooseAction's decision for a fixed corpus of
// seeded positions x difficulties, so the optimized search can be
// proven to make byte-identical choices. Regenerate ONLY on an
// intentional, recorded AI behaviour change.
// Run with: dart run tool/gen_ai_choices.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/game_status.dart';
import 'package:wallforge/domain/serialization/game_state_serializer.dart';

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
    final wallsSpentByMover =
        state.walls.where((w) => w.owner == state.currentPlayer).length;
    final walls = wallsSpentByMover >= wallCapPerPlayer
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

void main() {
  final entries = <Map<String, dynamic>>[];
  for (final size in [7, 9, 11]) {
    for (final kind in ['early', 'mid', 'dense']) {
      for (var seedIdx = 0; seedIdx < 2; seedIdx++) {
        final seed = 31000 + size * 1000 + kind.hashCode % 100 + seedIdx;
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
        if (state.status == GameStatus.finished) continue;
        final choices = <String, String>{};
        for (final difficulty in AiDifficulty.values) {
          final action = AiOpponent.chooseAction(
            state,
            difficulty,
            state.currentPlayer,
          );
          choices[difficulty.name] = action!.toNotation();
        }
        entries.add({
          'size': size,
          'kind': kind,
          'seed': seed,
          'state': GameStateSerializer.toJson(state),
          'choices': choices,
        });
        print('recorded size $size $kind seed $seed');
      }
    }
  }
  final out = File('test/fixtures/ai_choices_v1.json');
  out.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'comment':
          'AI choices recorded at Phase 16 start (HEAD d34cc53) from the '
          'unoptimized search. The optimized implementation must reproduce '
          'every choice unless a change is recorded as intentional.',
      'entries': entries,
    }),
  );
  print('wrote ${entries.length} entries to ${out.path}');
}
