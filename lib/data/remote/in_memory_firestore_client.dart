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
  final Map<String, StreamController<FirestoreSnapshot>> _watchers =
      <String, StreamController<FirestoreSnapshot>>{};

  @override
  Stream<Map<String, dynamic>?> watch(String path) =>
      watchWithMetadata(path).map((snapshot) => snapshot.data);

  StreamController<FirestoreSnapshot> _controllerFor(String path) => _watchers
      .putIfAbsent(path, StreamController<FirestoreSnapshot>.broadcast);

  Map<String, dynamic>? _snapshot(String path) {
    final data = documents[path];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  void _emit(String path) {
    final controller = _watchers[path];
    if (controller == null || controller.isClosed) return;
    controller.add(
      FirestoreSnapshot(data: _snapshot(path), fromCache: _offline),
    );
  }

  /// Closes every open stream. Tests call this in `tearDown` so a pending
  /// microtask cannot outlive the test.
  void closeWatchers() {
    for (final controller in _watchers.values) {
      if (!controller.isClosed) controller.close();
    }
    _watchers.clear();
  }

  // --- Offline simulation (Phase 9) -------------------------------------------

  bool _offline = false;

  /// Whether the simulated network is down.
  bool get isOffline => _offline;

  /// Simulates the network dropping.
  ///
  /// Modelled on the two real Firestore behaviours that shape Phase 9's
  /// reconnection design:
  ///
  /// * **A transaction fails; it does not queue.** Firestore has no offline
  ///   write queue for transactions, so a submit while offline is rejected rather
  ///   than silently buffered. That is why the app has to hold a pending action
  ///   and resubmit it itself.
  /// * **A listener keeps serving the last value, flagged as cached.** The board
  ///   stays on screen rather than blanking, which is what `rules.md` §9 requires
  ///   ("preserve the current local state"), and the client can tell the player it
  ///   is looking at a frozen copy.
  void goOffline() {
    if (_offline) return;
    _offline = true;
    for (final path in _watchers.keys) {
      final controller = _watchers[path];
      if (controller == null || controller.isClosed) continue;
      controller.add(FirestoreSnapshot(data: _snapshot(path), fromCache: true));
    }
  }

  /// Simulates the network coming back, re-emitting current values as live.
  void goOnline() {
    if (!_offline) return;
    _offline = false;
    for (final path in _watchers.keys) {
      final controller = _watchers[path];
      if (controller == null || controller.isClosed) continue;
      controller.add(FirestoreSnapshot(data: _snapshot(path)));
    }
  }

  void _maybeFail() {
    if (_offline) {
      throw StateError('simulated offline failure');
    }
    if (!failNextOperation) return;
    failNextOperation = false;
    throw StateError('simulated Firestore failure');
  }

  // --- Queries and transactions (Phase 8.1) -----------------------------------

  /// Bumped on every committed write or delete.
  ///
  /// A transaction captures this at its start and re-runs if it moved before
  /// commit, which is how the double models Firestore's conflict detection. It is
  /// deliberately coarse: a change to *any* document aborts the transaction, so
  /// the retry path is genuinely exercised rather than accidentally avoided.
  int _revision = 0;

  /// How many upcoming transaction commits should fail with a conflict.
  ///
  /// Lets a test prove the retry loop recovers, instead of only proving that
  /// contention never happens.
  int conflictsToInject = 0;

  /// How many transaction attempts have been made, including retries.
  int transactionAttempts = 0;

  /// How many of those attempts were aborted by a conflict.
  int transactionConflicts = 0;

  @override
  Future<List<FirestoreDocument>> query({
    required String collectionPath,
    String? orderBy,
    int limit = 10,
    String? startAfterDocumentId,
  }) async {
    _maybeFail();
    var entries = documents.entries
        .where((e) => _isInCollection(e.key, collectionPath))
        .toList();
    if (orderBy != null) {
      entries.sort((a, b) => _compareBy(a.value, b.value, orderBy));
    }
    if (startAfterDocumentId != null) {
      // Resume strictly after the cursor document, comparing the same way the
      // page was ordered, so a page boundary cannot skip or repeat a row.
      final seen = entries.any((e) => e.key.endsWith('/$startAfterDocumentId'));
      final index = entries.indexWhere(
        (e) => e.key.endsWith('/$startAfterDocumentId'),
      );
      if (seen) {
        entries = entries.sublist(orderBy == null ? index + 1 : index + 1);
      } else {
        // A cursor the server does not have: return nothing rather than
        // silently restarting from the beginning and duplicating the log.
        return const <FirestoreDocument>[];
      }
    }
    return entries
        .take(limit)
        .map(
          (e) => FirestoreDocument(
            path: e.key,
            data: Map<String, dynamic>.from(e.value),
          ),
        )
        .toList();
  }

  /// True when [path] sits directly inside [collectionPath].
  static bool _isInCollection(String path, String collectionPath) {
    if (!path.startsWith('$collectionPath/')) return false;
    final rest = path.substring(collectionPath.length + 1);
    return !rest.contains('/');
  }

  static int _compareBy(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    String field,
  ) {
    final left = a[field];
    final right = b[field];
    if (left is int && right is int) return left.compareTo(right);
    return (left?.toString() ?? '').compareTo(right?.toString() ?? '');
  }

  @override
  @override
  Stream<FirestoreSnapshot> watchWithMetadata(String path) async* {
    final controller = _controllerFor(path);
    yield FirestoreSnapshot(data: _snapshot(path), fromCache: _offline);
    yield* controller.stream;
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction txn) action,
  ) async {
    // A transaction fails outright while offline, exactly as Firestore does.
    // There is no write queue, so nothing is silently buffered.
    _maybeFail();
    // Mirrors Firestore: re-run the callback until it commits without conflict.
    for (var attempt = 0; attempt < maxTransactionAttempts; attempt++) {
      transactionAttempts++;
      final startRevision = _revision;
      final transaction = _InMemoryTransaction(this);
      final result = await action(transaction);
      if (_revision != startRevision || conflictsToInject > 0) {
        if (conflictsToInject > 0) conflictsToInject--;
        transactionConflicts++;
        continue;
      }
      // Commit every staged write as one indivisible step, so a listener never
      // observes a half-applied transaction.
      transaction.staged.forEach((path, data) {
        if (data == null) {
          documents.remove(path);
        } else {
          documents[path] = data;
          writeLog.add(path);
        }
        _emit(path);
        _revision++;
      });
      return result;
    }
    throw StateError(
      'transaction contention: gave up after $maxTransactionAttempts attempts',
    );
  }

  /// Upper bound on transaction retries before giving up.
  static const int maxTransactionAttempts = 5;
}

/// Stages a transaction's writes so they commit together or not at all.
class _InMemoryTransaction implements FirestoreTransaction {
  _InMemoryTransaction(this._client);

  final InMemoryFirestoreClient _client;

  /// Path -> data, or null for a staged delete.
  final Map<String, Map<String, dynamic>?> staged = {};

  @override
  Future<Map<String, dynamic>?> get(String path) async {
    // Reads see committed state only: a staged write is not visible until commit,
    // which is what stops a transaction "helping itself" across two attempts.
    final data = _client.documents[path];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  @override
  void set(String path, Map<String, dynamic> data) =>
      staged[path] = Map<String, dynamic>.from(data);

  @override
  void delete(String path) => staged[path] = null;
}
