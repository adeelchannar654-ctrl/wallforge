import '../../../domain/repositories/auth.dart';

/// Every player-facing account string (Phase 16.6, Part D), in one
/// place — the project's rule for user text, and the single home of
/// the [AuthError] → plain-language mapping, so an error reads the
/// same way on every surface that shows it.
abstract final class AccountCopy {
  // --- Status -----------------------------------------------------------------

  /// The guest status line (prompt wording, Part D).
  static const String guestStatus =
      'Playing as guest — sign in to keep your online identity';

  /// Why sign in, stated plainly (Part B decision 5: what an
  /// account does and does not buy).
  static const String guestExplainer =
      'As a guest your online identity lives only on this device. '
      'Sign in and it follows you to a new phone or a reinstall, '
      'and your leaderboard results are kept under your account. '
      'Local and AI games never need an account.';

  /// Signed in with Google.
  static const String signedInGoogle = 'Signed in with Google';

  /// Signed in with email.
  static const String signedInEmail = 'Signed in with email';

  /// Accounts cannot be reached (offline, or a build without
  /// Firebase configured). Play itself is unaffected.
  static const String unavailable =
      'Accounts are unavailable right now. You can keep playing '
      'as a guest — nothing here blocks a game.';

  /// Shown before the account layer has produced any state.
  static const String notStarted =
      'Not signed in yet. Online play signs you in anonymously.';

  // --- The device-data policy (D16.6-6), stated where players act ---------------

  /// The local-data policy, shown on the Account screen and
  /// summarised wherever identity changes are offered.
  static const String localDataNote =
      'Your match history, achievements and statistics totals are '
      'stored on this device. Signing in, switching accounts or '
      'signing out never deletes or merges them, and a second '
      'person using this device sees the same device progress — '
      'but never your email address or account details. Match '
      'history itself is never uploaded: an account keeps only '
      'your display name, your unlocked achievements and your '
      'statistics totals.';

  /// The explicit, separate device-clearing action.
  static const String clearProgressTitle = "Clear this device's progress?";

  /// What clearing removes — and what it deliberately keeps.
  static const String clearProgressBody =
      'This removes this device\u2019s match history list, unlocked '
      'achievements, statistics and any unfinished match. Your '
      'settings stay as they are, and if you are signed in, the '
      'copy kept with your account is not touched. This cannot '
      'be undone.';

  // --- Sign-out warnings ---------------------------------------------------------

  /// Shown before a guest signs out: that identity is gone for
  /// good (Part C requirement).
  static const String signOutGuestWarning =
      'You are playing as a guest. If you sign out, this guest '
      'identity is gone for good — its rooms and leaderboard '
      'entries cannot be reached again. Your progress on this '
      'device is kept either way.';

  /// Shown before an account signs out.
  static const String signOutAccountNote =
      'You will come back as a new guest. Your account — and the '
      'identity saved with it — will be there when you sign in '
      'again, on this device or any other. This device\u2019s '
      'progress is kept.';

  // --- Conflict (D16.6-4) ----------------------------------------------------------

  /// The conflict heading: the credential belongs to an account.
  static const String conflictTitle = 'That sign-in already has an account';

  /// The conflict explanation for Google.
  static const String conflictGoogleBody =
      'The Google account you chose is already linked to a '
      'different Wallforge account. Sign in to that account '
      'instead — this device\u2019s guest identity will be left '
      'behind, and this device\u2019s progress stays exactly as '
      'it is — or cancel and keep playing as this guest. The '
      'two are never merged automatically.';

  /// The conflict explanation for email.
  static String conflictEmailBody(String email) =>
      'The address $email already belongs to a different '
      'Wallforge account. Sign in to that account instead — '
      'this device\u2019s guest identity will be left behind, '
      'and this device\u2019s progress stays exactly as it is — '
      'or cancel and keep playing as this guest. The two are '
      'never merged automatically.';

  // --- Verification ------------------------------------------------------------------

  /// The verification-pending state.
  static const String verificationPending =
      'Your email address is not verified yet. Check your inbox '
      'for the verification link, tap it, then come back and '
      'refresh. Until then your online matches do not count on '
      'the leaderboard.';

  /// After a verification email is sent.
  static const String verificationSent =
      'Verification email sent. Check your inbox.';

  // --- Password reset ---------------------------------------------------------------------

  /// After a reset request — true whether or not the account
  /// exists, on purpose (D16.6-5).
  static const String resetSent =
      'If an account exists for that email address, a password '
      'reset link is on its way.';

  /// The hint when Forgot password is tapped with no email.
  static const String resetNeedsEmail =
      'Enter your email address above first, then tap '
      'Forgot password.';

  // --- Leaderboard prompt (Part D) -----------------------------------------------------------

  /// The gentle, dismissible guest prompt on the leaderboard.
  static const String leaderboardGuestPrompt =
      'You are playing as a guest, so your matches do not count '
      'here. Sign in and wins start counting — guests can always '
      'view the board and play online.';

  /// The prompt variant for an unverified email account.
  static const String leaderboardUnverifiedPrompt =
      'Your email address is not verified yet, so your matches '
      'do not count here. Verify it from the Account screen '
      'and wins start counting.';

  /// The leaderboard footer's account sentence (D16.6-10).
  static const String leaderboardAccountRule =
      ' Only matches played while signed in with a real account '
      'count — email accounts must be verified first. Guests '
      'can view the board and play online as always.';

  // --- Deletion (Part F wording lives here too, one home for strings) ----------------------------

  /// What deletion removes and what it deliberately leaves.
  static const String deleteExplainer =
      'Deleting your account removes your sign-in and the small '
      'profile kept with it (display name, achievements, '
      'statistics totals). Two things stay, on purpose: your '
      'leaderboard entries remain under your generated display '
      'name — deleting them would let results be counted twice, '
      'and the name identifies nobody — and matches you played '
      'keep an empty player slot. Nothing stored only on this '
      'device is removed; use "Clear this device\u2019s progress" '
      'for that. This cannot be undone.';

  /// The typed-error → plain-language mapping. Exactly one
  /// message per [AuthError]; raw provider text never appears.
  static String errorMessage(AuthError error) => switch (error) {
    AuthError.cancelled => 'Sign-in was cancelled. Nothing changed.',
    AuthError.offline =>
      'You appear to be offline. Check your connection and try again.',
    AuthError.invalidCredentials =>
      'That email and password were not accepted together. '
          'Check both and try again.',
    AuthError.emailAlreadyInUse =>
      'An account already uses that email address.',
    AuthError.weakPassword =>
      'That password is too short. Use at least '
          '${AccountPolicy.minPasswordLength} characters.',
    AuthError.invalidEmail =>
      'That email address does not look complete. Check it '
          'and try again.',
    AuthError.tooManyRequests =>
      'Too many attempts in a row. Wait a little while, then '
          'try again.',
    AuthError.requiresRecentLogin =>
      'For security, confirm your password to continue.',
    AuthError.credentialInUseByOtherAccount =>
      'That sign-in already belongs to a different Wallforge '
          'account.',
    AuthError.blockedByLiveMatch =>
      'Finish or leave your current match first — your '
          'identity cannot change while a match or room is open.',
    AuthError.unavailable =>
      'Accounts are unavailable right now. You can keep '
          'playing as a guest.',
    AuthError.unknown => 'Something went wrong. Please try again.',
  };
}
