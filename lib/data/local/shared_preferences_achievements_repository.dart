import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/repositories.dart';

/// Achievement unlocks stored with `shared_preferences`
/// (Phase 16.5, Part F).
///
/// One JSON blob: `{"schemaVersion": 1, "unlocks": {"id": ms}}`.
/// Tolerance mirrors the history store: corrupt reads as no
/// unlocks; a newer schema reads as no unlocks and is never
/// overwritten by this build.
class SharedPreferencesAchievementsRepository
    implements AchievementsRepository {
  const SharedPreferencesAchievementsRepository({
    this.key = 'wallforge.achievements.v1',
  });

  /// Versioned storage key.
  final String key;

  /// The blob schema this build reads and writes.
  static const int blobSchemaVersion = 1;

  @override
  Future<Map<String, int>> loadUnlocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return const {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final map = decoded.cast<String, dynamic>();
      final version = map['schemaVersion'];
      if (version is int && version > blobSchemaVersion) return const {};
      final unlocks = map['unlocks'];
      if (unlocks is! Map) return const {};
      return {
        for (final entry in unlocks.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: entry.value as int,
      };
    } on Object {
      return const {};
    }
  }

  @override
  Future<void> saveUnlocks(Map<String, int> unlocks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final version = decoded['schemaVersion'];
          if (version is int && version > blobSchemaVersion) return;
        }
      }
      await prefs.setString(
        key,
        jsonEncode(<String, dynamic>{
          'schemaVersion': blobSchemaVersion,
          'unlocks': unlocks,
        }),
      );
    } on Object {
      // Nothing to do; the unlocks simply remain unsaved.
    }
  }
}
