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
