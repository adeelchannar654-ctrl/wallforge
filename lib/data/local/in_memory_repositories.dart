import '../../domain/repositories/repositories.dart';

/// In-memory [SettingsRepository], for tests and as a null object.
///
/// Implements the same contracts as the `shared_preferences` implementations so
/// the application layer cannot tell the difference — which is exactly the point
/// of the repository boundary. Because it is the default when no storage is
/// supplied, an app launched without persistence wired up still behaves
/// correctly; it simply forgets on exit.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository([AppSettings? initial])
    : _settings = initial ?? AppSettings.defaults;

  AppSettings _settings;

  /// Number of times [save] was called, so tests can assert write-through.
  int saveCount = 0;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
    saveCount++;
  }
}

/// In-memory [StatisticsRepository].
class InMemoryStatisticsRepository implements StatisticsRepository {
  InMemoryStatisticsRepository([MatchStatistics? initial])
    : _statistics = initial ?? MatchStatistics.empty;

  MatchStatistics _statistics;

  @override
  Future<MatchStatistics> load() async => _statistics;

  @override
  Future<MatchStatistics> recordResult({
    required int boardSize,
    required String difficulty,
    required bool humanWon,
  }) async {
    _statistics = _statistics.recordResult(
      boardSize: boardSize,
      difficulty: difficulty,
      humanWon: humanWon,
    );
    return _statistics;
  }

  @override
  Future<void> clear() async => _statistics = MatchStatistics.empty;
}

/// In-memory [UnfinishedMatchRepository].
class InMemoryUnfinishedMatchRepository implements UnfinishedMatchRepository {
  InMemoryUnfinishedMatchRepository([UnfinishedMatch? initial])
    : _match = initial;

  UnfinishedMatch? _match;

  @override
  Future<UnfinishedMatch?> load() async => _match;

  @override
  Future<void> save(UnfinishedMatch match) async => _match = match;

  @override
  Future<void> clear() async => _match = null;
}
