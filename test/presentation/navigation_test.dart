import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/application/match_setup.dart';
import 'package:wallforge/app/router/app_router.dart';
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

/// Phase 11's exit criterion, exercised end to end: every major user
/// journey is completable without dead ends.
///
/// The walk uses the **real** router and starts at the app's real entry
/// route. Every screen the phase promises is visited through the same taps
/// a player would make, and every screen is left again the way a player
/// would leave it — a screen that cannot be reached, or cannot be left,
/// fails here even if its own widget tests pass.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> launch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        initialRoute: AppRoutes.root,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
    await tester.pump();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    // Several screens (the game screens above all) have no AppBar back
    // button — they are left through their own controls or the system
    // back, both of which pop the route, which is what this stands in for.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
  }

  testWidgets('the full journey: splash to a game and back, every screen', (
    tester,
  ) async {
    await launch(tester);

    // Entry: splash, then Home.
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    // Home -> Game Modes -> AI difficulty -> a real AI game -> back out.
    await tapText(tester, 'PLAY');
    expect(find.byType(GameModesScreen), findsOneWidget);
    await tapText(tester, 'Vs AI');
    await tapText(tester, 'CHOOSE DIFFICULTY');
    expect(find.byType(AiDifficultyScreen), findsOneWidget);
    await tapText(tester, 'START MATCH');
    expect(find.byType(GameScreen), findsOneWidget);
    await back(tester);
    expect(find.byType(AiDifficultyScreen), findsOneWidget);
    await back(tester);
    expect(find.byType(GameModesScreen), findsOneWidget);

    // Game Modes -> a local game -> back out.
    await tapText(tester, 'Local');
    await tapText(tester, 'START LOCAL MATCH');
    expect(find.byType(GameScreen), findsOneWidget);
    await back(tester);
    expect(find.byType(GameModesScreen), findsOneWidget);

    // Game Modes -> the online lobby (unavailable without Firebase, but
    // reachable and leavable) -> back.
    await tapText(tester, 'Online');
    await tapText(tester, 'OPEN ONLINE LOBBY');
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);
    await tapText(tester, 'BACK');
    expect(find.byType(GameModesScreen), findsOneWidget);
    await back(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Home -> Profile -> back; Home -> Settings -> back.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    await back(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await back(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // Home -> Tutorial -> skip -> Home again (no dead end, offer resolved).
    await tapText(tester, 'START');
    expect(find.byType(TutorialScreen), findsOneWidget);
    await tapText(tester, 'SKIP TUTORIAL');
    expect(find.byType(HomeScreen), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the /result route renders from arguments and can rematch', (
    tester,
  ) async {
    await launch(tester);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    final context = tester.element(find.byType(HomeScreen));
    Navigator.of(context).pushNamed(
      AppRoutes.result,
      arguments: const ResultRouteArgs(
        data: MatchResultData(
          mode: ResultMode.local,
          winner: PlayerId.blue,
          turnsPlayed: 17,
          wallsUsedBlue: 1,
          wallsUsedRed: 2,
          config: BoardConfig(),
        ),
        setup: MatchSetup.local(BoardConfig()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('BLUE WINS!'), findsOneWidget);

    await tapText(tester, 'REMATCH');
    expect(
      find.byType(GameScreen),
      findsOneWidget,
      reason: 'REMATCH from the result route starts a fresh local game',
    );
    // The result route was replaced by the game, so back lands on Home.
    await back(tester);
    expect(find.byType(HomeScreen), findsOneWidget);

    // And HOME on the result route returns to Home as well.
    final homeContext = tester.element(find.byType(HomeScreen));
    Navigator.of(homeContext).pushNamed(
      AppRoutes.result,
      arguments: const ResultRouteArgs(
        data: MatchResultData(
          mode: ResultMode.local,
          winner: PlayerId.red,
          turnsPlayed: 21,
          wallsUsedBlue: 3,
          wallsUsedRed: 3,
          config: BoardConfig(),
        ),
        setup: MatchSetup.local(BoardConfig()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ResultScreen), findsOneWidget);
    await tapText(tester, 'RETURN TO HOME');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the §18 alias routes all resolve to live screens', (
    tester,
  ) async {
    await launch(tester);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(HomeScreen));
    final navigator = Navigator.of(context);

    navigator.pushNamed(AppRoutes.local);
    await tester.pumpAndSettle();
    expect(find.byType(GameModesScreen), findsOneWidget);
    expect(find.text('START LOCAL MATCH'), findsOneWidget);
    await back(tester);

    navigator.pushNamed(AppRoutes.onlineCreate);
    await tester.pumpAndSettle();
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);
    await tapText(tester, 'BACK');

    navigator.pushNamed(AppRoutes.onlineJoin);
    await tester.pumpAndSettle();
    expect(find.byType(OnlineLobbyScreen), findsOneWidget);
    await tapText(tester, 'BACK');

    expect(tester.takeException(), isNull);
  });
}
