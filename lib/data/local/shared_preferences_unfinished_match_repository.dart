import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/repositories.dart';

/// The resumable match, stored with `shared_preferences`.
///
/// `phase.md` Phase 6 calls the unfinished game *optional*. It is implemented
/// because the data already exists — [UnfinishedMatch] reuses the engine's own
/// `GameStateSerializer` — and a single 9x9 mid-game state is roughly 1-2 KB,
/// comfortably inside the "small local preferences" bucket that `rules.md` §4
/// assigns to `shared_preferences`. A full match history would exceed that and
/// is the point at which `rules.md` says to consider a local database; that is
/// not needed here.
class SharedPreferencesUnfinishedMatchRepository
    implements UnfinishedMatchRepository {
  const SharedPreferencesUnfinishedMatchRepository({
    this.key = 'wallforge.unfinished_match.v1',
  });

  /// Versioned storage key.
  final String key;

  @override
  Future<UnfinishedMatch?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return UnfinishedMatch.fromJson(decoded.cast<String, dynamic>());
    } on Object {
      // A corrupt or unparseable save means "nothing to resume", never a crash.
      return null;
    }
  }

  @override
  Future<void> save(UnfinishedMatch match) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(match.toJson()));
    } on Object {
      // A failed write costs the resume affordance, nothing more.
    }
  }

  @override
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } on Object {
      // Nothing to do.
    }
  }
}
