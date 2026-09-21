import 'package:flutter/material.dart';

import '../../presentation/screens/board_preview/board_preview_screen.dart';

/// Canonical route paths for the application (see `architecture.md` §18).
///
/// Phase 0 defines only the routes that exist today. Later phases add their
/// own route entries here rather than pushing widgets ad hoc, keeping
/// navigation centralised and testable.
class AppRoutes {
  const AppRoutes._();

  /// Root of the application.
  static const String home = '/';
}

/// Builds the application's [Route] from a [RouteSettings].
///
/// Using `onGenerateRoute` instead of a static route map keeps navigation
/// arguments typed and centralised in one place.
class AppRouter {
  const AppRouter._();

  static Route<void> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BoardPreviewScreen(),
        );
    }
  }
}
