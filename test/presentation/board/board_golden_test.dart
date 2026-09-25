import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board.dart';

/// Golden tests for BoardView. Tagged `golden` — run with:
///   flutter test --tags golden
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Load Inter variable font for golden tests.
    final fontLoader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await fontLoader.load();
  });

  group('BoardView golden', () {
    testWidgets('initial 9x9 board', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0E131E),
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: BoardView(state: GameState.initial()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BoardView),
        matchesGoldenFile('goldens/board_view_initial_9x9.png'),
      );
    });

    testWidgets('board with walls and pawns moved', (tester) async {
      var state = GameState.initial();
      // Play a few moves.
      final actions = [
        (PlayerId.blue, const GameAction.move(Cell(row: 7, column: 4))),
        (PlayerId.red, const GameAction.move(Cell(row: 1, column: 4))),
        (PlayerId.blue, const GameAction.move(Cell(row: 6, column: 4))),
        (PlayerId.red, const GameAction.move(Cell(row: 2, column: 4))),
        (
          PlayerId.red,
          const GameAction.wall(
            orientation: WallOrientation.v,
            anchor: Cell(row: 6, column: 3),
          ),
        ),
        (
          PlayerId.blue,
          const GameAction.wall(
            orientation: WallOrientation.h,
            anchor: Cell(row: 6, column: 5),
          ),
        ),
      ];
      for (final (player, action) in actions) {
        final r = GameEngine.apply(state, player, action);
        if (r is SuccessResult) state = r.state;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0E131E),
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: BoardView(state: state, activeGlow: PlayerId.blue),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BoardView),
        matchesGoldenFile('goldens/board_view_with_walls.png'),
      );
    });

    testWidgets('board with legal move highlights', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0E131E),
            body: Center(
              child: SizedBox(
                width: 400,
                height: 400,
                child: BoardView(
                  state: GameState.initial(),
                  legalMoveTargets: {
                    const Cell(row: 7, column: 4),
                    const Cell(row: 7, column: 3),
                    const Cell(row: 7, column: 5),
                  },
                  showCoordinates: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BoardView),
        matchesGoldenFile('goldens/board_view_legal_moves.png'),
      );
    });

    testWidgets('board 5x5', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0E131E),
            body: Center(
              child: SizedBox(
                width: 300,
                height: 300,
                child: BoardView(
                  state: GameState.initial(const BoardConfig(size: 5)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BoardView),
        matchesGoldenFile('goldens/board_view_5x5.png'),
      );
    });

    testWidgets('board 11x11', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF0E131E),
            body: Center(
              child: SizedBox(
                width: 500,
                height: 500,
                child: BoardView(
                  state: GameState.initial(const BoardConfig(size: 11)),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(BoardView),
        matchesGoldenFile('goldens/board_view_11x11.png'),
      );
    });
  });
}
