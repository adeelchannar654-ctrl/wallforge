import 'dart:async';

import 'package:wallforge/domain/repositories/auth.dart';

/// A scriptable in-memory [AccountAuthGateway] for Phase 16.6 tests.
///
/// ## What it models faithfully
///
/// * **Linking preserves the uid.** A link operation changes the
///   current state's kind/provider/email, never its uid.
/// * **Conflicts are real.** Register an existing account with
///   [registerExistingEmail] / [existingGoogleUid] and a link aimed
///   at that credential rejects with
///   [AuthError.credentialInUseByOtherAccount], exactly as Firebase
///   behaves — the conflict flow tests exercise the real decision,
///   not a stub of it.
/// * **Enumeration safety.** Email sign-in rejects with
///   [AuthError.invalidCredentials] for a wrong password *and* for
///   an unknown address, indistinguishably.
/// * **Sign-out loses the guest.** The next anonymous sign-in mints
///   a fresh uid (`guest-N`), like Firebase.
/// * **Deletion freshness.** With [deleteNeedsReauth], deletion
///   rejects with [AuthError.requiresRecentLogin] until a
///   re-authentication (or a fresh sign-in/link) happens.
///
/// ## Scripting
///
/// [scriptedErrors] forces a typed failure per operation name (the
/// method names of [AccountAuthGateway]); it wins over the modelled
/// behaviour, for the one test that needs a specific failure.
/// [calls] records every operation, in order. [activeSubscriptions]
/// counts live `authStateChanges` listeners so lifecycle tests can
/// prove the account controller subscribes exactly once and cancels
/// on dispose.
class FakeAccountAuthGateway implements AccountAuthGateway {
  FakeAccountAuthGateway({AuthState initial = const AuthState.signedOut()})
    : _state = initial;

  AuthState _state;
  final StreamController<AuthState> _changes =
      StreamController<AuthState>.broadcast();
  int _subscriptions = 0;
  int _guestCounter = 0;
  int _googleCounter = 0;
  bool _fresh = false;

  /// Every operation invoked, by method name, in order.
  final List<String> calls = [];

  /// Operation name → forced typed failure.
  final Map<String, AuthError> scriptedErrors = {};

  /// Registered email accounts: email → (password, uid, verified).
  final Map<String, ({String password, String uid, bool verified})>
  emailAccounts = {};

  /// The uid a Google sign-in lands on, when the Google account is
  /// already a Wallforge account. Null means "new Google user".
  String? existingGoogleUid;

  /// The Google account's email (what the provider reports).
  String googleEmail = 'player@gmail.com';

  /// When true, [deleteCurrentUser] demands a fresh authentication.
  bool deleteNeedsReauth = false;

  /// Emails a password reset was requested for (the fake "sends"
  /// for known and unknown addresses alike, like the real gateway
  /// reports).
  final List<String> passwordResetsSent = [];

  /// Verification emails sent for the current account.
  int verificationEmailsSent = 0;

  /// Live `authStateChanges` subscriptions right now.
  int get activeSubscriptions => _subscriptions;

  /// Registers an email account owned by another (or the same) uid.
  void registerExistingEmail(
    String email, {
    required String password,
    required String uid,
    bool verified = true,
  }) {
    emailAccounts[email] = (password: password, uid: uid, verified: verified);
  }

  /// Marks the current email account verified (the user clicked the
  /// link in the verification email) and emits the change.
  void simulateEmailVerified() {
    if (!_state.isSignedIn) return;
    _set(
      AuthState.signedIn(
        _state.uid!,
        kind: _state.kind!,
        providerId: _state.providerId,
        email: _state.email,
        emailVerified: true,
      ),
    );
  }

  void _set(AuthState next) {
    _state = next;
    _changes.add(next);
  }

  AuthResult? _scripted(String op) {
    final error = scriptedErrors[op];
    if (error == null) return null;
    return AuthRejected(AuthFailure(error, detail: 'scripted'));
  }

  AuthState _guest() {
    _guestCounter += 1;
    return AuthState.signedIn('guest-$_guestCounter');
  }

  // --- Phase 8 contract -------------------------------------------------------

  @override
  Future<AuthState> signInAnonymously() async {
    calls.add('signInAnonymously');
    if (scriptedErrors.containsKey('signInAnonymously')) {
      return const AuthState.unavailable('scripted');
    }
    if (_state.isSignedIn) return _state;
    _fresh = true;
    final guest = _guest();
    _set(guest);
    return guest;
  }

  @override
  Future<AuthState> current() async => _state;

  @override
  Future<AuthState> signOut() async {
    calls.add('signOut');
    _fresh = false;
    const out = AuthState.signedOut();
    _set(out);
    return out;
  }

  @override
  Stream<AuthState> authStateChanges() {
    late StreamController<AuthState> controller;
    StreamSubscription<AuthState>? inner;
    controller = StreamController<AuthState>(
      onListen: () {
        _subscriptions += 1;
        inner = _changes.stream.listen(controller.add);
        controller.add(_state);
      },
      onCancel: () async {
        _subscriptions -= 1;
        await inner?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<String?> currentUid() async => _state.isSignedIn ? _state.uid : null;

  // --- Account operations ------------------------------------------------------

  @override
  Future<AuthResult> signInWithGoogle() async {
    calls.add('signInWithGoogle');
    final forced = _scripted('signInWithGoogle');
    if (forced != null) return forced;
    _fresh = true;
    final uid = existingGoogleUid ?? 'google-${++_googleCounter}';
    final next = AuthState.signedIn(
      uid,
      kind: AuthIdentityKind.account,
      providerId: AuthProviders.google,
      email: googleEmail,
      emailVerified: true,
    );
    _set(next);
    return AuthSuccess(next);
  }

  @override
  Future<AuthResult> linkWithGoogle() async {
    calls.add('linkWithGoogle');
    final forced = _scripted('linkWithGoogle');
    if (forced != null) return forced;
    if (!_state.isSignedIn) return signInWithGoogle();
    final other = existingGoogleUid;
    if (other != null && other != _state.uid) {
      return const AuthRejected(
        AuthFailure(AuthError.credentialInUseByOtherAccount),
      );
    }
    _fresh = true;
    final next = AuthState.signedIn(
      _state.uid!,
      kind: AuthIdentityKind.account,
      providerId: AuthProviders.google,
      email: googleEmail,
      emailVerified: true,
    );
    _set(next);
    return AuthSuccess(next);
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signUpWithEmail');
    final forced = _scripted('signUpWithEmail');
    if (forced != null) return forced;
    if (password.length < 8) {
      return const AuthRejected(AuthFailure(AuthError.weakPassword));
    }
    final existing = emailAccounts[email];
    if (existing != null && existing.uid != _state.uid) {
      return const AuthRejected(AuthFailure(AuthError.emailAlreadyInUse));
    }
    if (_state.isSignedIn && _state.isAccount) {
      return const AuthRejected(
        AuthFailure(AuthError.unknown, detail: 'already an account'),
      );
    }
    _fresh = true;
    final uid = _state.isSignedIn ? _state.uid! : 'email-${email.hashCode}';
    emailAccounts[email] = (password: password, uid: uid, verified: false);
    final next = AuthState.signedIn(
      uid,
      kind: AuthIdentityKind.account,
      providerId: AuthProviders.password,
      email: email,
    );
    _set(next);
    return AuthSuccess(next);
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signInWithEmail');
    final forced = _scripted('signInWithEmail');
    if (forced != null) return forced;
    final existing = emailAccounts[email];
    // One neutral rejection for unknown address and wrong password
    // alike — the fake models the real gateway's enumeration safety.
    if (existing == null || existing.password != password) {
      return const AuthRejected(AuthFailure(AuthError.invalidCredentials));
    }
    _fresh = true;
    final next = AuthState.signedIn(
      existing.uid,
      kind: AuthIdentityKind.account,
      providerId: AuthProviders.password,
      email: email,
      emailVerified: existing.verified,
    );
    _set(next);
    return AuthSuccess(next);
  }

  @override
  Future<AuthResult> linkWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('linkWithEmail');
    final forced = _scripted('linkWithEmail');
    if (forced != null) return forced;
    if (password.length < 8) {
      return const AuthRejected(AuthFailure(AuthError.weakPassword));
    }
    if (!_state.isSignedIn) {
      return const AuthRejected(
        AuthFailure(AuthError.unavailable, detail: 'no session to link'),
      );
    }
    if (_state.isAccount) {
      return const AuthRejected(
        AuthFailure(AuthError.unknown, detail: 'already an account'),
      );
    }
    final existing = emailAccounts[email];
    if (existing != null && existing.uid != _state.uid) {
      return const AuthRejected(
        AuthFailure(AuthError.credentialInUseByOtherAccount),
      );
    }
    _fresh = true;
    emailAccounts[email] = (
      password: password,
      uid: _state.uid!,
      verified: false,
    );
    final next = AuthState.signedIn(
      _state.uid!,
      kind: AuthIdentityKind.account,
      providerId: AuthProviders.password,
      email: email,
    );
    _set(next);
    return AuthSuccess(next);
  }

  @override
  Future<AuthResult> sendVerificationEmail() async {
    calls.add('sendVerificationEmail');
    final forced = _scripted('sendVerificationEmail');
    if (forced != null) return forced;
    if (!_state.isAccount || _state.providerId != AuthProviders.password) {
      return const AuthRejected(
        AuthFailure(AuthError.unavailable, detail: 'no email account'),
      );
    }
    verificationEmailsSent += 1;
    return AuthSuccess(_state);
  }

  @override
  Future<AuthResult> sendPasswordReset({required String email}) async {
    calls.add('sendPasswordReset');
    final forced = _scripted('sendPasswordReset');
    if (forced != null) return forced;
    passwordResetsSent.add(email);
    return AuthSuccess(_state);
  }

  @override
  Future<AuthResult> reauthenticateWithPassword({
    required String password,
  }) async {
    calls.add('reauthenticateWithPassword');
    final forced = _scripted('reauthenticateWithPassword');
    if (forced != null) return forced;
    final email = _state.email;
    final existing = email == null ? null : emailAccounts[email];
    if (existing == null || existing.password != password) {
      return const AuthRejected(AuthFailure(AuthError.invalidCredentials));
    }
    _fresh = true;
    return AuthSuccess(_state);
  }

  @override
  Future<AuthResult> reauthenticateWithGoogle() async {
    calls.add('reauthenticateWithGoogle');
    final forced = _scripted('reauthenticateWithGoogle');
    if (forced != null) return forced;
    if (_state.providerId != AuthProviders.google) {
      return const AuthRejected(
        AuthFailure(AuthError.unknown, detail: 'not a google account'),
      );
    }
    _fresh = true;
    return AuthSuccess(_state);
  }

  @override
  Future<AuthResult> refreshCurrentUser() async {
    calls.add('refreshCurrentUser');
    final forced = _scripted('refreshCurrentUser');
    if (forced != null) return forced;
    return AuthSuccess(_state);
  }

  @override
  Future<AuthResult> deleteCurrentUser() async {
    calls.add('deleteCurrentUser');
    final forced = _scripted('deleteCurrentUser');
    if (forced != null) return forced;
    if (!_state.isSignedIn) {
      return const AuthRejected(
        AuthFailure(AuthError.unavailable, detail: 'no current user'),
      );
    }
    if (deleteNeedsReauth && !_fresh) {
      return const AuthRejected(AuthFailure(AuthError.requiresRecentLogin));
    }
    _fresh = false;
    const out = AuthState.signedOut();
    _set(out);
    return const AuthSuccess(out);
  }
}
