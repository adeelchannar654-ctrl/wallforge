import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/finish_reason.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';
import 'package:wallforge/presentation/screens/result/result_screen.dart';

/// Phase 16.5, Part B (UI): the resign flow, the leave-match
/// confirmation, and the finish reason on the Result screen.
void main() {
  testWidgets('RESIGN asks first, then ends the match on the Result screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LocalGameController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );

    await tester.tap(find.text('RESIGN'));
    await tester.pumpAndSettle();
    expect(find.text('Resign this match?'), findsOneWidget);

    // Keep playing closes the dialog and changes nothing.
    await tester.tap(find.text('KEEP PLAYING'));
    await tester.pumpAndSettle();
    expect(controller.isFinished, isFalse);
    expect(find.byType(GameScreen), findsOneWidget);

    await tester.tap(find.text('RESIGN'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('RESIGN'),
      ),
    );
    await tester.pumpAndSettle();

    // Blue (to move) resigned, so Red wins — by resignation.
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('RED WINS!'), findsOneWidget);
    expect(find.text('Red wins · Resignation'), findsOneWidget);
  });

  testWidgets('BACK during an active match opens the leave dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = LocalGameController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );

    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this match?'), findsOneWidget);
    expect(find.text('LEAVE (SAVED)'), findsOneWidget);
    expect(find.text('RESIGN'), findsWidgets);

    await tester.tap(find.text('KEEP PLAYING'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this match?'), findsNothing);
    expect(controller.isFinished, isFalse);
  });

  testWidgets('Result screen names a timeout finish', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResultScreen(
            data: MatchResultData(
              mode: ResultMode.online,
              winner: PlayerId.blue,
              turnsPlayed: 23,
              wallsUsedBlue: 4,
              wallsUsedRed: 6,
              config: BoardConfig(),
              mySide: PlayerId.blue,
              finishReason: FinishReason.timeout,
            ),
            onHome: _noop,
          ),
        ),
      ),
    );
    expect(find.text('Blue wins · Timeout'), findsOneWidget);
  });
}

void _noop() {}
