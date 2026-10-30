// Phase 16 C.7: completes the responsive matrix and samples the
// accessibility settings matrix.
//
// Phase 14 rendered the non-game screens at five viewports
// (320x568, 390x844, 768x1024, 1440x900, 844x390) and the game
// screens across the breakpoint tiers. This file adds the sixth
// viewport from the Phase 16 brief (1024x768, landscape tablet) for
// every non-game screen plus Splash and the Online Lobby, and then
// renders the full app under each accessibility setting (UI scale
// 1.5, high contrast, colour assistance, reduced motion) at phone
// size, navigating to the most layout-sensitive screens. A full
// 13 x 6 x 5 grid would be ~390 renders; the sampling is recorded
// in the Phase 16 ledger.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/app/application/match_setup.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/ai/ai_difficulty_screen.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/modes/game_modes_screen.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';
import 'package:wallforge/presentation/screens/profile/profile_screen.dart';
import 'package:wallforge/presentation/screens/result/result_screen.dart';
import 'package:wallforge/presentation/screens/settings/settings_screen.dart';
import 'package:wallforge/presentation/screens/splash/splash_screen.dart';
import 'package:wallforge/presentation/screens/tutorial/tutorial_screen.dart';
import 'package:wallforge/app/application/local_game_controller.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.dark, home: home);

class _StubAuth implements AuthGateway {
  const _StubAuth();
  final String uid = 'uid-test';
  @override
  Future<AuthState> signInAnonymously() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> current() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() =>
      Stream<AuthState>.value(AuthState.signedIn(uid));
  @override
  Future<String?> currentUid() async => uid;
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

OnlineLobbyScreen _lobby() {
  final store = InMemoryFirestoreClient();
  const auth = _StubAuth();
  final controller = OnlineLobbyController(
    auth: auth,
    rooms: FirestoreRoomRepository(
      client: store,
      userId: auth.currentUid,
      clock: () => DateTime.utc(2026, 10, 30),
    ),
  );
  return OnlineLobbyScreen(controller: controller);
}

void main() {
  group('sixth viewport 1024x768 (landscape tablet)', () {
    final screens = <String, Widget Function()>{
      'Splash': () => const SplashScreen(displayDuration: Duration(days: 1)),
      'Home': () => HomeScreen(
        settingsRepository: InMemorySettingsRepository(),
        statisticsRepository: InMemoryStatisticsRepository(),
      ),
      'Game Modes': () => const GameModesScreen(),
      'AI Difficulty': () => const AiDifficultyScreen(config: BoardConfig()),
      'Tutorial': () => const TutorialScreen(),
      'Profile': () => ProfileScreen(
        statisticsRepository: InMemoryStatisticsRepository(),
        authGateway: const _StubAuth(),
      ),
      'Settings': () => SettingsScreen(
        settingsRepository: InMemorySettingsRepository(),
        authGateway: const _StubAuth(),
      ),
      'Result': () => const ResultScreen(
        data: MatchResultData(
          mode: ResultMode.local,
          winner: PlayerId.blue,
          turnsPlayed: 21,
          wallsUsedBlue: 7,
          wallsUsedRed: 9,
          config: BoardConfig(),
        ),
        onRematch: _noop,
        onHome: _noop,
      ),
      'Online Lobby': _lobby,
      'Local Game': () => GameScreen(controller: LocalGameController()),
    };
    for (final entry in screens.entries) {
      testWidgets('${entry.key} renders without overflow', (tester) async {
        _setSize(tester, const Size(1024, 768));
        await tester.pumpWidget(_app(entry.value()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: entry.key);
      });
    }
  });

  group('accessibility settings matrix through the real app', () {
    final variants = <String, Map<String, dynamic>>{
      'UI scale 1.5': {'uiScale': 1.5},
      'high contrast': {'highContrast': true},
      'colour assistance': {'colorAssistance': true},
      'reduced motion': {'reducedMotion': true},
    };
    for (final variant in variants.entries) {
      testWidgets('${variant.key}: Home, Settings and a game render', (
        tester,
      ) async {
        _setSize(tester, const Size(390, 844));
        addTearDown(() => FeedbackService.install(null));
        SharedPreferences.setMockInitialValues(<String, Object>{
          'wallforge.settings.v1': jsonEncode(variant.value),
        });
        await tester.pumpWidget(const WallforgeApp());
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Home');

        final homeContext = tester.element(find.byType(HomeScreen));
        Navigator.of(homeContext).pushNamed(AppRoutes.settings);
        await tester.pumpAndSettle();
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Settings');
        Navigator.of(homeContext).pop();

        Navigator.of(homeContext)
            .pushNamed(AppRoutes.game, arguments: const MatchSetup());
        await tester.pumpAndSettle();
        expect(find.byType(GameScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Game');
      });
    }
  });
}

void _noop() {}
