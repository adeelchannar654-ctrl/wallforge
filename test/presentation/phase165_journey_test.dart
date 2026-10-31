import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/match_setup.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/presentation/board/board_geometry.dart';
import 'package:wallforge/presentation/board/board_view.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';
import 'package:wallforge/presentation/screens/history/history_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/leaderboard/leaderboard_screen.dart';

/// Phase 16.5, Part I: the new features exercised end-to-end
/// through the REAL app (router, persistence, feedback) —
/// resign, the swapped rematch, history, the achievement
/// toast, sharing, and the leaderboard's graceful entry when
/// Firebase is absent.
Future<void> bootApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => FeedbackService.install(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(const WallforgeApp());
  await tester.pump(const Duration(milliseconds: 1300)); // splash beat
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
}

BoardGeometry geometryOf(WidgetTester tester, int boardSize) {
  final canvasFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(CustomPaint),
  );
  return BoardGeometry(
    boardSize: boardSize,
    areaSize: tester.getSize(canvasFinder).width,
  );
}

Future<void> tapCell(
  WidgetTester tester,
  Cell cell, {
  required int boardSize,
}) async {
  final gestureFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(GestureDetector),
  );
  final local = geometryOf(tester, boardSize).cellCenterFromModel(cell);
  await tester.tapAt(tester.getTopLeft(gestureFinder) + local);
  await tester.pumpAndSettle();
}

Future<void> openGame(WidgetTester tester, MatchSetup setup) async {
  Navigator.of(tester.element(find.byType(HomeScreen)))
      .pushNamed(AppRoutes.game, arguments: setup);
  await tester.pumpAndSettle();
  expect(find.byType(GameScreen), findsOneWidget);
}

LocalGameController gameController(WidgetTester tester) =>
    tester.widget<GameScreen>(find.byType(GameScreen)).controller;

void main() {
  testWidgets('journey A: vs-AI resign, swapped rematch, resize, history', (
    tester,
  ) async {
    await bootApp(tester, const Size(390, 844));
    await openGame(
      tester,
      const MatchSetup.versusAi(BoardConfig(), AiDifficulty.easy),
    );
    final controller = gameController(tester);
    expect(controller.humanSide, PlayerId.blue);

    // One human move — and the AI's answer, which lands
    // inside the same settle (its think is a fake-zone timer).
    await tapCell(tester, const Cell(row: 7, column: 4), boardSize: 9);
    expect(controller.state.turnNumber, 2);
    expect(
      controller.state.pawnPosition(PlayerId.blue),
      const Cell(row: 7, column: 4),
    );
    final stateBefore = controller.state;
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(gameController(tester), same(controller));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(stateBefore.turnNumber, 2);

    // Resign through the UI.
    await tester.tap(find.text('RESIGN'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('RESIGN'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Resignation'), findsWidgets);
    expect(controller.isFinished, isTrue);

    // Rematch: the sides swap — the AI now plays Blue and
    // opens without any human tap.
    await tester.tap(find.text('REMATCH'));
    await tester.pumpAndSettle();
    expect(controller.humanSide, PlayerId.red);
    expect(controller.aiSide, PlayerId.blue);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(controller.state.turnNumber, greaterThanOrEqualTo(1));
    expect(
      controller.state.pawnPosition(PlayerId.blue),
      isNot(const Cell(row: 8, column: 4)),
      reason: 'Blue (the AI) has opened the rematch',
    );

    // Home, then History: the resigned match is recorded.
    Navigator.of(tester.element(find.byType(GameScreen)))
        .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('MATCH HISTORY'), 300);
    await tester.tap(find.text('MATCH HISTORY'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.text('Lost · Vs AI'), findsOneWidget);
    await tester.tap(find.text('Lost · Vs AI'));
    await tester.pumpAndSettle();
    expect(find.text('Match details'), findsOneWidget);
    expect(find.text('Resignation'), findsWidgets);
  });

  testWidgets('journey B: a goal win unlocks, shares, and reaches the board', (
    tester,
  ) async {
    await bootApp(tester, const Size(390, 844));
    await openGame(tester, const MatchSetup.local(BoardConfig(size: 5)));
    final controller = gameController(tester);

    // The scripted 5x5 line: Blue walks home, Red shuffles.
    for (final cell in const [
      Cell(row: 3, column: 2),
      Cell(row: 0, column: 3),
      Cell(row: 2, column: 2),
      Cell(row: 0, column: 2),
      Cell(row: 1, column: 2),
      Cell(row: 0, column: 3),
      Cell(row: 0, column: 2),
    ]) {
      await tapCell(tester, cell, boardSize: 5);
    }
    expect(controller.isFinished, isTrue);
    await tester.pumpAndSettle();

    // The achievement toast fired for the recorded finish.
    expect(find.textContaining('chievement'), findsOneWidget);

    // Share: the native fallback previews the card.
    await tester.tap(find.text('SHARE RESULT'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 750)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your result card'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    // Home → Achievements: First Win is unlocked there.
    await tester.tap(find.text('RETURN TO HOME'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('MATCH HISTORY'), 300);
    await tester.tap(find.text('MATCH HISTORY'));
    await tester.pumpAndSettle();
    expect(find.text('Blue won · Local'), findsOneWidget);
    Navigator.of(tester.element(find.byType(HistoryScreen))).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('YOUR MATCHES'), 300);
    await tester.tap(find.text('YOUR MATCHES'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ACHIEVEMENTS'), 300);
    await tester.tap(find.text('ACHIEVEMENTS'));
    await tester.pumpAndSettle();
    expect(find.text('First Win'), findsOneWidget);
    expect(find.textContaining('Unlocked · '), findsWidgets);
    Navigator.of(tester.element(find.text('First Win'))).pop();
    await tester.pumpAndSettle();
    // Back out of Profile to Home.
    Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // The leaderboard entry exists (debug builds default the
    // flag on) and fails gracefully with no Firebase here.
    await tester.scrollUntilVisible(find.text('WEEKLY LEADERBOARD'), 300);
    await tester.tap(find.text('WEEKLY LEADERBOARD'));
    await tester.pumpAndSettle();
    expect(find.byType(LeaderboardScreen), findsOneWidget);
    expect(find.textContaining('needs an online sign-in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
