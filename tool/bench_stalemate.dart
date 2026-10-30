// ignore_for_file: avoid_print
// Phase 16 A.6: can a HUMAN-vs-AI game reach the Q-5.1 forced
// stalemate? Seeded simulations where the human side follows a fixed
// policy (random / pure race / wall-heavy race) and the AI side plays
// exactly as LocalGameController drives it (previousCell + visitOrder
// maintained the same way). Print-only analysis; the ply cap marks a
// game "stalled" and its end-state is characterized.
import 'dart:math';

import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/engine/pathfinder.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/game_status.dart';
import 'package:wallforge/domain/models/player_id.dart';

const int plyCap = 400;

GameAction humanAction(GameState state, String policy, Random random) {
  final actions = GameEngine.legalActions(state);
  final moves = actions.whereType<MoveAction>().toList();
  final walls = actions.whereType<WallAction>().toList();
  switch (policy) {
    case 'race':
      // Always the move that most shortens the human's own route.
      var best = moves.first;
      var bestLen = 1 << 30;
      for (final m in moves) {
        final r = GameEngine.apply(state, state.currentPlayer, m);
        if (r is! SuccessResult) continue;
        final len =
            Pathfinder.shortestRouteLength(
              from: r.state.pawnPosition(state.currentPlayer),
              goalRow: state.currentPlayer == PlayerId.blue
                  ? state.boardConfig.blueGoalRow
                  : state.boardConfig.redGoalRow,
              walls: r.state.walls,
              size: state.boardConfig.size,
            ) ??
            bestLen;
        if (len < bestLen) {
          bestLen = len;
          best = m;
        }
      }
      return best;
    case 'walls':
      // Spend walls early (any that lengthen the AI route), then race.
      if (walls.isNotEmpty && state.turnNumber < 24) {
        return walls[random.nextInt(walls.length)];
      }
      return humanAction(state, 'race', random);
    default: // random
      return actions[random.nextInt(actions.length)];
  }
}

({bool finished, int plies, GameState end}) playGame(
  int size,
  AiDifficulty difficulty,
  String policy,
  int seed,
) {
  var state = GameState.initial(BoardConfig(size: size));
  final random = Random(seed);
  final visitOrder = <String, int>{};
  Cell? aiPrevious;
  const aiPlayer = PlayerId.red;
  while (state.status != GameStatus.finished && state.turnNumber < plyCap) {
    visitOrder[AiOpponent.positionKey(state)] = state.turnNumber;
    if (state.currentPlayer == aiPlayer) {
      final action = AiOpponent.chooseAction(
        state,
        difficulty,
        aiPlayer,
        previousCell: aiPrevious,
        visitOrder: visitOrder,
      );
      aiPrevious = state.pawnPosition(aiPlayer);
      final r = GameEngine.apply(state, aiPlayer, action!);
      state = (r as SuccessResult).state;
    } else {
      final action = humanAction(state, policy, random);
      final r = GameEngine.apply(state, state.currentPlayer, action);
      if (r is SuccessResult) state = r.state;
    }
  }
  return (
    finished: state.status == GameStatus.finished,
    plies: state.turnNumber,
    end: state,
  );
}

void main() {
  final plan = <(int, AiDifficulty, String, int)>[
    // (size, difficulty, human policy, games)
    for (final size in [5, 7, 9])
      for (final d in AiDifficulty.values) (size, d, 'random', 6),
    for (final size in [7, 9]) ...[
      (size, AiDifficulty.hard, 'race', 4),
      (size, AiDifficulty.expert, 'race', 4),
      (size, AiDifficulty.hard, 'walls', 4),
      (size, AiDifficulty.expert, 'walls', 4),
    ],
    (11, AiDifficulty.expert, 'random', 2),
    (11, AiDifficulty.hard, 'random', 2),
  ];
  var seed = 77000;
  for (final (size, difficulty, policy, games) in plan) {
    var finished = 0;
    var stalled = 0;
    var totalPlies = 0;
    final stallNotes = <String>[];
    for (var g = 0; g < games; g++) {
      final r = playGame(size, difficulty, policy, seed++);
      totalPlies += r.plies;
      if (r.finished) {
        finished++;
      } else {
        stalled++;
        final e = r.end;
        stallNotes.add(
          'walls left B${e.wallsRemaining(PlayerId.blue)}/R${e.wallsRemaining(PlayerId.red)}',
        );
      }
    }
    print(
      '${size}x$size ${difficulty.name} vs $policy: finished $finished/$games, '
      'stalled $stalled, avg plies ${(totalPlies / games).toStringAsFixed(0)}'
      '${stallNotes.isEmpty ? '' : ' | stalls: ${stallNotes.join('; ')}'}',
    );
  }
}
