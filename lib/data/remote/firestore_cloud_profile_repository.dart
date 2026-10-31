import '../../domain/repositories/cloud_profile.dart';
import 'firestore_client.dart';
import 'firestore_settings_repository.dart' show UserIdResolver;

/// [CloudProfileRepository] over Firestore (Phase 16.6, Part E):
/// the single document `users/{uid}/profile`.
///
/// Total like every repository here: failures resolve to
/// null/false, never a throw, because a profile sync must never
/// break play. The owner comes from the same [UserIdResolver]
/// seam as the Phase 7 repositories — in production, the account
/// gateway's `currentUid`, so the document always belongs to
/// whoever is actually signed in.
class FirestoreCloudProfileRepository implements CloudProfileRepository {
  FirestoreCloudProfileRepository({
    required this.client,
    required this.userId,
    this.collection = 'users',
    this.document = 'profile',
  });

  /// Document transport.
  final FirestoreClient client;

  /// Resolves the owner id that scopes the document.
  final UserIdResolver userId;

  /// Top-level collection name.
  final String collection;

  /// Document name holding the profile.
  final String document;

  Future<String?> _path() async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return null;
    return '$collection/$uid/$document';
  }

  @override
  Future<CloudProfile?> load() async {
    final path = await _path();
    if (path == null) return null;
    Map<String, dynamic>? data;
    try {
      data = await client.read(path);
    } on Object {
      return null;
    }
    if (data == null) return null;
    return CloudProfile.fromJson(data);
  }

  @override
  Future<bool> save(CloudProfile profile) async {
    final path = await _path();
    if (path == null) return false;
    try {
      await client.write(path, profile.toJson());
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<bool> delete() async {
    final path = await _path();
    if (path == null) return false;
    try {
      await client.delete(path);
      return true;
    } on Object {
      return false;
    }
  }
}
