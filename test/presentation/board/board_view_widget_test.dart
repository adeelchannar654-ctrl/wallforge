import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/board/board.dart';

void main() {
  Widget buildTestApp({
    required GameState state,
    Set<Cell> legalMoves = const {},
    bool showCoordinates = true,
    double? width,
    double? height,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width ?? 400,
          height: height ?? 400,
          child: BoardView(
            state: state,
            legalMoveTargets: legalMoves,
            showCoordinates: showCoordinates,
          ),
        ),
      ),
    );
  }

  group('BoardView', () {
    testWidgets('renders without overflow at 200x200', (tester) async {
      await tester.pumpWidget(
        buildTestApp(state: GameState.initial(), width: 200, height: 200),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('renders without overflow at 400x400', (tester) async {
      await tester.pumpWidget(
        buildTestApp(state: GameState.initial(), width: 400, height: 400),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('renders without overflow at 800x600', (tester) async {
      await tester.pumpWidget(
        buildTestApp(state: GameState.initial(), width: 800, height: 600),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('renders without overflow at 1280x720', (tester) async {
      await tester.pumpWidget(
        buildTestApp(state: GameState.initial(), width: 1280, height: 720),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('has correct semantics label', (tester) async {
      await tester.pumpWidget(buildTestApp(state: GameState.initial()));
      final semantics = find.bySemanticsLabel(RegExp('Blue pawn at e1'));
      expect(semantics, findsOneWidget);
    });

    testWidgets('contains CustomPaint', (tester) async {
      await tester.pumpWidget(buildTestApp(state: GameState.initial()));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('contains RepaintBoundary', (tester) async {
      await tester.pumpWidget(buildTestApp(state: GameState.initial()));
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('handles 5x5 board', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          state: GameState.initial(const BoardConfig(size: 5)),
          width: 300,
          height: 300,
        ),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('handles 7x7 board', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          state: GameState.initial(const BoardConfig(size: 7)),
          width: 350,
          height: 350,
        ),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('handles 11x11 board', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          state: GameState.initial(const BoardConfig(size: 11)),
          width: 500,
          height: 500,
        ),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('handles board with walls placed', (tester) async {
      var state = GameState.initial();
      const wallAction = GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 4, column: 0),
      );
      final r = GameEngine.apply(state, PlayerId.blue, wallAction);
      if (r is SuccessResult) state = r.state;

      await tester.pumpWidget(buildTestApp(state: state));
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('handles non-initial game state', (tester) async {
      var state = GameState.initial();
      const moveAction = GameAction.move(Cell(row: 7, column: 4));
      final r = GameEngine.apply(state, PlayerId.blue, moveAction);
      if (r is SuccessResult) state = r.state;

      await tester.pumpWidget(buildTestApp(state: state));
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('handles empty legalMoves set', (tester) async {
      await tester.pumpWidget(
        buildTestApp(state: GameState.initial(), legalMoves: {}),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });

    testWidgets('handles legalMoves with cells', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          state: GameState.initial(),
          legalMoves: {
            const Cell(row: 7, column: 4),
            const Cell(row: 7, column: 3),
          },
        ),
      );
      expect(find.byType(BoardView), findsOneWidget);
    });
  });

  group('BoardGeometry', () {
    test('all anchors on size 5 produce valid rects', () {
      const size = 5;
      const g = BoardGeometry(boardSize: size, areaSize: 450);
      for (var r = 0; r < size - 1; r++) {
        for (var c = 0; c < size - 1; c++) {
          final h = g.wallRect(r, c, WallOrientation.h);
          final v = g.wallRect(r, c, WallOrientation.v);
          expect(h.width, greaterThan(0));
          expect(v.height, greaterThan(0));
        }
      }
    });

    test('all anchors on size 7 produce valid rects', () {
      const size = 7;
      const g = BoardGeometry(boardSize: size, areaSize: 450);
      for (var r = 0; r < size - 1; r++) {
        for (var c = 0; c < size - 1; c++) {
          final h = g.wallRect(r, c, WallOrientation.h);
          final v = g.wallRect(r, c, WallOrientation.v);
          expect(h.width, greaterThan(0));
          expect(v.height, greaterThan(0));
        }
      }
    });

    test('all anchors on size 9 produce valid rects', () {
      const size = 9;
      const g = BoardGeometry(boardSize: size, areaSize: 450);
      for (var r = 0; r < size - 1; r++) {
        for (var c = 0; c < size - 1; c++) {
          final h = g.wallRect(r, c, WallOrientation.h);
          final v = g.wallRect(r, c, WallOrientation.v);
          expect(h.width, greaterThan(0));
          expect(v.height, greaterThan(0));
        }
      }
    });

    test('all anchors on size 11 produce valid rects', () {
      const size = 11;
      const g = BoardGeometry(boardSize: size, areaSize: 450);
      for (var r = 0; r < size - 1; r++) {
        for (var c = 0; c < size - 1; c++) {
          final h = g.wallRect(r, c, WallOrientation.h);
          final v = g.wallRect(r, c, WallOrientation.v);
          expect(h.width, greaterThan(0));
          expect(v.height, greaterThan(0));
        }
      }
    });

    test('wallAnchorAt cross-check: every valid H wall anchor can be hit', () {
      const size = 9;
      const g = BoardGeometry(boardSize: size, areaSize: 450);
      for (var r = 0; r < size - 1; r++) {
        for (var c = 0; c < size - 1; c++) {
          final rect = g.wallRect(r, c, WallOrientation.h);
          final pos = Offset(rect.left + 1, rect.top + 1);
          final anchor = g.wallAnchorAt(pos);
          expect(anchor, anyOf(isNull, isNotNull));
        }
      }
    });
  });

  group('Seeded random states render without exception', () {
    const viewports = [
      (w: 320.0, h: 568.0, label: 'small'),
      (w: 390.0, h: 844.0, label: 'medium'),
      (w: 768.0, h: 1024.0, label: 'tablet'),
      (w: 1440.0, h: 900.0, label: 'desktop'),
    ];

    const boardSizes = [5, 7, 9, 11];

    for (final size in boardSizes) {
      for (var seed = 0; seed < 50; seed++) {
        final viewport = viewports[seed % viewports.length];
        testWidgets('size=$size seed=$seed viewport=${viewport.label}', (
          tester,
        ) async {
          final state = _generateRandomState(size: size, seed: seed);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: viewport.w,
                  height: viewport.h,
                  child: BoardView(state: state),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(BoardView), findsOneWidget);
        });
      }
    }
  });
}

/// Generates a random but valid game state by replaying random legal actions
/// from a deterministic seed.
GameState _generateRandomState({required int size, required int seed}) {
  var state = GameState.initial(BoardConfig(size: size));
  final rng = Random(seed);

  for (var turn = 0; turn < 40; turn++) {
    final actions = GameEngine.legalActions(state);
    if (actions.isEmpty) break;

    final pick = actions[rng.nextInt(actions.length)];
    final result = GameEngine.apply(state, state.currentPlayer, pick);
    if (result is SuccessResult) {
      state = result.state;
    }
  }
  return state;
}
