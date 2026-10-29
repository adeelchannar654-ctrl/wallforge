import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board.dart';
import 'package:wallforge/presentation/screens/ai/ai_difficulty_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/modes/game_modes_screen.dart';
import 'package:wallforge/presentation/screens/online/online_game_screen.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';
import 'package:wallforge/presentation/screens/profile/profile_screen.dart';
import 'package:wallforge/presentation/screens/result/result_screen.dart';
import 'package:wallforge/presentation/screens/settings/settings_screen.dart';
import 'package:wallforge/presentation/screens/tutorial/tutorial_screen.dart';
import 'package:wallforge/presentation/widgets/app_chrome.dart';

/// Phase 14, part 2: the online game screen's tiers, every non-game
/// screen at the standard viewports, the per-screen wide
/// arrangements (asserted structurally, tablet ≠ desktop), the
/// Splash screen through the real app, and Phase 13's uiScale
/// composed with Phase 14's breakpoints.
const _sizes = <Size>[
  Size(320, 568),
  Size(390, 844),
  Size(768, 1024),
  Size(1440, 900),
  Size(844, 390),
];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.dark, home: home);

class _StubAuth implements AuthGateway {
  const _StubAuth([this.uid = 'uid-test']);
  final String uid;
  @override
  Future<AuthState> signInAnonymously() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> current() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => uid;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('online game screen tiers', () {
    late InMemoryFirestoreClient store;
    setUp(() => store = InMemoryFirestoreClient());
    tearDown(() => store.closeWatchers());

    Future<OnlineGameController> startedBlue() async {
      FirestoreRoomRepository roomsFor(String uid) => FirestoreRoomRepository(
        client: store,
        userId: _StubAuth(uid).currentUid,
      );
      FirestoreMatchRepository matchesFor(String uid) =>
          FirestoreMatchRepository(
            client: store,
            userId: _StubAuth(uid).currentUid,
          );
      final host = roomsFor('uid-blue');
      final created = await host.create(config: const BoardConfig());
      final code = (created as RoomSuccess).room.code;
      final guest = roomsFor('uid-red');
      await guest.join(code);
      await host.setReady(code: code, ready: true);
      await guest.setReady(code: code, ready: true);
      await host.start(code);
      final controller = OnlineGameController(
        rooms: roomsFor('uid-blue'),
        matches: matchesFor('uid-blue'),
        uid: 'uid-blue',
        code: code,
      );
      await controller.connect();
      return controller;
    }

    Future<OnlineGameController> pumpOnline(
      WidgetTester tester,
      Size size,
    ) async {
      _setSize(tester, size);
      final controller = await startedBlue();
      await tester.pumpWidget(_app(OnlineGameScreen(controller: controller)));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$size');
      return controller;
    }

    /// The controller runs a periodic presence timer; like the
    /// screen's own test suite, unmount and dispose it in the body
    /// so no timer is pending when the test ends.
    Future<void> finishOnline(
      WidgetTester tester,
      OnlineGameController controller,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }

    testWidgets('tablet: narrow column capped, no desktop rails', (
      tester,
    ) async {
      final controller = await pumpOnline(tester, const Size(768, 1024));
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 280),
        findsNothing,
      );
      final board = tester.getSize(find.byType(BoardView));
      expect(board.width, lessThanOrEqualTo(680));
      expect(board.width, greaterThan(400));
      await finishOnline(tester, controller);
    });

    testWidgets('desktop: rails; landscape phone: compact rails', (
      tester,
    ) async {
      var controller = await pumpOnline(tester, const Size(1440, 900));
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 280),
        findsNWidgets(2),
      );
      await finishOnline(tester, controller);
      controller = await pumpOnline(tester, const Size(844, 390));
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 200),
        findsNWidgets(2),
      );
      await finishOnline(tester, controller);
    });

    testWidgets('phones render without overflow', (tester) async {
      var controller = await pumpOnline(tester, const Size(320, 568));
      await finishOnline(tester, controller);
      controller = await pumpOnline(tester, const Size(390, 844));
      await finishOnline(tester, controller);
    });
  });

  group('non-game screens: no overflow at any standard size', () {
    final screens = <String, Widget Function()>{
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
    };
    for (final entry in screens.entries) {
      for (final size in _sizes) {
        testWidgets('${entry.key} renders at ${size.width}x${size.height}', (
          tester,
        ) async {
          _setSize(tester, size);
          await tester.pumpWidget(_app(entry.value()));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('wide arrangements are structural, not stretched columns', () {
    testWidgets('Game Modes: phone stacks, tablet pairs, desktop rows', (
      tester,
    ) async {
      Future<void> pumpAt(Size size) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app(const GameModesScreen()));
        await tester.pump();
      }

      await pumpAt(const Size(390, 844));
      final localPhone = tester.getTopLeft(find.text('Local'));
      final aiPhone = tester.getTopLeft(find.text('Vs AI'));
      expect(aiPhone.dy, greaterThan(localPhone.dy + 20));

      await pumpAt(const Size(768, 1024));
      final localTab = tester.getTopLeft(find.text('Local'));
      final aiTab = tester.getTopLeft(find.text('Vs AI'));
      final onlineTab = tester.getTopLeft(find.text('Online'));
      expect(aiTab.dy, closeTo(localTab.dy, 1)); // paired row
      expect(onlineTab.dy, greaterThan(localTab.dy + 20)); // second row

      await pumpAt(const Size(1440, 900));
      final localDesk = tester.getTopLeft(find.text('Local'));
      final aiDesk = tester.getTopLeft(find.text('Vs AI'));
      final onlineDesk = tester.getTopLeft(find.text('Online'));
      expect(aiDesk.dy, closeTo(localDesk.dy, 1));
      expect(onlineDesk.dy, closeTo(localDesk.dy, 1)); // all three in a row
    });

    testWidgets('AI Difficulty: paired rows on tablet and desktop', (
      tester,
    ) async {
      Future<void> pumpAt(Size size) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(const AiDifficultyScreen(config: BoardConfig())),
        );
        await tester.pump();
      }

      await pumpAt(const Size(390, 844));
      final easyPhone = tester.getTopLeft(find.text('Easy'));
      final normalPhone = tester.getTopLeft(find.text('Medium'));
      expect(normalPhone.dy, greaterThan(easyPhone.dy + 20));

      for (final size in [const Size(768, 1024), const Size(1440, 900)]) {
        await pumpAt(size);
        final easy = tester.getTopLeft(find.text('Easy'));
        final normal = tester.getTopLeft(find.text('Medium'));
        expect(normal.dy, closeTo(easy.dy, 1), reason: '$size');
        expect(normal.dx, greaterThan(easy.dx), reason: '$size');
      }
    });

    testWidgets('Settings: two columns on desktop, one capped column '
        'on tablet', (tester) async {
      Future<void> pumpAt(Size size) async {
        _setSize(tester, size);
        await tester.pumpWidget(
          _app(
            SettingsScreen(
              settingsRepository: InMemorySettingsRepository(),
              authGateway: const _StubAuth(),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpAt(const Size(1440, 900));
      final gameplay = tester.getTopLeft(find.text('GAMEPLAY'));
      final accessibility = tester.getTopLeft(find.text('ACCESSIBILITY'));
      expect(accessibility.dy, closeTo(gameplay.dy, 1)); // same row band
      expect(accessibility.dx, greaterThan(gameplay.dx + 300));

      await pumpAt(const Size(768, 1024));
      final gameplayTab = tester.getTopLeft(find.text('GAMEPLAY'));
      final accTab = tester.getTopLeft(find.text('ACCESSIBILITY'));
      expect(accTab.dy, greaterThan(gameplayTab.dy + 100)); // stacked
      expect(accTab.dx, closeTo(gameplayTab.dx, 1));
    });

    testWidgets('Tutorial: board beside the text on desktop, below '
        'it on phone', (tester) async {
      Future<void> pumpAt(Size size) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app(const TutorialScreen()));
        await tester.pump();
      }

      await pumpAt(const Size(390, 844));
      final titlePhone = tester.getTopLeft(find.text('Reach the far row'));
      final boardPhone = tester.getTopLeft(find.byType(BoardView));
      expect(boardPhone.dy, greaterThan(titlePhone.dy + 40));

      await pumpAt(const Size(1440, 900));
      final titleDesk = tester.getTopLeft(find.text('Reach the far row'));
      final boardDesk = tester.getTopLeft(find.byType(BoardView));
      expect(boardDesk.dx, greaterThan(titleDesk.dx + 200)); // beside
      expect(boardDesk.dy, closeTo(titleDesk.dy, 60)); // same band
    });

    testWidgets('Lobby: entry cards side by side on desktop, stacked '
        'on phone', (tester) async {
      final store = InMemoryFirestoreClient();
      addTearDown(store.closeWatchers);
      OnlineLobbyController lobby() => OnlineLobbyController(
        auth: const _StubAuth(),
        rooms: FirestoreRoomRepository(
          client: store,
          userId: const _StubAuth().currentUid,
          clock: () => DateTime.utc(2026, 9, 27, 12),
        ),
      );
      Future<void> pumpAt(Size size) async {
        _setSize(tester, size);
        await tester.pumpWidget(_app(OnlineLobbyScreen(controller: lobby())));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
      }

      await pumpAt(const Size(390, 844));
      final createPhone = tester.getTopLeft(find.text('CREATE A ROOM'));
      final joinPhone = tester.getTopLeft(find.text('JOIN A ROOM'));
      expect(joinPhone.dy, greaterThan(createPhone.dy + 40));

      await pumpAt(const Size(1440, 900));
      final createDesk = tester.getTopLeft(find.text('CREATE A ROOM'));
      final joinDesk = tester.getTopLeft(find.text('JOIN A ROOM'));
      expect(joinDesk.dx, greaterThan(createDesk.dx + 300));
      expect(joinDesk.dy, closeTo(createDesk.dy, 120));

      await pumpAt(const Size(768, 1024));
      expect(tester.takeException(), isNull);
      await pumpAt(const Size(320, 568));
      await pumpAt(const Size(844, 390));
    });

    testWidgets('Home and Result stop stretching on desktop', (tester) async {
      _setSize(tester, const Size(1440, 900));
      await tester.pumpWidget(
        _app(
          HomeScreen(
            settingsRepository: InMemorySettingsRepository(),
            statisticsRepository: InMemoryStatisticsRepository(),
          ),
        ),
      );
      await tester.pump();
      // The statistics card spans the capped measure: far narrower
      // than the 1440 viewport, and centered within it.
      final card = tester.getSize(find.byType(AppCard).first);
      expect(card.width, lessThan(800));
      final cardCenter = tester.getCenter(find.byType(AppCard).first);
      expect(cardCenter.dx, closeTo(1440 / 2, 2));

      await tester.pumpWidget(
        _app(
          const ResultScreen(
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
        ),
      );
      await tester.pump();
      final heading = tester.getCenter(find.text('BLUE WINS!'));
      expect(heading.dx, closeTo(1440 / 2, 2));
    });
  });

  group('Splash through the real app', () {
    for (final size in _sizes) {
      testWidgets('splash renders at ${size.width}x${size.height}', (
        tester,
      ) async {
        _setSize(tester, size);
        await tester.pumpWidget(const WallforgeApp());
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('uiScale x viewport (Phase 13 x Phase 14)', () {
    Future<void> pumpScaledApp(WidgetTester tester, Size size) async {
      _setSize(tester, size);
      // The real app's own seam: persisted settings in
      // SharedPreferences, exactly as Phase 13's app-root test used.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallforge.settings.v1': jsonEncode(<String, dynamic>{'uiScale': 1.5}),
      });
      await tester.pumpWidget(const WallforgeApp());
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$size');
    }

    testWidgets('1.5x scale on the smallest phone reaches Home', (
      tester,
    ) async {
      await pumpScaledApp(tester, const Size(320, 568));
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('1.5x scale inside the tablet tier reaches Home', (
      tester,
    ) async {
      await pumpScaledApp(tester, const Size(768, 1024));
      expect(find.text('PLAY'), findsOneWidget);
    });

    testWidgets('1.5x scale at desktop width reaches Home', (tester) async {
      await pumpScaledApp(tester, const Size(1440, 900));
      expect(find.text('PLAY'), findsOneWidget);
    });
  });
}

void _noop() {}
