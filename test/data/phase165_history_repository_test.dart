import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_history_repository.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part E: the history store — the finish gate,
/// the bound, tolerant reads, and the newer-schema guard.
MatchRecord record(String id, {int endedAtMs = 1000}) => MatchRecord(
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
  endedAtMs: endedAtMs,
  timeControlSeconds: 0,
  moves: const ['M 7,4'],
  movesComplete: true,
  rematchOf: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPreferencesHistoryRepository', () {
    const repo = SharedPreferencesHistoryRepository();

    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('records once: the gate refuses the same id twice', () async {
      expect(await repo.recordIfNew(record('m1')), isTrue);
      expect(await repo.recordIfNew(record('m1')), isFalse);
      final loaded = await repo.load();
      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'm1');
    });

    test('the gate survives a restart (a new instance, same store)', () async {
      await repo.recordIfNew(record('m1'));
      const restarted = SharedPreferencesHistoryRepository();
      expect(await restarted.recordIfNew(record('m1')), isFalse);
      expect(await restarted.load(), hasLength(1));
    });

    test('newest first, bounded at 100 records and 100 gate ids', () async {
      for (var i = 1; i <= 105; i++) {
        await repo.recordIfNew(record('m$i', endedAtMs: i));
      }
      final loaded = await repo.load();
      expect(loaded, hasLength(100));
      expect(loaded.first.id, 'm105');
      expect(loaded.last.id, 'm6');
    });

    test('delete removes the record but never the gate entry', () async {
      await repo.recordIfNew(record('m1'));
      await repo.recordIfNew(record('m2'));
      await repo.delete('m1');
      expect((await repo.load()).map((r) => r.id), ['m2']);
      expect(await repo.recordIfNew(record('m1')), isFalse);
    });

    test('clear empties the list but keeps the gate', () async {
      await repo.recordIfNew(record('m1'));
      await repo.clear();
      expect(await repo.load(), isEmpty);
      expect(await repo.recordIfNew(record('m1')), isFalse);
    });

    test('a corrupt blob reads as empty and recording recovers', () async {
      SharedPreferences.setMockInitialValues({
        'wallforge.history.v1': 'this is not json',
      });
      expect(await repo.load(), isEmpty);
      expect(await repo.recordIfNew(record('m1')), isTrue);
      expect(await repo.load(), hasLength(1));
    });

    test('one damaged record does not lose the others', () async {
      SharedPreferences.setMockInitialValues({
        'wallforge.history.v1': jsonEncode({
          'schemaVersion': 1,
          'records': [
            record('good').toJson(),
            {'id': 'broken', 'mode': 'nonsense'},
            42,
          ],
          'recordedIds': ['good'],
        }),
      });
      final loaded = await repo.load();
      expect(loaded.map((r) => r.id), ['good']);
    });

    test('a newer schema reads as empty and is never overwritten', () async {
      final newer = jsonEncode({
        'schemaVersion': 99,
        'records': [record('from-the-future').toJson()],
        'recordedIds': ['from-the-future'],
      });
      SharedPreferences.setMockInitialValues({'wallforge.history.v1': newer});
      expect(await repo.load(), isEmpty);
      expect(await repo.recordIfNew(record('m1')), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wallforge.history.v1'), newer);
    });
  });

  group('InMemoryMatchHistoryRepository', () {
    test('same gate and bound semantics', () async {
      final repo = InMemoryMatchHistoryRepository();
      expect(await repo.recordIfNew(record('m1')), isTrue);
      expect(await repo.recordIfNew(record('m1')), isFalse);
      for (var i = 2; i <= 101; i++) {
        await repo.recordIfNew(record('m$i'));
      }
      expect(await repo.load(), hasLength(100));
      await repo.delete('m101');
      expect(await repo.recordIfNew(record('m101')), isFalse);
      await repo.clear();
      expect(await repo.load(), isEmpty);
    });
  });
}
