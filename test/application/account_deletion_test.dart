import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/account/account_controller.dart';
import 'package:wallforge/app/application/account/identity_guard.dart';
import 'package:wallforge/app/application/account/profile_sync_service.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/data/remote/firestore_cloud_profile_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

import '../support/fake_account_auth_gateway.dart';

/// Phase 16.6, Part F: deletion end to end — the controller, the
/// real profile sync service and the real Firestore profile
/// repository over the in-memory client — proving the profile
/// document actually goes, the Auth user goes after it, and a
/// profile that cannot be deleted stops the whole deletion
/// (D16.6-12).
void main() {
  group('account deletion, wired for real', () {
    late FakeAccountAuthGateway gateway;
    late InMemoryFirestoreClient client;
    late IdentityGuard guard;
    late AccountController controller;

    setUp(() {
      gateway = FakeAccountAuthGateway();
      client = InMemoryFirestoreClient();
      guard = IdentityGuard();
      final sync = ProfileSyncService(
        cloud: FirestoreCloudProfileRepository(
          client: client,
          userId: gateway.currentUid,
        ),
        history: InMemoryMatchHistoryRepository(),
        statistics: InMemoryStatisticsRepository(),
        achievements: InMemoryAchievementsRepository(),
        names: InMemoryLeaderboardNameRepository(),
        currentAuth: gateway.current,
      );
      controller = AccountController(
        gateway: gateway,
        guard: guard,
        deleteCloudProfile: sync.deleteProfile,
      );
    });

    tearDown(() => controller.dispose());

    test('deleting removes the profile document, then the user', () async {
      await controller.start();
      await controller.createEmailAccount(
        email: 'player@x.io',
        password: 'password-9',
      );
      final uid = controller.state.uid!;
      final profilePath = 'users/$uid/profile';
      client.documents[profilePath] = CloudProfile(
        displayName: generateDisplayName(uid, 0),
        nameGeneration: 0,
        achievements: const {},
        statistics: MatchStatistics.empty,
        statisticsRecordIds: const [],
        updatedAtMs: 1,
      ).toJson();

      gateway.deleteNeedsReauth = true;
      final result = await controller.deleteAccount(password: 'password-9');

      expect(result, isA<AuthSuccess>());
      expect(
        client.documents.containsKey(profilePath),
        isFalse,
        reason: 'the profile document is deleted first',
      );
      expect(
        controller.state.isGuest,
        isTrue,
        reason: 'and the player lands on a fresh guest',
      );
      expect(controller.state.uid, isNot(uid));
    });

    test('a profile that cannot be deleted aborts the deletion', () async {
      final failing = AccountController(
        gateway: gateway,
        guard: guard,
        deleteCloudProfile: () async => false,
      );
      addTearDown(failing.dispose);
      await failing.start();
      await failing.createEmailAccount(
        email: 'player@x.io',
        password: 'password-9',
      );
      final uid = failing.state.uid;

      final result = await failing.deleteAccount(password: 'password-9');

      expect(result, isA<AuthRejected>());
      expect((result as AuthRejected).failure.error, AuthError.unavailable);
      expect(failing.state.uid, uid, reason: 'the account still exists');
      expect(gateway.calls, isNot(contains('deleteCurrentUser')));
    });

    test(
      'a guest has no account to delete and the gateway is untouched',
      () async {
        await controller.start();
        final guestUid = controller.state.uid;
        final result = await controller.deleteAccount();
        expect(result, isA<AuthRejected>());
        expect((result as AuthRejected).failure.error, AuthError.unavailable);
        expect(gateway.calls, isNot(contains('deleteCurrentUser')));
        expect(
          controller.state.uid,
          guestUid,
          reason: 'the guest identity survives the refused deletion',
        );
      },
    );
  });
}
