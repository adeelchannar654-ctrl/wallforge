import 'dart:async';

import 'firestore_client.dart';

/// In-memory [FirestoreClient] for tests and for running without Firebase.
///
/// Implements exactly the same contract as [CloudFirestoreClient], including the
/// total behaviour: reads of missing documents return null and no operation
/// throws. Exposes the stored documents so a test can assert on the actual
/// document layout, which is how the free-tier cost stays visible.
class InMemoryFirestoreClient implements FirestoreClient {
  InMemoryFirestoreClient({Map<String, Map<String, dynamic>>? seed})
    : documents = <String, Map<String, dynamic>>{
        for (final entry
            in (seed ?? const <String, Map<String, dynamic>>{}).entries)
          entry.key: Map<String, dynamic>.from(entry.value),
      };

  /// Document path -> data. Public so tests can inspect the real layout.
  final Map<String, Map<String, dynamic>> documents;

  /// Every path written, in order. Lets a test assert the *number* of documents
  /// a flow touches, which is the quantity the free tier actually bills.
  final List<String> writeLog = <String>[];

  /// When set, the next operation of any kind fails, to prove the repositories
  /// degrade instead of throwing.
  bool failNextOperation = false;

  @override
  Future<Map<String, dynamic>?> read(String path) async {
    _maybeFail();
    final data = documents[path];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  @override
  Future<void> write(String path, Map<String, dynamic> data) async {
    _maybeFail();
    documents[path] = Map<String, dynamic>.from(data);
    writeLog.add(path);
  }

  @override
  Future<void> delete(String path) async {
    _maybeFail();
    documents.remove(path);
    writeLog.add(path);
  }

  void _maybeFail() {
    if (!failNextOperation) return;
    failNextOperation = false;
    throw StateError('simulated Firestore failure');
  }
}
