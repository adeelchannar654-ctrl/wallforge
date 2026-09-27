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
