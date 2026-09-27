import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_client.dart';
import 'package:wallforge/data/remote/firestore_matchmaking_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/data/remote/room_code_generator.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// One simulated player: its own repository over a shared document store, which
/// is what makes these two "devices".
({String uid, FirestoreMatchmakingRepository matchmaking}) player(
  InMemoryFirestoreClient store,
  String uid, {
  DateTime? at,
  Duration staleAfter = const Duration(seconds: 60),
}) {
  final clock = at ?? DateTime.utc(2026, 9, 27, 12);
  return (
    uid: uid,
    matchmaking: FirestoreMatchmakingRepository(
      client: store,
      userId: () async => uid,
      clock: () => clock,
      staleAfter: staleAfter,
    ),
  );
}

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  const board = BoardConfig();

  /// Every room document currently in the store.
  Map<String, Room> rooms() {
    final result = <String, Room>{};
    for (final entry in store.documents.entries) {
      if (!entry.key.startsWith('matches/')) continue;
      final room = Room.fromJson(entry.value);
      if (room != null) result[room.code] = room;
    }
    return result;
  }

  /// Waiting entries, by uid.
  Set<String> waiting() => store.documents.keys
      .where((k) => k.contains('/waiting/'))
      .map((k) => k.split('/').last)
      .toSet();

  group('the first player waits', () {
    test('with nobody else queued, findMatch reports queued', () async {
      final a = player(store, 'uid-a');
      final result = await a.matchmaking.findMatch(config: board);

      expect(result, isA<MatchQueued>());
      expect(waiting(), <String>{'uid-a'});
      expect(rooms(), isEmpty, reason: 'no room before an opponent exists');
    });

    test('a second player pairing later matches them', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: board);
      expect(await a.matchmaking.findMatch(config: board), isA<MatchQueued>());

      final b = player(store, 'uid-b');
      final result = await b.matchmaking.findMatch(config: board);

      expect(result, isA<MatchFound>());
      final room = (result as MatchFound).room;
      expect(room.blue.playerId, 'uid-a', reason: 'the waiting player hosts');
      expect(room.red.playerId, 'uid-b');
      expect(room.hostId, 'uid-a');
      expect(room.boardConfig, board);
      expect(
        waiting(),
        isEmpty,
        reason: 'the queue entry is consumed by the claim',
      );
    });

    test('the matched room is a normal Phase 8 room', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: board);
      final b = player(store, 'uid-b');
      final room =
          (await b.matchmaking.findMatch(config: board) as MatchFound).room;

      // Same document path and same serialised shape as a code-created room, so
      // every Phase 8 behaviour applies unchanged.
      expect(store.documents.containsKey('matches/${room.code}'), isTrue);
      final reloaded = Room.fromJson(store.documents['matches/${room.code}'])!;
      expect(reloaded, room);
      expect(reloaded.status, RoomStatus.waiting);
      expect(reloaded.version, 1);
      expect(
        () => room.sideFor('uid-a'),
        returnsNormally,
        reason: 'seat lookups must work exactly as for a code room',
      );
      expect(room.sideFor('uid-a'), PlayerId.blue);
      expect(room.sideFor('uid-b'), PlayerId.red);
    });
  });

  group('simultaneous requests — the race', () {
    test('two clients arriving together end up in exactly one room', () async {
      final a = player(store, 'uid-a');
      final b = player(store, 'uid-b');

      // Started together, not awaited in sequence: this is the case that a
      // non-atomic implementation gets wrong.
      final results = await Future.wait([
        a.matchmaking.findMatch(config: board),
        b.matchmaking.findMatch(config: board),
      ]);

      final all = rooms();
      expect(
        all.length,
        1,
        reason: 'exactly one room may exist, found ${all.keys}',
      );
      final room = all.values.single;
      expect(
        {room.blue.playerId, room.red.playerId},
        <String?>{'uid-a', 'uid-b'},
      );
      expect(waiting(), isEmpty, reason: 'neither may be left stranded');

      // Both clients must be told about the same room.
      for (final result in results) {
        expect(result, isA<MatchFound>());
        expect((result as MatchFound).room.code, room.code);
      }
    });

    test('a repeated simultaneous burst never double-books anyone', () async {
      // Twenty rounds of two-way simultaneous arrivals, each with a fresh store,
      // so one lucky interleaving cannot hide a failure.
      for (var round = 0; round < 20; round++) {
        final local = InMemoryFirestoreClient();
        final a = player(local, 'uid-a');
        final b = player(local, 'uid-b');
        await Future.wait([
          a.matchmaking.findMatch(config: board),
          b.matchmaking.findMatch(config: board),
        ]);
        final all = <Room>[];
        for (final entry in local.documents.entries) {
          if (!entry.key.startsWith('matches/')) continue;
          final room = Room.fromJson(entry.value);
          if (room != null) all.add(room);
        }
        expect(
          all.length,
          1,
          reason: 'round $round produced ${all.length} rooms',
        );
        local.closeWatchers();
      }
    });

    test(
      'three simultaneous clients pair into one room and one waiter',
      () async {
        final a = player(store, 'uid-a');
        final b = player(store, 'uid-b');
        final c = player(store, 'uid-c');

        final results = await Future.wait([
          a.matchmaking.findMatch(config: board),
          b.matchmaking.findMatch(config: board),
          c.matchmaking.findMatch(config: board),
        ]);

        final all = rooms();
        expect(all.length, 1, reason: 'three players cannot fill two rooms');
        final seated = all.values.single;
        expect(
          {seated.blue.playerId, seated.red.playerId},
          hasLength(2),
          reason: 'the room has exactly two seats',
        );

        // The odd one out waits; whoever it is, nobody is in two rooms.
        final waiters = waiting();
        expect(waiters.length, 1);
        expect(results.whereType<MatchFound>().length, 2);
        expect(results.whereType<MatchQueued>().length, 1);
        expect(
          seated.blue.playerId,
          isNot(waiters.single),
          reason: 'the waiting player must not also be seated',
        );
      },
    );

    test(
      'four simultaneous clients pair into two rooms, nobody twice',
      () async {
        final clients = [
          'uid-a',
          'uid-b',
          'uid-c',
          'uid-d',
        ].map((uid) => player(store, uid)).toList();

        await Future.wait(
          clients.map((c) => c.matchmaking.findMatch(config: board)),
        );

        final all = rooms().values.toList();
        expect(all.length, 2);
        final seated = all
            .expand((r) => [r.blue.playerId, r.red.playerId])
            .toList();
        expect(
          seated.toSet().length,
          4,
          reason: 'every player seated exactly once',
        );
        expect(
          seated.every((uid) => uid != null),
          isTrue,
          reason: 'no room may have an empty seat',
        );
        expect(waiting(), isEmpty);
      },
    );

    test('a client is never seated in two rooms', () async {
      // Four players arriving in two overlapping waves, so a claim can race a
      // claim across waves rather than only within one.
      final clients = [
        'uid-a',
        'uid-b',
        'uid-c',
        'uid-d',
      ].map((uid) => player(store, uid)).toList();
      await Future.wait(
        clients.take(2).map((c) => c.matchmaking.findMatch(config: board)),
      );
      await Future.wait(
        clients.skip(2).map((c) => c.matchmaking.findMatch(config: board)),
      );

      final perPlayer = <String, Set<String>>{};
      for (final room in rooms().values) {
        for (final uid in [room.blue.playerId, room.red.playerId]) {
          perPlayer.putIfAbsent(uid!, () => <String>{}).add(room.code);
        }
      }
      for (final entry in perPlayer.entries) {
        expect(
          entry.value.length,
          1,
          reason: '${entry.key} appears in ${entry.value}',
        );
      }
    });

    test('the claim uses a transaction, and conflict retries recover', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: board);
      final b = player(store, 'uid-b');

      // Force the first two commits to conflict, proving the retry loop is real
      // and not just untested defensive code.
      store.conflictsToInject = 2;
      final result = await b.matchmaking.findMatch(config: board);

      expect(result, isA<MatchFound>());
      expect(store.transactionConflicts, greaterThanOrEqualTo(2));
      expect(store.transactionAttempts, greaterThanOrEqualTo(3));
      expect(rooms().length, 1);
    });

    test('continual contention never fabricates a match', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: board);
      final b = player(store, 'uid-b');

      // Far more injected conflicts than the transaction will retry.
      store.conflictsToInject = 50;
      final result = await b.matchmaking.findMatch(config: board);

      // b's own queue entry is intact, so the honest answer is "still
      // searching" — not a match, and not a spurious failure either.
      expect(result, isA<MatchQueued>());
      expect(
        store.documents.keys.where((k) => k.startsWith('matches/')),
        isEmpty,
        reason: 'a client must never be told it matched when it did not',
      );
    });

    test('a queue entry that never lands is reported as a failure', () async {
      // The only genuine way to end up neither matched nor queued: the
      // announcement write itself failed.
      final flaky = FirestoreMatchmakingRepository(
        client: _WriteFailingClient(store),
        userId: () async => 'uid-a',
      );
      final result = await flaky.findMatch(config: board);

      expect(result, isA<MatchRejected>());
      expect(
        (result as MatchRejected).reason,
        MatchmakingFailureReason.pairingFailed,
      );
      expect(store.documents, isEmpty);
    });
  });

  group('cancel', () {
    test('cancelling removes the queue entry', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: board);
      expect(waiting(), <String>{'uid-a'});

      await a.matchmaking.cancel(config: board);

      expect(waiting(), isEmpty);
    });

    test('a later matcher does not pair with a cancelled player', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: board);
      await a.matchmaking.cancel(config: board);

      final b = player(store, 'uid-b');
      final result = await b.matchmaking.findMatch(config: board);

      expect(
        result,
        isA<MatchQueued>(),
        reason: 'the cancelled player must not be picked up',
      );
      expect(rooms(), isEmpty);
    });

    test('cancelling when not queued is not an error', () async {
      final a = player(store, 'uid-a');
      await expectLater(a.matchmaking.cancel(config: board), completes);
      expect(waiting(), isEmpty);
    });

    test('cancelling does not disturb a match already agreed', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: board);
      final b = player(store, 'uid-b');
      final room =
          (await b.matchmaking.findMatch(config: board) as MatchFound).room;

      // Cancelling after being matched removes no room and no match record.
      await b.matchmaking.cancel(config: board);

      expect(rooms().containsKey(room.code), isTrue);
      expect(
        store.documents.containsKey(
          'matchmaking/${matchmakingBoardKey(board)}/matched/uid-b',
        ),
        isTrue,
        reason: 'the opponent is on their way in; the record must survive',
      );
    });
  });

  group('abandoned entries', () {
    test(
      'an entry older than the staleness window is reaped, not claimed',
      () async {
        final old = player(
          store,
          'uid-gone',
          at: DateTime.utc(2026, 9, 27, 11),
        );
        await old.matchmaking.findMatch(config: board);
        expect(waiting(), <String>{'uid-gone'});

        // A real player arrives five minutes later.
        final live = player(
          store,
          'uid-live',
          at: DateTime.utc(2026, 9, 27, 12, 5),
        );
        final result = await live.matchmaking.findMatch(config: board);

        expect(
          result,
          isA<MatchQueued>(),
          reason: 'pairing with someone who left would strand the live player',
        );
        expect(rooms(), isEmpty);
        expect(waiting(), <String>{
          'uid-live',
        }, reason: 'the abandoned entry is reaped and the live one remains');
      },
    );

    test('a stale entry alongside a live one pairs the live pair', () async {
      final stale = player(
        store,
        'uid-stale',
        at: DateTime.utc(2026, 9, 27, 11),
      );
      await stale.matchmaking.findMatch(config: board);
      final live = player(
        store,
        'uid-live',
        at: DateTime.utc(2026, 9, 27, 12, 5),
      );
      await live.matchmaking.findMatch(config: board);

      final newcomer = player(
        store,
        'uid-new',
        at: DateTime.utc(2026, 9, 27, 12, 6),
      );
      final result = await newcomer.matchmaking.findMatch(config: board);

      expect(result, isA<MatchFound>());
      final room = (result as MatchFound).room;
      expect(
        {room.blue.playerId, room.red.playerId},
        <String>{'uid-live', 'uid-new'},
        reason: 'the newcomer must pair with the live player, not the ghost',
      );
      expect(waiting(), isEmpty);
    });

    test('a malformed queue entry is removed instead of blocking the queue', () async {
      store.documents['matchmaking/${matchmakingBoardKey(board)}/waiting/uid-bad'] =
          <String, dynamic>{'queuedAt': 1};
      final a = player(store, 'uid-a', at: DateTime.utc(2026, 9, 27, 12));

      final result = await a.matchmaking.findMatch(config: board);

      expect(result, isA<MatchQueued>());
      expect(
        store.documents.containsKey(
          'matchmaking/${matchmakingBoardKey(board)}/waiting/uid-bad',
        ),
        isFalse,
      );
    });
  });

  group('compatibility scope', () {
    test('players on different board sizes are not paired', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: const BoardConfig());

      final b = player(store, 'uid-b');
      final result = await b.matchmaking.findMatch(
        config: const BoardConfig(size: 7),
      );

      expect(result, isA<MatchQueued>());
      expect(rooms(), isEmpty);
      // Both are still waiting, in separate partitions.
      expect(waiting(), hasLength(2));
    });

    test('different wall counts are also a different queue', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: const BoardConfig());
      final b = player(store, 'uid-b');
      final result = await b.matchmaking.findMatch(
        config: const BoardConfig(wallsPerPlayer: 8),
      );
      expect(result, isA<MatchQueued>());
      expect(rooms(), isEmpty);
    });

    test('the board key is a stable, path-safe partition id', () {
      expect(matchmakingBoardKey(const BoardConfig()), 's9w10');
      expect(matchmakingBoardKey(const BoardConfig(size: 7)), 's7w10');
      expect(
        matchmakingBoardKey(const BoardConfig(size: 11, wallsPerPlayer: 12)),
        's11w12',
      );
    });
  });

  group('identity safety', () {
    test(
      'findMatch refuses without a resolved uid and writes nothing',
      () async {
        final anonymous = FirestoreMatchmakingRepository(
          client: store,
          userId: () async => null,
        );
        final result = await anonymous.findMatch(config: board);

        expect(result, isA<MatchRejected>());
        expect(
          (result as MatchRejected).reason,
          MatchmakingFailureReason.notAuthenticated,
        );
        expect(store.documents, isEmpty);
      },
    );

    test('an empty uid is treated as no uid', () async {
      final blank = FirestoreMatchmakingRepository(
        client: store,
        userId: () async => '',
      );
      final result = await blank.findMatch(config: board);
      expect(
        (result as MatchRejected).reason,
        MatchmakingFailureReason.notAuthenticated,
      );
      expect(store.documents, isEmpty);
    });

    test('an invalid board is refused', () async {
      final a = player(store, 'uid-a');
      final result = await a.matchmaking.findMatch(
        config: const BoardConfig(size: 4),
      );
      expect(result, isA<MatchRejected>());
      expect(store.documents, isEmpty);
    });
  });

  group('match notification', () {
    test(
      'the waiting player is notified through its own matched document',
      () async {
        final a = player(store, 'uid-a');
        await a.matchmaking.findMatch(config: board);

        final seen = <Room?>[];
        final sub = a.matchmaking
            .watchForMatch(config: board, uid: 'uid-a')
            .listen(seen.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();
        expect(seen.last, isNull, reason: 'still waiting');

        final b = player(store, 'uid-b');
        final room =
            (await b.matchmaking.findMatch(config: board) as MatchFound).room;
        await pumpEventQueue();

        expect(seen.last, isNotNull);
        expect(seen.last!.code, room.code);
        expect(seen.last!.red.playerId, 'uid-b');
      },
    );

    test(
      'a client that is already matched reports the existing room',
      () async {
        final a = player(store, 'uid-a');
        await a.matchmaking.findMatch(config: board);
        final b = player(store, 'uid-b');
        final first =
            (await b.matchmaking.findMatch(config: board) as MatchFound).room;

        // Reconnecting and asking again must not queue for a second room.
        final again = await b.matchmaking.findMatch(config: board);

        expect(again, isA<MatchFound>());
        expect((again as MatchFound).room.code, first.code);
        expect(rooms().length, 1);
      },
    );
  });

  group('document layout and cost', () {
    test('queue entries live at a board-partitioned path', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.findMatch(config: const BoardConfig(size: 7));

      expect(
        store.documents.containsKey('matchmaking/s7w10/waiting/uid-a'),
        isTrue,
      );
      final entry = store.documents['matchmaking/s7w10/waiting/uid-a']!;
      expect(entry['uid'], 'uid-a');
      expect(entry['queuedAt'], isA<int>());
    });

    test('a search writes one entry, not a document per poll', () async {
      final a = player(store, 'uid-a');
      store.writeLog.clear();
      await a.matchmaking.findMatch(config: board);

      expect(store.writeLog, <String>[
        'matchmaking/s9w10/waiting/uid-a',
      ], reason: 'one announcement, no periodic writes');
    });
  });

  group('code generation', () {
    test(
      'a room code that cannot be generated yields no half-built room',
      () async {
        final a = player(store, 'uid-a');
        await a.matchmaking.findMatch(config: board);

        final b = FirestoreMatchmakingRepository(
          client: store,
          userId: () async => 'uid-b',
          // Every candidate violates the format, past the point where the
          // generator would fall back to a real one. A malformed code must be
          // handled, never crash on a `!`.
          codeGenerator: ScriptedRoomCodeGenerator(
            List<String>.filled(12, 'oops'),
          ),
        );
        final result = await b.findMatch(config: board);

        // b is still queued, so "still searching" is the truthful outcome; the
        // point of the assertion is that nothing was half-built.
        expect(result, isA<MatchQueued>());
        expect(
          store.documents.keys.where((k) => k.startsWith('matches/')),
          isEmpty,
        );
      },
    );
  });
}

/// Reads pass through; writes always fail.
///
/// Models a transport that is up enough to query but cannot persist, which is
/// the only way to reach the \pairingFailed\ outcome honestly.
class _WriteFailingClient implements FirestoreClient {
  _WriteFailingClient(this.inner);

  final FirestoreClient inner;

  @override
  Future<Map<String, dynamic>?> read(String path) => inner.read(path);

  @override
  Future<void> write(String path, Map<String, dynamic> data) async =>
      throw StateError('simulated write failure');

  @override
  Future<void> delete(String path) => inner.delete(path);

  @override
  Stream<Map<String, dynamic>?> watch(String path) => inner.watch(path);

  @override
  Future<List<FirestoreDocument>> query({
    required String collectionPath,
    String? orderBy,
    int limit = 10,
  }) => inner.query(
    collectionPath: collectionPath,
    orderBy: orderBy,
    limit: limit,
  );

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction txn) action,
  ) => inner.runTransaction(action);
}
