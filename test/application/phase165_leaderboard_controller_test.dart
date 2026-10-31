import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/achievements/achievements_service.dart';
import 'package:wallforge/app/application/online/leaderboard_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';

/// Phase 16.5, Part H: the leaderboard controller — states,
/// the five-minute shared cache with exact fetch counts, the
/// 50+ case, name regeneration, and the fetched-data-only
/// top-10 achievement hook.
class _FakeLeaderboardRepository implements LeaderboardRepository {
  List<LeaderboardEntry> top = const [];
  LeaderboardEntry? mine;
  bool fail = false;
  int fetchTopCalls = 0;
  int fetchEntryCalls = 0;
  String? renamedTo;

  @override
  Future<List<LeaderboardEntry>> fetchTop(
    int weekStart, {
    int limit = kLeaderboardTopLimit,
  }) async {
    fetchTopCalls++;
    if (fail) throw StateError('transport down');
    return top.take(limit).toList();
  }

  @override
  Future<LeaderboardEntry?> fetchEntry(int weekStart, String uid) async {
    fetchEntryCalls++;
    if (fail) throw StateError('transport down');
    return mine;
  }

  @override
  Future<LeaderboardSubmitOutcome> recordResult({
    required String matchId,
    required String opponentUid,
    required bool won,
    required int plies,
    required int matchEndedAtMs,
    required String displayName,
  }) async => LeaderboardSubmitOutcome.counted;

  @override
  Future<bool> renameCurrentEntry({required String displayName}) async {
    renamedTo = displayName;
    return true;
  }
}

LeaderboardEntry entry(String uid, int points) => LeaderboardEntry(
  uid: uid,
  displayName: generateDisplayName(uid, 0),
  points: points,
  wins: points ~/ 3,
  losses: 0,
  countedMatches: const {},
  opponentCounts: const {},
);

void main() {
  late _FakeLeaderboardRepository repo;
  late InMemoryLeaderboardNameRepository names;
  late DateTime now;

  LeaderboardController controller({AchievementsService? achievements}) =>
      LeaderboardController(
        repository: repo,
        names: names,
        myUid: 'uid-me',
        achievements: achievements,
        clock: () => now,
      );

  setUp(() {
    LeaderboardController.clearCache();
    repo = _FakeLeaderboardRepository();
    names = InMemoryLeaderboardNameRepository();
    now = DateTime.utc(2026, 10, 28, 12);
  });

  test('load: ready with entries, rank, and last week fetched once', () async {
    repo.top = [entry('uid-x', 9), entry('uid-me', 6), entry('uid-y', 3)];
    repo.mine = repo.top[1];
    final c = controller();
    await c.load();
    expect(c.status, LeaderboardStatus.ready);
    expect(c.myRank, 2);
    expect(c.entries, hasLength(3));
    // One load = top-50 fetch + own entry + last-week podium.
    expect(repo.fetchTopCalls, 2);
    expect(repo.fetchEntryCalls, 1);
  });

  test('the cache is shared across instances for five minutes', () async {
    repo.top = [entry('uid-me', 3)];
    repo.mine = repo.top.single;
    await controller().load();
    expect(repo.fetchTopCalls, 2);

    // A new screen instance within the interval: no fetch.
    final second = controller();
    await second.load();
    expect(second.status, LeaderboardStatus.ready);
    expect(repo.fetchTopCalls, 2);
    expect(second.refreshIn, greaterThan(Duration.zero));

    // After the interval, a load fetches again.
    now = now.add(const Duration(minutes: 6));
    await controller().load();
    expect(repo.fetchTopCalls, 4);
  });

  test('empty and unavailable are distinct states', () async {
    repo.top = const [];
    repo.mine = null;
    final empty = controller();
    await empty.load();
    expect(empty.status, LeaderboardStatus.empty);

    LeaderboardController.clearCache();
    repo.fail = true;
    final down = controller();
    await down.load();
    expect(down.status, LeaderboardStatus.unavailable);
  });

  test('an entry outside the top shows as 50+', () async {
    repo.top = [for (var i = 0; i < 50; i++) entry('uid-$i', 100 - i)];
    repo.mine = entry('uid-me', 1);
    final c = controller();
    await c.load();
    expect(c.myRank, isNull);
    expect(c.mineOutsideTop, isTrue);
  });

  test('the top-10 hook fires from fetched data only', () async {
    final store = InMemoryAchievementsRepository();
    final service = AchievementsService(
      history: InMemoryMatchHistoryRepository(),
      statistics: InMemoryStatisticsRepository(),
      store: store,
    );
    repo.top = [entry('uid-a', 9), entry('uid-me', 6)];
    repo.mine = repo.top[1];
    await controller(achievements: service).load();
    await pumpEventQueue();
    expect((await store.loadUnlocks()).keys, contains('top-10-week'));

    // Rank 11 unlocks nothing.
    LeaderboardController.clearCache();
    final store2 = InMemoryAchievementsRepository();
    final service2 = AchievementsService(
      history: InMemoryMatchHistoryRepository(),
      statistics: InMemoryStatisticsRepository(),
      store: store2,
    );
    repo.top = [
      for (var i = 0; i < 10; i++) entry('uid-$i', 100 - i),
      entry('uid-me', 1),
    ];
    repo.mine = repo.top.last;
    await controller(achievements: service2).load();
    await pumpEventQueue();
    expect(await store2.loadUnlocks(), isEmpty);
  });

  test('regenerating renames the entry and the local name', () async {
    repo.top = [entry('uid-me', 3)];
    repo.mine = repo.top.single;
    final c = controller();
    await c.load();
    final before = c.displayName;
    await c.regenerateName();
    expect(c.displayName, isNot(before));
    expect(repo.renamedTo, c.displayName);
    expect(c.myEntry!.displayName, c.displayName);
    expect(c.entries.single.displayName, c.displayName);
  });

  test('the reset countdown targets Monday 00:00 UTC', () async {
    final c = controller();
    // Wednesday noon UTC: 4 days 12 hours remain.
    expect(c.resetIn, const Duration(days: 4, hours: 12));
  });
}
