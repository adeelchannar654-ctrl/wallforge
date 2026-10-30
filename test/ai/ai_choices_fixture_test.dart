// Phase 16: the optimized search must reproduce, move for move, the
// decisions the unoptimized search recorded in
// test/fixtures/ai_choices_v1.json (generated at HEAD d34cc53 before
// the _GoalFields evaluation reuse landed). A failure here means the
// optimization changed AI behaviour — that is only acceptable as an
// explicit, recorded decision with a regenerated fixture.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/serialization/deserialization_result.dart';
import 'package:wallforge/domain/serialization/game_state_serializer.dart';

GameState stateOf(Map<String, dynamic> entry) {
  final result = GameStateSerializer.fromJson(
    (entry['state'] as Map).cast<String, dynamic>(),
  );
  return (result as DeserializationSuccess).state;
}

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/ai_choices_v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final entries = (fixture['entries'] as List).cast<Map<String, dynamic>>();

  test('fixture is non-trivial', () {
    expect(entries.length, greaterThanOrEqualTo(18));
  });

  for (final entry in entries) {
    final label =
        'size ${entry['size']} ${entry['kind']} seed ${entry['seed']}';
    test('choices unchanged: $label', () {
      final state = stateOf(entry);
      final choices = (entry['choices'] as Map).cast<String, dynamic>();
      for (final difficulty in AiDifficulty.values) {
        final action = AiOpponent.chooseAction(
          state,
          difficulty,
          state.currentPlayer,
        );
        expect(
          action!.toNotation(),
          choices[difficulty.name],
          reason: '$label at ${difficulty.name} changed its move',
        );
      }
    });
  }

  test('async choices match the fixture on a sample', () async {
    for (final entry in entries.take(6)) {
      final state = stateOf(entry);
      final choices = (entry['choices'] as Map).cast<String, dynamic>();
      for (final difficulty in [AiDifficulty.hard, AiDifficulty.expert]) {
        final action = await AiOpponent.chooseActionAsync(
          state,
          difficulty,
          state.currentPlayer,
        );
        expect(action!.toNotation(), choices[difficulty.name]);
      }
    }
  });
}
