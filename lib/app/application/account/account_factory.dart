import '../../../data/remote/firebase_auth_gateway.dart';
import '../../../domain/repositories/auth.dart';
import 'account_controller.dart';
import 'identity_guard.dart';

/// Builds the app's one [AccountController] (Phase 16.6),
/// mirroring `OnlineLobbyFactory`'s role for the lobby.
///
/// Separate from the controller so tests can build controllers
/// over the fake gateway with the same shape, and so the app
/// root's wiring stays a single call. The collaborators that
/// arrive in later parts (cloud-profile sync on sign-in, profile
/// deletion, device-progress clearing) are passed through here.
abstract final class AccountFactory {
  /// The production controller: the real Firebase gateway, the
  /// app's shared [guard], and the phase's collaborators.
  static AccountController firebase({
    required IdentityGuard guard,
    Future<void> Function(AuthState state)? onAccountSignedIn,
    Future<bool> Function()? deleteCloudProfile,
    Future<void> Function()? clearLocalProgress,
  }) {
    return AccountController(
      gateway: FirebaseAuthGateway(),
      guard: guard,
      onAccountSignedIn: onAccountSignedIn,
      deleteCloudProfile: deleteCloudProfile,
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
