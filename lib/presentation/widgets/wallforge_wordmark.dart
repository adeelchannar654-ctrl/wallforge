import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Wallforge wordmark: "WALL" (white) + "FORGE" (cyan).
///
/// Matches the visual from `home_launcher/screen.png` and
/// `wallforge_strategic_logo/screen.png`.
class WallforgeWordmark extends StatelessWidget {
  const WallforgeWordmark({super.key, this.fontSize = 48});

  /// Font size for the display text.
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'WALL',
            style: AppTypography.displayLg.copyWith(
              fontSize: fontSize,
              color: AppColors.textPrimary,
            ),
          ),
          TextSpan(
            text: 'FORGE',
            style: AppTypography.displayLg.copyWith(
              fontSize: fontSize,
              color: AppColors.primaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
