import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_history_repository.dart';
import 'package:wallforge/data/remote/firestore_cloud_profile_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.6, Part E: the cloud profile model, its Firestore
/// repository, and the two repository additions the merge
/// stands on (the gate accessors and statistics replace).
CloudProfile profile({
  String name = 'Calm Falcon 42',
  int generation = 0,
  Map<String, int> achievements = const {},
  MatchStatistics statistics = MatchStatistics.empty,
  List<String> ids = const [],
  int updatedAtMs = 100,
}) => CloudProfile(
  displayName: name,
  nameGeneration: generation,
  achievements: achievements,
  statistics: statistics,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudProfile JSON', () {
    test('round-trips, and carries no identity but the name', () {
      final p = profile(
        achievements: const {'first-steps': 42},
        statistics: const MatchStatistics(matchesPlayed: 3, humanWins: 2),
        ids: const ['a', 'b', 'c'],
      );
      final restored = CloudProfile.fromJson(p.toJson());
      expect(restored, isNotNull);
      expect(restored!.displayName, p.displayName);
      expect(restored.nameGeneration, p.nameGeneration);
      expect(restored.achievements, p.achievements);
      expect(restored.statistics.matchesPlayed, 3);
      expect(restored.statisticsRecordIds, p.statisticsRecordIds);
      // The privacy contract, in the document itself: no email
      // field exists to write.
      expect(p.toJson().keys, isNot(contains('email')));
    });

    test('a newer schema is ignored wholesale', () {
      final json = profile().toJson()..['schemaVersion'] = 99;
      expect(CloudProfile.fromJson(json), isNull);
    });

    test('malformed documents are ignored, never guessed at', () {
      expect(CloudProfile.fromJson(const {}), isNull);
      final badStats = profile().toJson()..['statistics'] = 'nope';
      expect(CloudProfile.fromJson(badStats), isNull);
      final badIds = profile().toJson()..['statisticsRecordIds'] = [1, 2];
      expect(CloudProfile.fromJson(badIds), isNull);
      final badTime = profile().toJson()..['updatedAtMs'] = 'soon';
      expect(CloudProfile.fromJson(badTime), isNull);
      final tooMany = profile().toJson()
        ..['achievements'] = {
          for (var i = 0; i <= CloudProfile.maxAchievements; i++) 'a$i': i,
        };
      expect(CloudProfile.fromJson(tooMany), isNull);
    });

    test('sameContentAs ignores only the write stamp', () {
      final a = profile(ids: const ['x'], updatedAtMs: 1);
      final b = profile(ids: const ['x'], updatedAtMs: 999);
      expect(a.sameContentAs(b), isTrue);
      expect(a.sameContentAs(profile(ids: const ['y'])), isFalse);
    });
  });

  group('FirestoreCloudProfileRepository', () {
    test('save, load and delete under the owner uid', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreCloudProfileRepository(
        client: client,
        userId: () async => 'uid-1',
      );
      expect(await repo.load(), isNull);
      expect(await repo.save(profile()), isTrue);
      expect(client.documents.keys, ['users/uid-1/profile']);
      final loaded = await repo.load();
      expect(loaded?.displayName, 'Calm Falcon 42');
      expect(await repo.delete(), isTrue);
      expect(await repo.load(), isNull);
    });

    test('a different owner sees nothing', () async {
      final client = InMemoryFirestoreClient();
      final mine = FirestoreCloudProfileRepository(
        client: client,
        userId: () async => 'uid-1',
      );
      final theirs = FirestoreCloudProfileRepository(
        client: client,
        userId: () async => 'uid-2',
      );
      await mine.save(profile());
      expect(await theirs.load(), isNull);
    });

    test('no owner: every operation is a quiet no-op', () async {
      final repo = FirestoreCloudProfileRepository(
        client: InMemoryFirestoreClient(),
        userId: () async => null,
      );
      expect(await repo.load(), isNull);
      expect(await repo.save(profile()), isFalse);
      expect(await repo.delete(), isFalse);
    });

    test('a corrupt stored document loads as null', () async {
      final client = InMemoryFirestoreClient(
        seed: {
          'users/uid-1/profile': {'schemaVersion': 99, 'junk': true},
        },
      );
      final repo = FirestoreCloudProfileRepository(
        client: client,
        userId: () async => 'uid-1',
      );
      expect(await repo.load(), isNull);
    });
  });

  group('the finish-gate accessors the merge stands on', () {
    test('InMemory: recordedIds reflects the gate; absorb grows it', () async {
      final repo = InMemoryMatchHistoryRepository();
      expect(await repo.recordedIds(), isEmpty);
      await repo.recordIfNew(record('m1'));
      await repo.recordIfNew(record('m2'));
      expect(await repo.recordedIds(), {'m1', 'm2'});
      await repo.absorbRecordedIds({'m9', 'm1'});
      expect(await repo.recordedIds(), {'m1', 'm2', 'm9'});
      // An absorbed id is gated: its match can never record.
      expect(await repo.recordIfNew(record('m9')), isFalse);
    });

    test('InMemory statistics replace swaps the totals', () async {
      final repo = InMemoryStatisticsRepository();
      await repo.recordResult(boardSize: 9, difficulty: 'easy', humanWon: true);
      expect((await repo.load()).matchesPlayed, 1);
      await repo.replace(const MatchStatistics(matchesPlayed: 12));
      expect((await repo.load()).matchesPlayed, 12);
    });

    test('SharedPreferences: gate reads, absorb keeps records', () async {
      SharedPreferences.setMockInitialValues({});
      const repo = SharedPreferencesHistoryRepository();
      expect(await repo.recordedIds(), isEmpty);
      await repo.recordIfNew(record('s1'));
      await repo.absorbRecordedIds({'s7'});
      expect(await repo.recordedIds(), {'s1', 's7'});
      expect((await repo.load()).map((r) => r.id), ['s1']);
      expect(await repo.recordIfNew(record('s7')), isFalse);
    });

    test('SharedPreferences: a newer blob stops the gate read', () async {
      SharedPreferences.setMockInitialValues({
        'wallforge.history.v1': jsonEncode({
          'schemaVersion': 99,
          'records': [],
          'recordedIds': ['x'],
        }),
      });
      const repo = SharedPreferencesHistoryRepository();
      expect(await repo.recordedIds(), isNull);
      // And absorb leaves the newer blob strictly alone.
      await repo.absorbRecordedIds({'y'});
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonDecode(prefs.getString('wallforge.history.v1')!);
      expect((raw as Map)['recordedIds'], ['x']);
    });
  });
}
