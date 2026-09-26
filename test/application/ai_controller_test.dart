import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/match_setup.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('LocalGameController versus AI', () {
    testWidgets('the AI replies after the think delay', (tester) async {
      final controller = LocalGameController(versusAi: true);
      addTearDown(controller.dispose);

      expect(controller.versusAi, isTrue);
      expect(controller.isAiTurn, isFalse, reason: 'Blue moves first');

      // Human (Blue) moves.
      controller.tapCell(const Cell(row: 8, column: 3));
      await tester.pump();
      expect(controller.isAiTurn, isTrue, reason: 'now Red (the AI) to move');
      final plyBeforeAi = controller.state.turnNumber;

      // Nothing happens until the delay elapses.
      await tester.pump(kAiThinkDelay);
      await tester.pump();

      expect(
        controller.state.turnNumber,
        plyBeforeAi + 1,
        reason: 'the AI must have played exactly one action',
      );
      expect(controller.currentPlayer, PlayerId.blue, reason: 'turn passed');
    });

    testWidgets('the AI never plays an action the engine rejects', (
      tester,
    ) async {
      for (final difficulty in AiDifficulty.values) {
        final controller = LocalGameController(
          versusAi: true,
          aiDifficulty: difficulty,
        );
        var legal = 0;

        for (var i = 0; i < 12; i++) {
          if (controller.state.status == GameStatus.finished) break;
          if (controller.isAiTurn) {
            await tester.pump(kAiThinkDelay);
            await tester.pump();
            // Whatever it did, the state stayed consistent: R-STATE-02 holds and
            // the AI is not to move any more.
            expect(controller.isAiTurn, isFalse, reason: '$difficulty');
            expect(
              controller.state.wallsRemaining(PlayerId.red) +
                  controller.state.walls
                      .where((w) => w.owner == PlayerId.red)
                      .length,
              controller.state.boardConfig.wallsPerPlayer,
              reason: 'R-STATE-02 for Red after $difficulty',
            );
            legal++;
          }
          // Human side: pick any legal move.
          final moves = GameEngine.legalActions(controller.state)
              .whereType<MoveAction>()
              .toList();
          if (moves.isEmpty) break;
          final before = controller.state.turnNumber;
          controller.tapCell(moves.first.destination);
          await tester.pump();
          if (controller.state.turnNumber == before) break; // illegal tap
        }
        expect(legal, greaterThan(0), reason: '$difficulty never got a turn');
        controller.dispose();
      }
    });

    testWidgets('a local match is unaffected', (tester) async {
      final controller = LocalGameController();
      addTearDown(controller.dispose);

      expect(controller.versusAi, isFalse);
      expect(controller.isAiTurn, isFalse);

      controller.tapCell(const Cell(row: 8, column: 3));
      await tester.pump(const Duration(seconds: 1));

      expect(
        controller.state.turnNumber,
        1,
        reason: 'no AI may act in a pass-and-play match',
      );
      expect(controller.currentPlayer, PlayerId.red);
    });

    testWidgets('restart keeps the AI opponent and its difficulty', (
      tester,
    ) async {
      final controller = LocalGameController(
        versusAi: true,
        aiDifficulty: AiDifficulty.hard,
      );
      addTearDown(controller.dispose);

      controller.restart();

      expect(controller.versusAi, isTrue);
      expect(controller.aiDifficulty, AiDifficulty.hard);
      expect(controller.state.turnNumber, 0);
    });
  });

  group('MatchSetup', () {
    test('local and versusAi constructors set the right fields', () {
      const config = BoardConfig(size: 7);
      const local = MatchSetup.local(config);
      expect(local.versusAi, isFalse);
      expect(local.config.size, 7);

      const ai = MatchSetup.versusAi(config, AiDifficulty.expert);
      expect(ai.versusAi, isTrue);
      expect(ai.aiDifficulty, AiDifficulty.expert);
    });

    testWidgets('the game route accepts both a MatchSetup and a bare config', (
      tester,
    ) async {
      // A bare BoardConfig still means pass-and-play (Phase 4.1 behaviour).
      final bare = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.game, arguments: BoardConfig()),
      );
      expect(bare, isNotNull);

      final viaSetup = AppRouter.onGenerateRoute(
        const RouteSettings(
          name: AppRoutes.game,
          arguments: MatchSetup.versusAi(
            BoardConfig(size: 5),
            AiDifficulty.medium,
          ),
        ),
      );
      expect(viaSetup, isNotNull);

      // No argument at all must not crash.
      final noArgs = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.game),
      );
      expect(noArgs, isNotNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });
}
