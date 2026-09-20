/// Static, presentation-agnostic application metadata.
///
/// Keeping product strings in one place avoids magic strings scattered across
/// the presentation layer and gives later phases a single source of truth.
class AppInfo {
  const AppInfo._();

  /// Product name used for branding and platform surfaces.
  static const String appName = 'Wallforge';

  /// Short marketing tagline defined in `design.md`.
  static const String tagline = 'Forge your path. Block your rival.';

  /// One-line description used on the web manifest and store metadata.
  static const String description =
      'A two-player strategy board game of movement and walls.';
}
