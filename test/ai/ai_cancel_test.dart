// Phase 16 A.5: cancellation of an in-flight AI search, with real
// async (the widget-level interleave cannot be expressed under fake
// async — the search's zero-delay yields drain inside one pump; see
// ai_cancel_on_leave_test.dart).
//
// Two guarantees, both resting on the controller's generation token:
//  1. disposing mid-search drops the result;
//  2. restarting mid-search drops the result even when the new match
//     reaches the SAME turn number — the case a turn-number-only
//     guard cannot tell apart.
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/ai/ai_opponent.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';

LocalGameController expertGame() {
  final controller = LocalGameController();
  controller.startMatch(
    config: const BoardConfig(size: 11),
    versusAi: true,
    aiDifficulty: AiDifficulty.expert,
  );
  return controller;
}

void main() {
  test('disposing mid-search drops the result', () async {
    final controller = expertGame();
    // Human move on the default interaction: tap the cell ahead.
    controller.tapCell(const Cell(row: 9, column: 5));
    expect(controller.state.turnNumber, 1);
    expect(controller.isAiTurn, isTrue);

    // Think delay (300 ms) plus a slice of the ~700 ms search.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    controller.dispose();

    // Well past the search's full duration: nothing may land, and
    // the disposed controller's state is untouched.
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(controller.state.turnNumber, 1);
  });

  test('restarting mid-search supersedes the stale result', () async {
    final controller = expertGame();
    addTearDown(controller.dispose);

    // Match A: the human steps left; the Expert search starts.
    controller.tapCell(const Cell(row: 10, column: 4));
    expect(controller.state.turnNumber, 1);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    // Match B begins while A's search is still running. The human
    // steps right instead — a different position at the same turn
    // number, which is exactly what a turn-only guard cannot see.
    controller.startMatch(
      config: const BoardConfig(size: 11),
      versusAi: true,
      aiDifficulty: AiDifficulty.expert,
    );
    controller.tapCell(const Cell(row: 10, column: 6));
    expect(controller.state.turnNumber, 1);
    final positionB = controller.state;

    // What B's AI should play, computed independently.
    final expected = AiOpponent.chooseAction(
      positionB,
      AiDifficulty.expert,
      positionB.currentPlayer,
    );
    expect(expected, isNotNull);
    final expectedState = (GameEngine.apply(
      positionB,
      positionB.currentPlayer,
      expected!,
    ) as SuccessResult).state;

    // Both searches finish inside this window (A's stale one first).
    await Future<void>.delayed(const Duration(seconds: 4));
    expect(
      controller.state.turnNumber,
      2,
      reason: 'exactly one AI ply — B\u2019s — may land',
    );
    expect(
      controller.state,
      expectedState,
      reason: 'the ply that landed must be B\u2019s choice, not A\u2019s',
    );
  });
}
