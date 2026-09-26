@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/domain/models/action_failure.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontLoader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/InterVariable.ttf'));
    await fontLoader.load();
  });

  testWidgets('mobile valid wall ghost', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final controller = LocalGameController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    controller.setMode(InteractionMode.wall);
    controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_screen_mobile_valid_wall.png'),
    );
  });

  testWidgets('mobile invalid wall ghost and message', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final controller = LocalGameController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    controller.setMode(InteractionMode.wall);
    controller.tapWallSlot(const Cell(row: 8, column: 0), WallOrientation.h);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_screen_mobile_invalid_wall.png'),
    );
  });

  testWidgets('mobile invalid crossing ghost over own wall', (tester) async {
    await _setViewport(tester, const Size(390, 844));
    final controller = LocalGameController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    controller.setMode(InteractionMode.wall);
    controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
    controller.confirm();
    controller.setMode(InteractionMode.wall);
    controller.tapWallSlot(const Cell(row: 0, column: 0), WallOrientation.h);
    controller.confirm();
    controller.setMode(InteractionMode.wall);
    controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.v);
    await tester.pumpAndSettle();

    expect(controller.pendingWallFailure, ActionFailure.wallCrosses);
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_screen_mobile_crossing_own_wall.png'),
    );
  });

  testWidgets('desktop mode toggle visible', (tester) async {
    await _setViewport(tester, const Size(1024, 768));
    final controller = LocalGameController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(controller));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_screen_desktop_toggle.png'),
    );
  });
}

Widget _app(LocalGameController controller) {
  return MaterialApp(home: GameScreen(controller: controller));
}

Future<void> _setViewport(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
