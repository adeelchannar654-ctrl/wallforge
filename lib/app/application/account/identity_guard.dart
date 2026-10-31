/// Whether an identity change is currently unsafe (Phase 16.6,
/// Part C).
///
/// An online match — and the room that precedes it — keys its
/// seats on the player's uid. Changing identity mid-match (sign
/// in, sign out, switch account, delete) would strand the player
/// in a match their new identity does not own: the old seat
/// becomes unreachable, rematch links break, and the finish would
/// be recorded against the wrong identity. So the online
/// controllers report their liveness here, and the
/// account controller refuses every identity change while either
/// flag is set, telling the player to finish or leave first.
///
/// The flags are set by the controllers that own the live state:
/// `OnlineLobbyController` sets [roomOpen] while it holds a room
/// or a Quick Match queue entry, and `OnlineGameController` sets
/// [matchActive] for its whole lifetime (playing *and* viewing
/// the result — the rematch offered there is claimed with the
/// same uid). Both clear their flag on dispose.
///
/// One recorded limit (D16.6-9): a room abandoned by navigating
/// away is outside the guard, because the lobby controller is
/// disposed as the player leaves — the pre-existing Phase 8
/// behaviour. The seat keeps the old uid and the existing
/// abandonment rules clean it up; nothing is corrupted, the room
/// is simply lost to that guest, which the abandoned-room rules
/// have always allowed.
class IdentityGuard {
  /// An online match is live (or its result screen is showing).
  bool matchActive = false;

  /// A created/joined room or a Quick Match queue entry is held.
  bool roomOpen = false;

  /// Whether sign-in, sign-out, account switching and deletion
  /// must be refused right now.
  bool get identityChangeBlocked => matchActive || roomOpen;

  // --- Shared instance (the FeedbackService pattern) -------------------------

  static IdentityGuard? _shared;

  /// The app-wide guard the online controllers report to, or null
  /// when the accounts feature is off (or a test did not install
  /// one) — in which case nothing guards and nothing needs to:
  /// with no account controller either, there is no identity
  /// change to refuse.
  static IdentityGuard? get shared => _shared;

  /// Installs (or clears, with null) the shared guard. Called by
  /// the app root alongside `AccountService.install`.
  static void install(IdentityGuard? guard) => _shared = guard;
}
