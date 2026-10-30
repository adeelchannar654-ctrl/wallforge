// Phase 16 C.4: the resume journey through the real app — play,
// "restart the app" (a fresh WallforgeApp over the same stored
// data), resume from Home's resume card, and keep playing legally.
// Controller-level resume is covered in persistence_integration_test;
// this proves the user-facing path end to end.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
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
import 'package:wallforge/presentation/screens/home/home_screen.dart';

Future<void> bootApp(WidgetTester tester) async {
  await tester.pumpWidget(const WallforgeApp());
  await tester.pump(const Duration(milliseconds: 1300)); // splash beat
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
}

Future<void> tapMove(WidgetTester tester, LocalGameController c) async {
  final canvasFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(CustomPaint),
  );
  final geometry = BoardGeometry(
    boardSize: c.state.boardConfig.size,
    areaSize: tester.getSize(canvasFinder).width,
  );
  final gestureFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(GestureDetector),
  );
  final size = c.state.boardConfig.size;
  final player = c.currentPlayer;
  final goalRow = player == PlayerId.blue ? 0 : size - 1;
  final pawn = c.state.pawnPosition(player);
  final targets = c.legalMoveTargets.toList()
    ..sort((a, b) {
      final da = (a.row - goalRow).abs() * 10 + (a.column - pawn.column).abs();
      final db = (b.row - goalRow).abs() * 10 + (b.column - pawn.column).abs();
      return da.compareTo(db);
    });
  final Cell target = targets.first;
  final before = c.state.turnNumber;
  await tester.tapAt(
    tester.getTopLeft(gestureFinder) + geometry.cellCenterFromModel(target),
  );
  await tester.pumpAndSettle();
  expect(c.state.turnNumber, before + 1);
  expect(c.state.pawnPosition(player), target);
}

void main() {
  testWidgets('an unfinished match survives an app restart and resumes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => FeedbackService.install(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await bootApp(tester);
    Navigator.of(tester.element(find.byType(HomeScreen))).pushNamed(
      AppRoutes.game,
      arguments: const MatchSetup(config: BoardConfig(size: 5)),
    );
    await tester.pumpAndSettle();
    final first = tester.widget<GameScreen>(find.byType(GameScreen)).controller;
    await tapMove(tester, first);
    await tapMove(tester, first);
    await tapMove(tester, first);
    expect(first.state.turnNumber, 3);
    final blueAt = first.state.pawnPosition(PlayerId.blue);
    final redAt = first.state.pawnPosition(PlayerId.red);

    // Simulated restart: unmount the app completely (pumpWidget with
    // the same root type would reuse the element and restart
    // nothing), then boot a brand-new instance over the same stored
    // data. Home must offer the resume.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await bootApp(tester);
    expect(find.text('RESUME MATCH'), findsOneWidget);
    await tester.tap(find.text('RESUME MATCH'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsOneWidget);
    final resumed = tester
        .widget<GameScreen>(find.byType(GameScreen))
        .controller;
    expect(resumed.state.turnNumber, 3);
    expect(resumed.state.pawnPosition(PlayerId.blue), blueAt);
    expect(resumed.state.pawnPosition(PlayerId.red), redAt);

    // And the resumed match continues legally.
    await tapMove(tester, resumed);
    expect(resumed.state.turnNumber, 4);
  });

  testWidgets('leaving a match mid-session offers the resume on Home '
      'immediately (Phase 16 stale-Home fix)', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => FeedbackService.install(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await bootApp(tester);
    expect(find.text('RESUME MATCH'), findsNothing);
    Navigator.of(tester.element(find.byType(HomeScreen))).pushNamed(
      AppRoutes.game,
      arguments: const MatchSetup(config: BoardConfig(size: 5)),
    );
    await tester.pumpAndSettle();
    final controller = tester
        .widget<GameScreen>(find.byType(GameScreen))
        .controller;
    await tapMove(tester, controller);
    await tapMove(tester, controller);

    // Back out mid-match: Home must already know about the saved
    // match. Before the Phase 16 fix it loaded its data once at app
    // start and showed no resume card until a restart.
    Navigator.of(tester.element(find.byType(GameScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('RESUME MATCH'), findsOneWidget);
  });
}
