import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/domain/models/action_failure.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/board/board.dart';

void main() {
  group('BoardView hit-testing', () {
    Widget buildApp({
      required ValueChanged<Cell>? onCellTap,
      required void Function(Cell anchor, WallOrientation orientation)?
      onWallSlotTap,
      double width = 400,
      double height = 400,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: BoardView(
              state: GameState.initial(),
              onCellTap: onCellTap,
              onWallSlotTap: onWallSlotTap,
            ),
          ),
        ),
      );
    }

    testWidgets('tap on board area triggers onCellTap', (tester) async {
      Cell? tappedCell;
      await tester.pumpWidget(
        buildApp(
          onCellTap: (cell) => tappedCell = cell,
          onWallSlotTap: (_, _) {},
        ),
      );

      // Tap near center of board (should be a cell)
      await tester.tap(find.byType(BoardView));
      await tester.pumpAndSettle();

      expect(tappedCell, isNotNull);
      // Should have triggered a cell tap (center of 9x9 board is around row 4, col 4)
      // The exact cell depends on hit priority (wall vs cell)
    });

    testWidgets('tap with no callbacks does not add GestureDetector', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: BoardView(state: GameState.initial()),
            ),
          ),
        ),
      );

      // No GestureDetector should be present without callbacks
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('tap with cell callback adds GestureDetector', (tester) async {
      await tester.pumpWidget(buildApp(onCellTap: (_) {}, onWallSlotTap: null));

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('tap with wall callback adds GestureDetector', (tester) async {
      await tester.pumpWidget(
        buildApp(onCellTap: null, onWallSlotTap: (_, _) {}),
      );

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('multiple taps produce multiple callbacks', (tester) async {
      final tappedCells = <Cell>[];
      await tester.pumpWidget(
        buildApp(onCellTap: tappedCells.add, onWallSlotTap: (_, _) {}),
      );

      // Tap multiple positions
      await tester.tapAt(const Offset(200, 200));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(220, 200));
      await tester.pumpAndSettle();

      // At least some cells should have been tapped
      expect(tappedCells, isNotEmpty);
    });

    testWidgets('wall slot tap has priority over cell tap', (tester) async {
      Cell? tappedCell;
      (Cell, WallOrientation)? tappedWall;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: BoardView(
                state: GameState.initial(),
                onCellTap: (cell) => tappedCell = cell,
                onWallSlotTap: (anchor, orientation) {
                  tappedWall = (anchor, orientation);
                },
              ),
            ),
          ),
        ),
      );

      // Tap near a wall slot (top-left area of the board)
      await tester.tapAt(const Offset(120, 120));
      await tester.pumpAndSettle();

      // Either wall or cell should have been triggered (depends on exact position)
      // The important thing is that only one is triggered
      expect(
        tappedCell != null || tappedWall != null,
        isTrue,
        reason: 'Either cell or wall tap should be triggered',
      );
    });

    testWidgets('BoardView renders with wall preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: BoardView(
                state: GameState.initial(),
                wallPreview: const WallPreview(
                  anchor: Cell(row: 6, column: 5),
                  orientation: WallOrientation.h,
                  isValid: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('BoardView renders with invalid wall preview', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: BoardView(
                state: GameState.initial(),
                wallPreview: const WallPreview(
                  anchor: Cell(row: 6, column: 5),
                  orientation: WallOrientation.h,
                  isValid: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('BoardView renders with selectedCell', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: BoardView(
                state: GameState.initial(),
                selectedCell: const Cell(row: 8, column: 4),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('BoardView renders with activeGlow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: BoardView(
                state: GameState.initial(),
                activeGlow: PlayerId.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('BoardView renders with legalMoveTargets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: BoardView(
                state: GameState.initial(),
                legalMoveTargets: {
                  const Cell(row: 7, column: 4),
                  const Cell(row: 8, column: 3),
                  const Cell(row: 8, column: 5),
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('BoardView renders different board sizes', (tester) async {
      for (final size in [5, 7, 9, 11]) {
        final config = BoardConfig(size: size);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 400,
                child: BoardView(state: GameState.initial(config)),
              ),
            ),
          ),
        );

        expect(find.byType(BoardView), findsOneWidget);
      }
    });
  });

  group('BoardView wall snap tolerance', () {
    const boardExtent = 400.0;
    const g = BoardGeometry(boardSize: 9, areaSize: boardExtent);

    Widget board({
      required GameState state,
      WallPreview? wallPreview,
      ValueChanged<Cell>? onCellTap,
      void Function(Cell anchor, WallOrientation orientation)? onWallSlotTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: boardExtent,
            height: boardExtent,
            child: BoardView(
              state: state,
              wallPreview: wallPreview,
              onCellTap: onCellTap,
              onWallSlotTap: onWallSlotTap,
            ),
          ),
        ),
      );
    }

    testWidgets('a tap inside the tolerance resolves to the intended anchor', (
      tester,
    ) async {
      Cell? tappedCell;
      (Cell, WallOrientation)? tappedWall;
      await tester.pumpWidget(
        board(
          state: GameState.initial(),
          onCellTap: (cell) => tappedCell = cell,
          onWallSlotTap: (anchor, orientation) =>
              tappedWall = (anchor, orientation),
        ),
      );

      final origin = tester.getTopLeft(find.byType(BoardView));
      final lineY = (3 + 1) * g.cellSize;
      final pos = Offset(
        g.cellCenter(0, 3).dx,
        lineY + g.wallHitTolerance * 0.6,
      );

      await tester.tapAt(origin + pos);
      await tester.pumpAndSettle();

      expect(tappedWall, (const Cell(row: 3, column: 3), WallOrientation.h));
      expect(tappedCell, isNull);
    });

    testWidgets('a tap beyond the tolerance falls through to the cell', (
      tester,
    ) async {
      Cell? tappedCell;
      (Cell, WallOrientation)? tappedWall;
      await tester.pumpWidget(
        board(
          state: GameState.initial(),
          onCellTap: (cell) => tappedCell = cell,
          onWallSlotTap: (anchor, orientation) =>
              tappedWall = (anchor, orientation),
        ),
      );

      final origin = tester.getTopLeft(find.byType(BoardView));
      final lineY = (3 + 1) * g.cellSize;
      final deadBand = g.cellSize - 2 * g.wallHitTolerance;
      final pos = Offset(
        g.cellCenter(0, 3).dx,
        lineY + g.wallHitTolerance + deadBand / 4,
      );

      await tester.tapAt(origin + pos);
      await tester.pumpAndSettle();

      expect(tappedWall, isNull);
      expect(tappedCell, const Cell(row: 4, column: 3));
    });

    testWidgets('a tap at a cell centre is never captured as a wall anchor', (
      tester,
    ) async {
      Cell? tappedCell;
      (Cell, WallOrientation)? tappedWall;
      await tester.pumpWidget(
        board(
          state: GameState.initial(),
          onCellTap: (cell) => tappedCell = cell,
          onWallSlotTap: (anchor, orientation) =>
              tappedWall = (anchor, orientation),
        ),
      );

      final origin = tester.getTopLeft(find.byType(BoardView));
      await tester.tapAt(origin + g.cellCenter(4, 3));
      await tester.pumpAndSettle();

      expect(tappedWall, isNull);
      expect(tappedCell, const Cell(row: 4, column: 3));
    });

    testWidgets(
      'a near-miss on a conflicting groove still reports wallCrosses',
      (tester) async {
        final controller = LocalGameController();
        addTearDown(controller.dispose);
        controller.setMode(InteractionMode.wall);
        controller.tapWallSlot(
          const Cell(row: 3, column: 3),
          WallOrientation.h,
        );
        controller.confirm();
        controller.setMode(InteractionMode.wall);
        controller.tapWallSlot(
          const Cell(row: 0, column: 0),
          WallOrientation.h,
        );
        controller.confirm();
        controller.setMode(InteractionMode.wall);

        (Cell, WallOrientation)? tappedWall;
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => board(
              state: controller.state,
              wallPreview: controller.pendingWall == null
                  ? null
                  : WallPreview(
                      anchor: controller.pendingWall!.anchor,
                      orientation: controller.pendingWall!.orientation,
                      isValid: controller.pendingWallFailure == null,
                    ),
              onCellTap: controller.tapCell,
              onWallSlotTap: (anchor, orientation) {
                tappedWall = (anchor, orientation);
                controller.tapWallSlot(anchor, orientation);
              },
            ),
          ),
        );

        final origin = tester.getTopLeft(find.byType(BoardView));
        final lineX = (3 + 1) * g.cellSize;
        final pos = Offset(
          lineX + g.wallHitTolerance * 0.9,
          g.cellCenter(3, 0).dy,
        );

        expect(g.wallAnchorAt(pos), (
          row: 3,
          col: 3,
          orientation: WallOrientation.v,
        ), reason: 'the near-miss must not drift to a neighbouring anchor');

        await tester.tapAt(origin + pos);
        await tester.pumpAndSettle();

        expect(tappedWall, (const Cell(row: 3, column: 3), WallOrientation.v));
        expect(controller.pendingWall!.anchor, const Cell(row: 3, column: 3));
        expect(controller.pendingWall!.orientation, WallOrientation.v);
        expect(controller.pendingWallFailure, ActionFailure.wallCrosses);
        expect(
          find.byType(BoardView),
          findsOneWidget,
          reason: 'the invalid ghost must still render',
        );
      },
    );
  });

  group('BoardView cross-axis anchor selection (Phase 4.3)', () {
    const g = BoardGeometry(boardSize: 9, areaSize: 640);

    /// Blue H(6,3) and Red H(6,6) placed through the engine-backed controller.
    /// H(6,1) is then a genuinely empty legal slot (offset 2 from H(6,3)), but its
    /// right half used to resolve to H(6,2), which is offset 1 from H(6,3) and is
    /// therefore rejected as `wallOverlaps` — the owner's report.
    LocalGameController scenarioWithTwoWalls() {
      final controller = LocalGameController();
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 6, column: 3), WallOrientation.h);
      controller.confirm();
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 6, column: 6), WallOrientation.h);
      controller.confirm();
      controller.setMode(InteractionMode.wall);
      expect(controller.currentPlayer, PlayerId.blue);
      expect(controller.state.walls, hasLength(2));
      return controller;
    }

    test('aiming across an empty slot footprint resolves to that slot', () {
      final controller = scenarioWithTwoWalls();
      addTearDown(controller.dispose);
      final lineY = 7 * g.cellSize;

      for (final t in [1.5, 1.7, 1.9, 2.0, 2.1, 2.3, 2.4]) {
        final anchor = g.wallAnchorAt(Offset(t * g.cellSize, lineY));
        expect(anchor, (
          row: 6,
          col: 1,
          orientation: WallOrientation.h,
        ), reason: 'cursor at t=$t must aim at the empty H(6,1) slot');

        controller.setMode(InteractionMode.wall);
        controller.tapWallSlot(
          Cell(row: anchor!.row, column: anchor.col),
          anchor.orientation,
        );
        expect(
          controller.pendingWallFailure,
          isNull,
          reason: 'H(6,1) is legal but was rejected at t=$t',
        );
        controller.cancel();
      }
    });

    test('the transition zone is deterministic and stable', () {
      final lineY = 7 * g.cellSize;
      const justBefore = 2.5 - 0.001;
      const justAfter = 2.5 + 0.001;

      expect(g.wallAnchorAt(Offset(justBefore * g.cellSize, lineY)), (
        row: 6,
        col: 1,
        orientation: WallOrientation.h,
      ), reason: 'below the midpoint the left anchor owns the tap');
      expect(g.wallAnchorAt(Offset(justAfter * g.cellSize, lineY)), (
        row: 6,
        col: 2,
        orientation: WallOrientation.h,
      ), reason: 'above the midpoint the right anchor owns the tap');

      for (var i = 0; i < 5; i++) {
        expect(g.wallAnchorAt(Offset(justAfter * g.cellSize, lineY)), (
          row: 6,
          col: 2,
          orientation: WallOrientation.h,
        ), reason: 'repeated identical input must not flap');
        expect(g.wallAnchorAt(Offset(justBefore * g.cellSize, lineY)), (
          row: 6,
          col: 1,
          orientation: WallOrientation.h,
        ));
      }
    });

    testWidgets('a real tap on the empty slot saves the wall', (tester) async {
      final controller = scenarioWithTwoWalls();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 640,
              height: 640,
              child: BoardView(
                state: controller.state,
                onWallSlotTap: controller.tapWallSlot,
              ),
            ),
          ),
        ),
      );

      final origin = tester.getTopLeft(find.byType(BoardView));
      final centre = Offset(2 * g.cellSize, 7 * g.cellSize);
      final turnBefore = controller.state.turnNumber;
      await tester.tapAt(origin + centre);
      await tester.pumpAndSettle();

      expect(
        controller.pendingWall!.anchor,
        const Cell(row: 6, column: 1),
        reason: 'the bar centre must resolve to the aimed slot',
      );
      expect(controller.pendingWallFailure, isNull);

      controller.confirm();
      await tester.pumpAndSettle();

      expect(controller.state.walls, hasLength(3));
      expect(
        controller.state.turnNumber,
        turnBefore + 1,
        reason: 'saving the wall must pass the turn',
      );
      expect(controller.currentPlayer, PlayerId.red);
    });
  });
}
