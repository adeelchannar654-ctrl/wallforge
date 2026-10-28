// Regression tests for the Phase 12 local-play failure (memory.md §13u).
//
// The bug: in the real app, the /game route builder created a brand-new
// LocalGameController on every rebuild AND subscribed itself to the
// feedback layer's notifications (a dependOn read inside the builder).
// loadPersisted's settings application notified the feedback layer,
// which rebuilt the route around a fresh controller, whose own load
// notified again — an unbounded loop that replaced the match with a
// fresh one every frame. Every tap landed on a controller that was
// discarded before the next frame, so the pawn never moved and walls
// never placed. Online play was unaffected (its controller arrives via
// route arguments, created once by the lobby).
//
// These tests therefore boot the REAL WallforgeApp — router, feedback
// scope, persistence and all — and play through the real GameScreen
// with real taps. A bare GameScreen test cannot see this bug; the whole
// point is the wiring. Both a pass-and-play match and a vs-AI match
// are played tap by tap to completion.
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
import 'package:wallforge/domain/models/game_status.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/board/board_geometry.dart';
import 'package:wallforge/presentation/board/board_view.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';

Future<LocalGameController> startGame(
  WidgetTester tester, {
  required MatchSetup setup,
}) async {
  tester.view.physicalSize = const Size(1024, 768);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => FeedbackService.install(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await tester.pumpWidget(const WallforgeApp());
  await tester.pump(const Duration(milliseconds: 1300)); // splash beat
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
  Navigator.of(tester.element(find.byType(HomeScreen)))
      .pushNamed(AppRoutes.game, arguments: setup);
  await tester.pumpAndSettle();
  expect(find.byType(GameScreen), findsOneWidget);
  return tester.widget<GameScreen>(find.byType(GameScreen)).controller;
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

Future<void> tapBoard(WidgetTester tester, Offset localPosition) async {
  final gestureFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(GestureDetector),
  );
  await tester.tapAt(tester.getTopLeft(gestureFinder) + localPosition);
  await tester.pump();
}

/// The legal target bringing [player] closest to their goal row,
/// chosen from the targets the controller itself advertises.
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

/// Taps the greedy move for whoever is to move and asserts the tap
/// actually advanced the game by exactly one ply — the assertion the
/// §13u regression would have failed on every single tap.
Future<void> tapGreedyMove(
  WidgetTester tester,
  LocalGameController controller,
  BoardGeometry geometry,
) async {
  final player = controller.currentPlayer;
  final before = controller.state.turnNumber;
  final target = greedyTarget(controller, player);
  await tapBoard(tester, geometry.cellCenterFromModel(target));
  await tester.pumpAndSettle();
  expect(
    controller.state.turnNumber,
    before + 1,
    reason: 'the tap on $target must advance the match by one ply',
  );
  expect(controller.state.pawnPosition(player), target);
}

void main() {
  group('local play through the real app (Phase 12 regression)', () {
    testWidgets('pass-and-play: full 5x5 match played by real taps', (
      tester,
    ) async {
      final controller = await startGame(
        tester,
        setup: const MatchSetup(config: BoardConfig(size: 5)),
      );
      final geometry = geometryOf(tester, 5);
      final sameController = controller;

      // Ply 1 (Blue) and the direct regression assertions: the pawn
      // moves, the turn passes, and the screen still shows the SAME
      // controller instance afterwards.
      await tapGreedyMove(tester, controller, geometry);
      expect(find.text("RED'S TURN"), findsOneWidget);

      // Ply 2 (Red) places a wall by real taps: WALL mode, slot tap,
      // CONFIRM.
      await tester.tap(find.text('WALL'));
      await tester.pumpAndSettle();
      await tapBoard(tester, geometry.wallRect(2, 0, WallOrientation.h).center);
      await tester.pumpAndSettle();
      expect(controller.pendingWall, isNotNull);
      await tester.tap(find.text('CONFIRM'));
      await tester.pumpAndSettle();
      expect(controller.state.walls.length, 1);
      expect(controller.state.turnNumber, 2);
      expect(controller.currentPlayer, PlayerId.blue);

      // Play the rest of the match by taps until someone wins.
      var plies = 2;
      while (controller.state.status != GameStatus.finished && plies < 40) {
        await tapGreedyMove(tester, controller, geometry);
        plies++;
      }
      expect(
        controller.state.status,
        GameStatus.finished,
        reason: 'the tapped match must reach a finish',
      );
      expect(controller.state.winner, isNotNull);
      expect(
        identical(
          sameController,
          tester.widget<GameScreen>(find.byType(GameScreen)).controller,
        ),
        isTrue,
        reason: 'the screen must keep the same controller all match long',
      );
    });

    testWidgets('vs-AI: full 5x5 match — human taps, AI replies, '
        'match finishes', (tester) async {
      final controller = await startGame(
        tester,
        setup: const MatchSetup(
          config: BoardConfig(size: 5),
          versusAi: true,
          // (The default difficulty: Easy.)
        ),
      );
      final geometry = geometryOf(tester, 5);

      var rounds = 0;
      while (controller.state.status != GameStatus.finished && rounds < 60) {
        expect(controller.currentPlayer, PlayerId.blue);
        final before = controller.state.turnNumber;
        final target = greedyTarget(controller, PlayerId.blue);
        await tapBoard(tester, geometry.cellCenterFromModel(target));
        await tester.pump();
        expect(
          controller.state.turnNumber,
          before + 1,
          reason: 'the human tap must advance the match',
        );
        expect(controller.state.pawnPosition(PlayerId.blue), target);
        if (controller.state.status == GameStatus.finished) break;
        // The AI replies after its think delay.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(
          controller.state.turnNumber,
          before + 2,
          reason: 'the AI must reply to the human move',
        );
        expect(controller.currentPlayer, PlayerId.blue);
        rounds++;
      }
      expect(
        controller.state.status,
        GameStatus.finished,
        reason: 'the tapped vs-AI match must reach a finish',
      );
      expect(controller.state.winner, isNotNull);
    });
  });
}
