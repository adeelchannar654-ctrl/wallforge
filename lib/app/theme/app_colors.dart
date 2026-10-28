import 'package:flutter/material.dart';

import 'app_palette.dart';

export 'app_palette.dart';

/// Tactical Neon Arena colour tokens from Stitch `DESIGN.md`.
///
/// Every colour is sourced from `stitch_wallforge_ui_design_system/.../DESIGN.md`
/// front-matter. Do not invent colours here; log any gap in memory.md.
///
/// **Phase 13:** the values live in [AppPalette] and every token here
/// delegates to the *current* palette, which the app root selects from
/// the persisted accessibility settings (high contrast and colour
/// assistance — `design.md` §23/§26). Call sites are unchanged; only
/// `const` contexts had to give up their `const`, because the values
/// are now runtime-selected. The default palette is bit-identical to
/// the pre-Phase-13 constants (pinned by a snapshot test).
class AppColors {
  const AppColors._();

  static AppPalette _current = const AppPalette();

  /// The palette every token currently resolves through.
  static AppPalette get current => _current;

  /// Selects the active palette. Called by the app root whenever the
  /// persisted accessibility settings load or change; widgets rebuild
  /// through the app root's listener, so no call site does anything.
  static void applyPalette(AppPalette palette) => _current = palette;

  // --- Core surfaces -------------------------------------------------

  static Color get surface => _current.surface;
  static Color get surfaceDim => _current.surfaceDim;
  static Color get surfaceBright => _current.surfaceBright;
  static Color get surfaceContainerLowest => _current.surfaceContainerLowest;
  static Color get surfaceContainerLow => _current.surfaceContainerLow;
  static Color get surfaceContainer => _current.surfaceContainer;
  static Color get surfaceContainerHigh => _current.surfaceContainerHigh;
  static Color get surfaceContainerHighest => _current.surfaceContainerHighest;

  // --- Text / content --------------------------------------------------

  static Color get onSurface => _current.onSurface;
  static Color get onSurfaceVariant => _current.onSurfaceVariant;
  static Color get inverseSurface => _current.inverseSurface;
  static Color get inverseOnSurface => _current.inverseOnSurface;

  // --- Outline / structural --------------------------------------------

  static Color get outline => _current.outline;
  static Color get outlineVariant => _current.outlineVariant;

  // --- Tint --------------------------------------------------------------

  static Color get surfaceTint => _current.surfaceTint;

  // --- Primary (Player 1 / Cyan) -----------------------------------------

  static Color get primary => _current.primary;
  static Color get onPrimary => _current.onPrimary;
  static Color get primaryContainer => _current.primaryContainer;
  static Color get onPrimaryContainer => _current.onPrimaryContainer;
  static Color get inversePrimary => _current.inversePrimary;
  static Color get primaryFixed => _current.primaryFixed;
  static Color get primaryFixedDim => _current.primaryFixedDim;
  static Color get onPrimaryFixed => _current.onPrimaryFixed;
  static Color get onPrimaryFixedVariant => _current.onPrimaryFixedVariant;

  // --- Secondary (Player 2 / Crimson) ------------------------------------

  static Color get secondary => _current.secondary;
  static Color get onSecondary => _current.onSecondary;
  static Color get secondaryContainer => _current.secondaryContainer;
  static Color get onSecondaryContainer => _current.onSecondaryContainer;
  static Color get secondaryFixed => _current.secondaryFixed;
  static Color get secondaryFixedDim => _current.secondaryFixedDim;
  static Color get onSecondaryFixed => _current.onSecondaryFixed;
  static Color get onSecondaryFixedVariant => _current.onSecondaryFixedVariant;

  // --- Tertiary (Goal / Emerald) -----------------------------------------

  static Color get tertiary => _current.tertiary;
  static Color get onTertiary => _current.onTertiary;
  static Color get tertiaryContainer => _current.tertiaryContainer;
  static Color get onTertiaryContainer => _current.onTertiaryContainer;
  static Color get tertiaryFixed => _current.tertiaryFixed;
  static Color get tertiaryFixedDim => _current.tertiaryFixedDim;
  static Color get onTertiaryFixed => _current.onTertiaryFixed;
  static Color get onTertiaryFixedVariant => _current.onTertiaryFixedVariant;

  // --- Error ---------------------------------------------------------------

  static Color get error => _current.error;
  static Color get onError => _current.onError;
  static Color get errorContainer => _current.errorContainer;
  static Color get onErrorContainer => _current.onErrorContainer;

  // --- Named convenience aliases -------------------------------------------

  static Color get background => _current.surface;
  static Color get onBackground => _current.onSurface;
  static Color get surfaceVariant => _current.surfaceContainerHighest;
  static Color get bluePlayer => _current.bluePlayer;
  static Color get redPlayer => _current.redPlayer;
  static Color get goal => _current.tertiaryContainer;

  // --- Text convenience ------------------------------------------------------

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get border => _current.border;

  // --- Board-specific ---------------------------------------------------------

  static Color get boardOuter => _current.boardOuter;
  static Color get tileColor => _current.tileColor;
  static Color get groove => _current.groove;
  static Color get gridSurface => _current.gridSurface;

  // --- Pawn gradients (Phase 13: palette-driven for colour assistance) --------

  static List<Color> get pawnGradientBlue => _current.pawnGradientBlue;
  static List<Color> get pawnGradientRed => _current.pawnGradientRed;
}
