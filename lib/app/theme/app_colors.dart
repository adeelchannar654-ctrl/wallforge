import 'package:flutter/material.dart';

/// Tactical Neon Arena colour tokens from Stitch `DESIGN.md`.
///
/// Every colour is sourced from `stitch_wallforge_ui_design_system/.../DESIGN.md`
/// front-matter. Do not invent colours here; log any gap in memory.md.
class AppColors {
  const AppColors._();

  // --- Core surfaces (DESIGN.md §Colors front-matter) -----------------------

  static const Color surface = Color(0xFF0E131E);
  static const Color surfaceDim = Color(0xFF0E131E);
  static const Color surfaceBright = Color(0xFF343946);
  static const Color surfaceContainerLowest = Color(0xFF090E19);
  static const Color surfaceContainerLow = Color(0xFF171B27);
  static const Color surfaceContainer = Color(0xFF1B1F2B);
  static const Color surfaceContainerHigh = Color(0xFF252A36);
  static const Color surfaceContainerHighest = Color(0xFF303541);

  // --- Text / content -------------------------------------------------------

  static const Color onSurface = Color(0xFFDEE2F2);
  static const Color onSurfaceVariant = Color(0xFFBAC9CC);
  static const Color inverseSurface = Color(0xFFDEE2F2);
  static const Color inverseOnSurface = Color(0xFF2B303C);

  // --- Outline / structural -------------------------------------------------

  static const Color outline = Color(0xFF849396);
  static const Color outlineVariant = Color(0xFF3B494C);

  // --- Tint -----------------------------------------------------------------

  static const Color surfaceTint = Color(0xFF00DAF3);

  // --- Primary (Player 1 / Cyan) --------------------------------------------

  static const Color primary = Color(0xFFC3F5FF);
  static const Color onPrimary = Color(0xFF00363D);
  static const Color primaryContainer = Color(0xFF00E5FF);
  static const Color onPrimaryContainer = Color(0xFF00626E);
  static const Color inversePrimary = Color(0xFF006875);
  static const Color primaryFixed = Color(0xFF9CF0FF);
  static const Color primaryFixedDim = Color(0xFF00DAF3);
  static const Color onPrimaryFixed = Color(0xFF001F24);
  static const Color onPrimaryFixedVariant = Color(0xFF004F58);

  // --- Secondary (Player 2 / Crimson) ---------------------------------------

  static const Color secondary = Color(0xFFFFB2B9);
  static const Color onSecondary = Color(0xFF67001F);
  static const Color secondaryContainer = Color(0xFFB0003A);
  static const Color onSecondaryContainer = Color(0xFFFFBCC2);
  static const Color secondaryFixed = Color(0xFFFFDADC);
  static const Color secondaryFixedDim = Color(0xFFFFB2B9);
  static const Color onSecondaryFixed = Color(0xFF400010);
  static const Color onSecondaryFixedVariant = Color(0xFF91002F);

  // --- Tertiary (Goal / Emerald) --------------------------------------------

  static const Color tertiary = Color(0xFFA8FFD2);
  static const Color onTertiary = Color(0xFF003824);
  static const Color tertiaryContainer = Color(0xFF5BE9AD);
  static const Color onTertiaryContainer = Color(0xFF006645);
  static const Color tertiaryFixed = Color(0xFF6FFBBE);
  static const Color tertiaryFixedDim = Color(0xFF4EDea3);
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF005236);

  // --- Error ----------------------------------------------------------------

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  // --- Named convenience aliases (match common usage) -----------------------

  static const Color background = surface;
  static const Color onBackground = onSurface;
  static const Color surfaceVariant = surfaceContainerHighest;
  static const Color bluePlayer = primaryContainer;
  static const Color redPlayer = secondaryContainer;
  static const Color goal = tertiaryContainer;

  // --- Text convenience (from §Colors "Text & Borders") ----------------------

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color border = Color(0xFF334155);

  // --- Board-specific (from main_gameplay_screen/code.html) -----------------

  static const Color boardOuter = Color(0xFF0E1526);
  static const Color tileColor = Color(0xFF17233F);
  static const Color groove = Color(0xFF2C3A5C);
  static const Color gridSurface = Color(0xFF090E19);
}
