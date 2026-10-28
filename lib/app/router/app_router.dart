import 'package:flutter/material.dart';

import '../../core/feedback/feedback_controller.dart';
import '../../core/feedback/feedback_transitions.dart';
import '../../data/local/in_memory_repositories.dart';
import '../../domain/models/board_config.dart';
import '../../domain/repositories/room.dart';
import '../../app/application/ai/ai_difficulty.dart';
import '../../app/application/local_game_controller.dart';
import '../../app/application/online/online_game_controller.dart';
import '../../app/application/online/online_lobby_factory.dart';
import '../../app/application/online/rematch_controller.dart';
import '../../app/application/persistence_factory.dart';
import '../../app/application/match_setup.dart';
import '../../presentation/screens/ai/ai_difficulty_screen.dart';
import '../../presentation/screens/game/game_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/modes/game_modes_screen.dart';
import '../../presentation/screens/online/online_game_screen.dart';
import '../../presentation/screens/online/online_lobby_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/result/result_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/tutorial/tutorial_screen.dart';

/// Canonical route paths for the application (see `architecture.md` §18).
///
/// Phase 11 completed the §18 map. Two paths deserve a note:
///
/// * `/` is the splash entry; the §18 list's own `/home` is the home screen.
/// * `/online/game` is a Phase 11 addition to the list (§18 names `/game`
///   only): the online match screen's arguments are a live controller and
///   a room, not a `MatchSetup`, so it cannot share the `/game` route.
/// * `/online/create` and `/online/join` open the lobby focused on the
///   matching section (see `memory.md` §13s for the one-lobby decision).
class AppRoutes {
  const AppRoutes._();

  /// Entry point: the splash screen, which replaces itself with [home].
  static const String root = '/';

  /// The product home screen.
  static const String home = '/home';

  /// Game modes: pick a mode and a board configuration.
  static const String modes = '/modes';

  /// §18 alias: the modes screen with Local preselected.
  static const String local = '/local';

  /// AI difficulty picker (Phase 11, Q-5.2).
  static const String ai = '/ai';

  /// Online room lobby (Phase 8).
  static const String online = '/online';

  /// §18 alias: the lobby focused on its Create section.
  static const String onlineCreate = '/online/create';

  /// §18 alias: the lobby focused on its Join section.
  static const String onlineJoin = '/online/join';

  /// An online match in progress.
  static const String onlineGame = '/online/game';

  /// Local pass-and-play / vs-AI game.
  static const String game = '/game';

  /// The shared result screen.
  static const String result = '/result';

  /// The guided tutorial.
  static const String tutorial = '/tutorial';

  /// Profile: the player's real statistics.
  static const String profile = '/profile';

  /// Settings.
  static const String settings = '/settings';
}

/// Arguments for the `/online/game` route: the match controller the lobby
/// built and connected, plus its rematch negotiation.
class OnlineGameRouteArgs {
  const OnlineGameRouteArgs({required this.controller, this.rematch});

  final OnlineGameController controller;
  final RematchController? rematch;
}

/// Arguments for the `/result` route when it is addressed directly. (In the
/// app's own flows the game screens present the same [ResultScreen] in
/// place at match end, because their controllers own the rematch; the route
/// exists so the screen is addressable like every other screen in §18.)
class ResultRouteArgs {
  const ResultRouteArgs({required this.data, required this.setup});

  final MatchResultData data;

  /// The match to restart on Rematch (local / AI modes).
  final MatchSetup setup;
}

/// Builds the application's [Route] from a [RouteSettings].
class AppRouter {
  const AppRouter._();

  static Route<void> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.root:
        return _page(settings, const SplashScreen());
      case AppRoutes.home:
        return _page(settings, const HomeScreen());
      case AppRoutes.modes:
        return _page(
          settings,
          GameModesScreen(
            initialMode: settings.arguments is GameMode
                ? settings.arguments as GameMode
                : GameMode.local,
          ),
        );
      case AppRoutes.local:
        return _page(settings, const GameModesScreen());
      case AppRoutes.ai:
        return _page(
          settings,
          AiDifficultyScreen(
            config: settings.arguments is BoardConfig
                ? settings.arguments as BoardConfig
                : const BoardConfig(),
          ),
        );
      case AppRoutes.game:
        // The controller is created ONCE, here: onGenerateRoute runs a
        // single time per navigation, while a route builder may re-run
        // whenever an ancestor rebuilds. Creating it inside the builder
        // made the match ephemeral — the Phase 12 regression (§13u):
        // the builder also read FeedbackScope via dependOn…, which
        // subscribed the route element to FeedbackController
        // notifications, and loadPersisted's applySettings notification
        // then rebuilt the route around a brand-new controller every
        // frame, discarding every move and wall before it could be
        // seen. The builder below only ever *captures* this controller,
        // and feedback is assigned from FeedbackService.shared — the
        // mechanism FeedbackService documents for the router — never
        // via a dependOn call inside a builder.
        final gameController = _controllerFor(settings);
        // Phase 12: the game controller fires its cues through the
        // app's feedback layer.
        gameController.feedback = FeedbackService.shared;
        return WallforgePageRoute<void>(
          settings: settings,
          // The route owns the controller, so the screen disposes it with
          // the route (Q-8.6). Previously it leaked for the life of the
          // process.
          builder: (_) =>
              GameScreen(controller: gameController, ownsController: true),
        );
      case AppRoutes.online:
      case AppRoutes.onlineCreate:
      case AppRoutes.onlineJoin:
        return _onlineLobby(settings);
      case AppRoutes.onlineGame:
        final args = settings.arguments;
        if (args is OnlineGameRouteArgs) {
          return WallforgePageRoute<void>(
            settings: settings,
            builder: (_) {
              // Phase 12: assign the feedback layer if the lobby did not
              // already (the lobby normally assigns it at match entry).
              // From FeedbackService.shared, not a dependOn read: a route
              // builder must never subscribe itself to the feedback
              // layer's notifications (the §13u regression).
              args.controller.feedback ??= FeedbackService.shared;
              return OnlineGameScreen(
                controller: args.controller,
                rematch: args.rematch,
                ownsController: true,
              );
            },
          );
        }
        // No live controller: there is no match to show. Fall back to the
        // lobby rather than crash on a deep link.
        return _onlineLobby(settings);
      case AppRoutes.result:
        return _result(settings);
      case AppRoutes.tutorial:
        return _page(settings, const TutorialScreen());
      case AppRoutes.profile:
        return _page(settings, const ProfileScreen());
      case AppRoutes.settings:
        return _page(settings, const SettingsScreen());
      default:
        return _page(settings, const SplashScreen());
    }
  }

  /// Every app route uses the Phase 12 page route (the §24 UI-transition
  /// duration and treatment), so screen changes feel like one system.
  static WallforgePageRoute<void> _page(RouteSettings settings, Widget child) {
    return WallforgePageRoute<void>(settings: settings, builder: (_) => child);
  }

  /// The online lobby, optionally adopting an already-seated room (a
  /// rematch) or focused on one of its sections via the §18 alias routes.
  static Route<void> _onlineLobby(RouteSettings settings) {
    final args = settings.arguments;
    final lobby = OnlineLobbyFactory.firebase(
      boardConfig: args is BoardConfig ? args : null,
    );
    final focus = switch (settings.name) {
      AppRoutes.onlineCreate => OnlineLobbyFocus.create,
      AppRoutes.onlineJoin => OnlineLobbyFocus.join,
      _ => OnlineLobbyFocus.none,
    };
    return WallforgePageRoute<void>(
      settings: settings,
      // The route built the controller, so the screen disposes it.
      builder: (_) => OnlineLobbyScreen(
        controller: lobby,
        ownsController: true,
        focus: focus,
        adoptRoom: args is Room ? args : null,
      ),
    );
  }

  static Route<void> _result(RouteSettings settings) {
    final args = settings.arguments;
    if (args is ResultRouteArgs) {
      return WallforgePageRoute<void>(
        settings: settings,
        builder: (context) => Scaffold(
          body: ResultScreen(
            data: args.data,
            onRematch: () => Navigator.of(context)
                .pushReplacementNamed(AppRoutes.game, arguments: args.setup),
            onHome: () =>
                Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
          ),
        ),
      );
    }
    // A result with no data has nothing truthful to show; go home.
    return _page(settings, const HomeScreen());
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

  /// Attaches the default (local) repositories and kicks off the async load.
  ///
  /// Phase 7: the app still defaults to `shared_preferences` because Phase 7's
  /// goal is to connect Firebase "without changing local game behavior". When a
  /// Firebase project is configured, [PersistenceFactory.attachRemote] supplies
  /// the Firestore-backed implementations of the same interfaces instead —
  /// nothing above this line changes, which is the Phase 6 boundary doing its
  /// job.
  static LocalGameController _withPersistence(LocalGameController controller) {
    PersistenceFactory.attachLocal(controller);
    return controller;
  }

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
