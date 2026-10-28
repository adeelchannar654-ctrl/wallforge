import 'package:flutter/material.dart';

/// A complete set of Wallforge colour tokens (Phase 13).
///
/// Until Phase 13 the tokens were compile-time constants in
/// `AppColors`, which made any runtime variant impossible. They now
/// live in a palette object: [AppColors] delegates every token to the
/// *current* palette, and the app root selects the palette from the
/// persisted accessibility settings. The **default palette's values are
/// exactly the pre-Phase-13 constants** (pinned by a token snapshot
/// test), so the standard appearance does not change by a single bit.
///
/// Variants (composed by [AppPalette.resolve]):
///
/// * **Color assistance** swaps the player-identity colours to the
///   Okabe–Ito colour-blind-safe pair — blue `#0072B2` and orange
///   `#E69F00` — chosen because that pair remains separable under
///   deuteranopia, protanopia and tritanopia (verified by simulation
///   in the Phase 13 tests; `memory.md` §13v). Identity never rests on
///   these colours alone (`design.md` §26): pawns also carry B/R
///   letters and every player mention in the UI is text.
/// * **High contrast** raises surfaces to true black and text/borders
///   to values whose WCAG contrast ratios are computed and asserted in
///   the Phase 13 tests (main text pairs ≥ 4.5:1, most ≥ 7:1).
class AppPalette {
  const AppPalette({
    this.surface = const Color(0xFF0E131E),
    this.surfaceDim = const Color(0xFF0E131E),
    this.surfaceBright = const Color(0xFF343946),
    this.surfaceContainerLowest = const Color(0xFF090E19),
    this.surfaceContainerLow = const Color(0xFF171B27),
    this.surfaceContainer = const Color(0xFF1B1F2B),
    this.surfaceContainerHigh = const Color(0xFF252A36),
    this.surfaceContainerHighest = const Color(0xFF303541),
    this.onSurface = const Color(0xFFDEE2F2),
    this.onSurfaceVariant = const Color(0xFFBAC9CC),
    this.inverseSurface = const Color(0xFFDEE2F2),
    this.inverseOnSurface = const Color(0xFF2B303C),
    this.outline = const Color(0xFF849396),
    this.outlineVariant = const Color(0xFF3B494C),
    this.surfaceTint = const Color(0xFF00DAF3),
    this.primary = const Color(0xFFC3F5FF),
    this.onPrimary = const Color(0xFF00363D),
    this.primaryContainer = const Color(0xFF00E5FF),
    this.onPrimaryContainer = const Color(0xFF00626E),
    this.inversePrimary = const Color(0xFF006875),
    this.primaryFixed = const Color(0xFF9CF0FF),
    this.primaryFixedDim = const Color(0xFF00DAF3),
    this.onPrimaryFixed = const Color(0xFF001F24),
    this.onPrimaryFixedVariant = const Color(0xFF004F58),
    this.secondary = const Color(0xFFFFB2B9),
    this.onSecondary = const Color(0xFF67001F),
    this.secondaryContainer = const Color(0xFFB0003A),
    this.onSecondaryContainer = const Color(0xFFFFBCC2),
    this.secondaryFixed = const Color(0xFFFFDADC),
    this.secondaryFixedDim = const Color(0xFFFFB2B9),
    this.onSecondaryFixed = const Color(0xFF400010),
    this.onSecondaryFixedVariant = const Color(0xFF91002F),
    this.tertiary = const Color(0xFFA8FFD2),
    this.onTertiary = const Color(0xFF003824),
    this.tertiaryContainer = const Color(0xFF5BE9AD),
    this.onTertiaryContainer = const Color(0xFF006645),
    this.tertiaryFixed = const Color(0xFF6FFBBE),
    this.tertiaryFixedDim = const Color(0xFF4EDEA3),
    this.onTertiaryFixed = const Color(0xFF002113),
    this.onTertiaryFixedVariant = const Color(0xFF005236),
    this.error = const Color(0xFFFFB4AB),
    this.onError = const Color(0xFF690005),
    this.errorContainer = const Color(0xFF93000A),
    this.onErrorContainer = const Color(0xFFFFDAD6),
    this.textPrimary = const Color(0xFFF8FAFC),
    this.textSecondary = const Color(0xFF94A3B8),
    this.border = const Color(0xFF334155),
    this.boardOuter = const Color(0xFF0E1526),
    this.tileColor = const Color(0xFF17233F),
    this.groove = const Color(0xFF2C3A5C),
    this.gridSurface = const Color(0xFF090E19),
    this.bluePlayer = const Color(0xFF00E5FF),
    this.redPlayer = const Color(0xFFB0003A),
    this.pawnGradientBlue = const <Color>[
      Color(0xFFD9FBFF),
      Color(0xFF00DAF3),
      Color(0xFF004F58),
    ],
    this.pawnGradientRed = const <Color>[
      Color(0xFFFF8FA3),
      Color(0xFFE6004C),
      Color(0xFF67001F),
    ],
  });

  /// The palette for the persisted accessibility settings: the
  /// high-contrast surfaces/text when [highContrast] is on, and the
  /// colour-blind-safe player pair when [colorAssistance] is on. The
  /// two axes compose (both may be on at once).
  factory AppPalette.resolve({
    required bool highContrast,
    required bool colorAssistance,
  }) {
    if (!highContrast && !colorAssistance) return const AppPalette();
    return AppPalette(
      // --- High-contrast surfaces and text -------------------------
      surface: highContrast ? const Color(0xFF000000) : const Color(0xFF0E131E),
      surfaceDim: highContrast
          ? const Color(0xFF000000)
          : const Color(0xFF0E131E),
      surfaceBright: highContrast
          ? const Color(0xFF3A3A46)
          : const Color(0xFF343946),
      surfaceContainerLowest: highContrast
          ? const Color(0xFF000000)
          : const Color(0xFF090E19),
      surfaceContainerLow: highContrast
          ? const Color(0xFF0D0D12)
          : const Color(0xFF171B27),
      surfaceContainer: highContrast
          ? const Color(0xFF141419)
          : const Color(0xFF1B1F2B),
      surfaceContainerHigh: highContrast
          ? const Color(0xFF1E1E26)
          : const Color(0xFF252A36),
      surfaceContainerHighest: highContrast
          ? const Color(0xFF2A2A35)
          : const Color(0xFF303541),
      onSurface: highContrast
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFDEE2F2),
      onSurfaceVariant: highContrast
          ? const Color(0xFFD7DBE2)
          : const Color(0xFFBAC9CC),
      inverseSurface: highContrast
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFDEE2F2),
      inverseOnSurface: highContrast
          ? const Color(0xFF000000)
          : const Color(0xFF2B303C),
      outline: highContrast ? const Color(0xFFC6CBD4) : const Color(0xFF849396),
      outlineVariant: highContrast
          ? const Color(0xFF6E7684)
          : const Color(0xFF3B494C),
      textPrimary: highContrast
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFF8FAFC),
      textSecondary: highContrast
          ? const Color(0xFFD7DBE2)
          : const Color(0xFF94A3B8),
      border: highContrast ? const Color(0xFF6E7684) : const Color(0xFF334155),
      boardOuter: highContrast
          ? const Color(0xFF000000)
          : const Color(0xFF0E1526),
      tileColor: highContrast
          ? const Color(0xFF101018)
          : const Color(0xFF17233F),
      groove: highContrast ? const Color(0xFF454552) : const Color(0xFF2C3A5C),
      gridSurface: highContrast
          ? const Color(0xFF000000)
          : const Color(0xFF090E19),
      // --- Colour-assistance player pair (Okabe–Ito) ---------------
      bluePlayer: colorAssistance
          ? const Color(0xFF0072B2)
          : const Color(0xFF00E5FF),
      redPlayer: colorAssistance
          ? const Color(0xFFE69F00)
          : const Color(0xFFB0003A),
      pawnGradientBlue: colorAssistance
          ? const <Color>[
              Color(0xFFBEE3F5),
              Color(0xFF0072B2),
              Color(0xFF003A5C),
            ]
          : const <Color>[
              Color(0xFFD9FBFF),
              Color(0xFF00DAF3),
              Color(0xFF004F58),
            ],
      pawnGradientRed: colorAssistance
          ? const <Color>[
              Color(0xFFFFE1A8),
              Color(0xFFE69F00),
              Color(0xFF7A5200),
            ]
          : const <Color>[
              Color(0xFFFF8FA3),
              Color(0xFFE6004C),
              Color(0xFF67001F),
            ],
    );
  }

  final Color surface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color outline;
  final Color outlineVariant;
  final Color surfaceTint;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color inversePrimary;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color onPrimaryFixedVariant;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixed;
  final Color onSecondaryFixedVariant;
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixed;
  final Color onTertiaryFixedVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color boardOuter;
  final Color tileColor;
  final Color groove;
  final Color gridSurface;

  /// The board/HUD colour identifying the Blue player. Follows the
  /// colour-assistance setting via [AppPalette.resolve].
  final Color bluePlayer;

  /// The board/HUD colour identifying the Red player.
  final Color redPlayer;

  /// The Blue pawn's gradient stops (bright → identity → deep).
  final List<Color> pawnGradientBlue;

  /// The Red pawn's gradient stops.
  final List<Color> pawnGradientRed;
}
