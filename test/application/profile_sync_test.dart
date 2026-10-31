import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/application/account/profile_sync_service.dart';
import 'package:wallforge/app/application/account/syncing_history_repository.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_history_repository.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/data/remote/firestore_cloud_profile_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.6, Part E: the cloud-profile merge — deterministic,
/// idempotent, unable to double-count — and the service's
/// operation budget (1 read + ≤1 write per sign-in, ≤1 write
/// per finished match, nothing for guests).
CloudProfile prof({
  String uid = 'uid-1',
  int generation = 0,
  Map<String, int> achievements = const {},
  int played = 0,
  List<String> ids = const [],
  int updatedAtMs = 100,
}) => CloudProfile(
  displayName: generateDisplayName(uid, generation),
  nameGeneration: generation,
  achievements: achievements,
  statistics: MatchStatistics(matchesPlayed: played),
  statisticsRecordIds: ids,
  updatedAtMs: updatedAtMs,
);

MatchRecord record(String id) => MatchRecord(
  id: id,
  mode: MatchMode.versusAi,
  boardSize: 9,
  wallsPerPlayer: 10,
  mySide: PlayerId.blue,
  winnerSide: PlayerId.blue,
  finishReason: FinishReason.goal,
  opponentLabel: 'AI · Easy',
  plies: 12,
  durationMs: 60000,
  endedAtMs: 1000,
  timeControlSeconds: 0,
  moves: const ['M 7,4'],
  movesComplete: true,
  rematchOf: null,
);

/// A cloud repository that counts what the service spends.
class CountingCloud implements CloudProfileRepository {
  CountingCloud(this.inner);
  final CloudProfileRepository inner;
  int loads = 0;
  int saves = 0;
  int deletes = 0;

  @override
  Future<CloudProfile?> load() {
    loads++;
    return inner.load();
  }

  @override
  Future<bool> save(CloudProfile profile) {
    saves++;
    return inner.save(profile);
  }

  @override
  Future<bool> delete() {
    deletes++;
    return inner.delete();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the merge (pure)', () {
    test('achievements union, earliest unlock wins', () {
      final merged = ProfileSyncService.merge(
        local: prof(achievements: const {'a': 50, 'b': 10}),
        remote: prof(achievements: const {'a': 30, 'c': 5}),
        nowMs: 200,
      );
      expect(merged.achievements, {'a': 30, 'b': 10, 'c': 5});
    });

    test('the higher name generation wins, with its name', () {
      final merged = ProfileSyncService.merge(
        local: prof(generation: 1),
        remote: prof(generation: 3),
        nowMs: 200,
      );
      expect(merged.nameGeneration, 3);
      expect(merged.displayName, generateDisplayName('uid-1', 3));
    });

    test('cloud ids inside the local gate: local statistics win', () {
      final merged = ProfileSyncService.merge(
        local: prof(played: 5, ids: const ['1', '2', '3', '4', '5']),
        remote: prof(played: 2, ids: const ['2', '4']),
        nowMs: 200,
      );
      expect(merged.statistics.matchesPlayed, 5);
      expect(merged.statisticsRecordIds, ['1', '2', '3', '4', '5']);
    });

    test('local gate inside the cloud ids: cloud statistics win', () {
      final merged = ProfileSyncService.merge(
        local: prof(played: 1, ids: const ['1']),
        remote: prof(played: 7, ids: const ['1', '2', '3']),
        nowMs: 200,
      );
      expect(merged.statistics.matchesPlayed, 7);
      expect(merged.statisticsRecordIds, ['1', '2', '3']);
    });

    test(
      'diverged: more matches wins; ids union (undercount, never double)',
      () {
        final merged = ProfileSyncService.merge(
          local: prof(played: 3, ids: const ['l1', 'l2', 'shared']),
          remote: prof(played: 4, ids: const ['r1', 'shared']),
          nowMs: 200,
        );
        // Remote totals win (4 > 3); local-only ids are absorbed
        // into the counted set without inflating the totals.
        expect(merged.statistics.matchesPlayed, 4);
        expect(merged.statisticsRecordIds.toSet(), {
          'r1',
          'shared',
          'l1',
          'l2',
        });
      },
    );

    test('diverged tie: later write wins, then local', () {
      final later = ProfileSyncService.merge(
        local: prof(played: 2, ids: const ['l'], updatedAtMs: 10),
        remote: prof(played: 2, ids: const ['r'], updatedAtMs: 20),
        nowMs: 200,
      );
      expect(later.statisticsRecordIds.first, 'r');
      final tied = ProfileSyncService.merge(
        local: prof(played: 2, ids: const ['l'], updatedAtMs: 20),
        remote: prof(played: 2, ids: const ['r'], updatedAtMs: 20),
        nowMs: 200,
      );
      expect(tied.statisticsRecordIds.first, 'l');
    });

    test('merging is idempotent', () {
      final local = prof(
        achievements: const {'a': 5},
        played: 3,
        ids: const ['l1', 'shared'],
      );
      final remote = prof(
        achievements: const {'b': 9},
        played: 4,
        ids: const ['r1', 'shared'],
        generation: 2,
      );
      final once = ProfileSyncService.merge(
        local: local,
        remote: remote,
        nowMs: 300,
      );
      final twice = ProfileSyncService.merge(
        local: once,
        remote: once,
        nowMs: 400,
      );
      expect(twice.sameContentAs(once), isTrue);
      // And merging the result against the original remote is stable too.
      final thrice = ProfileSyncService.merge(
        local: once,
        remote: remote,
        nowMs: 500,
      );
      expect(thrice.sameContentAs(once), isTrue);
    });
  });

  group('ProfileSyncService', () {
    late InMemoryMatchHistoryRepository history;
    late InMemoryStatisticsRepository statistics;
    late InMemoryAchievementsRepository achievements;
    late InMemoryLeaderboardNameRepository names;
    late InMemoryFirestoreClient client;
    late CountingCloud cloud;
    late AuthState current;
    late ProfileSyncService service;

    const account = AuthState.signedIn(
      'uid-1',
      kind: AuthIdentityKind.account,
      providerId: AuthProviders.google,
    );

    setUp(() {
      history = InMemoryMatchHistoryRepository();
      statistics = InMemoryStatisticsRepository();
      achievements = InMemoryAchievementsRepository();
      names = InMemoryLeaderboardNameRepository();
      client = InMemoryFirestoreClient();
      cloud = CountingCloud(
        FirestoreCloudProfileRepository(
          client: client,
          userId: () async => 'uid-1',
        ),
      );
      current = account;
      service = ProfileSyncService(
        cloud: cloud,
        history: history,
        statistics: statistics,
        achievements: achievements,
        names: names,
        currentAuth: () async => current,
        clock: () => DateTime.fromMillisecondsSinceEpoch(1000),
        debounce: const Duration(milliseconds: 5),
      );
    });

    tearDown(() => service.dispose());

    test('a guest sync spends nothing', () async {
      current = AuthState.signedIn('uid-9');
      await service.syncOnSignIn(current);
      expect(cloud.loads, 0);
      expect(cloud.saves, 0);
    });

    test('first sign-in uploads the device snapshot in one write', () async {
      await history.recordIfNew(record('m1'));
      await statistics.recordResult(
        boardSize: 9,
        difficulty: 'easy',
        humanWon: true,
      );
      await achievements.saveUnlocks({'first-steps': 7});
      await service.syncOnSignIn(account);
      expect(cloud.loads, 1);
      expect(cloud.saves, 1);
      final stored = await cloud.inner.load();
      expect(stored?.statistics.matchesPlayed, 1);
      expect(stored?.statisticsRecordIds, ['m1']);
      expect(stored?.achievements, {'first-steps': 7});
      expect(stored?.displayName, generateDisplayName('uid-1', 0));
    });

    test(
      'a covering cloud snapshot is adopted locally, with no write',
      () async {
        // The device counted m1 only; the cloud already covers it
        // and more (another device played further).
        await history.recordIfNew(record('m1'));
        await statistics.recordResult(
          boardSize: 9,
          difficulty: 'easy',
          humanWon: true,
        );
        await cloud.inner.save(
          prof(
            played: 3,
            ids: const ['m1', 'm2', 'm3'],
            achievements: const {'online-regular': 42},
            generation: 2,
          ),
        );
        await service.syncOnSignIn(account);
        expect(cloud.saves, 0, reason: 'merged == stored: nothing to write');
        expect((await statistics.load()).matchesPlayed, 3);
        expect(await achievements.loadUnlocks(), {'online-regular': 42});
        expect(await names.loadGeneration('uid-1'), 2);
        expect(await history.recordedIds(), {'m1', 'm2', 'm3'});
      },
    );

    test(
      'a corrupt cloud profile is replaced by the device snapshot',
      () async {
        await history.recordIfNew(record('m1'));
        client.documents['users/uid-1/profile'] = {'schemaVersion': 99};
        await service.syncOnSignIn(account);
        expect(cloud.saves, 1);
        final stored = await cloud.inner.load();
        expect(stored?.statisticsRecordIds, ['m1']);
        // Local data was never touched by the bad document.
        expect(await history.recordedIds(), {'m1'});
      },
    );

    test('post-match sync: one debounced write, none when unchanged', () async {
      await service.syncOnSignIn(account);
      expect(cloud.saves, 1);
      await history.recordIfNew(record('m1'));
      await statistics.recordResult(
        boardSize: 9,
        difficulty: 'easy',
        humanWon: false,
      );
      service.noteMatchFinished();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cloud.saves, 2);
      // Nothing changed since: a further note is a no-op.
      service.noteMatchFinished();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cloud.saves, 2);
      // A guest never writes, changed or not.
      current = AuthState.signedIn('uid-9');
      await history.recordIfNew(record('m2'));
      service.noteMatchFinished();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(cloud.saves, 2);
    });

    test('a newer-schema local store stops the merge entirely', () async {
      SharedPreferences.setMockInitialValues({
        'wallforge.history.v1': jsonEncode({
          'schemaVersion': 99,
          'records': [],
          'recordedIds': ['x'],
        }),
      });
      final guarded = ProfileSyncService(
        cloud: cloud,
        history: const SharedPreferencesHistoryRepository(),
        statistics: statistics,
        achievements: achievements,
        names: names,
        currentAuth: () async => current,
      );
      addTearDown(guarded.dispose);
      await guarded.syncOnSignIn(account);
      expect(cloud.loads, 0);
      expect(cloud.saves, 0);
      expect((await statistics.load()).matchesPlayed, 0);
    });
  });

  group('SyncingHistoryRepository', () {
    test('notifies only for newly recorded matches', () async {
      final inner = InMemoryMatchHistoryRepository();
      var notes = 0;
      final repo = SyncingHistoryRepository(inner, onRecorded: () => notes++);
      expect(await repo.recordIfNew(record('a')), isTrue);
      expect(await repo.recordIfNew(record('a')), isFalse);
      expect(notes, 1);
      expect(await repo.load(), hasLength(1));
      expect(await repo.recordedIds(), {'a'});
    });
  });
}
