// Phase 15 (A.3): mid-match resize through the REAL app.
//
// Phase 14 proved resize discipline on a bare GameScreen; the Phase 12
// regression (§13u) proved the real app plays, but never resized. The
// §13u bug class — a route rebuild silently replacing the match's
// controller — is exactly what a resize could reintroduce, because a
// resize is the one event guaranteed to rebuild every layout branch.
// This test therefore boots the real WallforgeApp (router, feedback
// scope, persistence), plays real taps, and resizes the viewport
// between taps through every Phase 14 tier plus a landscape phone,
// asserting after each resize that the screen still holds the SAME
// controller instance and the match state is the identical object the
// taps produced.
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

Future<LocalGameController> startGameAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => FeedbackService.install(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(const WallforgeApp());
  await tester.pump(const Duration(milliseconds: 1300)); // splash beat
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  Navigator.of(
    tester.element(find.byType(HomeScreen)),
  ).pushNamed(AppRoutes.game, arguments: const MatchSetup.local(BoardConfig()));
  await tester.pumpAndSettle();
  expect(find.byType(GameScreen), findsOneWidget);
  return tester.widget<GameScreen>(find.byType(GameScreen)).controller;
}

BoardGeometry geometryOf(WidgetTester tester) {
  final canvasFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(CustomPaint),
  );
  return BoardGeometry(
    boardSize: 9,
    areaSize: tester.getSize(canvasFinder).width,
  );
}

Future<void> tapBoard(WidgetTester tester, Offset localPosition) async {
  final gestureFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(GestureDetector),
  );
  await tester.tapAt(tester.getTopLeft(gestureFinder) + localPosition);
  await tester.pump();
}

Cell greedyTarget(LocalGameController controller, PlayerId player) {
  final size = controller.state.boardConfig.size;
  final goalRow = player == PlayerId.blue ? 0 : size - 1;
  final pawn = controller.state.pawnPosition(player);
  final targets = controller.legalMoveTargets.toList();
  expect(targets, isNotEmpty, reason: 'a legal move must exist');
  targets.sort((a, b) {
    final da = (a.row - goalRow).abs() * 10 + (a.column - pawn.column).abs();
    final db = (b.row - goalRow).abs() * 10 + (b.column - pawn.column).abs();
    return da.compareTo(db);
  });
  return targets.first;
}

Future<void> tapGreedyMove(
  WidgetTester tester,
  LocalGameController controller,
) async {
  final player = controller.currentPlayer;
  final before = controller.state.turnNumber;
  final target = greedyTarget(controller, player);
  await tapBoard(tester, geometryOf(tester).cellCenterFromModel(target));
  await tester.pumpAndSettle();
  expect(
    controller.state.turnNumber,
    before + 1,
    reason: 'the tap on $target must advance the match by one ply',
  );
  expect(controller.state.pawnPosition(player), target);
}

/// Resizes and proves the resize touched nothing but the layout: the
/// screen's controller is the identical instance and the match state
/// is the identical object (the Phase 14 discipline, now through the
/// router).
Future<void> resizeAndAssertUnchanged(
  WidgetTester tester,
  LocalGameController controller,
  Size size,
) async {
  final stateBefore = controller.state;
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
  expect(find.byType(GameScreen), findsOneWidget, reason: 'size $size');
  final shown = tester.widget<GameScreen>(find.byType(GameScreen)).controller;
  expect(
    identical(shown, controller),
    isTrue,
    reason: 'resize to $size must not replace the controller',
  );
  expect(
    identical(controller.state, stateBefore),
    isTrue,
    reason: 'resize to $size must not touch the match state',
  );
  expect(tester.takeException(), isNull, reason: 'size $size');
}

void main() {
  testWidgets(
    'mid-match resize through the real app keeps controller and state',
    (tester) async {
      final controller = await startGameAt(tester, const Size(390, 844));

      // Phone (start) -> tablet.
      await tapGreedyMove(tester, controller);
      await resizeAndAssertUnchanged(tester, controller, const Size(768, 1024));

      // Tablet -> desktop.
      await tapGreedyMove(tester, controller);
      await resizeAndAssertUnchanged(tester, controller, const Size(1440, 900));

      // Desktop -> landscape phone (the compact-rails arrangement).
      await tapGreedyMove(tester, controller);
      await resizeAndAssertUnchanged(tester, controller, const Size(844, 390));

      // Landscape phone -> back to portrait phone; one more tap lands
      // on the same match, and the ply count is exactly the taps made.
      await tapGreedyMove(tester, controller);
      await resizeAndAssertUnchanged(tester, controller, const Size(390, 844));
      expect(controller.state.turnNumber, 4);
    },
  );
}
