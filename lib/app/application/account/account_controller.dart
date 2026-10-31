import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/repositories/auth.dart';
import 'identity_guard.dart';

/// A credential conflict awaiting the player's choice (D16.6-4).
///
/// Raised when linking from a guest fails because the Google or
/// email credential already belongs to a different account — the
/// classic reinstall case. The UI offers exactly two ways out:
/// sign in to that existing account (this device's guest identity
/// is left behind; its local data stays on the device, untouched)
/// or cancel. Nothing is ever merged automatically.
class AccountConflict {
  const AccountConflict({required this.providerId, this.email});

  /// Which provider the conflicting credential belongs to
  /// ([AuthProviders.google] or [AuthProviders.password]).
  final String providerId;

  /// The email the player entered, for the email flow. Null for
  /// Google — the gateway does not report the other account's
  /// address, and the app would not show it if it did.
  final String? email;
}

/// The one owner of account state for the whole app (Phase 16.6).
///
/// Subscribes to the gateway's auth-state stream **exactly once**
/// (in [start]) and cancels in [dispose] — the lifecycle test
/// counts the fake gateway's subscriptions to prove it. Every
/// screen reads identity from here; nothing else subscribes to
/// the gateway.
///
/// ## Flows
///
/// * **Link first.** Connecting from a guest always links, so the
///   uid — and every room, match and leaderboard entry keyed on
///   it — survives. A conflict becomes an [AccountConflict] for
///   the player to resolve; it is never silently resolved.
/// * **The mid-match guard.** Every identity-changing operation
///   checks [IdentityGuard] first and refuses with
///   [AuthError.blockedByLiveMatch] without touching the gateway.
/// * **Sign-out returns a fresh guest.** The previous identity
///   (a guest's above all) cannot be recovered afterwards; the UI
///   warns before calling. Local data is device-owned and is
///   never deleted or merged by an identity change (D16.6-6) —
///   clearing it is the separate, explicit [clearDeviceProgress].
/// * **Deletion** re-authenticates first, deletes the cloud
///   profile while still authenticated, then deletes the Auth
///   user (D16.6-12), and lands the player on a fresh guest.
class AccountController extends ChangeNotifier {
  AccountController({
    required this.gateway,
    required this.guard,
    this.onAccountSignedIn,
    this.deleteCloudProfile,
    this.clearLocalProgress,
  });

  /// The account gateway every operation goes through.
  final AccountAuthGateway gateway;

  /// The mid-match guard every identity change consults.
  final IdentityGuard guard;

  /// Invoked after any operation that lands on an account state
  /// (Part E's cloud-profile sync hangs off this).
  final Future<void> Function(AuthState state)? onAccountSignedIn;

  /// Deletes the cloud profile; must run while still
  /// authenticated (Part E/F). False aborts the deletion.
  final Future<bool> Function()? deleteCloudProfile;

  /// The device-progress clearer behind [clearDeviceProgress].
  final Future<void> Function()? clearLocalProgress;

  AuthState _state = const AuthState.signedOut();
  bool _busy = false;
  bool _started = false;
  bool _disposed = false;
  AuthFailure? _lastFailure;
  AccountConflict? _conflict;
  String? _pendingEmail;
  String? _pendingPassword;
  StreamSubscription<AuthState>? _subscription;

  /// The current identity, kept current by the one subscription.
  AuthState get state => _state;

  /// Whether an operation is in flight (the UI disables its
  /// buttons — a busy operation cannot be double-submitted).
  bool get isBusy => _busy;

  /// The last typed failure, for the UI's plain-language mapping.
  AuthFailure? get lastFailure => _lastFailure;

  /// The unresolved credential conflict, if any.
  AccountConflict? get conflict => _conflict;

  /// Whether the app has any identity at all yet.
  bool get isStarted => _started;

  /// Starts the controller: subscribes once, reads the current
  /// state, and — guest-first, exactly as the app has always
  /// behaved — creates the anonymous guest session when there is
  /// none. Safe to call more than once; later calls are no-ops.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = gateway.authStateChanges().listen((next) {
      if (_disposed) return;
      _state = next;
      notifyListeners();
    });
    _state = await gateway.current();
    if (_disposed) return;
    if (_state.status == AuthStatus.signedOut) {
      _state = await gateway.signInAnonymously();
    }
    notifyListeners();
    // A session restored already signed in (the ordinary case on
    // a second launch) is a landing on an account state too: the
    // sign-in hook (profile sync) must run for it, not only for
    // sign-ins performed through this controller.
    if (_state.isAccount) {
      final hook = onAccountSignedIn;
      if (hook != null) unawaited(hook(_state));
    }
  }

  // --- Connecting -------------------------------------------------------------

  /// Connects a Google account: links it to the guest (keeping
  /// the uid), or signs in directly when there is no guest
  /// session. A conflict is stored in [conflict], not resolved.
  Future<AuthResult> connectGoogle() {
    return _identityChange(() async {
      if (_state.isAccount) return AuthSuccess(_state);
      if (_state.isGuest) {
        final result = await gateway.linkWithGoogle();
        if (result is AuthRejected &&
            result.failure.error == AuthError.credentialInUseByOtherAccount) {
          _conflict = const AccountConflict(providerId: AuthProviders.google);
        }
        return result;
      }
      return gateway.signInWithGoogle();
    });
  }

  /// Creates an email account from the guest (linking, so the uid
  /// survives) or from signed-out, then sends the verification
  /// email. The password policy is enforced here so the fake and
  /// the real gateway behave identically.
  Future<AuthResult> createEmailAccount({
    required String email,
    required String password,
  }) {
    return _identityChange(() async {
      if (password.length < AccountPolicy.minPasswordLength) {
        return const AuthRejected(AuthFailure(AuthError.weakPassword));
      }
      final result = await gateway.signUpWithEmail(
        email: email,
        password: password,
      );
      if (result is AuthSuccess) {
        // Best effort: a failed verification send must not fail
        // the sign-up — the Account screen offers a resend.
        await gateway.sendVerificationEmail();
      }
      if (result is AuthRejected &&
          result.failure.error == AuthError.emailAlreadyInUse) {
        _conflict = AccountConflict(
          providerId: AuthProviders.password,
          email: email,
        );
        _pendingEmail = email;
        _pendingPassword = password;
      }
      return result;
    });
  }

  /// Signs in with email: from a guest this *links first* (the
  /// reinstall-recovery flow — an existing account surfaces as a
  /// conflict to resolve, never a silent switch); with no guest
  /// session it signs in directly.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _identityChange(() async {
      if (_state.isGuest) {
        final result = await gateway.linkWithEmail(
          email: email,
          password: password,
        );
        if (result is AuthRejected &&
            result.failure.error == AuthError.credentialInUseByOtherAccount) {
          _conflict = AccountConflict(
            providerId: AuthProviders.password,
            email: email,
          );
          _pendingEmail = email;
          _pendingPassword = password;
        }
        return result;
      }
      return gateway.signInWithEmail(email: email, password: password);
    });
  }

  /// Resolves a conflict by signing in to the existing account.
  /// This device's guest identity is left behind (its local data
  /// stays on the device, untouched — D16.6-6); the account's
  /// cloud profile is merged by the sign-in hook.
  Future<AuthResult> resolveConflictUseExisting() {
    final conflict = _conflict;
    if (conflict == null) {
      return Future.value(
        const AuthRejected(
          AuthFailure(AuthError.unknown, detail: 'no conflict pending'),
        ),
      );
    }
    return _identityChange(() async {
      final AuthResult result;
      if (conflict.providerId == AuthProviders.google) {
        result = await gateway.signInWithGoogle();
      } else {
        final email = _pendingEmail;
        final password = _pendingPassword;
        if (email == null || password == null) {
          return const AuthRejected(
            AuthFailure(AuthError.unknown, detail: 'conflict credential lost'),
          );
        }
        result = await gateway.signInWithEmail(
          email: email,
          password: password,
        );
      }
      if (result is AuthSuccess) _clearConflict();
      return result;
    });
  }

  /// Resolves a conflict by staying with the current guest. The
  /// held credential is dropped immediately.
  void resolveConflictCancel() {
    if (_conflict == null) return;
    _clearConflict();
    notifyListeners();
  }

  // --- Session ----------------------------------------------------------------

  /// Signs out and immediately returns as a **fresh guest** with a
  /// new anonymous uid. The previous identity cannot be recovered
  /// (for an unlinked guest it is gone entirely) — the UI warns
  /// before calling this. Local data is untouched (D16.6-6).
  Future<AuthResult> signOutToFreshGuest() {
    return _identityChange(() async {
      _clearConflict();
      final out = await gateway.signOut();
      if (out.isSignedIn) return AuthSuccess(out);
      return _freshGuest();
    });
  }

  /// Signs in anonymously as the post-sign-out / post-deletion
  /// landing, mapping a failed guest creation (offline, or
  /// Firebase unconfigured) onto a typed rejection rather than a
  /// "success" carrying an unavailable state.
  Future<AuthResult> _freshGuest() async {
    final guest = await gateway.signInAnonymously();
    if (guest.isSignedIn) return AuthSuccess(guest);
    return AuthRejected(
      AuthFailure(AuthError.unavailable, detail: guest.detail),
    );
  }

  /// Sends a password-reset email (enumeration-safe wording is
  /// the UI's; the gateway already refuses to leak existence).
  Future<AuthResult> sendPasswordReset({required String email}) {
    return _run(() => gateway.sendPasswordReset(email: email));
  }

  /// Resends the verification email for the current account.
  Future<AuthResult> resendVerification() {
    return _run(gateway.sendVerificationEmail);
  }

  /// Re-reads the account from the provider — the "I've verified"
  /// step that picks up a verification completed in the browser.
  Future<AuthResult> refreshAccount() {
    return _run(() async {
      final result = await gateway.refreshCurrentUser();
      if (result is AuthSuccess) _state = result.state;
      return result;
    });
  }

  // --- Deletion -----------------------------------------------------------------

  /// Deletes the account: re-authenticate, delete the cloud
  /// profile while still authenticated, delete the Auth user,
  /// and land on a fresh guest (D16.6-12).
  ///
  /// For an email account, [password] is the re-authentication
  /// credential; passing none when one is needed rejects with
  /// [AuthError.requiresRecentLogin], which is the UI's cue to
  /// ask for it. Leaderboard entries are deliberately NOT
  /// deleted (Part F: deleting them would reset the Phase 16.5
  /// double-count guards); they keep the generated display name,
  /// which identifies nobody.
  Future<AuthResult> deleteAccount({String? password}) {
    return _identityChange(() async {
      // 1. Re-authenticate (freshness) for the current provider.
      if (_state.providerId == AuthProviders.password) {
        if (password == null) {
          return const AuthRejected(AuthFailure(AuthError.requiresRecentLogin));
        }
        final reauth = await gateway.reauthenticateWithPassword(
          password: password,
        );
        if (reauth is AuthRejected) return reauth;
      } else if (_state.providerId == AuthProviders.google) {
        final reauth = await gateway.reauthenticateWithGoogle();
        if (reauth is AuthRejected) return reauth;
      }
      // 2. Delete the cloud profile while still authenticated. A
      // failure aborts the deletion: removing the Auth user while
      // its profile survived would orphan personal data under a
      // uid that can never sign in again.
      final deleteProfile = deleteCloudProfile;
      if (deleteProfile != null) {
        bool removed;
        try {
          removed = await deleteProfile();
        } on Object {
          removed = false;
        }
        if (!removed) {
          return const AuthRejected(
            AuthFailure(
              AuthError.unknown,
              detail: 'cloud profile could not be removed',
            ),
          );
        }
      }
      // 3. Delete the Auth identity itself.
      final deleted = await gateway.deleteCurrentUser();
      if (deleted is AuthRejected) return deleted;
      // 4. Land on a fresh guest, like every other path in this app.
      _clearConflict();
      return _freshGuest();
    });
  }

  // --- Device data --------------------------------------------------------------

  /// Clears this device's local progress — history, achievements,
  /// statistics, the unfinished match and saved display names —
  /// as a separate, explicit player choice. Identity changes
  /// never do this (D16.6-6); settings (preferences) are not
  /// progress and are kept.
  Future<void> clearDeviceProgress() async {
    final clear = clearLocalProgress;
    if (clear == null) return;
    await clear();
    notifyListeners();
  }

  // --- Internals ------------------------------------------------------------------

  void _clearConflict() {
    _conflict = null;
    _pendingEmail = null;
    _pendingPassword = null;
  }

  /// The guarded path every identity change takes: mid-match
  /// refusal first (without touching the gateway), then the busy
  /// lock, then bookkeeping and the sign-in hook.
  Future<AuthResult> _identityChange(Future<AuthResult> Function() op) async {
    if (guard.identityChangeBlocked) {
      const failure = AuthFailure(AuthError.blockedByLiveMatch);
      _lastFailure = failure;
      notifyListeners();
      return const AuthRejected(failure);
    }
    if (_busy) {
      return const AuthRejected(
        AuthFailure(AuthError.unknown, detail: 'another operation is running'),
      );
    }
    _busy = true;
    notifyListeners();
    try {
      final result = await op();
      switch (result) {
        case AuthSuccess(:final state):
          _state = state;
          _lastFailure = null;
          if (state.isAccount) {
            final hook = onAccountSignedIn;
            if (hook != null) unawaited(hook(state));
          }
        case AuthRejected(:final failure):
          _lastFailure = failure;
      }
      return result;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// The unguarded path for operations that change no identity.
  Future<AuthResult> _run(Future<AuthResult> Function() op) async {
    if (_busy) {
      return const AuthRejected(
        AuthFailure(AuthError.unknown, detail: 'another operation is running'),
      );
    }
    _busy = true;
    notifyListeners();
    try {
      final result = await op();
      _lastFailure = result is AuthRejected ? result.failure : null;
      return result;
    } finally {
      _busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _pendingPassword = null;
    super.dispose();
  }
}

/// App-wide access to the one [AccountController], following the
/// `FeedbackService` precedent exactly: installed by the app root,
/// null when the accounts feature is off (in which case the app
/// behaves precisely as it did before Phase 16.6), replaced by
/// tests before the app is pumped.
abstract final class AccountService {
  static AccountController? _shared;

  /// The installed controller, or null when accounts are off.
  static AccountController? get shared => _shared;

  /// Installs (or clears, with null) the shared controller.
  static void install(AccountController? controller) => _shared = controller;
}
