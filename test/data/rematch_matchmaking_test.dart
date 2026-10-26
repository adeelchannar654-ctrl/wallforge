import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_matchmaking_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 11 (Q-9.2) rematch support at the repository layer, plus the
/// matched-document liveness fix the flow depends on.
///
/// The rematch negotiation uses three operations Quick Match does not:
/// [FirestoreMatchmakingRepository.joinQueue] announces without pairing,
/// [FirestoreMatchmakingRepository.waitingPlayerIds] notices a specific
/// player, and [FirestoreMatchmakingRepository.claimPlayer] pairs with that
/// player. And because matched documents are never deleted, a finished
/// match's document must not count as "already matched" forever — before
/// this phase it did, which would have made every rematch (and every second
/// Quick Match on the same board) impossible.
({String uid, FirestoreMatchmakingRepository matchmaking}) player(
  InMemoryFirestoreClient store,
  String uid, {
  DateTime? at,
}) {
  final clock = at ?? DateTime.utc(2026, 10, 26, 12);
  return (
    uid: uid,
    matchmaking: FirestoreMatchmakingRepository(
      client: store,
      userId: () async => uid,
      clock: () => clock,
    ),
  );
}

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  const board = BoardConfig();

  Map<String, Room> rooms() {
    final result = <String, Room>{};
    for (final entry in store.documents.entries) {
      if (!entry.key.startsWith('matches/')) continue;
      final room = Room.fromJson(entry.value);
      if (room != null) result[room.code] = room;
    }
    return result;
  }

  Set<String> waiting() => store.documents.keys
      .where((k) => k.contains('/waiting/'))
      .map((k) => k.split('/').last)
      .toSet();

  /// Plays one full Quick Match pairing and returns its room.
  Future<Room> pairUp() async {
    final a = player(store, 'uid-a');
    await a.matchmaking.findMatch(config: board);
    final b = player(store, 'uid-b');
    return (await b.matchmaking.findMatch(config: board) as MatchFound).room;
  }

  /// Marks a room finished in the store, as a completed match leaves it.
  /// Goes through the client's write so watchers see the change, exactly as
  /// a real backend update would arrive.
  Future<void> finish(Room room) => store.write(
    'matches/${room.code}',
    room.copyWith(status: RoomStatus.finished, winnerId: 'uid-a').toJson(),
  );

  group('matched-document liveness', () {
    test('a finished pairing does not block a fresh pairing', () async {
      final first = await pairUp();
      await finish(first);

      final a = player(store, 'uid-a');
      final requeue = await a.matchmaking.findMatch(config: board);
      expect(
        requeue,
        isA<MatchQueued>(),
        reason:
            'the finished matched document must not read as already matched',
      );

      final b = player(store, 'uid-b');
      final result = await b.matchmaking.findMatch(config: board);
      expect(result, isA<MatchFound>());
      final second = (result as MatchFound).room;
      expect(second.code, isNot(first.code), reason: 'a genuinely new room');
      expect(second.blue.playerId, 'uid-a');
      expect(second.red.playerId, 'uid-b');
    });

    test('a live pairing still blocks re-pairing', () async {
      final first = await pairUp();

      final a = player(store, 'uid-a');
      final again = await a.matchmaking.findMatch(config: board);
      expect(again, isA<MatchFound>());
      expect(
        (again as MatchFound).room.code,
        first.code,
        reason: 'double-seating protection is unchanged for live rooms',
      );
      expect(rooms().length, 1);
    });

    test('watchForMatch falls silent once the room is finished', () async {
      final first = await pairUp();
      final a = player(store, 'uid-a');

      final events = <Room?>[];
      final subscription = a.matchmaking
          .watchForMatch(config: board, uid: 'uid-a')
          .listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, isNotEmpty);
      expect(events.last?.code, first.code);

      await finish(first);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        events.last,
        isNull,
        reason: 'a finished room is not a match to enter',
      );
      await subscription.cancel();
    });
  });

  group('the rematch operations', () {
    test('joinQueue announces without pairing greedily', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.joinQueue(config: board);
      final b = player(store, 'uid-b');
      await b.matchmaking.joinQueue(config: board);

      expect(waiting(), <String>{'uid-a', 'uid-b'});
      expect(
        rooms(),
        isEmpty,
        reason: 'joining the queue must never create a room on its own',
      );
    });

    test('waitingPlayerIds reports who is waiting', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.joinQueue(config: board);

      final b = player(store, 'uid-b');
      expect(await b.matchmaking.waitingPlayerIds(config: board), <String>{
        'uid-a',
      });
    });

    test('claimPlayer pairs with the named player, who hosts', () async {
      final a = player(store, 'uid-a');
      await a.matchmaking.joinQueue(config: board);

      final b = player(store, 'uid-b');
      final result = await b.matchmaking.claimPlayer(
        config: board,
        candidateUid: 'uid-a',
      );
      expect(result, isA<MatchFound>());
      final room = (result as MatchFound).room;
      expect(room.blue.playerId, 'uid-a', reason: 'the proposer hosts');
      expect(room.red.playerId, 'uid-b', reason: 'the acceptor takes Red');
      expect(waiting(), isEmpty);
    });

    test('claimPlayer after a finished match succeeds (the rematch)', () async {
      final first = await pairUp();
      await finish(first);

      // The exact Phase 11 negotiation: Blue proposes, Red accepts.
      final a = player(store, 'uid-a');
      await a.matchmaking.joinQueue(config: board);
      final b = player(store, 'uid-b');
      final result = await b.matchmaking.claimPlayer(
        config: board,
        candidateUid: 'uid-a',
      );
      expect(result, isA<MatchFound>());
      expect((result as MatchFound).room.code, isNot(first.code));
    });

    test('claimPlayer for a player who is not waiting fails plainly', () async {
      final b = player(store, 'uid-b');
      final result = await b.matchmaking.claimPlayer(
        config: board,
        candidateUid: 'uid-nobody',
      );
      expect(result, isA<MatchRejected>());
    });

    test(
      'claimPlayer refuses while a live room already seats the pair',
      () async {
        await pairUp();

        final b = player(store, 'uid-b');
        final result = await b.matchmaking.claimPlayer(
          config: board,
          candidateUid: 'uid-a',
        );
        expect(result, isA<MatchFound>());
        expect(
          rooms().length,
          1,
          reason: 'no second room while the live one stands',
        );
      },
    );
  });
}
