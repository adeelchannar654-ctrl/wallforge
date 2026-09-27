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
}
