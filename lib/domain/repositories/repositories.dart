import 'app_settings.dart';
import 'match_statistics.dart';
import 'unfinished_match.dart';

export 'app_settings.dart';
export 'match_statistics.dart';
export 'unfinished_match.dart';

/// Local persistence contracts, declared in the domain layer and implemented in
/// `lib/data/local/`.
///
/// `architecture.md` §2.4 requires repositories to "expose domain-friendly
/// interfaces to the application layer", and `lib/data/README.md` states the
/// dependency direction as `Data -> Domain interfaces`. Keeping the contracts
/// here is what lets Phase 7 supply a Firebase implementation without the
/// application layer changing.
///
/// All methods are `Future`-returning because a real device write is async, and
/// none of them throw: a storage failure resolves to the default value, because
/// losing a setting must never stop the app from starting.
abstract interface class SettingsRepository {
  /// Loads persisted settings, or [AppSettings.defaults] when nothing is stored
  /// or the stored value is unreadable.
  Future<AppSettings> load();

  /// Persists [settings], replacing whatever was stored.
  Future<void> save(AppSettings settings);
}

/// Local match-result history.
abstract interface class StatisticsRepository {
  /// Loads accumulated statistics, or [MatchStatistics.empty].
  Future<MatchStatistics> load();

  /// Folds one finished match into the stored totals and returns the new value.
  Future<MatchStatistics> recordResult({
    required int boardSize,
    required String difficulty,
    required bool humanWon,
  });

  /// Discards all stored statistics.
  Future<void> clear();
}

/// The single resumable match.
abstract interface class UnfinishedMatchRepository {
  /// Loads the resumable match, or null when there is none or it is unreadable.
  Future<UnfinishedMatch?> load();

  /// Stores [match] as the resumable match, replacing any previous one.
  Future<void> save(UnfinishedMatch match);

  /// Removes the resumable match. Called when a match finishes or is abandoned.
  Future<void> clear();
}
