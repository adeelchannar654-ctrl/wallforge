/// Whether an identity is available, and if not, why.
///
/// Modelled on Phase 7's `FirebaseStatus` rather than inventing a second
/// convention: an unreachable or misconfigured Firebase must degrade to a
/// reported status, never to a thrown exception or a hang.
enum AuthStatus {
  /// A user is signed in and [AuthState.uid] is usable.
  signedIn,

  /// Deliberately signed out, and a sign-in would be a user action.
  signedOut,

  /// Sign-in was attempted and did not succeed: offline, Firebase unreachable,
  /// or anonymous sign-in disabled in the Console.
  ///
  /// Distinct from [signedOut] because retrying automatically is reasonable here
  /// while it is not for a real sign-out.
  unavailable,
}

/// What kind of identity a signed-in state carries (Phase 16.6).
///
/// The distinction is the whole product shape of the accounts phase: a
/// [guest] is the anonymous identity the app has always started with —
/// free, instant, and lost on reinstall — while an [account] is a guest
/// that gained a durable credential (Google or Email/Password) by
/// *linking*, keeping the same uid, or an existing account signed in
/// directly.
enum AuthIdentityKind {
  /// An anonymous (guest) identity.
  guest,

  /// A durable account: a linked or directly signed-in credential.
  account,
}

/// Firebase's own provider identifiers, as they appear in
/// `request.auth.token.firebase.sign_in_provider` and in the SDK's
/// `providerData`. The Security Rules gate the leaderboard on exactly
/// these strings (Phase 16.6, Part G), so they are named once here.
abstract final class AuthProviders {
  /// Anonymous sign-in.
  static const String anonymous = 'anonymous';

  /// Google Sign-In.
  static const String google = 'google.com';

  /// Email + password.
  static const String password = 'password';
}

/// Account policy constants (Phase 16.6, D16.6-11).
abstract final class AccountPolicy {
  /// The minimum password length the app enforces client-side and
  /// states as a hint under the password field. Firebase's own
  /// floor is lower; the app's rule is the one players see, and
  /// the gateway still maps Firebase's `weak-password` onto
  /// [AuthError.weakPassword] for anything the client check
  /// cannot see. No composition rules (no required symbols or
  /// cases) — length is the requirement with the evidence behind
  /// it, and composition rules mostly manufacture reuse.
  static const int minPasswordLength = 8;
}

/// The outcome of an auth operation, or the currently known auth state.
class AuthState {
  const AuthState.signedIn(
    this.uid, {
    this.kind = AuthIdentityKind.guest,
    this.providerId = AuthProviders.anonymous,
    this.email,
    this.emailVerified = false,
  }) : status = AuthStatus.signedIn,
       detail = null;

  const AuthState.signedOut()
    : status = AuthStatus.signedOut,
      uid = null,
      kind = null,
      providerId = null,
      email = null,
      emailVerified = false,
      detail = null;

  const AuthState.unavailable(String reason)
    : status = AuthStatus.unavailable,
      uid = null,
      kind = null,
      providerId = null,
      email = null,
      emailVerified = false,
      detail = reason;

  /// Which state this is.
  final AuthStatus status;

  /// The signed-in user's id, or null when there is none.
  final String? uid;

  /// Whether the identity is a guest or a durable account.
  ///
  /// Null unless [status] is [AuthStatus.signedIn].
  final AuthIdentityKind? kind;

  /// The primary sign-in provider ([AuthProviders] values), or null
  /// unless signed in.
  final String? providerId;

  /// The account's email address, when the provider supplies one.
  ///
  /// **Memory only** (Phase 16.6 privacy decision D16.6-2): it is
  /// shown to the signed-in user themselves on the Account screen
  /// and is never persisted by app code, never written to
  /// Firestore, and never logged — it is deliberately excluded from
  /// [toString] for that reason.
  final String? email;

  /// Whether the account's email address is verified. Meaningful
  /// only for the email provider; Google accounts report true.
  final bool emailVerified;

  /// Human-readable reason for [AuthStatus.unavailable], safe to log.
  ///
  /// Never contains a token or any credential material (`rules.md` §8).
  final String? detail;

  /// Whether a uid is available to key documents on.
  ///
  /// An empty uid counts as *not* signed in: the Phase 6/7 repositories treat
  /// `null` or `''` as "no owner, store nothing", so calling an empty string a
  /// usable identity would let a document be written under a blank key.
  bool get isSignedIn =>
      status == AuthStatus.signedIn && uid != null && uid!.isNotEmpty;

  /// Whether the signed-in identity is an anonymous guest.
  bool get isGuest => isSignedIn && kind == AuthIdentityKind.guest;

  /// Whether the signed-in identity is a durable account.
  bool get isAccount => isSignedIn && kind == AuthIdentityKind.account;

  /// Whether this identity may write leaderboard entries under the
  /// Phase 16.6 rules: a non-anonymous provider, and for the email
  /// provider a verified address. Guests can view the board and play
  /// online; their matches are simply not counted (D16.6-10).
  bool get canWriteLeaderboard =>
      isAccount && (providerId != AuthProviders.password || emailVerified);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          status == other.status &&
          uid == other.uid &&
          kind == other.kind &&
          providerId == other.providerId &&
          email == other.email &&
          emailVerified == other.emailVerified &&
          detail == other.detail;

  @override
  int get hashCode =>
      Object.hash(status, uid, kind, providerId, email, emailVerified, detail);

  @override
  String toString() =>
      'AuthState(${status.name}${uid == null ? '' : ', uid: $uid'}'
      '${kind == null ? '' : ', ${kind!.name}'}'
      '${detail == null ? '' : ', $detail'})';
}

/// The typed failure of an account operation (Phase 16.6).
///
/// Every value maps to exactly one plain-language message in the UI
/// (the mapping lives in the account strings file); raw provider
/// messages never reach the screen. The gateway maps Firebase's error
/// codes onto these values; a few are produced by the account
/// controller itself (notably [blockedByLiveMatch]).
enum AuthError {
  /// The user dismissed the provider flow (closed the Google picker
  /// or popup). Not an error to scold about — the UI just returns to
  /// the form.
  cancelled,

  /// The network is unreachable (Firebase's
  /// `network-request-failed`).
  offline,

  /// Sign-in failed and the app cannot say more precisely — by
  /// design. With email-enumeration protection on, Firebase
  /// deliberately returns one generic code for "no such user" and
  /// "wrong password"; with it off, the gateway folds both codes
  /// into this value too, so the app never confirms whether an
  /// email is registered (D16.6-5).
  invalidCredentials,

  /// The email already belongs to an account (sign-up path).
  emailAlreadyInUse,

  /// The password does not meet the policy (client-side minimum 8,
  /// or Firebase's own `weak-password`).
  weakPassword,

  /// The email address is malformed.
  invalidEmail,

  /// Too many attempts; Firebase is throttling (`too-many-requests`
  /// — also the shape the 150/day Spark reset-email cap takes when
  /// exhausted).
  tooManyRequests,

  /// The operation needs a fresher sign-in than the current session
  /// (`requires-recent-login`): re-authenticate first. Account
  /// deletion is the main user of this.
  requiresRecentLogin,

  /// The credential already belongs to a *different* account
  /// (`credential-already-in-use` /
  /// `account-exists-with-different-credential` from a link). The
  /// conflict choice (D16.6-4) is built on this value: sign in to
  /// that account, or cancel. Never auto-merged.
  credentialInUseByOtherAccount,

  /// The identity change was refused because an online match or an
  /// open room is live: changing the uid mid-match would orphan the
  /// player's seat (Part C's guard). Produced by the account
  /// controller, never by the gateway.
  blockedByLiveMatch,

  /// Firebase itself is unavailable: not configured in this build,
  /// or the provider is not enabled in the Console
  /// (`operation-not-allowed`).
  unavailable,

  /// Anything else. [AuthFailure.detail] carries a log-safe
  /// category, never a provider message.
  unknown,
}

/// A typed account-operation failure: the [AuthError] the UI maps to
/// plain language, plus a log-safe diagnostic detail.
class AuthFailure {
  const AuthFailure(this.error, {this.detail});

  /// The typed error.
  final AuthError error;

  /// Log-safe detail (an error code or type name — never a token,
  /// password, or a provider's raw message; `rules.md` §8).
  final String? detail;

  @override
  String toString() =>
      'AuthFailure(${error.name}${detail == null ? '' : ', $detail'})';
}

/// The result of an account operation: either the new [AuthState] or
/// a typed [AuthFailure]. Sealed, mirroring the `RoomResult` /
/// `ResignResult` precedent — expected failures are values, never
/// exceptions (`rules.md` §7).
sealed class AuthResult {
  const AuthResult();
}

/// The operation succeeded; [state] is the resulting auth state.
final class AuthSuccess extends AuthResult {
  const AuthSuccess(this.state);

  /// The auth state after the operation.
  final AuthState state;
}

/// The operation failed; [failure] says why, in typed form.
final class AuthRejected extends AuthResult {
  const AuthRejected(this.failure);

  /// The typed failure.
  final AuthFailure failure;
}

/// Identity, declared in the domain layer and implemented in `lib/data/remote/`.
///
/// ## Why anonymous
///
/// This is spec-derived, not a preference. `rules.md` §6: "Authentication can
/// initially use an appropriate low-friction method such as anonymous
/// authentication", and adds that account linking may come later "if the product
/// later needs durable cross-device identity". `PRD.md` §6.4 likewise says
/// "Anonymous or account-based authentication as appropriate". Anonymous auth
/// satisfies Phase 8's exit criterion — two devices can identify themselves and
/// meet in a room — with no account UI and no personal data collected, which also
/// keeps `PRD.md` §15's "no private information should be stored" intact.
///
/// The same `rules.md` §6 paragraph carries a real limitation, recorded rather
/// than glossed: anonymous identity is not a durable account, so a user who
/// clears app data or reinstalls loses that uid and their cloud data becomes
/// unreachable. Phase 8 does not promise cross-device data restoration.
///
/// Phase 16.6 is the "later" `rules.md` §6 anticipated: durable identity
/// now exists, as [AccountAuthGateway] — an extension of this contract,
/// so the lobby and game controllers keep depending on exactly the
/// surface they need and nothing more (D16.6-3).
abstract interface class AuthGateway {
  /// Signs in anonymously, returning the resulting state.
  ///
  /// Never throws: a failure resolves to `AuthState.unavailable(reason)`.
  Future<AuthState> signInAnonymously();

  /// The current auth state without attempting to change it.
  Future<AuthState> current();

  /// Signs out. Never throws.
  Future<AuthState> signOut();

  /// Emits whenever the signed-in user changes.
  Stream<AuthState> authStateChanges();

  /// Resolves the current uid, or null when nobody is signed in.
  ///
  /// This is the exact shape Phase 6/7 repositories already accept as their
  /// `UserIdResolver`, which is how a real uid finally reaches that seam and
  /// resolves Q-7.2.
  Future<String?> currentUid();
}

/// The account operations (Phase 16.6): Google and Email/Password
/// sign-in, linking, verification, reset, re-authentication and
/// deletion, behind the typed [AuthResult] model.
///
/// ## Linking semantics
///
/// The `link…` operations attach a credential to the *current*
/// (guest) session, preserving its uid — rooms, matches and
/// leaderboard entries keyed on that uid stay valid. The `signIn…`
/// operations switch to whatever account the credential belongs
/// to. Choosing between them is the account controller's job
/// (link first; a [AuthError.credentialInUseByOtherAccount]
/// rejection becomes the player's explicit choice, D16.6-4).
///
/// Every method is total: expected failures resolve to
/// [AuthRejected] with a typed [AuthFailure], and an unconfigured
/// build resolves to [AuthError.unavailable] — the Phase 8
/// degradation contract, unchanged.
abstract interface class AccountAuthGateway extends AuthGateway {
  /// Signs in with a Google account, switching to that account's
  /// uid. On web this is Firebase's popup flow; on mobile the
  /// `google_sign_in` package supplies the ID token (written, not
  /// device-verified — see `memory.md` §13ab).
  Future<AuthResult> signInWithGoogle();

  /// Links a Google account to the current guest session, keeping
  /// its uid.
  Future<AuthResult> linkWithGoogle();

  /// Creates an email account: links the credential to the current
  /// guest session when there is one (keeping its uid), or creates
  /// a fresh account when signed out. The new email starts
  /// unverified; the controller sends the verification email.
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Signs in to an existing email account, switching to its uid.
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  /// Links an email credential to the current guest session,
  /// keeping its uid.
  Future<AuthResult> linkWithEmail({
    required String email,
    required String password,
  });

  /// Sends (or resends) the verification email for the current
  /// email account.
  Future<AuthResult> sendVerificationEmail();

  /// Sends a password-reset email. Resolves as success even when
  /// no account exists for the address — reporting otherwise would
  /// confirm registration, which D16.6-5 forbids.
  Future<AuthResult> sendPasswordReset({required String email});

  /// Re-authenticates the current email account with its password
  /// (the freshness step before deletion).
  Future<AuthResult> reauthenticateWithPassword({required String password});

  /// Re-authenticates the current Google account through a fresh
  /// Google flow (the freshness step before deletion).
  Future<AuthResult> reauthenticateWithGoogle();

  /// Deletes the current Firebase user. The caller deletes the
  /// cloud profile first, while still authenticated (D16.6-12);
  /// this method only removes the Auth identity. On success the
  /// state is signed out — returning to a fresh guest is the
  /// controller's composition, not the gateway's.
  Future<AuthResult> deleteCurrentUser();

  /// Reloads the current user from the provider and returns the
  /// fresh state. This exists for the verification loop: a player
  /// who taps the link in the verification email comes back to the
  /// app, and the cached user's `emailVerified` only updates on a
  /// reload. (Added beyond the phase brief's operation list for
  /// exactly this; recorded in §13ab.)
  Future<AuthResult> refreshCurrentUser();
}
