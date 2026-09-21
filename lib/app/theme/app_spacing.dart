/// Spacing and layout tokens from Stitch `DESIGN.md`.
///
/// All layout spacing must use these values instead of arbitrary numbers.
/// Base module: 4px.
class AppSpacing {
  const AppSpacing._();

  /// 4px — xs / space-xs.
  static const double xs = 4;

  /// 8px — sm / space-sm.
  static const double sm = 8;

  /// 12px — md / space-md.
  static const double md = 12;

  /// 16px — lg / space-lg / gutter.
  static const double lg = 16;

  /// 24px — xl / space-xl.
  static const double xl = 24;

  /// 32px — xxl.
  static const double xxl = 32;

  /// 48px — xxxl.
  static const double xxxl = 48;

  /// 64px — huge.
  static const double huge = 64;

  /// Outer margin for mobile (< 768px).
  static const double marginMobile = 16;

  /// Outer margin for desktop (>= 768px).
  static const double marginDesktop = 32;

  /// Gutter (alias for lg).
  static const double gutter = lg;
}
