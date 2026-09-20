import 'package:flutter/material.dart';

/// Wallforge colour palette.
///
/// Derived from the visual system in `design.md`:
/// a dark, front-facing, grid-based arena with vivid blue/red players and a
/// green goal area.
///
/// Only the Phase 0 foundation colours are defined here. Board-specific
/// gradients, bevels and glow effects belong to the board-rendering phase.
class AppColors {
  const AppColors._();

  // --- Backgrounds -----------------------------------------------------------

  /// Application background: very dark navy/charcoal.
  static const Color background = Color(0xFF0B1020);

  /// Raised surfaces (cards, panels) slightly lighter than the background.
  static const Color surface = Color(0xFF141B2E);

  /// Board outer frame / board surface. Not pure black.
  static const Color boardSurface = Color(0xFF17233F);

  /// Subtle blue-grey grid line colour.
  static const Color gridLine = Color(0xFF2C3A5C);

  // --- Players ---------------------------------------------------------------

  /// Vivid electric blue used for the blue player and their walls.
  static const Color bluePlayer = Color(0xFF2C7BFF);

  /// Vivid coral-red used for the red player and their walls.
  static const Color redPlayer = Color(0xFFFF4D4D);

  /// Green goal area, distinct from both players.
  static const Color goal = Color(0xFF3DDC84);

  // --- Text ------------------------------------------------------------------

  /// Primary text colour on dark surfaces.
  static const Color textPrimary = Color(0xFFF2F5FF);

  /// Secondary/muted text colour.
  static const Color textSecondary = Color(0xFF9AA6C4);
}
