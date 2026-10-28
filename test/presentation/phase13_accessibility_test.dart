import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/app/application/game_interaction.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/app/theme/app_colors.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/modes/game_modes_screen.dart';
import 'package:wallforge/presentation/screens/ai/ai_difficulty_screen.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';
import 'package:wallforge/presentation/screens/tutorial/tutorial_screen.dart';
import 'package:wallforge/presentation/screens/result/result_screen.dart';
import 'package:wallforge/presentation/screens/settings/settings_screen.dart';

/// Phase 13 — accessibility behaviour tests: the player-identity exit
/// criterion as automated checks, semantics coverage, keyboard
/// navigation, UI-scale layout, and the app-root wiring that applies
/// the persisted accessibility settings. Palette/contrast/simulation
/// checks live in `test/app/theme/app_palette_test.dart`.

class _StubAuth implements AuthGateway {
  const _StubAuth();
  @override
  Future<AuthState> signInAnonymously() async => const AuthState.signedIn('u1');
  @override
  Future<AuthState> current() async => const AuthState.signedIn('u1');
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => 'u1';
}

class _FailingAuth implements AuthGateway {
  const _FailingAuth();
  @override
  Future<AuthState> signInAnonymously() async =>
      const AuthState.unavailable('FirebaseAuthException(anonymous-disabled)');
  @override
  Future<AuthState> current() async => const AuthState.signedOut();
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => null;
}

Widget _themed(Widget home) => MaterialApp(theme: AppTheme.dark, home: home);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('player identity — never colour alone (the exit criterion)', () {
    test('pawns carry letter glyphs: B for Blue, R for Red', () {
      expect(BoardPainter.pawnLetter(PlayerId.blue), 'B');
      expect(BoardPainter.pawnLetter(PlayerId.red), 'R');
    });

    testWidgets('local game: banner words, named player rails, and a '
        'board semantics label that names both pawns', (tester) async {
      _setSize(tester, const Size(1024, 768));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_themed(GameScreen(controller: controller)));
      await tester.pump();

      // The turn banner is words, not a colour swatch.
      expect(find.text("BLUE'S TURN"), findsOneWidget);
      // The rails name the players in text next to their colours.
      expect(find.text('PLAYER 1'), findsOneWidget);
      expect(find.text('PLAYER 2'), findsOneWidget);
      // The board's own semantics label names both pawns in text.
      expect(find.bySemanticsLabel(RegExp('Blue pawn at')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Red pawn at')), findsOneWidget);
    });

    testWidgets('result: the winner is named in words and the pawn disc '
        'carries its letter', (tester) async {
      await tester.pumpWidget(
        _themed(
          Scaffold(
            body: ResultScreen(
              data: const MatchResultData(
                mode: ResultMode.local,
                winner: PlayerId.blue,
                turnsPlayed: 17,
                wallsUsedBlue: 1,
                wallsUsedRed: 2,
                config: BoardConfig(),
              ),
              onHome: () {},
              onRematch: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('BLUE WINS!'), findsOneWidget);
      // PlayerPawnDisc renders the letter as real text.
      expect(find.text('B'), findsWidgets);
    });

    testWidgets('online lobby: seats are labelled BLUE and RED in text, '
        'with (YOU) marking the local seat', (tester) async {
      final store = InMemoryFirestoreClient();
      addTearDown(store.closeWatchers);
      final controller = OnlineLobbyController(
        auth: const _StubAuth(),
        rooms: FirestoreRoomRepository(
          client: store,
          userId: () async => 'u1',
          clock: () => DateTime.utc(2026, 10, 28),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _themed(OnlineLobbyScreen(controller: controller)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();

      expect(find.text('BLUE'), findsOneWidget);
      expect(find.text('RED'), findsOneWidget);
      expect(find.text('(YOU)'), findsOneWidget);
    });
  });

  group('error states — plain, non-technical, announced', () {
    test('the sign-in failure message contains no exception detail', () async {
      final store = InMemoryFirestoreClient();
      addTearDown(store.closeWatchers);
      final controller = OnlineLobbyController(
        auth: const _FailingAuth(),
        rooms: FirestoreRoomRepository(
          client: store,
          userId: () async => null,
          clock: () => DateTime.utc(2026, 10, 28),
        ),
      );
      addTearDown(controller.dispose);
      await controller.signIn();
      expect(
        controller.failureMessage,
        'Could not sign in. Online play is unavailable.',
      );
      expect(controller.failureMessage, isNot(contains('Firebase')));
      expect(controller.failureMessage, isNot(contains('Exception')));
    });

    testWidgets('a rejected wall shows icon + text and is a live region', (
      tester,
    ) async {
      _setSize(tester, const Size(1024, 768));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 3, column: 3), WallOrientation.h);
      controller.confirm();
      controller.setMode(InteractionMode.wall);
      // Overlapping the placed wall is rejected by the engine.
      controller.tapWallSlot(const Cell(row: 3, column: 3), WallOrientation.h);
      expect(controller.pendingWallFailure, isNotNull);
      await tester.pumpWidget(_themed(GameScreen(controller: controller)));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsWidgets);
      final node = tester.getSemantics(
        find.byKey(const ValueKey('pending-wall-failure')),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
      expect(
        find.text(
          LocalGameController.failureMessage(controller.pendingWallFailure!),
        ),
        findsOneWidget,
      );
    });
  });

  group('semantics coverage', () {
    testWidgets('settings group titles are headers; the turn banner is '
        'a live region; the result heading is a header', (tester) async {
      final settings = InMemorySettingsRepository();
      await tester.pumpWidget(
        _themed(
          SettingsScreen(
            settingsRepository: settings,
            authGateway: const _StubAuth(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final groupNode = tester.getSemantics(find.text('GAMEPLAY'));
      expect(groupNode.flagsCollection.isHeader, isTrue);

      _setSize(tester, const Size(1024, 768));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_themed(GameScreen(controller: controller)));
      await tester.pump();
      final bannerNode = tester.getSemantics(find.text("BLUE'S TURN"));
      expect(bannerNode.flagsCollection.isLiveRegion, isTrue);

      await tester.pumpWidget(
        _themed(
          Scaffold(
            body: ResultScreen(
              data: const MatchResultData(
                mode: ResultMode.local,
                winner: PlayerId.red,
                turnsPlayed: 9,
                wallsUsedBlue: 0,
                wallsUsedRed: 0,
                config: BoardConfig(),
              ),
              onHome: () {},
              onRematch: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      final headingNode = tester.getSemantics(find.text('RED WINS!'));
      expect(headingNode.flagsCollection.isHeader, isTrue);
    });
  });

  group('keyboard navigation (PRD: where practical)', () {
    testWidgets('Tab reaches the Settings switches and Space toggles '
        'the focused one', (tester) async {
      final settings = InMemorySettingsRepository();
      await tester.pumpWidget(
        _themed(
          SettingsScreen(
            settingsRepository: settings,
            authGateway: const _StubAuth(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = await settings.load();

      var focusedSwitch = false;
      for (var i = 0; i < 20 && !focusedSwitch; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = FocusManager.instance.primaryFocus?.context;
        // The focusable node lives inside the Switch, so the Switch is
        // an ancestor of the focused element.
        focusedSwitch =
            context?.findAncestorWidgetOfExactType<Switch>() != null;
      }
      expect(focusedSwitch, isTrue, reason: 'Tab never reached a Switch');

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      var after = await settings.load();
      if (after == before) {
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        after = await settings.load();
      }
      expect(
        after,
        isNot(before),
        reason: 'keyboard activation did not toggle a setting',
      );
    });

    testWidgets('Tab + Enter activates Game Modes controls and navigates', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const GameModesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      bool arrived() => <Type>[
        AiDifficultyScreen,
        GameScreen,
        OnlineLobbyScreen,
        TutorialScreen,
      ].any((t) => find.byType(t).evaluate().isNotEmpty);

      var sawInteractiveFocus = false;
      var navigated = false;
      for (var i = 0; i < 30 && !navigated; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final context = FocusManager.instance.primaryFocus?.context;
        if (context == null) continue;
        final interactive =
            context.findAncestorWidgetOfExactType<InkWell>() != null ||
            context.findAncestorWidgetOfExactType<ElevatedButton>() != null ||
            context.findAncestorWidgetOfExactType<TextButton>() != null ||
            context.findAncestorWidgetOfExactType<IconButton>() != null;
        if (!interactive) continue;
        sawInteractiveFocus = true;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        navigated = arrived();
      }
      expect(
        sawInteractiveFocus,
        isTrue,
        reason: 'Tab never focused an interactive control',
      );
      expect(navigated, isTrue, reason: 'Enter never activated a control');
    });
  });

  group('UI scale — layout at 150%', () {
    for (final (name, screen) in <(String, Widget)>[
      ('Home', const HomeScreen()),
      ('Game Modes', const GameModesScreen()),
    ]) {
      testWidgets('$name lays out at 1.5x on a small phone', (tester) async {
        _setSize(tester, const Size(320, 568));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: screen,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Settings lays out at 1.5x on a small phone', (tester) async {
      _setSize(tester, const Size(320, 568));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: SettingsScreen(
                settingsRepository: InMemorySettingsRepository(),
                authGateway: const _StubAuth(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the local game lays out at 1.5x on a small phone', (
      tester,
    ) async {
      _setSize(tester, const Size(320, 568));
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: GameScreen(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('app root — persisted accessibility settings apply app-wide', () {
    testWidgets('stored uiScale and colorAssistance take effect in the '
        'real app', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallforge.settings.v1': jsonEncode(<String, dynamic>{
          'uiScale': 1.3,
          'colorAssistance': true,
        }),
      });
      await tester.pumpWidget(const WallforgeApp());
      await tester.pump(const Duration(milliseconds: 1300)); // splash beat
      await tester.pumpAndSettle();

      // The palette followed the stored setting.
      expect(AppColors.bluePlayer, const Color(0xFF0072B2));
      expect(AppColors.redPlayer, const Color(0xFFE69F00));
      // The text scaler followed too.
      final homeContext = tester.element(find.byType(HomeScreen));
      expect(
        MediaQuery.of(homeContext).textScaler.scale(10),
        closeTo(13, 0.01),
      );
      // Restore the shared static palette for other tests.
      AppColors.applyPalette(const AppPalette());
    });
  });
}
