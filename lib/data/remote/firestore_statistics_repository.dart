import 'dart:async';

import '../../domain/repositories/repositories.dart';
import 'firestore_client.dart';
import 'firestore_settings_repository.dart' show UserIdResolver;

/// Firestore-backed [StatisticsRepository].
///
/// ```text
/// users/{uid}/statistics
/// ```
///
/// One read-modify-write document per user, which is the cheapest shape the free
/// tier allows: a match result is a single `set`, not an increment, so there is
/// no transaction and no per-play document growth. The read-modify-write is not
/// atomic across devices; that is acceptable while the owner id is per-install
/// (see [UserIdResolver]) and is called out in `memory.md` §13o.
class FirestoreStatisticsRepository implements StatisticsRepository {
  FirestoreStatisticsRepository({
    required this.client,
    required this.userId,
    this.collection = 'users',
    this.document = 'statistics',
  });

  final FirestoreClient client;
  final UserIdResolver userId;

  final String collection;
  final String document;

  /// Storage layout version, so a later migration is detectable.
  static const int schemaVersion = 1;

  Future<String?> _path() async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return null;
    return '$collection/$uid/$document';
  }

  @override
  Future<MatchStatistics> load() async {
    final path = await _path();
    if (path == null) return MatchStatistics.empty;
    final data = await _read(path);
    if (data == null) return MatchStatistics.empty;
    final nested = data['statistics'];
    if (nested is Map) {
      return MatchStatistics.fromJson(nested.cast<String, dynamic>());
    }
    return MatchStatistics.fromJson(data);
  }

  @override
  Future<MatchStatistics> recordResult({
    required int boardSize,
    required String difficulty,
    required bool humanWon,
  }) async {
    final current = await load();
    final updated = current.recordResult(
      boardSize: boardSize,
      difficulty: difficulty,
      humanWon: humanWon,
    );
    final path = await _path();
    if (path == null) return updated;
    await _write(path, <String, dynamic>{
      ...updated.toJson(),
      'schemaVersion': schemaVersion,
    });
    return updated;
  }

  @override
  Future<void> clear() async {
    final path = await _path();
    if (path == null) return;
    try {
      await client.delete(path);
    } on Object {
      // Nothing to do; the document is already absent from our point of view.
    }
  }

  /// Totality is enforced here, not delegated to the client — see the note in
  /// `FirestoreSettingsRepository._read`.
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
}
