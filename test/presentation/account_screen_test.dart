import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/account/account_controller.dart';
import 'package:wallforge/app/application/account/identity_guard.dart';
import 'package:wallforge/app/application/online/leaderboard_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/core/feedback/feedback_backends.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/core/feedback/feedback_scope.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';
import 'package:wallforge/presentation/screens/account/account_screen.dart';
import 'package:wallforge/presentation/screens/leaderboard/leaderboard_screen.dart';
import 'package:wallforge/presentation/screens/profile/profile_screen.dart';
import 'package:wallforge/presentation/screens/settings/settings_screen.dart';

import '../support/fake_account_auth_gateway.dart';

/// Phase 16.6, Part D: the account surfaces — the Account
/// screen's states, the shared section in Settings and Profile,
/// and the leaderboard's guest prompt.
void main() {
  late FakeAccountAuthGateway gateway;
  late AccountController controller;

  setUp(() {
    gateway = FakeAccountAuthGateway();
    controller = AccountController(gateway: gateway, guard: IdentityGuard());
  });

  tearDown(() {
    AccountService.install(null);
    IdentityGuard.install(null);
    controller.dispose();
  });

  Future<void> pumpAccount(WidgetTester tester) async {
    // A tall viewport: the whole account column is reachable
    // without scrolling in most tests.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await controller.start();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AccountScreen(
          controller: controller,
          nameRepository: InMemoryLeaderboardNameRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AccountScreen as guest', () {
    testWidgets('status, google button, labelled fields, password toggle', (
      tester,
    ) async {
      await pumpAccount(tester);
      expect(find.textContaining('Playing as guest'), findsOneWidget);
      expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      // The visibility toggle carries an accessible label.
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      // Guests are told there is no account to delete.
      expect(
        find.textContaining('Guests have no account to delete'),
        findsOneWidget,
      );
    });

    testWidgets('create mode shows the password policy hint', (tester) async {
      await pumpAccount(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      expect(find.text('At least 8 characters.'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    });

    testWidgets('connecting with Google lands on the signed-in state', (
      tester,
    ) async {
      await pumpAccount(tester);
      final guestUid = controller.state.uid;
      await tester.tap(find.text('CONTINUE WITH GOOGLE'));
      await tester.pumpAndSettle();
      expect(find.text('Signed in with Google'), findsOneWidget);
      expect(find.text('player@gmail.com'), findsOneWidget);
      expect(controller.state.uid, guestUid);
      expect(find.text('SIGN OUT'), findsOneWidget);
    });

    testWidgets('a weak password shows the typed error, not a raw message', (
      tester,
    ) async {
      await pumpAccount(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'new@example.com');
      await tester.enterText(find.byType(TextField).last, 'short');
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();
      expect(
        find.text('That password is too short. Use at least 8 characters.'),
        findsOneWidget,
      );
      expect(controller.state.isGuest, isTrue);
    });

    testWidgets('creating an account shows the verification state', (
      tester,
    ) async {
      await pumpAccount(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'new@example.com');
      await tester.enterText(find.byType(TextField).last, 'password-1');
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();
      expect(find.text('VERIFY YOUR EMAIL'), findsOneWidget);
      expect(find.textContaining('Account created.'), findsOneWidget);
      expect(find.text('RESEND EMAIL'), findsOneWidget);
    });

    testWidgets('forgot password with no email explains itself', (
      tester,
    ) async {
      await pumpAccount(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Enter your email address above first'),
        findsOneWidget,
      );
    });

    testWidgets('forgot password reports the neutral sent message', (
      tester,
    ) async {
      await pumpAccount(tester);
      await tester.enterText(
        find.byType(TextField).first,
        'someone@example.com',
      );
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('If an account exists for that email address'),
        findsOneWidget,
      );
    });
  });

  group('AccountScreen conflicts and sign-out', () {
    testWidgets('conflict offers both choices; keeping the guest works', (
      tester,
    ) async {
      gateway.existingGoogleUid = 'existing-owner';
      await pumpAccount(tester);
      await tester.tap(find.text('CONTINUE WITH GOOGLE'));
      await tester.pumpAndSettle();
      expect(find.text('That sign-in already has an account'), findsOneWidget);
      expect(find.text('SIGN IN TO THAT ACCOUNT'), findsOneWidget);
      await tester.tap(find.text('KEEP THIS GUEST'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Playing as guest'), findsOneWidget);
      expect(controller.state.isGuest, isTrue);
    });

    testWidgets('sign-out warns, then lands on a fresh guest', (tester) async {
      await pumpAccount(tester);
      await tester.tap(find.text('CONTINUE WITH GOOGLE'));
      await tester.pumpAndSettle();
      final accountUid = controller.state.uid;
      await tester.scrollUntilVisible(find.text('SIGN OUT'), 300);
      await tester.tap(find.text('SIGN OUT'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('SIGN OUT'),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.uid, isNot(accountUid));
    });

    testWidgets('delete needs the password, then deletes', (tester) async {
      await pumpAccount(tester);
      await tester.tap(find.text('New here? Create an account'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'del@example.com');
      await tester.enterText(find.byType(TextField).last, 'password-1');
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pumpAndSettle();
      gateway.deleteNeedsReauth = true;

      // 'DELETE ACCOUNT' is both the card title and its button;
      // the button's label is the later one.
      await tester.scrollUntilVisible(find.text('DELETE ACCOUNT').last, 300);
      await tester.tap(find.text('DELETE ACCOUNT').last);
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsOneWidget);
      // The dialog's confirmation field is the third field on screen.
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'password-1',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('DELETE ACCOUNT'),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.state.isGuest, isTrue);
      expect(find.textContaining('Your account was deleted.'), findsOneWidget);
    });
  });

  group('the shared section in Settings and Profile', () {
    Future<void> installStarted() async {
      AccountService.install(controller);
      await controller.start();
    }

    testWidgets('Settings shows the section when a controller is installed', (
      tester,
    ) async {
      await installStarted();
      final feedback = FeedbackController(
        _SilentSound(),
        const PlatformHapticsBackend(),
      );
      addTearDown(feedback.dispose);
      await tester.pumpWidget(
        FeedbackScope(
          controller: feedback,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: SettingsScreen(
              settingsRepository: InMemorySettingsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('ACCOUNT'), 300);
      expect(find.textContaining('Playing as guest'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
    });

    testWidgets('Settings without a controller keeps the old summary', (
      tester,
    ) async {
      final feedback = FeedbackController(
        _SilentSound(),
        const PlatformHapticsBackend(),
      );
      addTearDown(feedback.dispose);
      await tester.pumpWidget(
        FeedbackScope(
          controller: feedback,
          child: MaterialApp(
            theme: AppTheme.dark,
            home: SettingsScreen(
              settingsRepository: InMemorySettingsRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('ACCOUNT'), 300);
      expect(find.text('Account information'), findsOneWidget);
    });

    testWidgets('Profile shows the section when a controller is installed', (
      tester,
    ) async {
      await installStarted();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: ProfileScreen(
            statisticsRepository: InMemoryStatisticsRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Playing as guest'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
    });
  });

  group('the leaderboard guest prompt', () {
    LeaderboardController boardController() => LeaderboardController(
      repository: _EmptyBoardRepo(),
      names: InMemoryLeaderboardNameRepository(),
      myUid: 'uid-me',
      clock: () => DateTime.utc(2026, 10, 28, 12),
    );

    testWidgets('a guest sees the prompt and can dismiss it', (tester) async {
      AccountService.install(controller);
      await controller.start();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LeaderboardScreen(controller: boardController()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('You are playing as a guest'), findsOneWidget);
      expect(find.text('OPEN ACCOUNT'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.textContaining('You are playing as a guest'), findsNothing);
    });

    testWidgets('no installed controller, no prompt', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LeaderboardScreen(controller: boardController()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('You are playing as a guest'), findsNothing);
    });

    testWidgets('the footer states the account rule', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: LeaderboardScreen(controller: boardController()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Only matches played while signed in'),
        findsOneWidget,
      );
    });
  });

  testWidgets('no controller anywhere: the screen says so, calmly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const AccountScreen()),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Accounts are not enabled in this build'),
      findsOneWidget,
    );
  });
}

class _SilentSound implements SoundBackend {
  @override
  Future<void> playEffect(String asset, double volume) async {}

  @override
  Future<void> startMusic(String asset, double volume) async {}

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> setMusicVolume(double volume) async {}

  @override
  void dispose() {}
}

class _EmptyBoardRepo implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> fetchTop(
    int weekStart, {
    int limit = kLeaderboardTopLimit,
  }) async => const [];

  @override
  Future<LeaderboardEntry?> fetchEntry(int weekStart, String uid) async => null;

  @override
  Future<LeaderboardSubmitOutcome> recordResult({
    required String matchId,
    required String opponentUid,
    required bool won,
    required int plies,
    required int matchEndedAtMs,
    required String displayName,
  }) async => LeaderboardSubmitOutcome.counted;

  @override
  Future<bool> renameCurrentEntry({required String displayName}) async => true;
}
