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

  @override
  Stream<Map<String, dynamic>?> watch(String path) {
    // Errors are mapped to "gone" rather than propagated, matching [read]: the
    // lobby must show a connection problem, not crash the screen. The caller
    // detects the disconnection from the repository's own status, not from a
    // stream error.
    return _firestore
        .doc(path)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return data == null ? null : Map<String, dynamic>.from(data);
        })
        .handleError((Object _) => null);
  }

  @override
  Future<List<FirestoreDocument>> query({
    required String collectionPath,
    String? orderBy,
    int limit = 10,
    String? startAfterDocumentId,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection(collectionPath);
      if (orderBy != null) query = query.orderBy(orderBy);
      if (startAfterDocumentId != null) {
        // Firestore has no offset, so paging is done with a document-id cursor.
        // Move records are named after their zero-padded ply, so ordering by
        // the document id is the same order as ordering by `turnNumber` — which
        // is what makes the cursor agree with the page boundary.
        query = query.orderBy(FieldPath.documentId).startAfter([
          startAfterDocumentId,
        ]);
      }
      final snapshot = await query.limit(limit).get();
      return snapshot.docs
          .map(
            (doc) =>
                FirestoreDocument(path: doc.reference.path, data: doc.data()),
          )
          .toList();
    } on Object {
      // A failed query is an empty queue, not a crash: the caller will simply
      // keep waiting, which is the correct behaviour when the network is down.
      return const <FirestoreDocument>[];
    }
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction txn) action,
  ) =>
      // Firestore retries the callback itself on conflict, so the retry loop
      // lives in the SDK and this method is a direct delegation.
      _firestore.runTransaction<T>(
        (transaction) => action(_CloudTransaction(_firestore, transaction)),
      );
  @override
  Stream<FirestoreSnapshot> watchWithMetadata(String path) => _firestore
      .doc(path)
      .snapshots()
      .map(
        (snapshot) => FirestoreSnapshot(
          data: snapshot.data(),
          // `metadata.isFromCache` is the honest signal for "this came off the
          // device, not the server" — the basis of the Reconnecting state.
          fromCache: snapshot.metadata.isFromCache,
        ),
      );
}

class _CloudTransaction implements FirestoreTransaction {
  _CloudTransaction(this._firestore, this._txn);

  /// `Transaction` exposes neither `doc()` nor `collection()`, so references are
  /// built from the Firestore instance and handed to the transaction.
  final FirebaseFirestore _firestore;
  final Transaction _txn;

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    final snapshot = await _txn.get(_firestore.doc(path));
    return snapshot.data();
  }

  /// Staged, not applied: Firestore applies transaction writes at commit.
  @override
  void set(String path, Map<String, dynamic> data) =>
      _txn.set(_firestore.doc(path), data);

  @override
  void delete(String path) => _txn.delete(_firestore.doc(path));
}
