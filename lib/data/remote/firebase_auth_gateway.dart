import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/logging/app_logger.dart';
import '../../domain/repositories/auth.dart';

/// [AuthGateway] backed by Firebase Authentication, using anonymous sign-in.
///
/// ## Why anonymous
///
/// `rules.md` §6 sanctions "an appropriate low-friction method such as
/// anonymous authentication"; `PRD.md` §6.4 says "Anonymous or account-based
/// authentication as appropriate". See [AuthGateway] for the full reasoning and
/// for the durability limitation `rules.md` §6 explicitly warns about.
///
/// ## Failure behaviour
///
/// Nothing here throws. Every failure resolves to
/// `AuthState.unavailable(reason)`, matching the non-fatal `FirebaseStatus`
/// pattern Phase 7 established. The app must still be playable offline and in a
/// build with no Firebase configuration at all, so a sign-in failure is a
/// reported state rather than an error dialog or a hang.
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({fb.FirebaseAuth? auth, DateTime Function()? clock})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _clock = clock ?? DateTime.now;

  static const AppLogger _log = AppLogger('auth');

  final fb.FirebaseAuth _auth;

  /// Injected for tests; the server needs a real timestamp.
  final DateTime Function() _clock;

  @override
  Future<AuthState> signInAnonymously() async {
    try {
      // Already signed in: reuse the existing uid rather than churning a new
      // anonymous account, which would orphan any documents already keyed on it.
      final existing = _auth.currentUser;
      if (existing != null) {
        _log.log('reusing existing anonymous uid');
        return AuthState.signedIn(existing.uid);
      }
      final credential = await _auth.signInAnonymously();
      final uid = credential.user?.uid;
      if (uid == null || uid.isEmpty) {
        return const AuthState.unavailable('sign-in returned no uid');
      }
      _log.log('signed in anonymously');
      return AuthState.signedIn(uid);
    } on fb.FirebaseAuthException catch (e) {
      // Most likely: anonymous sign-in disabled in the Console, or offline.
      return AuthState.unavailable('FirebaseAuthException(${e.code})');
    } on Object catch (e) {
      // Includes "no Firebase app initialised", which is the expected state for
      // an unconfigured build.
      return AuthState.unavailable(e.runtimeType.toString());
    }
  }

  @override
  Future<AuthState> current() async {
    final user = _auth.currentUser;
    if (user == null) return const AuthState.signedOut();
    return AuthState.signedIn(user.uid);
  }

  @override
  Future<AuthState> signOut() async {
    try {
      await _auth.signOut();
      return const AuthState.signedOut();
    } on Object catch (e) {
      return AuthState.unavailable(e.runtimeType.toString());
    }
  }

  @override
  Stream<AuthState> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null
        ? const AuthState.signedOut()
        : AuthState.signedIn(user.uid),
  );

  @override
  Future<String?> currentUid() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return uid;
  }

  /// Exposed so the sign-in moment can be timestamped in a room document.
  int nowMs() => _clock().millisecondsSinceEpoch;
}
