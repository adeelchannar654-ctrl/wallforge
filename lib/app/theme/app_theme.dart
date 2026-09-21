import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_typography.dart';

/// Builds the Wallforge [ThemeData].
///
/// Tactical Neon Arena tokens from Stitch `DESIGN.md`.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.primaryContainer,
      onPrimary: AppColors.onPrimaryContainer,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      shadow: Colors.black,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      surfaceTint: AppColors.surfaceTint,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLg.copyWith(
          color: AppColors.textPrimary,
        ),
        displayMedium: AppTypography.displayMd.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineLarge: AppTypography.headlineLg.copyWith(
          color: AppColors.textPrimary,
        ),
        headlineMedium: AppTypography.headlineMd.copyWith(
          color: AppColors.textPrimary,
        ),
        titleMedium: AppTypography.titleMd.copyWith(color: AppColors.onSurface),
        bodyMedium: AppTypography.bodyBase.copyWith(color: AppColors.onSurface),
        labelLarge: AppTypography.labelCaps.copyWith(
          color: AppColors.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
    );
  }
}
