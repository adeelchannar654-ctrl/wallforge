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
///
/// ## Why Firebase is resolved lazily
///
/// `fb.FirebaseAuth.instance` throws immediately — `[core/no-app]` — when no
/// Firebase app has been initialised, which is the real state of a fresh clone,
/// since `.gitignore` forbids committing the client config. Resolving it in the
/// constructor's initializer list therefore made `FirebaseAuthGateway()` itself
/// throw, *before* any of the try/catch blocks in this class could run. That is
/// what made tapping "Online Play" silently do nothing: route construction threw
/// and no lobby was ever shown.
///
/// So resolution is deferred to [_auth], a cached getter, and is only ever
/// reached from inside a guarded call path. This mirrors
/// `CloudFirestoreClient._firestore`, which had the identical bug and was fixed
/// the same way in Phase 7. A failed resolution is not cached, so a gateway
/// constructed before `Firebase.initializeApp()` still works afterwards.
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({fb.FirebaseAuth? auth, DateTime Function()? clock})
    : _injected = auth,
      _clock = clock ?? DateTime.now;

  static const AppLogger _log = AppLogger('auth');

  final fb.FirebaseAuth? _injected;
  fb.FirebaseAuth? _resolved;

  /// The Firebase Auth instance, resolved on first use.
  ///
  /// Only call this from inside a try/catch-guarded method.
  fb.FirebaseAuth get _auth =>
      _resolved ??= _injected ?? fb.FirebaseAuth.instance;

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
    // Guarded like every other method here: an unguarded `_auth` read turns
    // "no Firebase app" into a rejected Future, which is exactly the throw the
    // class promises never to throw.
    try {
      final user = _auth.currentUser;
      if (user == null) return const AuthState.signedOut();
      return AuthState.signedIn(user.uid);
    } on Object catch (e) {
      return AuthState.unavailable(e.runtimeType.toString());
    }
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
  Stream<AuthState> authStateChanges() {
    // A stream is not covered by the `Future` methods' try/catch pattern: the
    // expression is evaluated when this method is *called*, so an unresolved
    // Firebase would throw synchronously to the caller. Caught here and reported
    // as a single `unavailable` event, which is the truthful state — nobody is
    // signed in, and no change will ever arrive.
    try {
      return _auth.authStateChanges().map(
        (user) => user == null
            ? const AuthState.signedOut()
            : AuthState.signedIn(user.uid),
      );
    } on Object catch (e) {
      _log.error('auth stream unavailable: ${e.runtimeType}');
      return Stream<AuthState>.value(
        AuthState.unavailable('auth state unavailable (${e.runtimeType})'),
      );
    }
  }

  @override
  Future<String?> currentUid() async {
    // This is the `userId` resolver every Phase 6/7/8 repository is handed, so a
    // throw here would propagate out of `load()`/`save()` on an unconfigured
    // build. Null is the documented "no owner, store nothing" answer.
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null || uid.isEmpty) return null;
      return uid;
    } on Object catch (e) {
      _log.error('uid unavailable: ${e.runtimeType}');
      return null;
    }
  }

  /// Exposed so the sign-in moment can be timestamped in a room document.
  int nowMs() => _clock().millisecondsSinceEpoch;
}
