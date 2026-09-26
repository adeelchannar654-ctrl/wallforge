import 'dart:async';

import '../../domain/repositories/repositories.dart';
import 'firestore_client.dart';
import 'firestore_settings_repository.dart' show UserIdResolver;

/// Firestore-backed [UnfinishedMatchRepository].
///
/// ```text
/// users/{uid}/unfinishedMatch
/// ```
///
/// The saved state goes through the same `GameStateSerializer` round-trip as the
/// local implementation, so a stored state that violates a spec invariant is
/// rejected by the engine's own decoder rather than by a second schema.
class FirestoreUnfinishedMatchRepository implements UnfinishedMatchRepository {
  FirestoreUnfinishedMatchRepository({
    required this.client,
    required this.userId,
    this.collection = 'users',
    this.document = 'unfinishedMatch',
  });

  final FirestoreClient client;
  final UserIdResolver userId;

  final String collection;
  final String document;

  Future<String?> _path() async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return null;
    return '$collection/$uid/$document';
  }

  @override
  Future<UnfinishedMatch?> load() async {
    final path = await _path();
    if (path == null) return null;
    final data = await _read(path);
    if (data == null) return null;
    final nested = data['unfinishedMatch'];
    if (nested is Map) {
      return UnfinishedMatch.fromJson(nested.cast<String, dynamic>());
    }
    return UnfinishedMatch.fromJson(data);
  }

  @override
  Future<void> save(UnfinishedMatch match) async {
    final path = await _path();
    if (path == null) return;
    try {
      await client.write(path, <String, dynamic>{
        ...match.toJson(),
        'schemaVersion': schemaVersion,
      });
    } on Object {
      // A failed write costs the resume affordance, nothing more.
    }
  }

  @override
  Future<void> clear() async {
    final path = await _path();
    if (path == null) return;
    try {
      await client.delete(path);
    } on Object {
      // Nothing to do.
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

  /// Storage layout version, so a later migration is detectable.
  static const int schemaVersion = 1;
}
