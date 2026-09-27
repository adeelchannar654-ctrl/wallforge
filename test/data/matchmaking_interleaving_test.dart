import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_client.dart';
import 'package:wallforge/data/remote/firestore_matchmaking_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Covers the interleavings the sequential race tests cannot reach.
class _InterleavingClient implements FirestoreClient {
  _InterleavingClient(this.inner, {required this.onFirstQuery});

  final FirestoreClient inner;

  /// Runs once, the first time a query is issued, before it is answered.
  final Future<void> Function() onFirstQuery;

  bool _fired = false;

  Future<void> _maybeInterleave() async {
    if (_fired) return;
    _fired = true;
    await onFirstQuery();
  }

  @override
  Future<List<FirestoreDocument>> query({
    required String collectionPath,
    String? orderBy,
    int limit = 10,
  }) async {
    await _maybeInterleave();
    return inner.query(
      collectionPath: collectionPath,
      orderBy: orderBy,
      limit: limit,
    );
  }

  @override
  Future<Map<String, dynamic>?> read(String path) => inner.read(path);

  @override
  Future<void> write(String path, Map<String, dynamic> data) =>
      inner.write(path, data);

  @override
  Future<void> delete(String path) => inner.delete(path);

  @override
  Stream<Map<String, dynamic>?> watch(String path) => inner.watch(path);

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction txn) action,
  ) => inner.runTransaction(action);
}

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  const board = BoardConfig();

  FirestoreMatchmakingRepository repoFor(
    String uid, {
    FirestoreClient? client,
  }) => FirestoreMatchmakingRepository(
    client: client ?? store,
    userId: () async => uid,
  );

  group('a player matched by someone else mid-search', () {
    // The one interleaving sequential tests cannot produce: the claimant is taken
    // out of the queue by a third client *while* it is searching, so its own
    // claim finds nothing and it has to notice its own match record.
    test('the searching player learns it was matched, not left queued', () async {
      await repoFor('uid-victim').findMatch(config: board);

      final searcher = FirestoreMatchmakingRepository(
        // Fires after the searcher has queued itself but before it looks for an
        // opponent: the window in which a competing claim can take it.
        client: _InterleavingClient(
          store,
          onFirstQuery: () async {
            // Two arrivals drain the queue, so the searcher finds nobody to claim
            // and must fall back to reading its own match record.
            await repoFor('uid-thief-1').findMatch(config: board);
            await repoFor('uid-thief-2').findMatch(config: board);
          },
        ),
        userId: () async => 'uid-searcher',
      );

      final result = await searcher.findMatch(config: board);

      expect(
        result,
        isA<MatchFound>(),
        reason:
            'the searcher was claimed by another client and must be told, not '
            'left believing it is still queued',
      );
      final room = (result as MatchFound).room;
      expect(room.sideFor('uid-searcher'), isNotNull);
      expect(
        room.blue.playerId,
        isNot(room.red.playerId),
        reason: 'a matched room has two distinct players',
      );
      expect(
        store.documents.keys.where((k) => k.contains('/waiting/')),
        isEmpty,
        reason: 'the queue is drained and nobody is left stranded in it',
      );
    });

    test(
      'a player already matched short-circuits without queueing again',
      () async {
        final a = repoFor('uid-a');
        final b = repoFor('uid-b');
        await a.findMatch(config: board);
        final first = (await b.findMatch(config: board) as MatchFound).room;

        final again = await b.findMatch(config: board);

        expect(again, isA<MatchFound>());
        expect((again as MatchFound).room.code, first.code);
        expect(
          store.documents.keys.where((k) => k.contains('/waiting/')),
          isEmpty,
        );
      },
    );
  });

  group('MatchmakingFailure value semantics', () {
    test('compares by value and names its reason', () {
      const a = MatchmakingFailure(
        MatchmakingFailureReason.notAuthenticated,
        'x',
      );
      const b = MatchmakingFailure(
        MatchmakingFailureReason.notAuthenticated,
        'x',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(
          const MatchmakingFailure(MatchmakingFailureReason.pairingFailed, 'x'),
        ),
      );
      expect(a.toString(), contains('notAuthenticated'));
    });

    test('a rejection carries the failure and its reason', () {
      const rejected = MatchRejected(
        MatchmakingFailure(MatchmakingFailureReason.pairingFailed, 'busy'),
      );
      expect(rejected.reason, MatchmakingFailureReason.pairingFailed);
      expect(rejected.failure.message, 'busy');
    });

    test('every reason is distinct', () {
      final reasons = MatchmakingFailureReason.values.toSet();
      expect(reasons.length, MatchmakingFailureReason.values.length);
    });
  });

  group('query ordering robustness', () {
    test('a document missing the sort field does not break ordering', () async {
      // Ordering happens before the repository validates entries, so the
      // transport has to survive a missing or non-numeric sort key.
      store.documents['q/a'] = <String, dynamic>{'queuedAt': 'not-a-number'};
      store.documents['q/b'] = <String, dynamic>{'queuedAt': 5};
      store.documents['q/c'] = <String, dynamic>{'other': 1};
      store.documents['q/nested/d'] = <String, dynamic>{'queuedAt': 1};

      final docs = await store.query(collectionPath: 'q', orderBy: 'queuedAt');

      // Only direct children of the collection, and all of them returned.
      final paths = docs.map((d) => d.path).toSet();
      expect(paths, containsAll(<String>['q/a', 'q/b', 'q/c']));
      expect(
        paths,
        isNot(contains('q/nested/d')),
        reason: 'not a direct child',
      );
    });

    test('the limit is honoured', () async {
      for (var i = 0; i < 5; i++) {
        store.documents['q/$i'] = <String, dynamic>{'queuedAt': i};
      }
      final docs = await store.query(
        collectionPath: 'q',
        orderBy: 'queuedAt',
        limit: 2,
      );
      expect(docs, hasLength(2));
      expect(docs.first.data['queuedAt'], 0, reason: 'oldest first');
    });

    test('a query of a missing collection is empty, not an error', () async {
      final docs = await store.query(collectionPath: 'nothing/here');
      expect(docs, isEmpty);
    });
  });

  group('transaction mechanics', () {
    test('a transaction commits all its writes together', () async {
      await store.runTransaction<void>((txn) async {
        txn.set('t/one', <String, dynamic>{'v': 1});
        txn.set('t/two', <String, dynamic>{'v': 2});
      });
      expect(store.documents['t/one']!['v'], 1);
      expect(store.documents['t/two']!['v'], 2);
    });

    test('a transaction cannot see its own staged writes', () async {
      // Prevents a transaction from "helping itself" across attempts.
      late Map<String, dynamic>? observed;
      await store.runTransaction<void>((txn) async {
        txn.set('t/x', <String, dynamic>{'v': 9});
        observed = await txn.get('t/x');
      });
      expect(observed, isNull);
      expect(store.documents['t/x']!['v'], 9);
    });

    test('a conflicting transaction is retried, not failed', () async {
      store.conflictsToInject = 2;
      final result = await store.runTransaction<String>((txn) async {
        txn.set('t/retried', <String, dynamic>{'ok': true});
        return 'done';
      });
      expect(result, 'done');
      expect(store.transactionConflicts, 2);
      expect(store.documents.containsKey('t/retried'), isTrue);
    });

    test('sustained contention gives up rather than looping forever', () async {
      store.conflictsToInject = 1000;
      await expectLater(
        store.runTransaction<void>((txn) async {
          txn.set('t/never', <String, dynamic>{});
        }),
        throwsA(isA<StateError>()),
      );
      expect(store.documents.containsKey('t/never'), isFalse);
    });
  });
}
