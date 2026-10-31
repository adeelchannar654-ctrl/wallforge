import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/leaderboard.dart';

/// The display-name generation store (Phase 16.5, Part H):
/// one small int per uid in shared preferences.
class SharedPreferencesLeaderboardNameRepository
    implements LeaderboardNameRepository {
  const SharedPreferencesLeaderboardNameRepository({
    this.keyPrefix = 'wallforge.leaderboard_name.v1',
  });

  /// Storage key prefix; the uid is appended per player.
  final String keyPrefix;

  @override
  Future<int> loadGeneration(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$keyPrefix.$uid') ?? 0;
    } on Object {
      return 0;
    }
  }

  @override
  Future<void> saveGeneration(String uid, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$keyPrefix.$uid', generation);
    } on Object {
      // Nothing to do; the name simply regenerates next time.
    }
  }
}

/// In-memory [LeaderboardNameRepository] for tests.
class InMemoryLeaderboardNameRepository implements LeaderboardNameRepository {
  final Map<String, int> _generations = {};

  @override
  Future<int> loadGeneration(String uid) async => _generations[uid] ?? 0;

  @override
  Future<void> saveGeneration(String uid, int generation) async {
    _generations[uid] = generation;
  }
}
