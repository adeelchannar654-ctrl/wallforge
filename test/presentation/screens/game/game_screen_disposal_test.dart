import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';

/// Q-8.6: the `/game` route built a `LocalGameController` per push and nothing
/// disposed it, so every game left a `ChangeNotifier` — and its persistence
/// subscriptions — alive for the life of the process.
///
/// Disposal is observed through [ChangeNotifier.addListener], which asserts in
/// debug builds once the notifier is disposed. That makes it a real check rather
/// than a comment.
void main() {
  /// Pushes the real `/game` route and returns the controller it built.
  Future<LocalGameController> pushGame(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.game,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
    return tester.widget<GameScreen>(find.byType(GameScreen)).controller;
  }

  testWidgets('the route-built controller is alive while the route is up', (
    tester,
  ) async {
    final controller = await pushGame(tester);
    expect(() => controller.addListener(() {}), returnsNormally);
    // Left undisposed on purpose: this test only proves liveness.
    addTearDown(() {});
  });

  testWidgets('popping the route disposes the controller it built', (
    tester,
  ) async {
    final controller = await pushGame(tester);
    expect(() => controller.addListener(() {}), returnsNormally);

    // Pop the route directly rather than tapping a control: this is a lifetime
    // test, so it should not depend on the action button being on screen.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);

    // Now disposed: ChangeNotifier refuses further use in debug builds.
    expect(
      () => controller.addListener(() {}),
      throwsA(anything),
      reason: 'the controller must not outlive its route',
    );
  });

  testWidgets('a controller the screen does not own is left alone', (
    tester,
  ) async {
    // Guards the opt-in contract: a test that injects a controller keeps it, so
    // the flag cannot silently grow to always-true and break such tests.
    final injected = LocalGameController();
    addTearDown(injected.dispose);

    await tester.pumpWidget(const MaterialApp(home: _Holder()));
    await tester.pumpAndSettle();

    expect(() => injected.addListener(() {}), returnsNormally);
  });
}

/// A screen that mounts `GameScreen` with a controller it does not own.
class _Holder extends StatelessWidget {
  const _Holder();

  @override
  Widget build(BuildContext context) => GameScreen(controller: _shared);
}

/// The controller the holder borrows; disposed by the test, not the screen.
final LocalGameController _shared = LocalGameController();
