import 'package:flutter/material.dart';

/// Typography tokens from Stitch `DESIGN.md` §Typography.
///
/// Inter is the only font family. Sizes, weights, line-heights and
/// letter-spacing are copied verbatim from DESIGN.md.
class AppTypography {
  const AppTypography._();

  /// The single font family used across the entire app.
  static const String fontFamily = 'Inter';

  // --- Scale ----------------------------------------------------------------

  /// Display large: 48px / 800 / 56px / +0.08em.
  static const TextStyle displayLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 56 / 48,
    letterSpacing: 0.08,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Display medium: 32px / 800 / 40px / +0.04em.
  static const TextStyle displayMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 40 / 32,
    letterSpacing: 0.04,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Headline large: 24px / 700 / 32px / +0.01em.
  static const TextStyle headlineLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 32 / 24,
    letterSpacing: 0.01,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Headline medium: 20px / 600 / 28px / 0em.
  static const TextStyle headlineMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Title medium: 16px / 600 / 24px / 0em.
  static const TextStyle titleMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Body base: 14px / 400 / 20px / 0em.
  static const TextStyle bodyBase = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Label caps: 12px / 700 / 16px / +0.06em.
  static const TextStyle labelCaps = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    height: 16 / 12,
    letterSpacing: 0.06,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Numeric stat: 20px / 700 / 24px / -0.01em.
  static const TextStyle numericStat = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 24 / 20,
    letterSpacing: -0.01,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Headline large mobile: 28px / 800 / 36px / +0.04em.
  static const TextStyle headlineLgMobile = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 36 / 28,
    letterSpacing: 0.04,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
