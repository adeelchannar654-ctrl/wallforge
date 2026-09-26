import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'firestore_client.dart';

/// [FirestoreClient] backed by a real Cloud Firestore instance.
///
/// Uses only free-tier-compatible Firestore operations: reading and writing
/// individual documents. No paid APIs, no Cloud Functions, no Admin SDK.
class CloudFirestoreClient implements FirestoreClient {
  /// [firestore] is normally null, in which case the default app's instance is
  /// resolved lazily on first use.
  ///
  /// Resolution is lazy on purpose. `FirebaseFirestore.instance` throws when no
  /// Firebase app has been initialised, so resolving it in the constructor would
  /// make merely *building* this client fail on an unconfigured build — and the
  /// app must stay usable there.
  CloudFirestoreClient({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;
  FirebaseFirestore? _resolved;

  FirebaseFirestore get _firestore =>
      _resolved ??= _injected ?? FirebaseFirestore.instance;

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    try {
      final snapshot = await _firestore.doc(path).get();
      final data = snapshot.data();
      return data == null ? null : Map<String, dynamic>.from(data);
    } on Object {
      // Offline, permission-denied, missing-document and not-initialised cases
      // all degrade to "nothing stored" rather than propagating: a persistence
      // failure must never stop the app from running.
      return null;
    }
  }

  @override
  Future<void> write(String path, Map<String, dynamic> data) async {
    try {
      // `set` with an explicit document id; the repositories own their own
      // document layout, so this never relies on auto-generated ids.
      await _firestore.doc(path).set(data);
    } on Object {
      // Same rationale as [read]: a failed write costs persistence, not play.
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _firestore.doc(path).delete();
    } on Object {
      // Nothing to do; the document is already absent from our point of view.
    }
  }
}
