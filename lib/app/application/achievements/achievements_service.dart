import '../../../domain/models/achievement.dart';
import '../../../domain/repositories/repositories.dart';
import 'achievement_evaluator.dart';

/// Orchestrates achievement evaluation (Phase 16.5, Part F):
/// after a match is recorded, evaluate the catalogue over the
/// full history + statistics, persist any new unlocks with
/// their unlock time, and report what is new so the caller can
/// toast it.
///
/// Idempotent by construction: evaluation is a pure function
/// and the store only ever gains entries, so running this
/// twice — or after every match for a year — unlocks each
/// achievement exactly once.
///
/// Achievements are local and fakeable (the store is the
/// player's own device). They never feed the leaderboard or
/// anything else.
class AchievementsService {
  AchievementsService({
    required this.history,
    required this.statistics,
    required this.store,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Where match records live.
  final MatchHistoryRepository history;

  /// The legacy statistics snapshot source.
  final StatisticsRepository statistics;

  /// The unlock store.
  final AchievementsRepository store;

  final DateTime Function() _clock;

  /// The current unlock map (id → unlock time, epoch ms).
  Future<Map<String, int>> loadUnlocks() => store.loadUnlocks();

  /// Evaluates after a recorded match. Returns the definitions
  /// unlocked by this call (usually zero or one), in catalogue
  /// order.
  Future<List<AchievementDefinition>> onMatchRecorded() async {
    final records = await history.load();
    final stats = await statistics.load();
    final earned = AchievementEvaluator.evaluate(records, stats);
    return _unlockAll(earned);
  }

  /// The leaderboard hook (Part H): a fetched top-10 placing
  /// is the ONLY way 'top-10-week' unlocks. A rank outside the
  /// top 10 — or no fetched data at all — unlocks nothing.
  Future<List<AchievementDefinition>> onLeaderboardRank(int? rank) async {
    if (rank == null || rank < 1 || rank > 10) return const [];
    return _unlockAll(const {'top-10-week'});
  }

  Future<List<AchievementDefinition>> _unlockAll(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final current = await store.loadUnlocks();
    final fresh = ids.difference(current.keys.toSet());
    if (fresh.isEmpty) return const [];
    final nowMs = _clock().millisecondsSinceEpoch;
    final updated = {...current, for (final id in fresh) id: nowMs};
    await store.saveUnlocks(updated);
    return [
      for (final definition in kAchievements)
        if (fresh.contains(definition.id)) definition,
    ];
  }
}
