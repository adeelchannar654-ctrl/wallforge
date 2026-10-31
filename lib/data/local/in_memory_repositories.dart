import '../../domain/models/match_record.dart';
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

/// In-memory [MatchHistoryRepository] with the same gate and
/// bound semantics as the shared-preferences implementation.
class InMemoryMatchHistoryRepository implements MatchHistoryRepository {
  InMemoryMatchHistoryRepository([List<MatchRecord>? initial])
    : _records = [...?initial],
      _recordedIds = <String>{
        for (final r in initial ?? const <MatchRecord>[]) r.id,
      };

  List<MatchRecord> _records;
  final Set<String> _recordedIds;

  @override
  Future<List<MatchRecord>> load() async => List.unmodifiable(_records);

  @override
  Future<bool> recordIfNew(MatchRecord record) async {
    if (_recordedIds.contains(record.id)) return false;
    _recordedIds.add(record.id);
    _records = [
      record,
      ..._records,
    ].take(MatchHistoryRepository.maxRecords).toList();
    // The gate is bounded with the records: the set's
    // insertion order is chronological, so trimming the FIRST
    // ids drops the oldest — the blob store's take() on its
    // newest-first list, mirrored.
    while (_recordedIds.length > MatchHistoryRepository.maxRecords) {
      _recordedIds.remove(_recordedIds.first);
    }
    return true;
  }

  @override
  Future<void> delete(String id) async {
    _records = _records.where((r) => r.id != id).toList();
  }

  @override
  Future<void> clear() async {
    _records = [];
  }
}
