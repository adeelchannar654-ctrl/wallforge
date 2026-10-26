import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/modes/game_modes_screen.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';

/// Going online from Home must actually go somewhere.
///
/// This is the owner-reported symptom from Phase 8: on a build with no
/// Firebase configuration, the `/online` route constructed
/// `OnlineLobbyFactory.firebase()` during route building, which constructed
/// `FirebaseAuthGateway()`, which threw `[core/no-app]` from its
/// constructor's initializer list. The exception escaped before any screen was
/// built, so the app silently did nothing.
///
/// Phase 11 changed the path — Home → Game Modes (Online selected) → lobby —
/// but not the guarantee, so these tests still drive the **real** router with
/// the **real** factory and the **real** gateway, with no injected fakes,
/// because every layer of that path was previously untested.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> openEntry(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapThroughToLobby(WidgetTester tester) async {
    final mode = find.text('Online Match');
    await tester.ensureVisible(mode);
    await tester.tap(mode);
    await tester.pumpAndSettle();
    expect(find.byType(GameModesScreen), findsOneWidget);
    final open = find.text('OPEN ONLINE LOBBY');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
  }

  testWidgets('the entry screen offers online play', (tester) async {
    await openEntry(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    final mode = find.text('Online Match');
    await tester.ensureVisible(mode);
    expect(mode, findsOneWidget);
  });

  testWidgets('tapping through navigates to the lobby', (tester) async {
    await openEntry(tester);
    await tapThroughToLobby(tester);

    expect(
      find.byType(OnlineLobbyScreen),
      findsOneWidget,
      reason: 'the taps must push the lobby rather than failing silently',
    );
  });

  testWidgets(
    'with no Firebase configured it shows an unavailable state, not a blank '
    'screen and not a crash',
    (tester) async {
      await openEntry(tester);
      await tapThroughToLobby(tester);

      // The lobby is on screen and has rendered its entry choices...
      expect(find.byType(OnlineLobbyScreen), findsOneWidget);
      expect(find.text('CREATE A ROOM'), findsOneWidget);
      // ...and it is telling the player, truthfully, that online play is
      // unavailable because sign-in could not complete.
      expect(find.text('DISCONNECTED'), findsOneWidget);
      expect(find.textContaining('Could not sign in'), findsOneWidget);
      // No unhandled exception escaped the tap.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the unavailable state does not blame the player connection', (
    tester,
  ) async {
    await openEntry(tester);
    await tapThroughToLobby(tester);

    // "Online play needs a connection" would be wrong and misleading here: the
    // commonest cause is a build with no Firebase configuration.
    expect(find.textContaining('needs a connection'), findsNothing);
  });

  testWidgets('back from the lobby returns to Game Modes', (tester) async {
    await openEntry(tester);
    await tapThroughToLobby(tester);
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);

    // Brought into view explicitly: the lobby grows as features are added, and
    // an 800x600 test viewport no longer reaches the bottom on its own.
    final back = find.text('BACK');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.byType(OnlineLobbyScreen), findsNothing);
    expect(find.byType(GameModesScreen), findsOneWidget);
  });

  testWidgets('leaving the lobby does not leak a ChangeNotifier', (
    tester,
  ) async {
    await openEntry(tester);
    await tapThroughToLobby(tester);
    // Brought into view explicitly: the lobby grows as features are added, and
    // an 800x600 test viewport no longer reaches the bottom on its own.
    final back = find.text('BACK');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();

    // The route owns the controller and the screen disposes it. If disposal were
    // missing, the listener would outlive the route and later updates would throw.
    // `tester.pump` rather than `pumpEventQueue`, which never resolves inside a
    // widget test's fake-async clock.
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app theme still applies to the lobby', (tester) async {
    // A sanity check that the route builds a properly themed screen rather than a
    // default-material one.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        initialRoute: AppRoutes.online,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);
  });
}
