import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the Wallforge [ThemeData].
///
/// Phase 0 provides a dark, low-noise base theme. Board-specific visual
/// treatment is intentionally out of scope until the board-rendering phase.
class AppTheme {
  const AppTheme._();

  /// Shared border radius for cards and primary buttons.
  static const double radius = 12;

  static ThemeData get dark {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.bluePlayer,
          brightness: Brightness.dark,
        ).copyWith(
          surface: AppColors.surface,
          primary: AppColors.bluePlayer,
          secondary: AppColors.redPlayer,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: 4,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.textPrimary),
      ),
    );
  }
}
