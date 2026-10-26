import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_info.dart';
import '../../widgets/wallforge_logo.dart';
import '../../widgets/wallforge_wordmark.dart';

/// The branding beat shown at launch (Stitch `splash_screen`).
///
/// Deliberately honest: the Stitch mock surrounds the logo with telemetry
/// ("60 FPS", "ONLINE ARENA", shader/load readouts, a hard-coded version) —
/// none of that is real in this app, so none of it is shown. The splash is
/// not a loading gate: the app has no heavy assets to load, and the
/// persistence/auth bootstrap is already fire-and-forget in `main()`. It is
/// shown for a short fixed beat ([displayDuration]) and then replaces itself
/// with Home. A tap skips the wait.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.displayDuration = _defaultDuration});

  static const Duration _defaultDuration = Duration(milliseconds: 1200);

  /// How long the brand is shown before Home replaces it.
  final Duration displayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.displayDuration, _goHome);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goHome() {
    if (_left || !mounted) return;
    // Only the visible splash may hand over to Home. When this screen sits
    // underneath other routes — a deep initial route builds `/` below the
    // target — its timer must not replace whatever the player is looking
    // at now.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;
    _left = true;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: _goHome,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WallforgeLogo(size: 120),
              const SizedBox(height: AppSpacing.xl),
              const WallforgeWordmark(fontSize: 40),
              const SizedBox(height: AppSpacing.md),
              Text(
                AppInfo.tagline,
                textAlign: TextAlign.center,
                style: AppTypography.labelCaps.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
