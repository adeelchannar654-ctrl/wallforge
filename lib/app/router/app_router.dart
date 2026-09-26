import 'package:flutter/material.dart';

import '../../domain/models/board_config.dart';
import '../../app/application/local_game_controller.dart';
import '../../app/application/match_setup.dart';
import '../../presentation/screens/board_preview/board_preview_screen.dart';
import '../../presentation/screens/game/game_screen.dart';

/// Canonical route paths for the application (see `architecture.md` Â§18).
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
  /// Accepts a [MatchSetup] (which may include the AI opponent and its
  /// difficulty) or a bare [BoardConfig], which still means pass-and-play. A
  /// missing or unexpected argument falls back to the default local match, so a
  /// deep link with no arguments can never crash.
  static LocalGameController _controllerFor(RouteSettings settings) {
    final args = settings.arguments;
    if (args is MatchSetup) {
      return LocalGameController(
        config: args.config,
        versusAi: args.versusAi,
        aiDifficulty: args.aiDifficulty,
      );
    }
    final config = args is BoardConfig ? args : const BoardConfig();
    return LocalGameController(config: config);
  }
}
