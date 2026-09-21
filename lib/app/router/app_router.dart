import 'package:flutter/material.dart';

import '../../app/application/local_game_controller.dart';
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
          builder: (_) => GameScreen(controller: LocalGameController()),
        );
      case AppRoutes.home:
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BoardPreviewScreen(),
        );
    }
  }
}
