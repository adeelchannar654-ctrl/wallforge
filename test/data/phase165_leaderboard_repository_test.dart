import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_leaderboard_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';

/// Phase 16.5, Part H: week arithmetic, name generation, and
/// the leaderboard repository against the in-memory double —
/// eligibility, caps, ordering and rename. (The rules'
/// server-side re-validation is covered by the JS rules
/// tests the owner runs against the emulator.)
void main() {
  group('week arithmetic', () {
    int ms(int y, int m, int d) => DateTime.utc(y, m, d).millisecondsSinceEpoch;

    test('a Saturday belongs to the Monday before', () {
      // 2026-10-31 is a Saturday; its week starts Mon 10-26.
      expect(weekStartMs(ms(2026, 10, 31)), ms(2026, 10, 26));
    });

    test('a Monday starts its own week; a Sunday ends the previous', () {
      expect(weekStartMs(ms(2026, 10, 26)), ms(2026, 10, 26));
      expect(weekStartMs(ms(2026, 11, 1)), ms(2026, 10, 26));
      expect(weekStartMs(ms(2026, 11, 2)), ms(2026, 11, 2));
    });

    test('the residue identity holds for Mondays', () {
      final monday = weekStartMs(ms(2026, 10, 31));
      expect(monday % kWeekMs, kMondayResidueMs);
      final asDate = DateTime.fromMillisecondsSinceEpoch(monday, isUtc: true);
      expect(asDate.weekday, DateTime.monday);
      expect(asDate.hour, 0);
    });
  });

  group('display names', () {
    final pattern = RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+ [0-9]{2}$');

    test('shape, determinism, and regeneration', () {
      final name = generateDisplayName('uid-abc', 0);
      expect(pattern.hasMatch(name), isTrue, reason: name);
      expect(generateDisplayName('uid-abc', 0), name);
      expect(generateDisplayName('uid-abc', 1), isNot(name));
      expect(pattern.hasMatch(generateDisplayName('uid-abc', 1)), isTrue);
      expect(generateDisplayName('uid-xyz', 0), isNot(name));
    });
  });

  group('FirestoreLeaderboardRepository', () {
    late InMemoryFirestoreClient store;
    late DateTime now;

    FirestoreLeaderboardRepository repoFor(String uid) =>
        FirestoreLeaderboardRepository(
          client: store,
          userId: () async => uid,
          clock: () => now,
        );

    setUp(() {
      // Wednesday 2026-10-28, mid-week.
      now = DateTime.utc(2026, 10, 28, 12);
      store = InMemoryFirestoreClient(clock: () => now);
    });

    tearDown(() => store.closeWatchers());

    Future<LeaderboardSubmitOutcome> submit(
      String uid, {
      String matchId = 'MATCH1',
      String opponent = 'opp-1',
      bool won = true,
      int plies = 14,
      int? endedAtMs,
    }) => repoFor(uid).recordResult(
      matchId: matchId,
      opponentUid: opponent,
      won: won,
      plies: plies,
      matchEndedAtMs: endedAtMs ?? now.millisecondsSinceEpoch,
      displayName: generateDisplayName(uid, 0),
    );

    test('a win counts 3 points and stores the rules fields', () async {
      expect(await submit('uid-a'), LeaderboardSubmitOutcome.counted);
      final entry = await repoFor('uid-a')
          .fetchEntry(weekStartMs(now.millisecondsSinceEpoch), 'uid-a');
      expect(entry, isNotNull);
      expect(entry!.points, 3);
      expect(entry.wins, 1);
      expect(entry.losses, 0);
      expect(entry.countedMatches, {'MATCH1': 'opp-1'});
      expect(entry.opponentCounts, {'opp-1': 1});
      final raw = store
          .documents['leaderboards/${weekStartMs(now.millisecondsSinceEpoch)}/entries/uid-a'];
      expect(raw!['weekStartMs'], weekStartMs(now.millisecondsSinceEpoch));
      expect(raw['lastCountedMatch'], 'MATCH1');
    });

    test(
      'a loss counts 1; a duplicate and a short match do not count',
      () async {
        expect(
          await submit('uid-a', won: false),
          LeaderboardSubmitOutcome.counted,
        );
        expect(
          await submit('uid-a', won: false),
          LeaderboardSubmitOutcome.notCounted,
        );
        expect(
          await submit('uid-a', matchId: 'SHORT', plies: 9),
          LeaderboardSubmitOutcome.notCounted,
        );
        final entry = await repoFor('uid-a')
            .fetchEntry(weekStartMs(now.millisecondsSinceEpoch), 'uid-a');
        expect(entry!.points, 1);
        expect(entry.losses, 1);
      },
    );

    test('a match from last week cannot be counted into this one', () async {
      final lastWeek = now.subtract(const Duration(days: 7));
      expect(
        await submit('uid-a', endedAtMs: lastWeek.millisecondsSinceEpoch),
        LeaderboardSubmitOutcome.notCounted,
      );
    });

    test('the per-opponent cap is 3 counted matches', () async {
      for (var i = 1; i <= 3; i++) {
        expect(
          await submit('uid-a', matchId: 'M$i'),
          LeaderboardSubmitOutcome.counted,
        );
      }
      expect(
        await submit('uid-a', matchId: 'M4'),
        LeaderboardSubmitOutcome.notCounted,
      );
      // A different opponent still counts.
      expect(
        await submit('uid-a', matchId: 'M5', opponent: 'opp-2'),
        LeaderboardSubmitOutcome.counted,
      );
    });

    test('the weekly cap is 20 counted matches', () async {
      var counted = 0;
      for (var i = 0; i < 21; i++) {
        final outcome = await submit(
          'uid-a',
          matchId: 'M$i',
          opponent: 'opp-${i % 7}',
        );
        if (outcome == LeaderboardSubmitOutcome.counted) counted++;
      }
      expect(counted, 20);
    });

    test('fetchTop orders by points, then wins, then uid', () async {
      Future<void> seed(String uid, int points, int wins) async {
        await submit(uid, matchId: 'SEED-$uid', won: points >= 3);
        // Adjust the stored entry directly for the ordering
        // fixture (points/wins combinations recordResult
        // alone cannot reach quickly).
        final week = weekStartMs(now.millisecondsSinceEpoch);
        final path = 'leaderboards/$week/entries/$uid';
        store.documents[path] = {
          ...store.documents[path]!,
          'points': points,
          'wins': wins,
        };
      }

      await seed('uid-b', 10, 2);
      await seed('uid-a', 10, 3);
      await seed('uid-c', 10, 3);
      await seed('uid-d', 4, 9);
      final top = await repoFor('uid-a')
          .fetchTop(weekStartMs(now.millisecondsSinceEpoch));
      expect(top.map((e) => e.uid), ['uid-a', 'uid-c', 'uid-b', 'uid-d']);
    });

    test(
      'rename changes only the name, and only when an entry exists',
      () async {
        expect(
          await repoFor('uid-a').renameCurrentEntry(displayName: 'New Name 42'),
          isFalse,
        );
        await submit('uid-a');
        expect(
          await repoFor('uid-a').renameCurrentEntry(displayName: 'New Name 42'),
          isTrue,
        );
        final entry = await repoFor('uid-a')
            .fetchEntry(weekStartMs(now.millisecondsSinceEpoch), 'uid-a');
        expect(entry!.displayName, 'New Name 42');
        expect(entry.points, 3);
        expect(entry.countedMatches, {'MATCH1': 'opp-1'});
      },
    );
  });
}
