import '../../data/local/shared_preferences_settings_repository.dart';
import '../../data/local/shared_preferences_statistics_repository.dart';
import '../../data/local/shared_preferences_unfinished_match_repository.dart';
import '../../data/remote/cloud_firestore_client.dart';
import '../../data/remote/firebase_bootstrap.dart';
import '../../data/remote/firestore_settings_repository.dart';
import '../../data/remote/firestore_statistics_repository.dart';
import '../../data/remote/firestore_unfinished_match_repository.dart';
import '../../domain/models/board_config.dart';
import 'ai/ai_difficulty.dart';
import 'local_game_controller.dart';

/// Attaches persistence to a `LocalGameController`.
///
/// ## Why local storage is still the default
///
/// `phase.md` Phase 7's goal is verbatim: "Connect Firebase **without changing
/// local game behavior**". Its exit criterion is "Each platform initializes
/// Firebase correctly" — not "serves settings from the cloud". Phase 8 is where
/// online data is actually used by the app.
///
/// So Firebase is initialised and available, but the app keeps using
/// `shared_preferences` until there is an authenticated user to key documents by
/// (Phase 8). A build with no Firebase configuration therefore behaves exactly as
/// it did in Phase 6, which is the safest possible default for a phase whose
/// stated purpose is not to change behaviour. Recorded as Q-7.1.
class PersistenceFactory {
  const PersistenceFactory._();

  /// Attaches the `shared_preferences` repositories — the Phase 6 default — and
  /// starts the async load.
  ///
  /// None of these repositories throw, so this cannot fail the app at startup;
  /// if storage is unavailable the controller runs with defaults and forgets on
  /// exit.
  static void attachLocal(LocalGameController controller) {
    controller
      ..attachPersistence(
        settings: const SharedPreferencesSettingsRepository(),
        statistics: const SharedPreferencesStatisticsRepository(),
        unfinishedMatch: const SharedPreferencesUnfinishedMatchRepository(),
      )
      ..loadPersisted();
  }

  /// Attaches the Firestore-backed repositories and starts the async load.
  ///
  /// [ownerId] is the seam Phase 8 replaces with the authenticated uid; until
  /// then a per-install device id isolates one install's documents. It may be
  /// null, in which case every repository call is a no-op — deliberately safer
  /// than writing every document under a shared placeholder owner.
  ///
  /// If [firebase] is not usable this falls back to [attachLocal] rather than
  /// handing out repositories that can never reach a project. Falling back is
  /// deliberate: `phase.md` Phase 7's goal is to connect Firebase *without
  /// changing local game behavior*, so a build without configuration must behave
  /// exactly as it did in Phase 6.
  static void attachRemote(
    LocalGameController controller, {
    required FirebaseBootstrapResult firebase,
    required Future<String?> Function() ownerId,
  }) {
    if (!firebase.isUsable) {
      attachLocal(controller);
      return;
    }
    final client = CloudFirestoreClient();
    controller
      ..attachPersistence(
        settings: FirestoreSettingsRepository(client: client, userId: ownerId),
        statistics: FirestoreStatisticsRepository(
          client: client,
          userId: ownerId,
        ),
        unfinishedMatch: FirestoreUnfinishedMatchRepository(
          client: client,
          userId: ownerId,
        ),
      )
      ..loadPersisted();
  }

  /// A new controller backed by `shared_preferences`.
  static LocalGameController local({
    BoardConfig config = const BoardConfig(),
    bool versusAi = false,
    AiDifficulty aiDifficulty = AiDifficulty.easy,
  }) {
    final controller = LocalGameController(
      config: config,
      versusAi: versusAi,
      aiDifficulty: aiDifficulty,
    );
    attachLocal(controller);
    return controller;
  }

  /// A new controller backed by Firestore.
  static LocalGameController remote({
    required FirebaseBootstrapResult firebase,
    required Future<String?> Function() ownerId,
    BoardConfig config = const BoardConfig(),
    bool versusAi = false,
    AiDifficulty aiDifficulty = AiDifficulty.easy,
  }) {
    final controller = LocalGameController(
      config: config,
      versusAi: versusAi,
      aiDifficulty: aiDifficulty,
    );
    attachRemote(controller, firebase: firebase, ownerId: ownerId);
    return controller;
  }
}
