import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_status.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/board/board.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';

void main() {
  group('GameScreen', () {
    testWidgets('mobile layout exposes a functional mode toggle', (
      tester,
    ) async {
      await _setViewport(tester, const Size(390, 844));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));

      expect(find.text('MOVE'), findsOneWidget);
      expect(find.text('WALL'), findsOneWidget);
      await tester.tap(find.text('WALL'));
      await tester.pump();
      expect(controller.mode, InteractionMode.wall);

      await tester.tap(find.text('MOVE'));
      await tester.pump();
      expect(controller.mode, InteractionMode.move);
    });

    testWidgets('desktop layout exposes a functional mode toggle', (
      tester,
    ) async {
      await _setViewport(tester, const Size(1024, 768));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));

      expect(find.text('PLAYER 1'), findsOneWidget);
      expect(find.text('PLAYER 2'), findsOneWidget);
      expect(find.byType(WallInventoryNotches), findsNWidgets(2));
      expect(find.text('MOVE'), findsOneWidget);
      expect(find.text('WALL'), findsOneWidget);

      await tester.tap(find.text('WALL'));
      await tester.pump();
      expect(controller.mode, InteractionMode.wall);

      await tester.tap(find.text('MOVE'));
      await tester.pump();
      expect(controller.mode, InteractionMode.move);
    });

    testWidgets('valid wall ghost enables Confirm and applies the wall', (
      tester,
    ) async {
      await _setViewport(tester, const Size(390, 844));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
      await tester.pump();

      final board = tester.widget<BoardView>(find.byType(BoardView));
      expect(board.wallPreview, isNotNull);
      expect(board.wallPreview!.isValid, isTrue);
      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'CONFIRM'),
      );
      expect(confirm.onPressed, isNotNull);
      expect(find.byKey(const ValueKey('pending-wall-failure')), findsNothing);

      await tester.tap(find.text('CONFIRM'));
      await tester.pump();
      expect(controller.state.wallsRemaining(PlayerId.blue), 9);
      expect(controller.state.turnNumber, 1);
      expect(controller.mode, InteractionMode.move);
      expect(controller.currentPlayer, PlayerId.red);
    });

    testWidgets('invalid wall ghost shows reason and disables Confirm', (
      tester,
    ) async {
      await _setViewport(tester, const Size(390, 844));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 8, column: 0), WallOrientation.h);
      await tester.pump();

      final board = tester.widget<BoardView>(find.byType(BoardView));
      expect(board.wallPreview!.isValid, isFalse);
      expect(
        find.byKey(const ValueKey('pending-wall-failure')),
        findsOneWidget,
      );
      expect(find.text('Wall placement is out of bounds.'), findsOneWidget);
      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'CONFIRM'),
      );
      expect(confirm.onPressed, isNull);
      final before = controller.state;
      await tester.tap(find.text('CONFIRM'));
      await tester.pump();
      expect(controller.state, before);

      await tester.tap(find.text('CANCEL'));
      await tester.pump();
      expect(controller.pendingWall, isNull);
    });

    testWidgets('failure feedback is visible after an illegal move', (
      tester,
    ) async {
      await _setViewport(tester, const Size(390, 844));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));

      controller.tapCell(const Cell(row: 0, column: 0));
      await tester.pump();

      expect(
        find.text('You can only move to an adjacent cell.'),
        findsOneWidget,
      );
    });

    testWidgets('move mode: a tap near a groove still moves the pawn', (
      tester,
    ) async {
      await _setViewport(tester, const Size(1024, 768));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));

      final board = find.byType(BoardView);
      final origin = tester.getTopLeft(board);
      final extent = tester.getSize(board).width;
      final geometry = BoardGeometry(
        boardSize: controller.state.boardConfig.size,
        areaSize: extent,
      );

      final pos = Offset(
        geometry.cellCenter(7, 4).dx,
        7 * geometry.cellSize + geometry.wallHitTolerance * 0.5,
      );
      expect(
        geometry.wallAnchorAt(pos),
        isNotNull,
        reason: 'the point is inside wall-snap range',
      );

      await tester.tapAt(origin + pos);
      await tester.pump();

      expect(
        controller.state.pawnPosition(PlayerId.blue),
        const Cell(row: 7, column: 4),
      );
      expect(controller.state.turnNumber, 1);
    });

    testWidgets('a legal wall beside an existing wall shows a valid ghost', (
      tester,
    ) async {
      await _setViewport(tester, const Size(1024, 768));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 3, column: 3), WallOrientation.h);
      controller.confirm();
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 0, column: 0), WallOrientation.h);
      controller.confirm();
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 3, column: 5), WallOrientation.h);
      await tester.pumpWidget(_gameApp(controller));
      await tester.pump();

      final board = tester.widget<BoardView>(find.byType(BoardView));
      expect(controller.pendingWallFailure, isNull);
      expect(board.wallPreview!.isValid, isTrue);
      expect(find.byKey(const ValueKey('pending-wall-failure')), findsNothing);
      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'CONFIRM'),
      );
      expect(confirm.onPressed, isNotNull);
    });

    testWidgets('desktop breakpoint renders without overflow', (tester) async {
      await _setViewport(tester, const Size(768, 900));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));
      expect(tester.takeException(), isNull);
    });

    testWidgets('desktop layout keeps the board centered with side rails', (
      tester,
    ) async {
      await _setViewport(tester, const Size(1440, 900));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));

      expect(find.byType(BoardView), findsOneWidget);
      expect(find.byType(WallInventoryNotches), findsNWidgets(2));
      expect(find.text('RESTART'), findsOneWidget);
      expect(find.text('BACK'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('result overlay appears and Rematch resets the match', (
      tester,
    ) async {
      await _setViewport(tester, const Size(1024, 768));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_gameApp(controller));
      _replayScriptedGame(controller);
      await tester.pump();

      expect(controller.state.status, GameStatus.finished);
      expect(find.byKey(const ValueKey('game-result-overlay')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-heading')), findsOneWidget);
      expect(find.text('REMATCH'), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);

      await tester.tap(find.text('REMATCH'));
      await tester.pump();
      expect(controller.state.status, GameStatus.inProgress);
      expect(controller.state.turnNumber, 0);
      expect(find.byKey(const ValueKey('game-result-overlay')), findsNothing);
    });

    testWidgets('result Home returns to the previous route', (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GameScreen(controller: controller),
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      _replayScriptedGame(controller);
      await tester.pump();

      await tester.tap(find.text('HOME'));
      await tester.pumpAndSettle();
      expect(find.text('OPEN'), findsOneWidget);
    });

    testWidgets('Restart and Back work', (tester) async {
      await _setViewport(tester, const Size(390, 844));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GameScreen(controller: controller),
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();
      controller.tapCell(const Cell(row: 7, column: 4));
      await tester.pump();
      expect(controller.state.turnNumber, 1);

      await tester.tap(find.text('RESTART'));
      await tester.pump();
      expect(controller.state.turnNumber, 0);

      await tester.tap(find.text('BACK'));
      await tester.pumpAndSettle();
      expect(find.text('OPEN'), findsOneWidget);
    });
  });

  group('AppRouter', () {
    testWidgets('passes a BoardConfig argument to GameScreen', (tester) async {
      await _setViewport(tester, const Size(390, 844));
      const config = BoardConfig(size: 7);
      await tester.pumpWidget(
        const MaterialApp(
          initialRoute: AppRoutes.home,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      final preset = find.text('Initial 7×7');
      await tester.ensureVisible(preset);
      await tester.tap(preset);
      await tester.pumpAndSettle();
      await tester.tap(find.text('START LOCAL MATCH'));
      await tester.pumpAndSettle();

      final game = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(game.controller.state.boardConfig, config);
    });

    testWidgets('falls back to the default config without route arguments', (
      tester,
    ) async {
      await _setViewport(tester, const Size(390, 844));
      await tester.pumpWidget(
        const MaterialApp(
          initialRoute: AppRoutes.game,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pumpAndSettle();

      final game = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(game.controller.state.boardConfig, const BoardConfig());
    });

    testWidgets('router can be called directly with a config argument', (
      tester,
    ) async {
      const config = BoardConfig(size: 7, wallsPerPlayer: 8);
      final route = AppRouter.onGenerateRoute(
        const RouteSettings(name: AppRoutes.game, arguments: config),
      );
      await tester.pumpWidget(MaterialApp(onGenerateRoute: (_) => route));
      await tester.pumpAndSettle();
      final game = tester.widget<GameScreen>(find.byType(GameScreen));
      expect(game.controller.state.boardConfig, config);
    });
  });
}

Widget _gameApp(LocalGameController controller) {
  return MaterialApp(home: GameScreen(controller: controller));
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _replayScriptedGame(LocalGameController controller) {
  const actions = <(PlayerId, GameAction)>[
    (PlayerId.blue, GameAction.move(Cell(row: 7, column: 4))),
    (PlayerId.red, GameAction.move(Cell(row: 1, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 6, column: 4))),
    (PlayerId.red, GameAction.move(Cell(row: 2, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 5, column: 4))),
    (
      PlayerId.red,
      GameAction.wall(
        orientation: WallOrientation.v,
        anchor: Cell(row: 6, column: 3),
      ),
    ),
    (
      PlayerId.blue,
      GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 6, column: 5),
      ),
    ),
    (PlayerId.red, GameAction.move(Cell(row: 3, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 4, column: 4))),
    (
      PlayerId.red,
      GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 1, column: 3),
      ),
    ),
    (PlayerId.blue, GameAction.move(Cell(row: 2, column: 4))),
    (PlayerId.red, GameAction.move(Cell(row: 4, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 2, column: 5))),
    (PlayerId.red, GameAction.move(Cell(row: 5, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 1, column: 5))),
    (PlayerId.red, GameAction.move(Cell(row: 6, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 0, column: 5))),
  ];

  for (final (_, action) in actions) {
    switch (action) {
      case MoveAction(:final destination):
        controller.tapCell(destination);
      case WallAction(:final orientation, :final anchor):
        controller.setMode(InteractionMode.wall);
        controller.tapWallSlot(anchor, orientation);
        controller.confirm();
    }
  }
}
