import 'dart:async';

/// The narrow slice of document storage the Phase 7 repositories actually use.
///
/// Deliberately tiny — a single document's JSON map, nothing more. It exists so
/// the Firestore-backed repositories can be exercised by tests without a live
/// project or the Firestore emulator.
///
/// **Why not depend on `FirebaseFirestore` directly?** Two reasons, both
/// recorded rather than assumed:
///
/// * `FirebaseFirestore` is a concrete, platform-bound class. Depending on it
///   directly would make every repository test require either a real project or
///   a running emulator. The Firestore emulator is *not* usable in this
///   environment: the emulator cache contains only the UI emulator, and the
///   Firebase CLI has no logged-in project, so there is no `firebase.json`
///   target to boot against. Rather than pretend otherwise, the repositories
///   depend on this port and [InMemoryFirestoreClient] stands in for tests.
/// * Keeping the surface this small documents exactly what Phase 7 stores, which
///   matters for a free-tier budget and for writing Security Rules in Phase 10.
///
/// Phase 8+ can widen this interface (sub-collections, queries, transactions)
/// without touching the repositories, because they only ever see this contract.
/// The first widening was [watch], added for the online lobby.
abstract interface class FirestoreClient {
  /// Reads the document at [path], or null when it does not exist.
  ///
  /// Must not throw for a missing document; a transport failure is reported as
  /// null, matching the "never lose the app" rule used everywhere else in the
  /// persistence layer.
  Future<Map<String, dynamic>?> read(String path);

  /// Writes [data] at [path], replacing any existing document.
  Future<void> write(String path, Map<String, dynamic> data);

  /// Removes the document at [path]. A missing document is not an error.
  Future<void> delete(String path);

  /// Emits the document at [path] now and again on every change, emitting null
  /// when it does not exist.
  ///
  /// Added in Phase 8, which needs the room creator to see the opponent join
  /// without polling. `phase.md` Phase 7 anticipated exactly this widening, and
  /// the repositories are unchanged by it because they only ever see this
  /// contract.
  ///
  /// **Free-tier cost, verified against current Firestore documentation rather
  /// than assumed:** a real-time listener is not billed as its own operation, but
  /// "real-time updates are billed as standard document reads — you are charged
  /// one read each time a document is added or updated in the listener's result
  /// set". So a listener on a document costs one extra read per write for every
  /// client watching it. With two players in a lobby and a handful of writes per
  /// room that is negligible against the 50,000 reads/day no-cost quota, but it
  /// is the reason the lobby must not write on a timer.
  Stream<Map<String, dynamic>?> watch(String path);

  /// Reads up to [limit] documents from [collectionPath], oldest first by
  /// [orderBy] when given.
  ///
  /// Added in Phase 8.1 for the matchmaking queue.
  ///
  /// **There is deliberately no filter parameter.** Firestore only serves
  /// "equality filter on one field + `orderBy` on a different field" from a
  /// *composite* index, which is a manual console step (or a Blaze-plan deploy).
  /// Partitioning the queue by board configuration in the *path* instead
  /// (`matchmaking/{boardKey}/waiting/{uid}`) means the only query needed is a
  /// bare `orderBy` + `limit` on one subcollection, which the automatic
  /// single-field index serves. That keeps the feature inside the Spark plan with
  /// no manual index step. Verified against current Firestore indexing docs
  /// rather than assumed.
  Future<List<FirestoreDocument>> query({
    required String collectionPath,
    String? orderBy,
    int limit = 10,
  });

  /// Runs [action] as an atomic transaction, retrying it on conflict.
  ///
  /// Added in Phase 8.1. Matchmaking's correctness rests entirely on "verify the
  /// candidate is still claimable, then claim it" being a single atomic step — a
  /// plain read followed by a write lets two simultaneous clients claim the same
  /// queue entry, or both create rooms and never pair.
  ///
  /// Implementations must re-run [action] on conflict, as Firestore itself does.
  ///
  /// ## Why this takes no `query`
  ///
  /// `cloud_firestore`'s `Transaction.get` accepts only a `DocumentReference`; it
  /// cannot run a query. That is a real SDK limitation, not an oversight here, and
  /// it shapes the whole design: candidate discovery happens with a plain
  /// [FirestoreClient.query] *outside* the transaction, and the transaction then
  /// re-reads that one candidate document to confirm it is still claimable before
  /// claiming it. The commit is still atomic, and a lost race surfaces as a
  /// conflict that re-runs the callback, which then sees the candidate gone.
  ///
  /// Reads inside a transaction must all happen before writes; [set] and [delete]
  /// only stage a change until the transaction commits.
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction txn) action,
  );
}

/// A document returned by [FirestoreClient.query], carrying the path needed to
/// address it again.
class FirestoreDocument {
  const FirestoreDocument({required this.path, required this.data});

  /// Full document path.
  final String path;

  /// The document's fields.
  final Map<String, dynamic> data;

  @override
  String toString() => 'FirestoreDocument($path)';
}

/// The staging area handed to a [FirestoreClient.runTransaction] callback.
///
/// Document operations only — see [FirestoreClient.runTransaction] for why a
/// query cannot appear here.
abstract interface class FirestoreTransaction {
  /// Reads a document, or null when it does not exist.
  Future<Map<String, dynamic>?> get(String path);

  /// Stages a write at [path]. Committed only if the transaction succeeds.
  void set(String path, Map<String, dynamic> data);

  /// Stages a delete at [path]. Committed only if the transaction succeeds.
  void delete(String path);
}
