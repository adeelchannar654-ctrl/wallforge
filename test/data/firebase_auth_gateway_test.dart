import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firebase_auth_gateway.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// The real adapter, exercised on an **unconfigured** build.
///
/// ## Why this file exists
///
/// `FirebaseAuthGateway` used to resolve `fb.FirebaseAuth.instance` in its
/// constructor's initializer list, which throws `[core/no-app]` when no Firebase
/// app exists. Because that ran before any try/catch in the class, constructing
/// the gateway threw — and since the only production caller is
/// `OnlineLobbyFactory.firebase()`, tapping "Online Play" threw during route
/// construction and the app silently failed to navigate.
///
/// The Phase 8 suite missed it because **every test injected a fake gateway**:
/// `FakeAuthGateway` in the controller tests and `_StubAuth` in the widget tests.
/// The real class was constructed only via its injected `auth` parameter, which
/// skips the faulty expression entirely, and its 0% coverage was recorded as a
/// known gap. Recording a coverage gap is not the same as the gap being safe.
///
/// So these tests deliberately construct the real, zero-argument path with no
/// Firebase app initialised — the exact state of a fresh clone.
void main() {
  /// Guards against this file silently becoming vacuous. If a future test
  /// environment ever initialises a Firebase app, the SDK stops throwing and
  /// these tests would pass for the wrong reason, so the premise is asserted
  /// explicitly.
  void expectNoFirebaseApp() {
    expect(
      () => fb.FirebaseAuth.instance,
      throwsA(isA<fb.FirebaseException>()),
      reason:
          'this suite assumes no Firebase app is initialised; if that changed, '
          'these tests no longer prove anything about the unconfigured build',
    );
  }

  group('construction on an unconfigured build', () {
    test(
      'the Firebase SDK really does throw without an app',
      expectNoFirebaseApp,
    );

    test('constructing the real gateway does not throw', () {
      // The regression test. This is what the owner hit as "Online Play does
      // nothing".
      expect(
        FirebaseAuthGateway.new,
        returnsNormally,
        reason: 'resolution must be deferred to first use, not run in the ctor',
      );
    });

    test('construction succeeds with an injected clock only', () {
      expect(
        () => FirebaseAuthGateway(clock: () => DateTime.utc(2026, 9, 27)),
        returnsNormally,
      );
    });
  });

  group('every method is total on an unconfigured build', () {
    late FirebaseAuthGateway gateway;

    setUp(() {
      expectNoFirebaseApp();
      gateway = FirebaseAuthGateway();
    });

    test('signInAnonymously resolves to unavailable, never throwing', () async {
      final state = await gateway.signInAnonymously();
      expect(state.status, AuthStatus.unavailable);
      expect(state.isSignedIn, isFalse);
      expect(state.uid, isNull);
      expect(state.detail, isNotNull);
    });

    test('signInAnonymously completes rather than hanging', () async {
      // A timeout turns a hang into a failure instead of a stuck suite.
      await expectLater(
        gateway.signInAnonymously().timeout(const Duration(seconds: 5)),
        completes,
      );
    });

    test('current resolves to unavailable rather than throwing', () async {
      final state = await gateway.current();
      expect(state.status, AuthStatus.unavailable);
      expect(state.isSignedIn, isFalse);
    });

    test('currentUid resolves to null, which repositories treat as no owner', () async {
      // This is the resolver handed to every Phase 6/7/8 repository, so a throw
      // here would escape `load()` and `save()`.
      await expectLater(
        gateway.currentUid().timeout(const Duration(seconds: 5)),
        completion(isNull),
      );
    });

    test('signOut resolves rather than throwing', () async {
      final state = await gateway.signOut();
      expect(state.isSignedIn, isFalse);
    });

    test('authStateChanges is obtainable without throwing', () {
      // A Stream is not covered by the Future methods' try/catch pattern: the
      // expression is evaluated when the method is called.
      expect(() => gateway.authStateChanges(), returnsNormally);
    });

    test('authStateChanges reports unavailable instead of erroring', () async {
      final states = await gateway.authStateChanges().toList();
      expect(states, isNotEmpty);
      expect(states.last.status, AuthStatus.unavailable);
      expect(states.last.isSignedIn, isFalse);
    });

    test('no public method throws, on any path', () async {
      // One sweep over the whole surface, so a future method added to the class
      // is covered by the same expectation.
      await expectLater(gateway.signInAnonymously(), completes);
      await expectLater(gateway.current(), completes);
      await expectLater(gateway.currentUid(), completes);
      await expectLater(gateway.signOut(), completes);
      expect(() => gateway.authStateChanges(), returnsNormally);
      await expectLater(gateway.authStateChanges().drain<void>(), completes);
    });
  });

  group('logging and timestamps stay safe without Firebase', () {
    test('nowMs works because it needs no Firebase', () {
      final gateway = FirebaseAuthGateway(
        clock: () => DateTime.utc(2026, 9, 27, 12, 30),
      );
      expect(
        gateway.nowMs(),
        DateTime.utc(2026, 9, 27, 12, 30).millisecondsSinceEpoch,
      );
    });
  });
}
