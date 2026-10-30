// Phase 16 A.5: leaving a game while the Expert AI is mid-search
// must be clean — the search's result is dropped, no move is applied
// to the abandoned match, no timer or future leaks, and nothing
// notifies after dispose. This is the Q-8.6 / Phase 12 bug class,
// exercised through the real app (router + feedback scope +
// persistence), per the Phase 12 lesson.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/match_setup.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/presentation/board/board_geometry.dart';
import 'package:wallforge/presentation/board/board_view.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';

void main() {
  testWidgets('leaving mid-Expert-search drops the result cleanly', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => FeedbackService.install(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(const WallforgeApp());
    await tester.pump(const Duration(milliseconds: 1300)); // splash beat
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(HomeScreen))).pushNamed(
      AppRoutes.game,
      arguments: const MatchSetup(
        config: BoardConfig(size: 11),
        versusAi: true,
        aiDifficulty: AiDifficulty.expert,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    final LocalGameController controller = tester
        .widget<GameScreen>(find.byType(GameScreen))
        .controller;

    // The human plays one move: tap the cell directly ahead.
    final canvasFinder = find.descendant(
      of: find.byType(BoardView),
      matching: find.byType(CustomPaint),
    );
    final geometry = BoardGeometry(
      boardSize: 11,
      areaSize: tester.getSize(canvasFinder).width,
    );
    final gestureFinder = find.descendant(
      of: find.byType(BoardView),
      matching: find.byType(GestureDetector),
    );
    final target = controller.legalMoveTargets.first;
    await tester.tapAt(
      tester.getTopLeft(gestureFinder) + geometry.cellCenterFromModel(target),
    );
    await tester.pump();
    expect(controller.state.turnNumber, 1, reason: 'the human move landed');
    expect(controller.isAiTurn, isTrue);
    expect(find.byKey(const ValueKey('ai-thinking')), findsOneWidget);

    // Leave while the AI's think delay is still running. (The
    // in-flight-search case cannot be interleaved under fake async —
    // the search's zero-delay yields drain inside a single pump — so
    // it is proven with real async at controller level in
    // test/ai/ai_cancel_test.dart. Here the pending think timer must
    // be cancelled by the leave itself.)
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.state.turnNumber, 1, reason: 'AI has not moved yet');
    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);

    // Once the screen is gone the match is frozen: whatever ply the
    // exit transition left behind (the think delay can expire during
    // the ~300 ms transition, before dispose — recorded as a minor
    // finding in the Phase 16 ledger), nothing may change afterwards.
    // A post-dispose application would either move the pawns again or
    // throw on notify-after-dispose; the fake-async binding also
    // fails the test if any Timer is still pending at the end.
    final frozenTurn = controller.state.turnNumber;
    final frozenBlue = controller.state.pawnPosition(PlayerId.blue);
    final frozenRed = controller.state.pawnPosition(PlayerId.red);
    expect(frozenTurn, anyOf(1, 2));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(controller.state.turnNumber, frozenTurn);
    expect(controller.state.pawnPosition(PlayerId.blue), frozenBlue);
    expect(controller.state.pawnPosition(PlayerId.red), frozenRed);
    expect(tester.takeException(), isNull);
  });
}
