import 'package:flutter/foundation.dart';

/// The build identifier shown in Settings → Account (Phase 16 A.1),
/// so the owner — and any bug report — can state exactly which build
/// is running. Injected at build/run time:
///
/// ```sh
/// flutter run --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
/// ```
///
/// A build made without the define reports `dev`, which is itself
/// the signal that the copy did not come from the documented flow.
class BuildInfo {
  const BuildInfo._();

  /// The raw injected value, or `dev` when absent.
  static const String gitSha = String.fromEnvironment(
    'GIT_SHA',
    defaultValue: 'dev',
  );

  /// The display label for a raw define value: `Build <sha>`, with
  /// blank or missing values falling back to `dev`. Pure, so the
  /// fallback is unit-testable with fakes.
  static String labelFor(String? sha) {
    final trimmed = sha?.trim() ?? '';
    return 'Build ${trimmed.isEmpty ? 'dev' : trimmed}';
  }

  /// The label for this build.
  static String get label => labelFor(gitSha);
}

/// Whether the weekly leaderboard is compiled in (Phase 16.5,
/// Part H): `--dart-define=FEATURE_LEADERBOARD=true` enables
/// it; debug builds default to on, release builds to OFF
/// unless explicitly enabled — so Phase 17 can ship without
/// it if the owner has not deployed the leaderboard rules or
/// decided on billing.
const bool kFeatureLeaderboard = bool.fromEnvironment(
  'FEATURE_LEADERBOARD',
  defaultValue: kDebugMode,
);

/// Whether the optional accounts UI is compiled in (Phase 16.6):
/// `--dart-define=FEATURE_ACCOUNTS=true` enables it; debug
/// builds default to on, release builds to OFF until the owner
/// has finished the Firebase Console setup in
/// `owner_tests_16_6.md` (providers, fingerprints, templates).
/// With the flag off the app behaves exactly as it did before
/// Phase 16.6: anonymous guest identity, no account UI. Mirrors
/// [kFeatureLeaderboard]'s pattern and reasoning.
const bool kFeatureAccounts = bool.fromEnvironment(
  'FEATURE_ACCOUNTS',
  defaultValue: kDebugMode,
);
