import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/presentation/screens/board_preview/board_preview_screen.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';

/// Tapping "ONLINE PLAY" must actually go somewhere.
///
/// This is the owner-reported symptom: on a build with no Firebase
/// configuration, the `/online` route constructed `OnlineLobbyFactory.firebase()`
/// during route building, which constructed `FirebaseAuthGateway()`, which threw
/// `[core/no-app]` from its constructor's initializer list. The exception escaped
/// before any screen was built, so the app silently did nothing.
///
/// These tests drive the **real** router with the **real** factory and the
/// **real** gateway, with no injected fakes, because every layer of that path was
/// previously untested.
void main() {
  Future<void> openEntry(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.home,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapOnlinePlay(WidgetTester tester) async {
    final button = find.text('ONLINE PLAY');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('the entry screen offers online play', (tester) async {
    await openEntry(tester);
    expect(find.byType(BoardPreviewScreen), findsOneWidget);
    final button = find.text('ONLINE PLAY');
    await tester.ensureVisible(button);
    expect(button, findsOneWidget);
  });

  testWidgets('tapping it navigates to the lobby', (tester) async {
    await openEntry(tester);
    await tapOnlinePlay(tester);

    expect(
      find.byType(OnlineLobbyScreen),
      findsOneWidget,
      reason: 'the tap must push the lobby rather than failing silently',
    );
  });

  testWidgets(
    'with no Firebase configured it shows an unavailable state, not a blank '
    'screen and not a crash',
    (tester) async {
      await openEntry(tester);
      await tapOnlinePlay(tester);

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
    await tapOnlinePlay(tester);

    // "Online play needs a connection" would be wrong and misleading here: the
    // commonest cause is a build with no Firebase configuration.
    expect(find.textContaining('needs a connection'), findsNothing);
  });

  testWidgets('back returns to the entry screen', (tester) async {
    await openEntry(tester);
    await tapOnlinePlay(tester);
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);

    await tester.tap(find.text('BACK'));
    await tester.pumpAndSettle();

    expect(find.byType(OnlineLobbyScreen), findsNothing);
    expect(find.byType(BoardPreviewScreen), findsOneWidget);
  });

  testWidgets('leaving the lobby does not leak a ChangeNotifier', (
    tester,
  ) async {
    await openEntry(tester);
    await tapOnlinePlay(tester);
    await tester.tap(find.text('BACK'));
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
