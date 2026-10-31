import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/account/account_controller.dart';
import 'package:wallforge/app/application/account/identity_guard.dart';
import 'package:wallforge/domain/repositories/auth.dart';

import '../support/fake_account_auth_gateway.dart';

/// Phase 16.6, Part C: the account controller's flows over the
/// fake gateway — linking, conflicts, sign-out, deletion, the
/// mid-match guard, and the one-subscription lifecycle.
void main() {
  late FakeAccountAuthGateway gateway;
  late IdentityGuard guard;
  late AccountController controller;

  setUp(() {
    gateway = FakeAccountAuthGateway();
    guard = IdentityGuard();
    controller = AccountController(gateway: gateway, guard: guard);
  });

  tearDown(() {
    controller.dispose();
  });

  Future<void> startAsGuest() async {
    await controller.start();
    await Future<void>.delayed(Duration.zero);
  }

  group('start and lifecycle', () {
    test('start creates the guest session, like the app always has', () async {
      await startAsGuest();
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.uid, isNotNull);
    });

    test('exactly one auth subscription, cancelled on dispose', () async {
      // Own instances: this test disposes its controller itself.
      final ownGateway = FakeAccountAuthGateway();
      final own = AccountController(gateway: ownGateway, guard: guard);
      await own.start();
      await own.start(); // second start is a no-op
      expect(ownGateway.activeSubscriptions, 1);
      own.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(ownGateway.activeSubscriptions, 0);
    });

    test('external auth changes flow into the controller state', () async {
      await startAsGuest();
      gateway.simulateEmailVerified();
      await gateway.linkWithGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.isAccount, isTrue);
    });
  });

  group('linking preserves the uid', () {
    test('google link keeps the guest uid', () async {
      await startAsGuest();
      final uid = controller.state.uid;
      final result = await controller.connectGoogle();
      expect(result, isA<AuthSuccess>());
      expect(controller.state.uid, uid);
      expect(controller.state.isAccount, isTrue);
      expect(controller.state.providerId, AuthProviders.google);
    });

    test('email create keeps the guest uid and sends verification', () async {
      await startAsGuest();
      final uid = controller.state.uid;
      final result = await controller.createEmailAccount(
        email: 'new@example.com',
        password: 'password-1',
      );
      expect(result, isA<AuthSuccess>());
      expect(controller.state.uid, uid);
      expect(controller.state.providerId, AuthProviders.password);
      expect(controller.state.emailVerified, isFalse);
      expect(gateway.verificationEmailsSent, 1);
    });

    test('a short password is refused before the gateway is touched', () async {
      await startAsGuest();
      final result = await controller.createEmailAccount(
        email: 'new@example.com',
        password: 'short',
      );
      expect((result as AuthRejected).failure.error, AuthError.weakPassword);
      expect(gateway.calls, isNot(contains('signUpWithEmail')));
      expect(controller.state.isGuest, isTrue);
    });
  });

  group('conflicts are the player\u2019s choice, never auto-merged', () {
    test('google conflict, then sign in to the existing account', () async {
      await startAsGuest();
      final guestUid = controller.state.uid;
      gateway.existingGoogleUid = 'existing-owner';

      final attempt = await controller.connectGoogle();
      expect(attempt, isA<AuthRejected>());
      expect(controller.conflict, isNotNull);
      expect(controller.conflict!.providerId, AuthProviders.google);
      // Nothing changed yet: still the same guest.
      expect(controller.state.uid, guestUid);
      expect(controller.state.isGuest, isTrue);

      final resolved = await controller.resolveConflictUseExisting();
      expect(resolved, isA<AuthSuccess>());
      expect(controller.state.uid, 'existing-owner');
      expect(controller.state.isAccount, isTrue);
      expect(controller.conflict, isNull);
    });

    test('google conflict, then cancel: the guest is untouched', () async {
      await startAsGuest();
      final guestUid = controller.state.uid;
      gateway.existingGoogleUid = 'existing-owner';
      await controller.connectGoogle();
      expect(controller.conflict, isNotNull);

      controller.resolveConflictCancel();
      expect(controller.conflict, isNull);
      expect(controller.state.uid, guestUid);
      expect(controller.state.isGuest, isTrue);
      expect(gateway.calls, isNot(contains('signInWithGoogle')));
    });

    test('email sign-in from a guest surfaces the conflict', () async {
      await startAsGuest();
      gateway.registerExistingEmail(
        'taken@example.com',
        password: 'password-9',
        uid: 'email-owner',
      );
      final attempt = await controller.signInWithEmail(
        email: 'taken@example.com',
        password: 'password-9',
      );
      expect(attempt, isA<AuthRejected>());
      expect(controller.conflict!.email, 'taken@example.com');

      final resolved = await controller.resolveConflictUseExisting();
      expect(resolved, isA<AuthSuccess>());
      expect(controller.state.uid, 'email-owner');
    });

    test('email create over a registered address conflicts too', () async {
      await startAsGuest();
      gateway.registerExistingEmail(
        'taken@example.com',
        password: 'password-9',
        uid: 'email-owner',
      );
      final attempt = await controller.createEmailAccount(
        email: 'taken@example.com',
        password: 'password-9',
      );
      expect(
        (attempt as AuthRejected).failure.error,
        AuthError.emailAlreadyInUse,
      );
      expect(controller.conflict, isNotNull);
      final resolved = await controller.resolveConflictUseExisting();
      expect(resolved, isA<AuthSuccess>());
      expect(controller.state.uid, 'email-owner');
    });
  });

  group('email sign-in failures are neutral', () {
    test('wrong password and unknown address reject identically', () async {
      // No guest session: the direct sign-in path.
      final direct = AccountController(gateway: gateway, guard: guard);
      addTearDown(direct.dispose);
      gateway.registerExistingEmail(
        'real@example.com',
        password: 'correct-1',
        uid: 'uid-real',
      );
      final wrong = await direct.signInWithEmail(
        email: 'real@example.com',
        password: 'incorrect-1',
      );
      final unknown = await direct.signInWithEmail(
        email: 'ghost@example.com',
        password: 'correct-1',
      );
      expect(
        (wrong as AuthRejected).failure.error,
        AuthError.invalidCredentials,
      );
      expect(
        (unknown as AuthRejected).failure.error,
        AuthError.invalidCredentials,
      );
      expect(direct.conflict, isNull);
    });
  });

  group('sign-out returns a fresh guest', () {
    test('from an account: a new guest uid, the account left behind', () async {
      await startAsGuest();
      await controller.connectGoogle();
      final accountUid = controller.state.uid;

      final result = await controller.signOutToFreshGuest();
      expect(result, isA<AuthSuccess>());
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.uid, isNot(accountUid));
    });

    test('from a guest: the old guest identity is gone', () async {
      await startAsGuest();
      final guestUid = controller.state.uid;
      await controller.signOutToFreshGuest();
      expect(controller.state.isGuest, isTrue);
      expect(controller.state.uid, isNot(guestUid));
    });
  });

  group('the mid-match guard refuses every identity change', () {
    test('with a live match, nothing reaches the gateway', () async {
      await startAsGuest();
      final callsBefore = List<String>.of(gateway.calls);
      guard.matchActive = true;

      for (final attempt in <Future<AuthResult> Function()>[
        controller.connectGoogle,
        () => controller.createEmailAccount(
          email: 'a@b.c',
          password: 'password-1',
        ),
        () =>
            controller.signInWithEmail(email: 'a@b.c', password: 'password-1'),
        controller.signOutToFreshGuest,
        () => controller.deleteAccount(),
      ]) {
        final result = await attempt();
        expect(
          (result as AuthRejected).failure.error,
          AuthError.blockedByLiveMatch,
        );
      }
      expect(gateway.calls, callsBefore);
      expect(controller.state.isGuest, isTrue);

      guard.matchActive = false;
      expect(await controller.connectGoogle(), isA<AuthSuccess>());
    });

    test('an open room blocks too', () async {
      await startAsGuest();
      guard.roomOpen = true;
      final result = await controller.signOutToFreshGuest();
      expect(
        (result as AuthRejected).failure.error,
        AuthError.blockedByLiveMatch,
      );
      expect(controller.state.isGuest, isTrue);
    });
  });

  group('deletion', () {
    test('email account: re-auth, profile first, then the user', () async {
      // A restored session (constructed already signed in) is stale
      // by construction: it never freshly authenticated in this run.
      final direct = FakeAccountAuthGateway(
        initial: const AuthState.signedIn(
          'uid-d',
          kind: AuthIdentityKind.account,
          providerId: AuthProviders.password,
          email: 'd@example.com',
          emailVerified: true,
        ),
      )..deleteNeedsReauth = true;
      direct.registerExistingEmail(
        'd@example.com',
        password: 'password-1',
        uid: 'uid-d',
      );
      var profileDeletedAtCallCount = -1;
      final staleController = AccountController(
        gateway: direct,
        guard: guard,
        deleteCloudProfile: () async {
          profileDeletedAtCallCount = direct.calls.length;
          return true;
        },
      );
      addTearDown(staleController.dispose);
      await staleController.start();

      // No password yet: the UI's cue to ask.
      final needsPassword = await staleController.deleteAccount();
      expect(
        (needsPassword as AuthRejected).failure.error,
        AuthError.requiresRecentLogin,
      );
      // Wrong password: refused, account intact.
      final wrong = await staleController.deleteAccount(password: 'nope-nope');
      expect(
        (wrong as AuthRejected).failure.error,
        AuthError.invalidCredentials,
      );
      expect(staleController.state.uid, 'uid-d');
      // Right password: re-auth first, profile second, identity last.
      final done = await staleController.deleteAccount(password: 'password-1');
      expect(done, isA<AuthSuccess>());
      expect(profileDeletedAtCallCount, greaterThan(0));
      expect(
        direct.calls.indexOf('deleteCurrentUser'),
        greaterThanOrEqualTo(profileDeletedAtCallCount),
      );
      expect(
        direct.calls.indexOf('deleteCurrentUser'),
        greaterThan(direct.calls.lastIndexOf('reauthenticateWithPassword')),
      );
      // And the player lands on a fresh guest.
      expect(staleController.state.isGuest, isTrue);
    });

    test('a failed profile deletion aborts the account deletion', () async {
      final aborting = AccountController(
        gateway: gateway,
        guard: guard,
        deleteCloudProfile: () async => false,
      );
      addTearDown(aborting.dispose);
      await aborting.start();
      await aborting.connectGoogle();
      final result = await aborting.deleteAccount();
      expect(result, isA<AuthRejected>());
      expect(aborting.state.isAccount, isTrue);
      expect(gateway.calls, isNot(contains('deleteCurrentUser')));
    });

    test('google account deletes after a google re-auth', () async {
      await startAsGuest();
      await controller.connectGoogle();
      final result = await controller.deleteAccount();
      expect(result, isA<AuthSuccess>());
      expect(gateway.calls, contains('reauthenticateWithGoogle'));
      expect(controller.state.isGuest, isTrue);
    });
  });

  group('local data policy (D16.6-6)', () {
    test(
      'identity changes never clear progress; the explicit action does',
      () async {
        var clears = 0;
        final withProgress = AccountController(
          gateway: gateway,
          guard: guard,
          clearLocalProgress: () async {
            clears += 1;
          },
        );
        addTearDown(withProgress.dispose);
        await withProgress.start();
        await withProgress.connectGoogle();
        await withProgress.signOutToFreshGuest();
        expect(clears, 0);
        await withProgress.clearDeviceProgress();
        expect(clears, 1);
      },
    );

    test('the sign-in hook fires for accounts only', () async {
      final seen = <AuthState>[];
      final hooked = AccountController(
        gateway: gateway,
        guard: guard,
        onAccountSignedIn: (state) async {
          seen.add(state);
        },
      );
      addTearDown(hooked.dispose);
      await hooked.start();
      expect(seen, isEmpty); // a guest start is not an account sign-in
      await hooked.connectGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 1);
      expect(seen.single.isAccount, isTrue);
    });
  });

  group('password reset and verification resend', () {
    test('reset passes through and reports success', () async {
      await startAsGuest();
      final result = await controller.sendPasswordReset(
        email: 'anyone@example.com',
      );
      expect(result, isA<AuthSuccess>());
      expect(gateway.passwordResetsSent, ['anyone@example.com']);
    });

    test('resend counts a verification email', () async {
      await startAsGuest();
      await controller.createEmailAccount(
        email: 'v@example.com',
        password: 'password-1',
      );
      final before = gateway.verificationEmailsSent;
      expect(await controller.resendVerification(), isA<AuthSuccess>());
      expect(gateway.verificationEmailsSent, before + 1);
      gateway.simulateEmailVerified();
      final refreshed = await controller.refreshAccount();
      expect(refreshed, isA<AuthSuccess>());
      expect(controller.state.emailVerified, isTrue);
    });
  });
}
