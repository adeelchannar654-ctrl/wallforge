import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/constants/app_info.dart';

/// Minimal Phase 0 application shell.
///
/// This screen proves the foundation works: theme, routing and branding are
/// wired end-to-end. The full home screen (Play button, mode options,
/// profile/settings access and board preview) belongs to the UI phase and is
/// intentionally not implemented here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                AppInfo.appName.toUpperCase(),
                textAlign: TextAlign.center,
                style: text.displayLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppInfo.tagline,
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              // Neutral shell marker: explicitly NOT gameplay or a board.
              Text(
                'Phase 0 — project foundation',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
