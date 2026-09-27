// ignore_for_file: close_sinks — the realtime controllers in this file are
// long-lived by design and are closed by closeWatchers() in tearDown. Closing a
// broadcast controller on first cancel instead would break the second simulated
// client watching the same document, which is the point of the lobby test.
library;

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
    _emit(path);
  }

  @override
  Future<void> delete(String path) async {
    _maybeFail();
    documents.remove(path);
    writeLog.add(path);
    _emit(path);
  }

  // --- Realtime watching (Phase 8) --------------------------------------------

  /// Live document streams, one broadcast controller per path.
  ///
  /// A broadcast controller is used so two simulated clients can watch the same
  /// document — which is exactly what the lobby test needs to prove the room
  /// creator sees the opponent arrive. Each write emits to every watcher, so the
  /// double reproduces the one-read-per-write cost the real listener bills.
  final Map<String, StreamController<Map<String, dynamic>?>> _watchers =
      <String, StreamController<Map<String, dynamic>?>>{};

  @override
  Stream<Map<String, dynamic>?> watch(String path) async* {
    final controller = _controllerFor(path);
    // The current value first, matching the real listener's initial event.
    yield _snapshot(path);
    yield* controller.stream;
  }

  StreamController<Map<String, dynamic>?> _controllerFor(String path) =>
      _watchers.putIfAbsent(
        path,
        StreamController<Map<String, dynamic>?>.broadcast,
      );

  Map<String, dynamic>? _snapshot(String path) {
    final data = documents[path];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  void _emit(String path) {
    final controller = _watchers[path];
    if (controller == null || controller.isClosed) return;
    controller.add(_snapshot(path));
  }

  /// Closes every open stream. Tests call this in `tearDown` so a pending
  /// microtask cannot outlive the test.
  void closeWatchers() {
    for (final controller in _watchers.values) {
      if (!controller.isClosed) controller.close();
    }
    _watchers.clear();
  }

  void _maybeFail() {
    if (!failNextOperation) return;
    failNextOperation = false;
    throw StateError('simulated Firestore failure');
  }
}
