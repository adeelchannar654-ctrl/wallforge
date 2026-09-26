import 'package:flutter/material.dart';

import '../../data/local/in_memory_repositories.dart';
import '../../data/local/shared_preferences_settings_repository.dart';
import '../../data/local/shared_preferences_statistics_repository.dart';
import '../../data/local/shared_preferences_unfinished_match_repository.dart';
import '../../domain/models/board_config.dart';
import '../../app/application/ai/ai_difficulty.dart';
import '../../app/application/local_game_controller.dart';
import '../../app/application/match_setup.dart';
import '../../presentation/screens/board_preview/board_preview_screen.dart';
import '../../presentation/screens/game/game_screen.dart';

/// Canonical route paths for the application (see `architecture.md` §18).
class AppRoutes {
  const AppRoutes._();

  /// Root of the application.
  static const String home = '/';

  /// Local pass-and-play game.
  static const String game = '/game';
}

/// Builds the application's [Route] from a [RouteSettings].
class AppRouter {
  const AppRouter._();

  static Route<void> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.game:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => GameScreen(controller: _controllerFor(settings)),
        );
      case AppRoutes.home:
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BoardPreviewScreen(),
        );
    }
  }

  /// Builds the controller for the game route.
  ///
  /// Accepts, in order of preference:
  ///
  /// * a [LocalGameController] — used by the entry screen's resume path, which
  ///   has already adopted a saved match and must not have a second controller
  ///   silently replace it;
  /// * a [MatchSetup], which may include the AI opponent and its difficulty;
  /// * a bare [BoardConfig], which still means pass-and-play.
  ///
  /// A missing or unexpected argument falls back to the default local match, so
  /// a deep link with no arguments can never crash.
  static LocalGameController _controllerFor(RouteSettings settings) {
    final args = settings.arguments;
    if (args is LocalGameController) {
      return _withPersistence(args);
    }
    if (args is MatchSetup) {
      return _withPersistence(
        LocalGameController(
          config: args.config,
          versusAi: args.versusAi,
          aiDifficulty: args.aiDifficulty,
        ),
      );
    }
    final config = args is BoardConfig ? args : const BoardConfig();
    return _withPersistence(LocalGameController(config: config));
  }

  /// Attaches the device-backed repositories and kicks off the async load.
  ///
  /// The application layer still only sees the domain repository interfaces, so
  /// Phase 7 can replace these with a Firebase implementation without touching
  /// anything above this line. [SharedPreferencesSettingsRepository] and
  /// friends never throw, so this cannot fail the app at startup; if storage is
  /// unavailable the controller simply runs with defaults and forgets on exit.
  static LocalGameController _withPersistence(LocalGameController controller) =>
      controller
        ..attachPersistence(
          settings: const SharedPreferencesSettingsRepository(),
          statistics: const SharedPreferencesStatisticsRepository(),
          unfinishedMatch: const SharedPreferencesUnfinishedMatchRepository(),
        )
        ..loadPersisted();

  /// Builds a controller with in-memory persistence. Used by tests and by any
  /// caller that explicitly wants a throwaway, non-persistent match.
  static LocalGameController inMemoryController({
    BoardConfig config = const BoardConfig(),
    bool versusAi = false,
    AiDifficulty aiDifficulty = AiDifficulty.easy,
  }) {
    final controller = LocalGameController(
      config: config,
      versusAi: versusAi,
      aiDifficulty: aiDifficulty,
    );
    controller.attachPersistence(
      settings: InMemorySettingsRepository(),
      statistics: InMemoryStatisticsRepository(),
      unfinishedMatch: InMemoryUnfinishedMatchRepository(),
    );
    return controller;
  }
}
