import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/persistence_factory.dart';
import 'package:wallforge/data/remote/firebase_bootstrap.dart';
import 'package:wallforge/data/remote/firestore_settings_repository.dart';
import 'package:wallforge/data/remote/firestore_statistics_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  group('FirebaseBootstrapResult', () {
    test('ready and emulator are usable, unavailable is not', () {
      expect(
        const FirebaseBootstrapResult(FirebaseStatus.ready).isUsable,
        isTrue,
      );
      expect(
        const FirebaseBootstrapResult(FirebaseStatus.emulator).isUsable,
        isTrue,
      );
      expect(
        const FirebaseBootstrapResult(FirebaseStatus.unavailable).isUsable,
        isFalse,
      );
    });

    test('the reason is reported without leaking anything else', () {
      const result = FirebaseBootstrapResult(
        FirebaseStatus.unavailable,
        detail: 'FirebaseException(no-app)',
      );
      expect(result.toString(), contains('unavailable'));
      expect(result.toString(), contains('no-app'));
    });
  });

  group('FirebaseBootstrap', () {
    test('initialisation never throws, even with no configuration', () async {
      // The test host has no Firebase platform implementation, so this is
      // exactly the "fresh clone" path the app must survive.
      final result = await FirebaseBootstrap.initialize();
      expect(result.status, FirebaseStatus.unavailable);
      expect(result.detail, isNotNull);
    });
  });

  group('PersistenceFactory', () {
    test('attachLocal gives the controller working persistence', () async {
      final controller = LocalGameController();
      PersistenceFactory.attachLocal(controller);
      expect(controller.hasPersistence, isTrue);
      // The Phase 6 behaviour must survive the Phase 7 refactor.
      await controller.loadPersisted();
      controller.startMatch(config: const BoardConfig(size: 5));
      controller.tapCell(const Cell(row: 3, column: 2));
      await Future<void>.delayed(Duration.zero);
      // turnNumber counts moves made, so a single tap is 1.
      expect(controller.state.turnNumber, 1);
      controller.dispose();
    });

    test('local() builds an already-attached controller', () {
      final controller = PersistenceFactory.local();
      expect(controller.hasPersistence, isTrue);
      controller.dispose();
    });

    test('remote() falls back to local when Firebase is unavailable', () async {
      // The unconfigured-build path. Phase 7 promises not to change local game
      // behavior, so this must behave exactly like a Phase 6 build.
      final controller = PersistenceFactory.remote(
        firebase: const FirebaseBootstrapResult(FirebaseStatus.unavailable),
        ownerId: () async => null,
      );
      expect(controller.hasPersistence, isTrue);
      controller.startMatch(config: const BoardConfig(size: 5));
      controller.tapCell(const Cell(row: 3, column: 2));
      await Future<void>.delayed(Duration.zero);
      // turnNumber counts moves made, so a single tap is 1.
      expect(controller.state.turnNumber, 1);
      controller.dispose();
    });
  });

  group('owner scoping', () {
    test(
      'a null owner id short-circuits before any document is written',
      () async {
        final client = InMemoryFirestoreClient();
        final settings = FirestoreSettingsRepository(
          client: client,
          userId: () async => null,
        );
        expect(await settings.load(), same(AppSettings.defaults));
        await settings.save(const AppSettings(confirmWallPlacement: false));
        expect(client.documents, isEmpty);
      },
    );

    test('documents are scoped to the resolved owner', () async {
      final client = InMemoryFirestoreClient();
      final settings = FirestoreSettingsRepository(
        client: client,
        userId: () async => 'owner-a',
      );
      await settings.save(const AppSettings(confirmWallPlacement: false));
      expect(client.documents.containsKey('users/owner-a/settings'), isTrue);
      expect(client.documents.containsKey('users/owner-b/settings'), isFalse);
    });

    test(
      'statistics are recorded under the owner and clearing is idempotent',
      () async {
        final client = InMemoryFirestoreClient();
        final statistics = FirestoreStatisticsRepository(
          client: client,
          userId: () async => 'owner-a',
        );
        final updated = await statistics.recordResult(
          boardSize: 5,
          difficulty: 'local',
          humanWon: true,
        );
        expect(updated.matchesPlayed, 1);
        expect(
          client.documents.containsKey('users/owner-a/statistics'),
          isTrue,
        );

        await statistics.clear();
        await statistics.clear();
        expect(await statistics.load(), same(MatchStatistics.empty));
      },
    );
  });
}
