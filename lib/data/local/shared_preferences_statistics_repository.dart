import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/repositories.dart';

/// Match statistics stored with `shared_preferences`.
///
/// See [SharedPreferencesSettingsRepository] for why `shared_preferences` is the
/// sanctioned mechanism. Statistics are a handful of counters, so they stay well
/// inside the "small local preferences" bucket.
///
/// The read-modify-write in [recordResult] is not atomic across processes, which
/// is accepted deliberately: the app is a single local pass-and-play/AI client
/// and Phase 7's online implementation replaces this entirely.
class SharedPreferencesStatisticsRepository implements StatisticsRepository {
  const SharedPreferencesStatisticsRepository({
    this.key = 'wallforge.statistics.v1',
  });

  /// Versioned storage key.
  final String key;

  @override
  Future<MatchStatistics> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return MatchStatistics.empty;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return MatchStatistics.empty;
      return MatchStatistics.fromJson(decoded.cast<String, dynamic>());
    } on Object {
      return MatchStatistics.empty;
    }
  }

  @override
  Future<MatchStatistics> recordResult({
    required int boardSize,
    required String difficulty,
    required bool humanWon,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await load();
      final updated = current.recordResult(
        boardSize: boardSize,
        difficulty: difficulty,
        humanWon: humanWon,
      );
      await prefs.setString(key, jsonEncode(updated.toJson()));
      return updated;
    } on Object {
      return await load();
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } on Object {
      // Nothing to do; the statistics simply remain.
    }
  }
}
