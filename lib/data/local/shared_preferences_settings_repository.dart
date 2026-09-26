import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/repositories.dart';

/// Settings stored with `shared_preferences`.
///
/// Chosen because `rules.md` §4 already approves `shared_preferences` for
/// exactly this purpose ("Small local settings / Tutorial completion / Simple
/// local preferences"), so this is the project's pre-decided mechanism rather
/// than a new dependency. `rules.md` §4 also notes a local database is only
/// warranted for *larger* local storage; a few hundred bytes of settings is far
/// below that bar.
///
/// Defensive by construction: every read tolerates a missing key, a wrong type
/// or unparseable JSON and falls back to defaults, because a corrupt store must
/// never stop the app from starting.
class SharedPreferencesSettingsRepository implements SettingsRepository {
  const SharedPreferencesSettingsRepository({
    this.key = 'wallforge.settings.v1',
  });

  /// Storage key, versioned so a future shape change can migrate rather than
  /// misread old data.
  final String key;

  @override
  Future<AppSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return AppSettings.defaults;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AppSettings.defaults;
      return AppSettings.fromJson(decoded.cast<String, dynamic>());
    } on Object {
      // Any storage or decoding failure degrades to defaults.
      return AppSettings.defaults;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(settings.toJson()));
    } on Object {
      // A failed write must not break gameplay; the setting simply will not
      // survive a restart.
    }
  }
}
