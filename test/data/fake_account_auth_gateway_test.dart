import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/repositories/auth.dart';

import '../support/fake_account_auth_gateway.dart';

/// Contract tests for the Phase 16.6 fake gateway.
///
/// The fake is the foundation every account-flow test stands on, so
/// its own modelled behaviour is pinned here: if the fake lied, the
/// flow tests built on it would prove nothing.
void main() {
  late FakeAccountAuthGateway gateway;

  setUp(() {
    gateway = FakeAccountAuthGateway();
  });

  Future<AuthState> asGuest() => gateway.signInAnonymously();

  group('guest session', () {
    test('sign-in mints a guest and reuses it while signed in', () async {
      final first = await asGuest();
      expect(first.isGuest, isTrue);
      expect(await gateway.signInAnonymously(), first);
      expect(await gateway.currentUid(), first.uid);
    });

    test('sign-out loses the guest: the next guest uid differs', () async {
      final first = await asGuest();
      await gateway.signOut();
      final second = await asGuest();
      expect(second.uid, isNot(first.uid));
    });
  });

  group('linking', () {
    test('google link preserves the uid and upgrades the kind', () async {
      final guest = await asGuest();
      final result = await gateway.linkWithGoogle();
      final state = (result as AuthSuccess).state;
      expect(state.uid, guest.uid);
      expect(state.isAccount, isTrue);
      expect(state.providerId, AuthProviders.google);
      expect(state.emailVerified, isTrue);
    });

    test('email link preserves the uid and starts unverified', () async {
      final guest = await asGuest();
      final result = await gateway.signUpWithEmail(
        email: 'new@example.com',
        password: 'password-1',
      );
      final state = (result as AuthSuccess).state;
      expect(state.uid, guest.uid);
      expect(state.providerId, AuthProviders.password);
      expect(state.emailVerified, isFalse);
      expect(gateway.emailAccounts['new@example.com']!.uid, guest.uid);
    });

    test('a google link aimed at another account conflicts', () async {
      await asGuest();
      gateway.existingGoogleUid = 'someone-else';
      final result = await gateway.linkWithGoogle();
      expect(
        (result as AuthRejected).failure.error,
        AuthError.credentialInUseByOtherAccount,
      );
      // And the session is untouched: still the same guest.
      expect((await gateway.current()).isGuest, isTrue);
    });

    test('an email link aimed at another account conflicts', () async {
      await asGuest();
      gateway.registerExistingEmail(
        'taken@example.com',
        password: 'password-9',
        uid: 'owner-uid',
      );
      final result = await gateway.linkWithEmail(
        email: 'taken@example.com',
        password: 'password-1',
      );
      expect(
        (result as AuthRejected).failure.error,
        AuthError.credentialInUseByOtherAccount,
      );
    });
  });

  group('email sign-in', () {
    test('unknown address and wrong password reject identically', () async {
      gateway.registerExistingEmail(
        'real@example.com',
        password: 'correct-1',
        uid: 'uid-real',
      );
      final unknown = await gateway.signInWithEmail(
        email: 'ghost@example.com',
        password: 'correct-1',
      );
      final wrong = await gateway.signInWithEmail(
        email: 'real@example.com',
        password: 'incorrect-1',
      );
      expect(unknown, isA<AuthRejected>());
      expect(wrong, isA<AuthRejected>());
      final unknownFailure = (unknown as AuthRejected).failure;
      final wrongFailure = (wrong as AuthRejected).failure;
      expect(unknownFailure.error, AuthError.invalidCredentials);
      // Indistinguishable: same typed error, same (absent) detail.
      expect(wrongFailure.error, unknownFailure.error);
      expect(wrongFailure.detail, unknownFailure.detail);
    });

    test('the right password signs in to the registered uid', () async {
      gateway.registerExistingEmail(
        'real@example.com',
        password: 'correct-1',
        uid: 'uid-real',
        verified: false,
      );
      final result = await gateway.signInWithEmail(
        email: 'real@example.com',
        password: 'correct-1',
      );
      final state = (result as AuthSuccess).state;
      expect(state.uid, 'uid-real');
      expect(state.emailVerified, isFalse);
    });

    test('google sign-in switches to the registered google uid', () async {
      final guest = await asGuest();
      gateway.existingGoogleUid = 'google-owner';
      final result = await gateway.signInWithGoogle();
      final state = (result as AuthSuccess).state;
      expect(state.uid, 'google-owner');
      expect(state.uid, isNot(guest.uid));
    });
  });

  group('verification, reset, deletion freshness', () {
    test('verification sends once the account exists', () async {
      await asGuest();
      await gateway.signUpWithEmail(
        email: 'v@example.com',
        password: 'password-1',
      );
      final result = await gateway.sendVerificationEmail();
      expect(result, isA<AuthSuccess>());
      expect(gateway.verificationEmailsSent, 1);
      gateway.simulateEmailVerified();
      expect((await gateway.current()).emailVerified, isTrue);
    });

    test('password reset reports success for any address', () async {
      final result = await gateway.sendPasswordReset(
        email: 'whoever@example.com',
      );
      expect(result, isA<AuthSuccess>());
      expect(gateway.passwordResetsSent, ['whoever@example.com']);
    });

    test('deletion demands freshness only when configured to', () async {
      await asGuest();
      await gateway.linkWithGoogle();
      gateway.deleteNeedsReauth = true;
      // A link just happened, so the session is fresh.
      expect(await gateway.deleteCurrentUser(), isA<AuthSuccess>());
    });

    test('a stale session must re-authenticate before deletion', () async {
      // A restored session (constructed already signed in) has never
      // freshly authenticated in this run — the stale case.
      final stale = FakeAccountAuthGateway(
        initial: const AuthState.signedIn(
          'uid-d',
          kind: AuthIdentityKind.account,
          providerId: AuthProviders.password,
          email: 'd@example.com',
          emailVerified: true,
        ),
      )..deleteNeedsReauth = true;
      stale.registerExistingEmail(
        'd@example.com',
        password: 'password-1',
        uid: 'uid-d',
      );
      final refused = await stale.deleteCurrentUser();
      expect(
        (refused as AuthRejected).failure.error,
        AuthError.requiresRecentLogin,
      );
      final wrong = await stale.reauthenticateWithPassword(
        password: 'nope-nope',
      );
      expect(wrong, isA<AuthRejected>());
      final ok = await stale.reauthenticateWithPassword(password: 'password-1');
      expect(ok, isA<AuthSuccess>());
      expect(await stale.deleteCurrentUser(), isA<AuthSuccess>());
      expect((await stale.current()).status, AuthStatus.signedOut);
    });
  });

  group('stream', () {
    test('emits the current state on listen and every change after', () async {
      final states = <AuthState>[];
      final sub = gateway.authStateChanges().listen(states.add);
      await gateway.signInAnonymously();
      await gateway.linkWithGoogle();
      await Future<void>.delayed(Duration.zero);
      expect(states.length, 3);
      expect(states.first.status, AuthStatus.signedOut);
      expect(states[1].isGuest, isTrue);
      expect(states[2].isAccount, isTrue);
      await sub.cancel();
    });

    test('subscription counting tracks listen and cancel', () async {
      expect(gateway.activeSubscriptions, 0);
      final sub = gateway.authStateChanges().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(gateway.activeSubscriptions, 1);
      await sub.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(gateway.activeSubscriptions, 0);
    });
  });

  group('scripting', () {
    test('a scripted error wins over the modelled behaviour', () async {
      await asGuest();
      gateway.scriptedErrors['linkWithGoogle'] = AuthError.offline;
      final result = await gateway.linkWithGoogle();
      expect((result as AuthRejected).failure.error, AuthError.offline);
      expect(gateway.calls, contains('linkWithGoogle'));
    });
  });
}
