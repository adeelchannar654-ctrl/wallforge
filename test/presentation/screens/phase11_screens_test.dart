import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board.dart';
import 'package:wallforge/presentation/screens/ai/ai_difficulty_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/modes/game_modes_screen.dart';
import 'package:wallforge/presentation/screens/profile/profile_screen.dart';
import 'package:wallforge/presentation/screens/result/result_screen.dart';
import 'package:wallforge/presentation/screens/settings/settings_screen.dart';
import 'package:wallforge/presentation/screens/splash/splash_screen.dart';
import 'package:wallforge/presentation/screens/tutorial/tutorial_screen.dart';

/// Phase 11's screens, one by one: each renders, its key actions work, and
/// none of them overflow at the four sizes the phase promises support for
/// (design ledger §13s): 320×568, 390×844, 768×1024, 1440×900.
class _FakeAuthGateway implements AuthGateway {
  AuthState state = const AuthState.signedIn('uid-test');
  bool signedOut = false;

  @override
  Future<AuthState> signInAnonymously() async => state;

  @override
  Future<AuthState> current() async => state;

  @override
  Future<AuthState> signOut() async {
    signedOut = true;
    state = const AuthState.signedOut();
    return state;
  }

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Future<String?> currentUid() async => state.uid;
}

const _sizes = <Size>[
  Size(320, 568),
  Size(390, 844),
  Size(768, 1024),
  Size(1440, 900),
];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.dark, home: home);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('rendering at every supported size', () {
    for (final size in _sizes) {
      testWidgets('Home renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(
            HomeScreen(
              settingsRepository: InMemorySettingsRepository(),
              statisticsRepository: InMemoryStatisticsRepository(),
              unfinishedMatchRepository: InMemoryUnfinishedMatchRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Game Modes renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app(const GameModesScreen()));
        await tester.pumpAndSettle();
        expect(find.text('Two players on one device.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AI difficulty renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(
            AiDifficultyScreen(
              config: const BoardConfig(),
              settingsRepository: InMemorySettingsRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Expert'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Result renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(
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
        await tester.pumpAndSettle();
        expect(find.text('BLUE WINS!'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Profile renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(
            ProfileScreen(
              statisticsRepository: InMemoryStatisticsRepository(),
              authGateway: _FakeAuthGateway(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('No matches played yet.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Settings renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(
            SettingsScreen(
              settingsRepository: InMemorySettingsRepository(),
              authGateway: _FakeAuthGateway(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Confirm wall placement'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Tutorial renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(
            TutorialScreen(settingsRepository: InMemorySettingsRepository()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Reach the far row'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Splash', () {
    testWidgets('shows the brand, then replaces itself with Home', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          initialRoute: AppRoutes.root,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Forge your path. Block your rival.'), findsOneWidget);
      // Nothing the Stitch mock invented may appear (ledger §13s).
      expect(find.textContaining('FPS'), findsNothing);
      expect(find.textContaining('SHADERS'), findsNothing);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('a tap skips the wait', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          initialRoute: AppRoutes.root,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(SplashScreen));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Home', () {
    testWidgets('statistics card appears only when matches exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          HomeScreen(
            settingsRepository: InMemorySettingsRepository(),
            statisticsRepository: InMemoryStatisticsRepository(
              const MatchStatistics(
                matchesPlayed: 4,
                humanWins: 3,
                humanLosses: 1,
              ),
            ),
            unfinishedMatchRepository: InMemoryUnfinishedMatchRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('YOUR MATCHES'), findsOneWidget);
      expect(find.text('4 played · 3 won · 1 lost'), findsOneWidget);
    });
  });

  group('Game Modes', () {
    testWidgets('selecting a mode changes the action offered', (tester) async {
      await tester.pumpWidget(_app(const GameModesScreen()));
      await tester.pumpAndSettle();
      expect(find.text('START LOCAL MATCH'), findsOneWidget);
      await tester.tap(find.text('Vs AI'));
      await tester.pumpAndSettle();
      expect(find.text('CHOOSE DIFFICULTY'), findsOneWidget);
      await tester.tap(find.text('Online'));
      await tester.pumpAndSettle();
      expect(find.text('OPEN ONLINE LOBBY'), findsOneWidget);
    });
  });

  group('AI difficulty', () {
    testWidgets('starting saves the chosen difficulty and navigates', (
      tester,
    ) async {
      final settings = InMemorySettingsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: AiDifficultyScreen(
            config: const BoardConfig(),
            settingsRepository: settings,
          ),
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('GAME SCREEN')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expert'));
      await tester.pumpAndSettle();
      final start = find.text('START MATCH');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.text('GAME SCREEN'), findsOneWidget);
      expect((await settings.load()).aiDifficulty, 'expert');
    });

    testWidgets('descriptions are the honest ones from the AI itself', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          AiDifficultyScreen(
            config: const BoardConfig(),
            settingsRepository: InMemorySettingsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Looks three moves ahead over the widest set of choices.'),
        findsOneWidget,
      );
      expect(find.textContaining('perfect'), findsNothing);
    });
  });

  group('Result', () {
    testWidgets('a lost AI match reads "Match complete." with its difficulty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ResultScreen(
              data: const MatchResultData(
                mode: ResultMode.versusAi,
                winner: PlayerId.red,
                turnsPlayed: 23,
                wallsUsedBlue: 4,
                wallsUsedRed: 6,
                config: BoardConfig(),
                mySide: PlayerId.blue,
                aiDifficulty: AiDifficulty.hard,
              ),
              onHome: () {},
              onRematch: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Match complete.'), findsOneWidget);
      expect(find.text('Red wins'), findsOneWidget);
      expect(find.text('Difficulty: Hard'), findsOneWidget);
    });

    testWidgets('an abandoned online match shows room and note, no winner', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ResultScreen(
              data: const MatchResultData(
                mode: ResultMode.online,
                winner: null,
                turnsPlayed: 12,
                wallsUsedBlue: 2,
                wallsUsedRed: 2,
                config: BoardConfig(),
                mySide: PlayerId.blue,
                roomCode: 'ABC234',
                note: 'You claimed this match as abandoned.',
              ),
              onHome: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Match complete.'), findsOneWidget);
      expect(find.text('Abandoned'), findsOneWidget);
      expect(
        find.text('Room ABC234 · You claimed this match as abandoned.'),
        findsOneWidget,
      );
    });
  });

  group('Profile', () {
    testWidgets('renders recorded statistics and the online caveat', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ProfileScreen(
            statisticsRepository: InMemoryStatisticsRepository(
              const MatchStatistics(
                matchesPlayed: 4,
                humanWins: 3,
                humanLosses: 1,
                byDifficulty: <String, Bucket>{
                  'local': Bucket(played: 3, wins: 2, losses: 1),
                  'hard': Bucket(played: 1, wins: 1),
                },
                byBoardSize: <String, Bucket>{
                  '9': Bucket(played: 4, wins: 3, losses: 1),
                },
              ),
            ),
            authGateway: _FakeAuthGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Matches played'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('Local pass-and-play'), findsOneWidget);
      expect(find.text('Vs AI — Hard'), findsOneWidget);
      expect(find.text('9×9 board'), findsOneWidget);
      expect(
        find.textContaining('Online matches are not recorded'),
        findsOneWidget,
      );
    });
  });

  group('Settings', () {
    testWidgets('the gameplay toggles round-trip through persistence', (
      tester,
    ) async {
      final settings = InMemorySettingsRepository();
      await tester.pumpWidget(
        _app(
          SettingsScreen(
            settingsRepository: settings,
            authGateway: _FakeAuthGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The rows are label + Switch pairs; find each switch by its label.
      Finder switchFor(String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Row))
            .first,
        matching: find.byType(Switch),
      );

      final confirm = switchFor('Confirm wall placement');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect((await settings.load()).confirmWallPlacement, isFalse);

      final assist = switchFor('Movement assistance');
      await tester.ensureVisible(assist);
      await tester.tap(assist);
      await tester.pumpAndSettle();
      expect((await settings.load()).movementAssistance, isTrue);
    });

    testWidgets('unbuilt features are visibly inert, never fake', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SettingsScreen(
            settingsRepository: InMemorySettingsRepository(),
            authGateway: _FakeAuthGateway(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Phase 12 made Audio, Haptics and Reduced motion real, so the
      // only "not yet available" rows left are Phase 13's (Color
      // assistance, High contrast, UI scale) — the Phase 12 wording is
      // gone entirely.
      expect(
        find.text('Not yet available — arrives with Phase 12.'),
        findsNothing,
      );
      expect(
        find.text('Not yet available — arrives with Phase 13.'),
        findsWidgets,
      );
      // Exactly the three Phase 13 switches are disabled; every other
      // switch on the screen is live.
      final disabled = find.byWidgetPredicate(
        (w) => w is Switch && w.onChanged == null,
      );
      expect(disabled, findsNWidgets(3));
      // And the account section tells the truth about anonymous play.
      expect(
        find.textContaining('Signed in anonymously (Guest).'),
        findsOneWidget,
      );
    });

    testWidgets('sign out uses the real gateway', (tester) async {
      final auth = _FakeAuthGateway();
      await tester.pumpWidget(
        _app(
          SettingsScreen(
            settingsRepository: InMemorySettingsRepository(),
            authGateway: auth,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final signOut = find.text('SIGN OUT');
      await tester.ensureVisible(signOut);
      await tester.tap(signOut);
      await tester.pumpAndSettle();
      expect(auth.signedOut, isTrue);
      expect(find.textContaining('Not signed in.'), findsOneWidget);
    });
  });

  group('Tutorial', () {
    Future<void> tapBoard(WidgetTester tester, Offset local) async {
      final gestureFinder = find.descendant(
        of: find.byType(BoardView),
        matching: find.byType(GestureDetector),
      );
      await tester.tapAt(tester.getTopLeft(gestureFinder) + local);
      await tester.pumpAndSettle();
    }

    testWidgets('walks the steps; acting on the board advances them', (
      tester,
    ) async {
      final settings = InMemorySettingsRepository();
      await tester.pumpWidget(
        _app(TutorialScreen(settingsRepository: settings)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('Reach the far row'), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(
        find.text('Make the move to continue.'),
        findsOneWidget,
        reason: 'an interactive step explains what it waits for',
      );
      final nextButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('NEXT'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        nextButton.onPressed,
        isNull,
        reason: 'an interactive step cannot be skipped past',
      );

      // The move step starts Blue at model (3,2) on the 5x5 teaching
      // board; step north toward the goal row. Completing the action
      // enables NEXT — the step never advances on its own.
      final boardSize = tester.getSize(find.byType(BoardView)).width;
      final geometry = BoardGeometry(boardSize: 5, areaSize: boardSize);
      await tapBoard(
        tester,
        geometry.cellCenterFromModel(const Cell(row: 2, column: 2)),
      );
      final enabledNext = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('NEXT'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(enabledNext.onPressed, isNotNull);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Place a wall'), findsOneWidget);

      // The wall step starts in wall mode: tap the horizontal groove
      // directly below Blue's pawn on screen, then confirm.
      await tapBoard(
        tester,
        Offset(
          geometry.cellCenter(0, 2).dx,
          geometry.padding + geometry.cellSize,
        ),
      );
      final confirm = find.text('CONFIRM');
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Step 4 of 5'), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('Step 5 of 5'), findsOneWidget);
      await tester.tap(find.text('FINISH'));
      await tester.pumpAndSettle();
      expect((await settings.load()).tutorialCompleted, isTrue);
      expect(find.byType(TutorialScreen), findsNothing);
    });

    testWidgets('skipping also resolves the first-run offer', (tester) async {
      final settings = InMemorySettingsRepository();
      await tester.pumpWidget(
        _app(TutorialScreen(settingsRepository: settings)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('SKIP TUTORIAL'));
      await tester.pumpAndSettle();
      expect((await settings.load()).tutorialCompleted, isTrue);
      expect(find.byType(TutorialScreen), findsNothing);
    });
  });
}
