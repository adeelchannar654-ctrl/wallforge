import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/app/application/account/account_controller.dart';
import 'package:wallforge/app/application/account/identity_guard.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/account/account_screen.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/leaderboard/leaderboard_screen.dart';
import 'package:wallforge/presentation/screens/settings/settings_screen.dart';

import '../support/fake_account_auth_gateway.dart';

/// Phase 16.6, Part H: accounts end to end through the REAL
/// app — guest play, the sign-in journey, the leaderboard
/// prompt flipping with identity, sign-out back to a fresh
/// guest, a mid-match refusal, typed-error surfacing, and the
/// one-subscription lifecycle. The gateway is the fake; no
/// Firebase exists in this environment (the real gateway's
/// totality is covered by its own suite).
class _Rig {
  _Rig() {
    gateway = FakeAccountAuthGateway();
    guard = IdentityGuard();
    controller = AccountController(gateway: gateway, guard: guard);
  }

  late final FakeAccountAuthGateway gateway;
  late final IdentityGuard guard;
  late final AccountController controller;
  bool _disposed = false;

  Future<void> install() async {
    IdentityGuard.install(guard);
    AccountService.install(controller);
    await controller.start();
  }

  void disposeController() {
    if (_disposed) return;
    _disposed = true;
    controller.dispose();
  }

  void uninstall() {
    AccountService.install(null);
    IdentityGuard.install(null);
    disposeController();
  }
}

Future<void> _bootApp(WidgetTester tester, _Rig rig, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(() => FeedbackService.install(null));
  addTearDown(rig.uninstall);
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await rig.install();
  await tester.pumpWidget(const WallforgeApp());
  await tester.pump(const Duration(milliseconds: 1300)); // splash beat
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<void> _openAccountFromSettings(
  WidgetTester tester, {
  String cta = 'SIGN IN',
}) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  expect(find.byType(SettingsScreen), findsOneWidget);
  await tester.scrollUntilVisible(find.text(cta), 300);
  await tester.tap(find.text(cta));
  await tester.pumpAndSettle();
  expect(find.byType(AccountScreen), findsOneWidget);
}

Future<void> _openLeaderboard(WidgetTester tester) async {
  Navigator.of(tester.element(find.byType(HomeScreen)))
      .pushNamed(AppRoutes.leaderboard);
  await tester.pumpAndSettle();
  expect(find.byType(LeaderboardScreen), findsOneWidget);
}

void main() {
  testWidgets('journey: guest → sign in → board unlocks → sign out → guest', (
    tester,
  ) async {
    final rig = _Rig();
    await _bootApp(tester, rig, const Size(390, 844));
    final guestUid = rig.controller.state.uid;
    expect(rig.controller.state.isGuest, isTrue);

    // As a guest, the leaderboard explains the account rule.
    await _openLeaderboard(tester);
    expect(find.textContaining('You are playing as a guest'), findsOneWidget);
    Navigator.of(tester.element(find.byType(LeaderboardScreen))).pop();
    await tester.pumpAndSettle();

    // Sign in with Google (the fake links: same uid).
    await _resize(tester, const Size(800, 600));
    await _openAccountFromSettings(tester);
    await tester.tap(find.text('CONTINUE WITH GOOGLE'));
    await tester.pumpAndSettle();
    expect(rig.controller.state.isAccount, isTrue);
    expect(rig.controller.state.uid, guestUid, reason: 'linking keeps the uid');
    expect(find.text('Signed in with Google'), findsOneWidget);
    expect(find.text('player@gmail.com'), findsOneWidget);

    // Back home; the board no longer prompts.
    Navigator.of(tester.element(find.byType(AccountScreen)))
      ..pop()
      ..pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    await _resize(tester, const Size(1280, 800));
    await _openLeaderboard(tester);
    expect(find.textContaining('You are playing as a guest'), findsNothing);
    Navigator.of(tester.element(find.byType(LeaderboardScreen))).pop();
    await tester.pumpAndSettle();

    // Sign out: a fresh guest, a different uid, the prompt back.
    await _resize(tester, const Size(390, 844));
    await _openAccountFromSettings(tester, cta: 'MANAGE ACCOUNT');
    await tester.scrollUntilVisible(find.text('SIGN OUT'), 300);
    await tester.tap(find.text('SIGN OUT'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('SIGN OUT'),
      ),
    );
    await tester.pumpAndSettle();
    expect(rig.controller.state.isGuest, isTrue);
    expect(rig.controller.state.uid, isNot(guestUid));
    Navigator.of(tester.element(find.byType(AccountScreen)))
      ..pop()
      ..pop();
    await tester.pumpAndSettle();
    await _openLeaderboard(tester);
    expect(find.textContaining('You are playing as a guest'), findsOneWidget);
  });

  testWidgets('sign-in is refused while a match is live, through the app', (
    tester,
  ) async {
    final rig = _Rig();
    await _bootApp(tester, rig, const Size(390, 844));
    // What a live OnlineGameController holds for its lifetime
    // (Part C proves the real controllers set this).
    rig.guard.matchActive = true;
    await _openAccountFromSettings(tester);
    await tester.tap(find.text('CONTINUE WITH GOOGLE'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Finish or leave your current match first'),
      findsOneWidget,
    );
    expect(rig.controller.state.isGuest, isTrue);
    expect(rig.gateway.calls, isNot(contains('linkWithGoogle')));
  });

  testWidgets('a typed gateway failure surfaces as its plain message', (
    tester,
  ) async {
    final rig = _Rig();
    rig.gateway.scriptedErrors['linkWithGoogle'] = AuthError.offline;
    await _bootApp(tester, rig, const Size(390, 844));
    await _openAccountFromSettings(tester);
    await tester.tap(find.text('CONTINUE WITH GOOGLE'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You appear to be offline. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(rig.controller.state.isGuest, isTrue);
  });

  testWidgets('one auth subscription for the app, none after dispose', (
    tester,
  ) async {
    final rig = _Rig();
    await _bootApp(tester, rig, const Size(390, 844));
    expect(rig.gateway.activeSubscriptions, 1);
    // Unmounting the app does not dispose a controller it does
    // not own (the root disposes only its own — Part D); ours
    // keeps its one subscription until we dispose it.
    await tester.pumpWidget(const SizedBox());
    expect(rig.gateway.activeSubscriptions, 1);
    rig.disposeController();
    expect(rig.gateway.activeSubscriptions, 0);
  });

  group('controller-level flows (Part H)', () {
    test('deleting without a password asks for a recent login', () async {
      final gateway = FakeAccountAuthGateway();
      final controller = AccountController(
        gateway: gateway,
        guard: IdentityGuard(),
      );
      addTearDown(controller.dispose);
      await controller.start();
      await controller.createEmailAccount(
        email: 'player@x.io',
        password: 'password-9',
      );
      final result = await controller.deleteAccount();
      expect(result, isA<AuthRejected>());
      expect(
        (result as AuthRejected).failure.error,
        AuthError.requiresRecentLogin,
      );
      expect(gateway.calls, isNot(contains('deleteCurrentUser')));
    });

    test(
      'a second operation while one runs is refused, gateway untouched',
      () async {
        final gateway = _GatedGateway();
        final controller = AccountController(
          gateway: gateway,
          guard: IdentityGuard(),
        );
        addTearDown(controller.dispose);
        await controller.start();
        final first = controller.connectGoogle();
        await Future<void>.delayed(Duration.zero);
        final second = await controller.connectGoogle();
        expect(second, isA<AuthRejected>());
        expect(gateway.googleCalls, 1, reason: 'the gateway saw one attempt');
        gateway.gate.complete();
        expect(await first, isA<AuthSuccess>());
      },
    );

    test('too many requests maps through the controller unchanged', () async {
      final gateway = FakeAccountAuthGateway()
        ..scriptedErrors['signUpWithEmail'] = AuthError.tooManyRequests;
      final controller = AccountController(
        gateway: gateway,
        guard: IdentityGuard(),
      );
      addTearDown(controller.dispose);
      await controller.start();
      final result = await controller.createEmailAccount(
        email: 'player@x.io',
        password: 'password-9',
      );
      expect(result, isA<AuthRejected>());
      expect((result as AuthRejected).failure.error, AuthError.tooManyRequests);
    });
  });
}

/// A fake whose Google flow waits on a completer, so a test can
/// hold an operation open and probe the busy guard.
class _GatedGateway extends FakeAccountAuthGateway {
  final Completer<void> gate = Completer<void>();
  int googleCalls = 0;

  @override
  Future<AuthResult> linkWithGoogle() async {
    googleCalls++;
    await gate.future;
    return super.linkWithGoogle();
  }
}
