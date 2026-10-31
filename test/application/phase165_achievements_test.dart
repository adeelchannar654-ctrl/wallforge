import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/achievements/achievement_evaluator.dart';
import 'package:wallforge/app/application/achievements/achievements_service.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part F: the achievement predicates against
/// crafted records, the service's idempotent unlocking, and
/// the controller hook that fires the toast callback.
MatchRecord rec({
  String id = 'm',
  MatchMode mode = MatchMode.versusAi,
  int boardSize = 9,
  int wallsPerPlayer = 10,
  PlayerId? mySide = PlayerId.blue,
  PlayerId? winnerSide = PlayerId.blue,
  FinishReason finishReason = FinishReason.goal,
  String opponentLabel = 'AI · Easy',
  List<String> moves = const ['M 7,4'],
  bool movesComplete = true,
  int? plies,
  int timeControlSeconds = 0,
  String? rematchOf,
}) => MatchRecord(
  id: id,
  mode: mode,
  boardSize: boardSize,
  wallsPerPlayer: wallsPerPlayer,
  mySide: mySide,
  winnerSide: winnerSide,
  finishReason: finishReason,
  opponentLabel: opponentLabel,
  plies: plies ?? moves.length,
  durationMs: 60000,
  endedAtMs: 1000,
  timeControlSeconds: timeControlSeconds,
  moves: moves,
  movesComplete: movesComplete,
  rematchOf: rematchOf,
);

void main() {
  group('AchievementEvaluator', () {
    Set<String> evaluate(List<MatchRecord> records, [MatchStatistics? stats]) =>
        AchievementEvaluator.evaluate(records, stats ?? MatchStatistics.empty);

    test('first win: from a record, and from legacy statistics alone', () {
      expect(evaluate([rec()]), contains('first-win'));
      expect(evaluate(const []), isNot(contains('first-win')));
      const legacy = MatchStatistics(humanWins: 3, matchesPlayed: 5);
      expect(evaluate(const [], legacy), contains('first-win'));
    });

    test('a pass-and-play record counts its Blue win, not a Red one', () {
      expect(
        evaluate([rec(mode: MatchMode.local, mySide: null)]),
        contains('first-win'),
      );
      expect(
        evaluate([
          rec(mode: MatchMode.local, mySide: null, winnerSide: PlayerId.red),
        ]),
        isNot(contains('first-win')),
      );
    });

    test('an abandoned match is nobody\'s win', () {
      expect(
        evaluate([rec(winnerSide: null, finishReason: FinishReason.abandon)]),
        isEmpty,
      );
    });

    test('streaks use the best run, and a loss ends a run', () {
      // Stored newest first; chronological: W W L W W W.
      final records = [
        rec(id: '6'),
        rec(id: '5'),
        rec(id: '4'),
        rec(id: '3', winnerSide: PlayerId.red),
        rec(id: '2'),
        rec(id: '1'),
      ];
      final unlocked = evaluate(records);
      expect(unlocked, contains('streak-3'));
      expect(unlocked, isNot(contains('streak-5')));
      expect(
        AchievementEvaluator.progress(
          'streak-5',
          records,
          MatchStatistics.empty,
        ),
        (3, 5),
      );
    });

    test('beat each difficulty: from records and from legacy buckets', () {
      expect(
        evaluate([rec(opponentLabel: 'AI · Expert')]),
        contains('beat-expert'),
      );
      expect(
        evaluate([rec(opponentLabel: 'AI · Expert', winnerSide: PlayerId.red)]),
        isNot(contains('beat-expert')),
      );
      const legacy = MatchStatistics(
        matchesPlayed: 2,
        byDifficulty: {'hard': Bucket(played: 2, wins: 1)},
      );
      expect(evaluate(const [], legacy), contains('beat-hard'));
    });

    test('every board: sizes from records and legacy buckets combine', () {
      final records = [
        rec(id: 'a', boardSize: 5),
        rec(id: 'b', boardSize: 7),
        rec(id: 'c'), // boardSize 9, the factory default
      ];
      expect(evaluate(records), isNot(contains('all-boards')));
      expect(
        AchievementEvaluator.progress(
          'all-boards',
          records,
          MatchStatistics.empty,
        ),
        (3, 4),
      );
      const legacy = MatchStatistics(
        matchesPlayed: 1,
        byBoardSize: {'11': Bucket(played: 1, wins: 1)},
      );
      expect(evaluate(records, legacy), contains('all-boards'));
    });

    test('wall counts follow the winner\'s plies only', () {
      // Blue wins; the only wall is Red's (ply index 1).
      final noWalls = rec(moves: ['M 7,4', 'W H 4,4', 'M 6,4']);
      expect(evaluate([noWalls]), contains('no-walls-win'));
      // Blue's own wall (ply index 0) breaks Minimalist.
      final ownWall = rec(moves: ['W H 4,4', 'M 1,4', 'M 6,4']);
      expect(evaluate([ownWall]), isNot(contains('no-walls-win')));
      // Both walls placed by the winner of a 2-wall game.
      final builder = rec(
        wallsPerPlayer: 2,
        moves: ['W H 4,4', 'M 1,4', 'W V 2,2', 'M 2,4', 'M 6,4'],
      );
      expect(evaluate([builder]), contains('fully-walled'));
      // A partial move list proves nothing.
      final partial = rec(moves: ['M 7,4'], movesComplete: false);
      expect(evaluate([partial]), isNot(contains('no-walls-win')));
    });

    test('fast win is a plies threshold', () {
      expect(evaluate([rec(plies: 25, moves: const [])]), contains('fast-win'));
      expect(
        evaluate([rec(plies: 26, moves: const [])]),
        isNot(contains('fast-win')),
      );
    });

    test('comeback: a genuine come-from-behind line on 5x5', () {
      // Blue dawdles while Red closes to one step from goal
      // (deficit 3 after ply 6), then Blue sprints home.
      final comeback = rec(
        boardSize: 5,
        moves: [
          'M 4,1', 'M 1,2', // B sideways, R advances
          'M 4,2', 'M 2,2',
          'M 4,1', 'M 3,2', // R is 1 step away; B is 4 away
          'M 3,1', 'M 3,3',
          'M 2,1', 'M 3,2',
          'M 1,1', 'M 3,3',
          'M 0,1', // Blue reaches the goal
        ],
      );
      expect(evaluate([comeback]), contains('comeback'));
      // A wire-to-wire win never trails.
      final wireToWire = rec(
        boardSize: 5,
        moves: ['M 3,2', 'M 0,3', 'M 2,2', 'M 0,2', 'M 1,2', 'M 0,3', 'M 0,2'],
      );
      expect(evaluate([wireToWire]), isNot(contains('comeback')));
    });

    test('timeout, online and rematch wins', () {
      expect(
        evaluate([rec(finishReason: FinishReason.timeout)]),
        contains('timeout-win'),
      );
      expect(
        evaluate([rec(mode: MatchMode.online, opponentLabel: 'Online player')]),
        contains('online-win'),
      );
      expect(evaluate([rec(rematchOf: 'earlier')]), contains('rematch-win'));
      // The evaluator never produces the external achievement.
      expect(
        evaluate([rec(mode: MatchMode.online, opponentLabel: 'Online player')]),
        isNot(contains('top-10-week')),
      );
    });
  });

  group('AchievementsService', () {
    late InMemoryMatchHistoryRepository history;
    late InMemoryStatisticsRepository stats;
    late InMemoryAchievementsRepository store;
    late AchievementsService service;

    setUp(() {
      history = InMemoryMatchHistoryRepository();
      stats = InMemoryStatisticsRepository();
      store = InMemoryAchievementsRepository();
      service = AchievementsService(
        history: history,
        statistics: stats,
        store: store,
        clock: () => DateTime.utc(2026, 10, 31, 20),
      );
    });

    test('unlocks once, persists, and never re-reports', () async {
      await history.recordIfNew(rec());
      final fresh = await service.onMatchRecorded();
      expect(
        fresh.map((d) => d.id),
        containsAll(['first-win', 'beat-easy', 'fast-win']),
      );
      expect(await service.onMatchRecorded(), isEmpty);
      final unlocks = await store.loadUnlocks();
      expect(unlocks['first-win'], isNotNull);
      // A fresh service over the same store agrees.
      final restarted = AchievementsService(
        history: history,
        statistics: stats,
        store: store,
      );
      expect(await restarted.onMatchRecorded(), isEmpty);
    });

    test('the leaderboard hook is the only way to Top of the Week', () async {
      expect(await service.onLeaderboardRank(null), isEmpty);
      expect(await service.onLeaderboardRank(11), isEmpty);
      final fresh = await service.onLeaderboardRank(10);
      expect(fresh.map((d) => d.id), ['top-10-week']);
      expect(await service.onLeaderboardRank(1), isEmpty);
    });
  });

  group('controller hook', () {
    test('a recorded finish fires the unlock callback once', () async {
      final history = InMemoryMatchHistoryRepository();
      final stats = InMemoryStatisticsRepository();
      final service = AchievementsService(
        history: history,
        statistics: stats,
        store: InMemoryAchievementsRepository(),
      );
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.attachPersistence(
        settings: InMemorySettingsRepository(),
        statistics: stats,
        unfinishedMatch: InMemoryUnfinishedMatchRepository(),
        history: history,
        achievements: service,
      );
      final seen = <String>[];
      controller.onAchievementsUnlocked = (unlocked) =>
          seen.addAll(unlocked.map((d) => d.id));
      controller.startMatch(versusAi: true);
      controller.resign(PlayerId.red); // the AI concedes: human wins
      await pumpEventQueue();
      expect(seen, contains('first-win'));
      expect(seen, contains('beat-easy'));
    });
  });
}
