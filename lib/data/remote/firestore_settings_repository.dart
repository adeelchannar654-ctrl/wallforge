import 'dart:async';

import '../../domain/repositories/repositories.dart';
import 'firestore_client.dart';

/// Resolves the owner id that scopes a user's documents.
///
/// This is the seam that keeps Phase 7 from inventing a login system.
/// `phase.md` Phase 7 lists the `firebase_auth` *package* as a task, but
/// "Authentication" as a *feature* is a Phase 8 task, so there is no signed-in
/// user yet and therefore no `currentUser.uid` to key documents on.
///
/// Phase 7 wiring supplies a locally generated device id, so a developer's
/// documents are isolated per install; Phase 8 replaces this with the real
/// authenticated uid and nothing above this file changes. Recorded as Q-7.2.
typedef UserIdResolver = Future<String?> Function();

/// Firestore-backed [SettingsRepository].
///
/// Document layout, three small documents per user:
///
/// ```text
/// users/{uid}/settings
/// ```
class FirestoreSettingsRepository implements SettingsRepository {
  FirestoreSettingsRepository({
    required this.client,
    required this.userId,
    this.collection = 'users',
    this.document = 'settings',
  });

  /// Document transport.
  final FirestoreClient client;

  /// Resolves the owner id that scopes this user's documents.
  final UserIdResolver userId;

  /// Top-level collection name.
  final String collection;

  /// Document name holding the settings.
  final String document;

  /// The document path for a user, or null when there is no owner yet.
  Future<String?> _path() async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return null;
    return '$collection/$uid/$document';
  }

  @override
  Future<AppSettings> load() async {
    final path = await _path();
    if (path == null) return AppSettings.defaults;
    final data = await _read(path);
    if (data == null) return AppSettings.defaults;
    return AppSettings.fromJson(_settingsFields(data));
  }

  @override
  Future<void> save(AppSettings settings) async {
    final path = await _path();
    if (path == null) return;
    await _write(path, <String, dynamic>{
      ...settings.toJson(),
      'schemaVersion': schemaVersion,
    });
  }

  /// Reads through the client, converting a transport failure into "nothing
  /// stored".
  ///
  /// The guard lives here rather than only in the client so totality is a
  /// property of the *repository*, exactly as in the Phase 6 local
  /// implementation. Relying on the client to swallow every error would make
  /// "a failing store never breaks the app" true only for one implementation —
  /// a test with a throwing client caught precisely that.
  Future<Map<String, dynamic>?> _read(String path) async {
    try {
      return await client.read(path);
    } on Object {
      return null;
    }
  }

  Future<void> _write(String path, Map<String, dynamic> data) async {
    try {
      await client.write(path, data);
    } on Object {
      // A failed write costs persistence, not play.
    }
  }

  /// Accepts both the flat layout written here and a nested one, so a document
  /// written by a future version cannot make settings unreadable.
  static Map<String, dynamic> _settingsFields(Map<String, dynamic> data) {
    final nested = data['settings'];
    if (nested is Map) return nested.cast<String, dynamic>();
    return data;
  }

  /// Storage layout version, so a later migration is detectable.
  static const int schemaVersion = 1;
}
