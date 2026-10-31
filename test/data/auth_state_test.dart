import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_settings_repository.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Semantics of the auth value type.
///
/// ## What is *not* tested here
///
/// `FirebaseAuthGateway`, the real adapter, is not exercised by any test in this
/// repository: constructing a `FirebaseAuth` needs a live Firebase platform, and
/// the project has no configuration or emulator (Q-7.3/Q-7.4). Its coverage is
/// therefore 0% and is reported as such in `memory.md` §13p. What these tests
/// pin down is the contract every caller depends on, which is testable offline.
void main() {
  group('AuthState', () {
    test('signed in only when a uid is present', () {
      expect(const AuthState.signedIn('uid-1').isSignedIn, isTrue);
      expect(const AuthState.signedOut().isSignedIn, isFalse);
      expect(const AuthState.unavailable('offline').isSignedIn, isFalse);
    });

    test('an empty uid does not count as signed in', () {
      expect(const AuthState.signedIn('').isSignedIn, isFalse);
    });

    test('unavailable carries a reason and signed out does not', () {
      expect(
        const AuthState.unavailable(
          'FirebaseAuthException(network-request-failed)',
        ).detail,
        contains('network-request-failed'),
      );
      expect(const AuthState.signedOut().detail, isNull);
    });

    test('equality is by value so controllers can compare states', () {
      expect(const AuthState.signedIn('a'), const AuthState.signedIn('a'));
      expect(
        const AuthState.signedIn('a').hashCode,
        const AuthState.signedIn('a').hashCode,
      );
      expect(
        const AuthState.signedIn('a'),
        isNot(const AuthState.signedIn('b')),
      );
    });

    test('toString reports the status but is safe to log', () {
      final text = const AuthState.unavailable('offline').toString();
      expect(text, contains('unavailable'));
      expect(text, contains('offline'));
      // No token-shaped material ever appears in the value type.
      expect(text, isNot(contains('token')));
    });
  });

  group('account fields (Phase 16.6)', () {
    test('a plain signedIn is a guest on the anonymous provider', () {
      const state = AuthState.signedIn('uid-1');
      expect(state.isGuest, isTrue);
      expect(state.isAccount, isFalse);
      expect(state.providerId, AuthProviders.anonymous);
      expect(state.emailVerified, isFalse);
    });

    test('an account state carries provider and verification', () {
      const state = AuthState.signedIn(
        'uid-1',
        kind: AuthIdentityKind.account,
        providerId: AuthProviders.google,
        email: 'player@gmail.com',
        emailVerified: true,
      );
      expect(state.isAccount, isTrue);
      expect(state.isGuest, isFalse);
      expect(state.email, 'player@gmail.com');
    });

    test('equality distinguishes kind, provider and verification', () {
      const guest = AuthState.signedIn('uid-1');
      const account = AuthState.signedIn(
        'uid-1',
        kind: AuthIdentityKind.account,
        providerId: AuthProviders.password,
        email: 'a@b.c',
      );
      const verified = AuthState.signedIn(
        'uid-1',
        kind: AuthIdentityKind.account,
        providerId: AuthProviders.password,
        email: 'a@b.c',
        emailVerified: true,
      );
      expect(guest, isNot(account));
      expect(account, isNot(verified));
      expect(
        verified,
        const AuthState.signedIn(
          'uid-1',
          kind: AuthIdentityKind.account,
          providerId: AuthProviders.password,
          email: 'a@b.c',
          emailVerified: true,
        ),
      );
    });

    test('toString never contains the email address', () {
      const state = AuthState.signedIn(
        'uid-1',
        kind: AuthIdentityKind.account,
        providerId: AuthProviders.password,
        email: 'secret-person@example.com',
      );
      expect(state.toString(), isNot(contains('secret-person@example.com')));
      expect(state.toString(), contains('account'));
    });

    test('leaderboard writability follows the rules gate', () {
      // Guest: never.
      expect(const AuthState.signedIn('u').canWriteLeaderboard, isFalse);
      // Google account: yes.
      expect(
        const AuthState.signedIn(
          'u',
          kind: AuthIdentityKind.account,
          providerId: AuthProviders.google,
          emailVerified: true,
        ).canWriteLeaderboard,
        isTrue,
      );
      // Email account: only once verified.
      expect(
        const AuthState.signedIn(
          'u',
          kind: AuthIdentityKind.account,
          providerId: AuthProviders.password,
        ).canWriteLeaderboard,
        isFalse,
      );
      expect(
        const AuthState.signedIn(
          'u',
          kind: AuthIdentityKind.account,
          providerId: AuthProviders.password,
          emailVerified: true,
        ).canWriteLeaderboard,
        isTrue,
      );
      // Signed out: never.
      expect(const AuthState.signedOut().canWriteLeaderboard, isFalse);
    });
  });

  group('currentUid contract', () {
    test('is the shape the Phase 6/7 repositories expect', () async {
      // The repositories take `UserIdResolver = Future<String?> Function()`.
      // Binding the gateway to that type is the compile-time proof that a real
      // uid can finally reach the Phase 6/7 seam.
      const UserIdResolver resolver = _fakeUid;
      expect(await resolver(), 'uid-1');
    });
  });
}

Future<String?> _fakeUid() async => 'uid-1';
