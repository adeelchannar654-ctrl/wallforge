import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_info.dart';
import '../core/feedback/feedback_backends.dart';
import '../core/feedback/feedback_controller.dart';
import '../core/feedback/feedback_scope.dart';
import '../data/local/shared_preferences_settings_repository.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget of the Wallforge application.
///
/// Phase 12: the root also owns the app's single [FeedbackController]
/// (the sound/haptics layer, `design.md` §25). It is created here with
/// the platform backends, installed as the shared instance for the
/// router and controllers, and exposed to widgets through
/// [FeedbackScope]. Persisted settings are loaded once at startup and
/// applied to it (which also starts the background music when enabled);
/// the Settings screen re-applies on every save, so the snapshot cues
/// are gated by is never stale.
class WallforgeApp extends StatefulWidget {
  const WallforgeApp({super.key});

  @override
  State<WallforgeApp> createState() => _WallforgeAppState();
}

class _WallforgeAppState extends State<WallforgeApp> {
  late final FeedbackController _feedback;

  @override
  void initState() {
    super.initState();
    _feedback = FeedbackController(
      AudioplayersSoundBackend(),
      const PlatformHapticsBackend(),
    );
    FeedbackService.install(_feedback);
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final settings = await const SharedPreferencesSettingsRepository().load();
    if (!mounted) return;
    _feedback.applySettings(settings);
  }

  @override
  void dispose() {
    FeedbackService.install(null);
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeedbackScope(
      controller: _feedback,
      child: MaterialApp(
        title: AppInfo.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: AppRoutes.root,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
