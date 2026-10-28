import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/theme/app_palette.dart';
import 'package:wallforge/domain/repositories/app_settings.dart';

/// Phase 13 — palette, contrast, colour-vision and settings tests.
///
/// These are computed checks, not visual ones: WCAG contrast ratios are
/// calculated from the palette's actual values, and the colour
/// assistance pair is run through published colour-vision-deficiency
/// simulation matrices (Machado, Oliveira & Fernandes 2009, severity
/// 1.0). The measured numbers are recorded in `memory.md` §13v.

double _luminance(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Machado et al. (2009) simulation matrices, severity 1.0.
const _protan = <List<double>>[
  <double>[0.567, 0.433, 0],
  <double>[0.558, 0.442, 0],
  <double>[0, 0.242, 0.758],
];
const _deutan = <List<double>>[
  <double>[0.625, 0.375, 0],
  <double>[0.7, 0.3, 0],
  <double>[0, 0.3, 0.7],
];
const _tritan = <List<double>>[
  <double>[0.95, 0.05, 0],
  <double>[0, 0.433, 0.567],
  <double>[0, 0.475, 0.525],
];

List<double> _simulate(Color c, List<List<double>> m) {
  final rgb = <double>[c.r * 255, c.g * 255, c.b * 255];
  return <double>[
    for (var row = 0; row < 3; row++)
      m[row][0] * rgb[0] + m[row][1] * rgb[1] + m[row][2] * rgb[2],
  ];
}

double _distance(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var i = 0; i < 3; i++) {
    sum += math.pow(a[i] - b[i], 2).toDouble();
  }
  return math.sqrt(sum);
}

void main() {
  group('AppSettings — Phase 13 fields', () {
    test('round-trips colorAssistance, highContrast and uiScale', () {
      const settings = AppSettings(
        colorAssistance: true,
        highContrast: true,
        uiScale: 1.3,
      );
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored, settings);
      expect(restored.colorAssistance, isTrue);
      expect(restored.highContrast, isTrue);
      expect(restored.uiScale, 1.3);
    });

    test('defaults are off/off/1.0 and survive missing or malformed data', () {
      expect(AppSettings.defaults.colorAssistance, isFalse);
      expect(AppSettings.defaults.highContrast, isFalse);
      expect(AppSettings.defaults.uiScale, 1.0);
      final restored = AppSettings.fromJson(<String, dynamic>{
        'colorAssistance': 'yes',
        'highContrast': 1,
        'uiScale': 'big',
      });
      expect(restored, AppSettings.defaults);
      expect(AppSettings.fromJson(null), AppSettings.defaults);
      expect(
        AppSettings.fromJson(const <String, dynamic>{}),
        AppSettings.defaults,
      );
    });

    test('uiScale is clamped to the offered range', () {
      expect(
        AppSettings.fromJson(const <String, dynamic>{'uiScale': 7}).uiScale,
        AppSettings.maxUiScale,
      );
      expect(
        AppSettings.fromJson(const <String, dynamic>{'uiScale': 0.2}).uiScale,
        AppSettings.defaultUiScale,
      );
      expect(
        AppSettings.fromJson(const <String, dynamic>{'uiScale': 1}).uiScale,
        1.0,
      );
    });

    test('copyWith and equality cover the new fields', () {
      const base = AppSettings();
      final changed = base.copyWith(highContrast: true);
      expect(changed, isNot(base));
      expect(changed.copyWith(highContrast: false), base);
      expect(base.copyWith(uiScale: 1.5).uiScale, 1.5);
    });
  });

  group('AppPalette', () {
    test('the default palette is bit-identical to the pre-Phase-13 '
        'constants', () {
      const p = AppPalette();
      // The full historical token snapshot (from the old AppColors).
      expect(p.surface, const Color(0xFF0E131E));
      expect(p.surfaceContainer, const Color(0xFF1B1F2B));
      expect(p.surfaceContainerHigh, const Color(0xFF252A36));
      expect(p.onSurface, const Color(0xFFDEE2F2));
      expect(p.onSurfaceVariant, const Color(0xFFBAC9CC));
      expect(p.outline, const Color(0xFF849396));
      expect(p.outlineVariant, const Color(0xFF3B494C));
      expect(p.primaryContainer, const Color(0xFF00E5FF));
      expect(p.secondary, const Color(0xFFFFB2B9));
      expect(p.secondaryContainer, const Color(0xFFB0003A));
      expect(p.tertiaryContainer, const Color(0xFF5BE9AD));
      expect(p.error, const Color(0xFFFFB4AB));
      expect(p.textPrimary, const Color(0xFFF8FAFC));
      expect(p.textSecondary, const Color(0xFF94A3B8));
      expect(p.boardOuter, const Color(0xFF0E1526));
      expect(p.tileColor, const Color(0xFF17233F));
      expect(p.groove, const Color(0xFF2C3A5C));
      expect(p.bluePlayer, const Color(0xFF00E5FF));
      expect(p.redPlayer, const Color(0xFFB0003A));
      expect(p.pawnGradientBlue, const <Color>[
        Color(0xFFD9FBFF),
        Color(0xFF00DAF3),
        Color(0xFF004F58),
      ]);
      expect(p.pawnGradientRed, const <Color>[
        Color(0xFFFF8FA3),
        Color(0xFFE6004C),
        Color(0xFF67001F),
      ]);
      expect(
        AppPalette.resolve(highContrast: false, colorAssistance: false),
        isA<AppPalette>(),
      );
      final resolved = AppPalette.resolve(
        highContrast: false,
        colorAssistance: false,
      );
      expect(resolved.surface, p.surface);
      expect(resolved.bluePlayer, p.bluePlayer);
    });

    test('colour assistance swaps only the player-identity colours', () {
      final assisted = AppPalette.resolve(
        highContrast: false,
        colorAssistance: true,
      );
      expect(assisted.bluePlayer, const Color(0xFF0072B2)); // Okabe–Ito blue
      expect(assisted.redPlayer, const Color(0xFFE69F00)); // Okabe–Ito orange
      expect(assisted.pawnGradientBlue[1], const Color(0xFF0072B2));
      expect(assisted.pawnGradientRed[1], const Color(0xFFE69F00));
      // Everything else is the default palette.
      expect(assisted.surface, const AppPalette().surface);
      expect(assisted.onSurface, const AppPalette().onSurface);
      expect(assisted.primaryContainer, const AppPalette().primaryContainer);
    });

    test('high contrast composes with colour assistance', () {
      final both = AppPalette.resolve(
        highContrast: true,
        colorAssistance: true,
      );
      expect(both.surface, const Color(0xFF000000));
      expect(both.bluePlayer, const Color(0xFF0072B2));
      expect(both.redPlayer, const Color(0xFFE69F00));
      final hcOnly = AppPalette.resolve(
        highContrast: true,
        colorAssistance: false,
      );
      expect(hcOnly.bluePlayer, const Color(0xFF00E5FF));
    });
  });

  group('WCAG contrast (computed from the palette values)', () {
    final hc = AppPalette.resolve(highContrast: true, colorAssistance: false);

    test('high-contrast text pairs meet WCAG AA (≥ 4.5), most at AAA', () {
      // Main text.
      expect(contrastRatio(hc.onSurface, hc.surface), greaterThanOrEqualTo(7));
      expect(
        contrastRatio(hc.onSurface, hc.surfaceContainer),
        greaterThanOrEqualTo(7),
      );
      expect(
        contrastRatio(hc.onSurface, hc.surfaceContainerHigh),
        greaterThanOrEqualTo(7),
      );
      // Secondary text.
      expect(
        contrastRatio(hc.onSurfaceVariant, hc.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(hc.onSurfaceVariant, hc.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(hc.textSecondary, hc.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      // Identity/banner text accents.
      expect(
        contrastRatio(hc.primaryContainer, hc.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(hc.secondary, hc.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5),
      );
      // Error text.
      expect(
        contrastRatio(hc.error, hc.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      // Borders/outlines are visible (non-text ≥ 3).
      expect(contrastRatio(hc.outline, hc.surface), greaterThanOrEqualTo(3));
      expect(
        contrastRatio(hc.outlineVariant, hc.surface),
        greaterThanOrEqualTo(3),
      );
    });

    test('the default palette main text already meets AA, and the '
        'Phase 13 banner-token change fixed the one failing pair', () {
      const d = AppPalette();
      expect(contrastRatio(d.onSurface, d.surface), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(d.onSurfaceVariant, d.surfaceContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(d.primaryContainer, d.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5),
      );
      // The banner's Red text now uses `secondary` (light tint)...
      expect(
        contrastRatio(d.secondary, d.surfaceContainerHigh),
        greaterThanOrEqualTo(4.5),
      );
      // ...because the old token for that text, the deep container
      // crimson, genuinely failed (≈ 2:1, measured in §13v).
      expect(
        contrastRatio(d.secondaryContainer, d.surfaceContainerHigh),
        lessThan(3),
      );
    });
  });

  group('colour-vision simulation (Machado et al. 2009)', () {
    final assisted = AppPalette.resolve(
      highContrast: false,
      colorAssistance: true,
    );

    test('the assisted player pair stays clearly separable under '
        'protanopia, deuteranopia and tritanopia', () {
      for (final (name, matrix) in <(String, List<List<double>>)>[
        ('protanopia', _protan),
        ('deuteranopia', _deutan),
        ('tritanopia', _tritan),
      ]) {
        final d = _distance(
          _simulate(assisted.bluePlayer, matrix),
          _simulate(assisted.redPlayer, matrix),
        );
        // Measured: 245 / 262 / 246 (of a 441 maximum). The threshold
        // leaves generous margin while still proving separation.
        expect(d, greaterThan(200), reason: '$name distance was $d');
      }
    });

    test('the assisted pair differs in simulated lightness too, so it '
        'does not rest on hue alone', () {
      for (final matrix in <List<List<double>>>[_protan, _deutan, _tritan]) {
        final a = _simulate(assisted.bluePlayer, matrix);
        final b = _simulate(assisted.redPlayer, matrix);
        final lightnessGap =
            (0.2126 * a[0] + 0.7152 * a[1] + 0.0722 * a[2]) -
            (0.2126 * b[0] + 0.7152 * b[1] + 0.0722 * b[2]);
        // Measured gaps: 129 (protan), 151 (deutan), 16.5 (tritan).
        expect(lightnessGap.abs(), greaterThan(10));
      }
    });
  });
}
