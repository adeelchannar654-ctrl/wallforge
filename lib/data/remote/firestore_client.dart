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
}
