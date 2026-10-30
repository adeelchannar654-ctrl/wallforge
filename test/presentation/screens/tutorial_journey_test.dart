// Phase 16 C.4: the tutorial journey through the real app — enter
// from Home's card, perform each step's required interaction on the
// tutorial's own board (a pawn move, then a wall placement with
// confirm), finish, and verify completion persisted (Home's card
// changes from "Learn to play" to "Tutorial").
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/board/board_geometry.dart';
import 'package:wallforge/presentation/board/board_view.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/tutorial/tutorial_screen.dart';

BoardGeometry _geometry(WidgetTester tester) {
  final size = tester.getSize(find.byType(BoardView)).width;
  return BoardGeometry(boardSize: 5, areaSize: size);
}

Future<void> _tapBoard(WidgetTester tester, Offset local) async {
  final gestureFinder = find.descendant(
    of: find.byType(BoardView),
    matching: find.byType(GestureDetector),
  );
  await tester.tapAt(tester.getTopLeft(gestureFinder) + local);
  await tester.pump();
}

void main() {
  testWidgets('the tutorial is completed end to end and remembered', (
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
    expect(find.text('Learn to play'), findsOneWidget);

    await tester.ensureVisible(find.text('Learn to play'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialScreen), findsOneWidget);

    // Step 1 of 5: reading only — NEXT is enabled.
    expect(find.text('Step 1 of 5'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    // Step 2: move the pawn (Blue starts at (3,2); step forward).
    expect(find.text('Step 2 of 5'), findsOneWidget);
    await _tapBoard(
      tester,
      _geometry(tester).cellCenterFromModel(const Cell(row: 2, column: 2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    // Step 3: place a wall and confirm it.
    expect(find.text('Step 3 of 5'), findsOneWidget);
    final rect = _geometry(tester).wallRect(1, 1, WallOrientation.h);
    await _tapBoard(tester, Offset(rect.left + rect.width / 4, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('CONFIRM'), findsOneWidget);
    await tester.tap(find.text('CONFIRM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();

    // Steps 4 and 5: reading only; the last button is FINISH.
    expect(find.text('Step 4 of 5'), findsOneWidget);
    await tester.tap(find.text('NEXT'));
    await tester.pumpAndSettle();
    expect(find.text('Step 5 of 5'), findsOneWidget);
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();

    // Back Home, and completion is remembered on the card.
    expect(find.byType(TutorialScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Tutorial'), findsWidgets);
    expect(find.text('Learn to play'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
