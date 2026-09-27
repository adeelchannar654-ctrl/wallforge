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

/// The outcome of an auth operation, or the currently known auth state.
class AuthState {
  const AuthState.signedIn(this.uid)
    : status = AuthStatus.signedIn,
      detail = null;

  const AuthState.signedOut()
    : status = AuthStatus.signedOut,
      uid = null,
      detail = null;

  const AuthState.unavailable(String reason)
    : status = AuthStatus.unavailable,
      uid = null,
      detail = reason;

  /// Which state this is.
  final AuthStatus status;

  /// The signed-in user's id, or null when there is none.
  final String? uid;

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          status == other.status &&
          uid == other.uid &&
          detail == other.detail;

  @override
  int get hashCode => Object.hash(status, uid, detail);

  @override
  String toString() =>
      'AuthState(${status.name}${uid == null ? '' : ', uid: $uid'}'
      '${detail == null ? '' : ', $detail'})';
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
