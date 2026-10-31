import '../../../data/local/shared_preferences_achievements_repository.dart';
import '../../../data/local/shared_preferences_history_repository.dart';
import '../../../data/local/shared_preferences_leaderboard_name_repository.dart';
import '../../../data/local/shared_preferences_statistics_repository.dart';
import '../../../data/remote/cloud_firestore_client.dart';
import '../../../data/remote/firebase_auth_gateway.dart';
import '../../../data/remote/firestore_cloud_profile_repository.dart';
import '../../../domain/repositories/auth.dart';
import 'account_controller.dart';
import 'identity_guard.dart';
import 'profile_sync_service.dart';

/// Builds the app's one [AccountController] (Phase 16.6),
/// mirroring `OnlineLobbyFactory`'s role for the lobby.
///
/// Separate from the controller so tests can build controllers
/// over the fake gateway with the same shape, and so the app
/// root's wiring stays a single call.
abstract final class AccountFactory {
  /// The production controller: the real Firebase gateway, the
  /// app's shared [guard], and the phase's collaborators — the
  /// cloud-profile sync (Part E) built over the same gateway (so
  /// the profile always belongs to the actually-signed-in uid)
  /// and the local stores, and installed as the shared sync
  /// service the history decorators report to.
  static AccountController firebase({
    required IdentityGuard guard,
    Future<void> Function(AuthState state)? onAccountSignedIn,
    Future<bool> Function()? deleteCloudProfile,
    Future<void> Function()? clearLocalProgress,
    void Function(ProfileSyncService sync)? onSyncCreated,
  }) {
    final gateway = FirebaseAuthGateway();
    final sync = ProfileSyncService(
      cloud: FirestoreCloudProfileRepository(
        client: CloudFirestoreClient(),
        userId: gateway.currentUid,
      ),
      history: const SharedPreferencesHistoryRepository(),
      statistics: const SharedPreferencesStatisticsRepository(),
      achievements: const SharedPreferencesAchievementsRepository(),
      names: const SharedPreferencesLeaderboardNameRepository(),
      currentAuth: gateway.current,
    );
    ProfileSyncService.install(sync);
    // The caller owns the sync service's lifecycle: it holds a
    // debounce timer, and whoever creates it must dispose it.
    onSyncCreated?.call(sync);
    return AccountController(
      gateway: gateway,
      guard: guard,
      onAccountSignedIn: onAccountSignedIn ?? sync.syncOnSignIn,
      deleteCloudProfile: deleteCloudProfile ?? sync.deleteProfile,
      clearLocalProgress: clearLocalProgress,
    );
  }

  /// A controller over an injected gateway — the test path, and
  /// the seam a future non-Firebase backend would use.
  static AccountController withGateway({
    required AccountAuthGateway gateway,
    required IdentityGuard guard,
    Future<void> Function(AuthState state)? onAccountSignedIn,
    Future<bool> Function()? deleteCloudProfile,
    Future<void> Function()? clearLocalProgress,
  }) {
    return AccountController(
      gateway: gateway,
      guard: guard,
      onAccountSignedIn: onAccountSignedIn,
      deleteCloudProfile: deleteCloudProfile,
      clearLocalProgress: clearLocalProgress,
    );
  }
}
