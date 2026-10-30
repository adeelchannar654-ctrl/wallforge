// ignore_for_file: avoid_print
// Phase 16: cost breakdown of one Expert search — where do the
// milliseconds actually go? Times the primitives the search is built
// from, level by level, on the fixture's mid/early positions.
import 'dart:convert';
import 'dart:io';

import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_evaluator.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/serialization/deserialization_result.dart';
import 'package:wallforge/domain/serialization/game_state_serializer.dart';

double timeMs(void Function() body, int reps) {
  final sw = Stopwatch()..start();
  for (var i = 0; i < reps; i++) {
    body();
  }
  return sw.elapsedMilliseconds / reps;
}

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/ai_choices_v1.json').readAsStringSync())
          as Map<String, dynamic>;
  final entries = (fixture['entries'] as List).cast<Map<String, dynamic>>();
  for (final entry in entries) {
    if (entry['size'] != 9 || entry['kind'] == 'dense') continue;
    final result = GameStateSerializer.fromJson(
      (entry['state'] as Map).cast<String, dynamic>(),
    );
    final GameState state = (result as DeserializationSuccess).state;
    final mover = state.currentPlayer;

    final legalMs = timeMs(() => GameEngine.legalActions(state), 20);
    final legal = GameEngine.legalActions(state);
    final applyMs = timeMs(() {
      for (final a in legal) {
        GameEngine.apply(state, mover, a);
      }
    }, 20);
    final children = <GameState>[];
    for (final a in legal) {
      final r = GameEngine.apply(state, mover, a);
      if (r is SuccessResult) children.add(r.state);
    }
    final scoreMs = timeMs(() {
      for (final c in children) {
        AiEvaluator.score(c, mover);
      }
    }, 20);
    final childLegalMs = timeMs(() {
      for (final c in children) {
        GameEngine.legalActions(c);
      }
    }, 5);
    final fullMs = timeMs(
      () => AiOpponent.chooseAction(state, AiDifficulty.expert, mover),
      3,
    );
    print(
      '${entry['kind']} seed ${entry['seed']}: legal(root) ${legalMs.toStringAsFixed(2)} ms '
      '| apply x${legal.length} ${applyMs.toStringAsFixed(2)} ms '
      '| scoreOld x${children.length} ${scoreMs.toStringAsFixed(2)} ms '
      '| legal(children) ${childLegalMs.toStringAsFixed(2)} ms '
      '| full Expert ${fullMs.toStringAsFixed(0)} ms',
    );
  }
}
