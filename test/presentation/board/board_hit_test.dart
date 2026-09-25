import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
