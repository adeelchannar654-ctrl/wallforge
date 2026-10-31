import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/logging/app_logger.dart';
import '../../domain/repositories/auth.dart';

/// [AccountAuthGateway] backed by Firebase Authentication.
///
/// Phase 8 shipped the anonymous half; Phase 16.6 adds Google and
/// Email/Password sign-in, linking, verification, reset,
/// re-authentication and deletion behind the typed [AuthResult]
/// model.
///
/// ## Why anonymous is still the default
///
/// `rules.md` §6 sanctions "an appropriate low-friction method such as
/// anonymous authentication"; `PRD.md` §6.4 says "Anonymous or account-based
/// authentication as appropriate". See [AuthGateway] for the full reasoning and
/// for the durability limitation `rules.md` §6 explicitly warns about.
/// Accounts are the optional upgrade of that guest, never a gate.
///
/// ## Failure behaviour
///
/// Nothing here throws. Every failure resolves to a reported state or a
/// typed [AuthRejected], matching the non-fatal `FirebaseStatus`
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
///
/// ## Google sign-in: popup on web, package on mobile
///
/// On web, Firebase Auth's own `signInWithPopup` is the supported flow
/// and needs no extra package (`google_sign_in_web` cannot authenticate
/// programmatically — it requires the GIS-rendered button). On mobile,
/// the `google_sign_in` package (v7 API) obtains the ID token that
/// [fb.GoogleAuthProvider.credential] turns into a Firebase credential;
/// the OAuth client configuration comes from the platform config files
/// (`google-services.json` / `GoogleService-Info.plist`), so
/// `initialize()` is called with no explicit client id. **The mobile
/// flow is written against the documented v7 API and is not
/// device-verified** — no Android build can run in the build VM
/// (§13ab); the owner script carries the device checks.
class FirebaseAuthGateway implements AccountAuthGateway {
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

  bool _googleInitialized = false;

  /// Maps an SDK user onto the domain state. The email rides along in
  /// memory only (D16.6-2); nothing here persists or logs it.
  AuthState _stateFor(fb.User user) {
    var provider = AuthProviders.anonymous;
    for (final info in user.providerData) {
      if (info.providerId != 'firebase') {
        provider = info.providerId;
        break;
      }
    }
    return AuthState.signedIn(
      user.uid,
      kind: user.isAnonymous
          ? AuthIdentityKind.guest
          : AuthIdentityKind.account,
      providerId: provider,
      email: user.email,
      emailVerified: user.emailVerified,
    );
  }

  /// Maps an SDK error code onto the typed model (D16.6-5 folds the
  /// three credential codes into one neutral value, so the app can
  /// never confirm whether an email is registered).
  AuthFailure _mapError(fb.FirebaseAuthException e) {
    final error = switch (e.code) {
      'network-request-failed' => AuthError.offline,
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => AuthError.invalidCredentials,
      'user-disabled' => AuthError.invalidCredentials,
      'email-already-in-use' => AuthError.emailAlreadyInUse,
      'credential-already-in-use' ||
      'account-exists-with-different-credential' =>
        AuthError.credentialInUseByOtherAccount,
      'weak-password' => AuthError.weakPassword,
      'invalid-email' => AuthError.invalidEmail,
      'too-many-requests' => AuthError.tooManyRequests,
      'requires-recent-login' => AuthError.requiresRecentLogin,
      'popup-closed-by-user' ||
      'cancelled-popup-request' => AuthError.cancelled,
      'operation-not-allowed' ||
      'admin-restricted-operation' => AuthError.unavailable,
      _ => AuthError.unknown,
    };
    return AuthFailure(error, detail: 'FirebaseAuthException(${e.code})');
  }

  /// Runs [body] under the class's total-failure contract and folds
  /// the outcome into an [AuthResult].
  Future<AuthResult> _guard(Future<AuthState> Function() body) async {
    try {
      return AuthSuccess(await body());
    } on _GatewayFailure catch (f) {
      return AuthRejected(f.failure);
    } on fb.FirebaseAuthException catch (e) {
      return AuthRejected(_mapError(e));
    } on fb.FirebaseException catch (e) {
      // Includes "no Firebase app initialised" ([core/no-app]) — the
      // expected state of an unconfigured build.
      return AuthRejected(
        AuthFailure(
          AuthError.unavailable,
          detail: 'FirebaseException(${e.code})',
        ),
      );
    } on Object catch (e) {
      return AuthRejected(
        AuthFailure(AuthError.unknown, detail: e.runtimeType.toString()),
      );
    }
  }

  /// The current SDK user, or a typed rejection when there is no
  /// session to operate on.
  fb.User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const _GatewayFailure(
        AuthFailure(AuthError.unavailable, detail: 'no current user'),
      );
    }
    return user;
  }

  /// Obtains a Google credential on mobile via the `google_sign_in`
  /// package (v7). Web never calls this — it uses the popup flow.
  Future<fb.AuthCredential> _googleCredential() async {
    final signIn = GoogleSignIn.instance;
    try {
      if (!_googleInitialized) {
        // No explicit client id: the platform configuration files
        // supply it (google-services.json's generated resources on
        // Android, GoogleService-Info.plist on iOS).
        await signIn.initialize();
        _googleInitialized = true;
      }
      if (!signIn.supportsAuthenticate()) {
        throw const _GatewayFailure(
          AuthFailure(
            AuthError.unavailable,
            detail: 'google sign-in unsupported on this platform',
          ),
        );
      }
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const _GatewayFailure(
          AuthFailure(AuthError.unknown, detail: 'google returned no id token'),
        );
      }
      return fb.GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      throw _GatewayFailure(
        AuthFailure(switch (e.code) {
          GoogleSignInExceptionCode.canceled => AuthError.cancelled,
          GoogleSignInExceptionCode.clientConfigurationError =>
            AuthError.unavailable,
          _ => AuthError.unknown,
        }, detail: 'GoogleSignInException(${e.code.name})'),
      );
    }
  }

  // --- Phase 8 contract (unchanged semantics) -------------------------------

  @override
  Future<AuthState> signInAnonymously() async {
    try {
      // Already signed in: reuse the existing session rather than churning a
      // new anonymous account, which would orphan any documents already keyed
      // on it. Since Phase 16.6 the existing session may be a real account;
      // its state is reported as it is, never downgraded.
      final existing = _auth.currentUser;
      if (existing != null) {
        _log.log('reusing existing session');
        return _stateFor(existing);
      }
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null || user.uid.isEmpty) {
        return const AuthState.unavailable('sign-in returned no uid');
      }
      _log.log('signed in anonymously');
      return _stateFor(user);
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
      return _stateFor(user);
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
        (user) => user == null ? const AuthState.signedOut() : _stateFor(user),
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

  // --- Phase 16.6 account operations -----------------------------------------

  @override
  Future<AuthResult> signInWithGoogle() => _guard(() async {
    if (kIsWeb) {
      final credential = await _auth.signInWithPopup(fb.GoogleAuthProvider());
      final user = credential.user;
      if (user == null) {
        throw const _GatewayFailure(
          AuthFailure(
            AuthError.unknown,
            detail: 'google sign-in returned no user',
          ),
        );
      }
      return _stateFor(user);
    }
    final credential = await _auth.signInWithCredential(
      await _googleCredential(),
    );
    final user = credential.user;
    if (user == null) {
      throw const _GatewayFailure(
        AuthFailure(
          AuthError.unknown,
          detail: 'google sign-in returned no user',
        ),
      );
    }
    return _stateFor(user);
  });

  @override
  Future<AuthResult> linkWithGoogle() => _guard(() async {
    final current = _auth.currentUser;
    if (current == null) {
      // Nothing to link to: signing in is the truthful operation.
      return switch (await signInWithGoogle()) {
        AuthSuccess(:final state) => state,
        AuthRejected(:final failure) => throw _GatewayFailure(failure),
      };
    }
    if (kIsWeb) {
      final credential = await current.linkWithPopup(fb.GoogleAuthProvider());
      return _stateFor(credential.user ?? current);
    }
    final credential = await current.linkWithCredential(
      await _googleCredential(),
    );
    return _stateFor(credential.user ?? current);
  });

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) => _guard(() async {
    final current = _auth.currentUser;
    if (current != null && !current.isAnonymous) {
      throw const _GatewayFailure(
        AuthFailure(
          AuthError.unknown,
          detail: 'already signed in with an account',
        ),
      );
    }
    if (current != null) {
      // Link, so the guest's uid — and everything keyed on it — survives.
      final credential = await current.linkWithCredential(
        fb.EmailAuthProvider.credential(email: email, password: password),
      );
      return _stateFor(credential.user ?? current);
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const _GatewayFailure(
        AuthFailure(AuthError.unknown, detail: 'sign-up returned no user'),
      );
    }
    return _stateFor(user);
  });

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) => _guard(() async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw const _GatewayFailure(
        AuthFailure(AuthError.unknown, detail: 'sign-in returned no user'),
      );
    }
    return _stateFor(user);
  });

  @override
  Future<AuthResult> linkWithEmail({
    required String email,
    required String password,
  }) => _guard(() async {
    final current = _requireUser();
    if (!current.isAnonymous) {
      throw const _GatewayFailure(
        AuthFailure(
          AuthError.unknown,
          detail: 'already signed in with an account',
        ),
      );
    }
    final credential = await current.linkWithCredential(
      fb.EmailAuthProvider.credential(email: email, password: password),
    );
    return _stateFor(credential.user ?? current);
  });

  @override
  Future<AuthResult> sendVerificationEmail() => _guard(() async {
    final user = _requireUser();
    if (user.isAnonymous) {
      throw const _GatewayFailure(
        AuthFailure(
          AuthError.unavailable,
          detail: 'a guest has no email to verify',
        ),
      );
    }
    await user.sendEmailVerification();
    return _stateFor(user);
  });

  @override
  Future<AuthResult> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        // Anti-enumeration (D16.6-5): a reset request for an
        // unregistered address reports exactly what a registered one
        // does. (With enumeration protection enabled in the Console,
        // Firebase already behaves this way and never throws this.)
        _log.log('password reset requested');
        return AuthSuccess(await current());
      }
      return AuthRejected(_mapError(e));
    } on Object catch (e) {
      return AuthRejected(
        AuthFailure(AuthError.unavailable, detail: e.runtimeType.toString()),
      );
    }
    _log.log('password reset requested');
    return AuthSuccess(await current());
  }

  @override
  Future<AuthResult> reauthenticateWithPassword({required String password}) =>
      _guard(() async {
        final user = _requireUser();
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw const _GatewayFailure(
            AuthFailure(
              AuthError.unavailable,
              detail: 'account has no email to re-authenticate with',
            ),
          );
        }
        final credential = await user.reauthenticateWithCredential(
          fb.EmailAuthProvider.credential(email: email, password: password),
        );
        return _stateFor(credential.user ?? user);
      });

  @override
  Future<AuthResult> reauthenticateWithGoogle() => _guard(() async {
    final user = _requireUser();
    if (kIsWeb) {
      final credential = await user.reauthenticateWithPopup(
        fb.GoogleAuthProvider(),
      );
      return _stateFor(credential.user ?? user);
    }
    final credential = await user.reauthenticateWithCredential(
      await _googleCredential(),
    );
    return _stateFor(credential.user ?? user);
  });

  @override
  Future<AuthResult> deleteCurrentUser() => _guard(() async {
    final user = _requireUser();
    await user.delete();
    return const AuthState.signedOut();
  });

  @override
  Future<AuthResult> refreshCurrentUser() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return const AuthState.signedOut();
    await user.reload();
    final fresh = _auth.currentUser;
    return fresh == null ? const AuthState.signedOut() : _stateFor(fresh);
  });

  /// Exposed so the sign-in moment can be timestamped in a room document.
  int nowMs() => _clock().millisecondsSinceEpoch;
}

/// An internal carrier for a typed failure across the guarded call
/// paths above; converted to [AuthRejected] by [_guard] and never
/// allowed to escape the class.
class _GatewayFailure implements Exception {
  const _GatewayFailure(this.failure);

  final AuthFailure failure;
}
