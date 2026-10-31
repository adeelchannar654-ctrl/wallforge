import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_info.dart';
import '../core/feedback/feedback_backends.dart';
import '../core/feedback/feedback_controller.dart';
import '../core/feedback/feedback_scope.dart';
import '../data/local/shared_preferences_achievements_repository.dart';
import '../data/local/shared_preferences_history_repository.dart';
import '../data/local/shared_preferences_settings_repository.dart';
import '../data/local/shared_preferences_statistics_repository.dart';
import '../data/local/shared_preferences_unfinished_match_repository.dart';
import 'application/account/account_controller.dart';
import 'application/account/account_factory.dart';
import 'application/account/identity_guard.dart';
import 'application/account/profile_sync_service.dart';
import 'build_info.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
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
  IdentityGuard? _identityGuard;
  AccountController? _account;

  @override
  void initState() {
    super.initState();
    _feedback = FeedbackController(
      AudioplayersSoundBackend(),
      const PlatformHapticsBackend(),
    );
    FeedbackService.install(_feedback);
    // Phase 16.6: with the accounts feature compiled in, the app
    // owns one IdentityGuard and one AccountController, installed
    // the way FeedbackService is, and started immediately — its
    // guest session is the same anonymous sign-in the app has
    // always created, just owned in one place now. With the flag
    // off, nothing is installed and the app behaves exactly as
    // it did before the phase. Tests may pre-install their own
    // controller; the root respects an existing install.
    if (kFeatureAccounts && AccountService.shared == null) {
      final guard = IdentityGuard();
      _identityGuard = guard;
      IdentityGuard.install(guard);
      final account = AccountFactory.firebase(
        guard: guard,
        clearLocalProgress: _clearDeviceProgress,
      );
      _account = account;
      AccountService.install(account);
      unawaited(account.start());
    }
    unawaited(_loadSettings());
  }

  /// The device-progress clearer (D16.6-6): the local stores are
  /// device-owned, so clearing them is a local-only operation
  /// over the same `shared_preferences` repositories the game
  /// uses. History's finish gate is retained by that store's own
  /// contract (records are removed; the "already counted" memory
  /// is not progress to clear). Settings are preferences, not
  /// progress, and are kept.
  static Future<void> _clearDeviceProgress() async {
    await const SharedPreferencesHistoryRepository().clear();
    await const SharedPreferencesAchievementsRepository().saveUnlocks(const {});
    await const SharedPreferencesStatisticsRepository().clear();
    await const SharedPreferencesUnfinishedMatchRepository().clear();
  }

  Future<void> _loadSettings() async {
    final settings = await const SharedPreferencesSettingsRepository().load();
    if (!mounted) return;
    _feedback.applySettings(settings);
  }

  @override
  void dispose() {
    FeedbackService.install(null);
    if (identical(AccountService.shared, _account)) {
      AccountService.install(null);
    }
    if (identical(IdentityGuard.shared, _identityGuard)) {
      IdentityGuard.install(null);
    }
    // The factory installed the sync service when it built the
    // controller this root owns; clear it with the rest.
    if (_account != null) ProfileSyncService.install(null);
    _account?.dispose();
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeedbackScope(
      controller: _feedback,
      // Phase 13: the persisted accessibility settings live in the same
      // settings snapshot the feedback controller already carries, so
      // the app root listens to it and derives three things on every
      // change — the active colour palette (high contrast and colour
      // assistance, design.md §23/§26), the theme built from it, and
      // the UI text scale (TextScaler, §23's UI scale).
      //
      // §13u safety: this rebuilds the MaterialApp *widget* only. The
      // Navigator's state persists across it (same tree shape), no
      // route is regenerated and no route builder re-runs, so an
      // in-progress match is never disturbed by a settings change.
      // The palette is applied before the subtree builds, so every
      // token read in the same pass sees the new palette.
      child: ListenableBuilder(
        listenable: _feedback,
        builder: (context, _) {
          final settings = _feedback.settings;
          AppColors.applyPalette(
            AppPalette.resolve(
              highContrast: settings.highContrast,
              colorAssistance: settings.colorAssistance,
            ),
          );
          return MaterialApp(
            title: AppInfo.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            initialRoute: AppRoutes.root,
            onGenerateRoute: AppRouter.onGenerateRoute,
            navigatorObservers: [AppRouter.routeObserver],
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(settings.uiScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          );
        },
      ),
    );
  }
}
