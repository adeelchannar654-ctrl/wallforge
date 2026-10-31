import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part E: each online client records the finished
/// match locally, from the snapshots it already holds — the
/// winner on one side is the loss on the other, the move list
/// is reconstructed by diffing, and repeated snapshots never
/// double-record. No statistics are touched by online matches.
void main() {
  late InMemoryFirestoreClient store;
  late DateTime now;
  late InMemoryMatchHistoryRepository hostHistory;
  late InMemoryMatchHistoryRepository guestHistory;
  late OnlineGameController hostView;
  late OnlineGameController guestView;
  late String code;

  FirestoreRoomRepository roomsFor(String uid) => FirestoreRoomRepository(
    client: store,
    userId: () async => uid,
    clock: () => now,
  );

  FirestoreMatchRepository matchesFor(String uid) => FirestoreMatchRepository(
    client: store,
    userId: () async => uid,
    clock: () => now,
  );

  Future<void> setUpMatch({int timeControlSeconds = 0}) async {
    store = InMemoryFirestoreClient(clock: () => now);
    hostHistory = InMemoryMatchHistoryRepository();
    guestHistory = InMemoryMatchHistoryRepository();
    final created = await roomsFor('uid-host').create(
      config: const BoardConfig(),
      timeControlSeconds: timeControlSeconds,
    );
    code = (created as RoomSuccess).room.code;
    await roomsFor('uid-guest').join(code);
    await roomsFor('uid-host').setReady(code: code, ready: true);
    await roomsFor('uid-guest').setReady(code: code, ready: true);
    await roomsFor('uid-host').start(code);
    hostView = OnlineGameController(
      rooms: roomsFor('uid-host'),
      matches: matchesFor('uid-host'),
      uid: 'uid-host',
      code: code,
      clock: () => now,
      history: hostHistory,
    );
    guestView = OnlineGameController(
      rooms: roomsFor('uid-guest'),
      matches: matchesFor('uid-guest'),
      uid: 'uid-guest',
      code: code,
      clock: () => now,
      history: guestHistory,
    );
    await hostView.connect();
    await guestView.connect();
    await pumpEventQueue();
  }

  tearDown(() {
    hostView.dispose();
    guestView.dispose();
    store.closeWatchers();
  });

  setUp(() => now = DateTime.utc(2026, 10, 31, 12));

  test('a resign finish is recorded by both clients, mirrored', () async {
    await setUpMatch();
    await matchesFor('uid-host').submitAction(
      code: code,
      expectedTurnNumber: 0,
      action: const GameAction.move(Cell(row: 7, column: 4)),
    );
    await matchesFor('uid-guest').submitAction(
      code: code,
      expectedTurnNumber: 1,
      action: const GameAction.move(Cell(row: 1, column: 4)),
    );
    await pumpEventQueue();
    await hostView.resign();
    await pumpEventQueue();

    final hostRecords = await hostHistory.load();
    final guestRecords = await guestHistory.load();
    expect(hostRecords, hasLength(1));
    expect(guestRecords, hasLength(1));

    final host = hostRecords.single;
    expect(host.id, code);
    expect(host.mode, MatchMode.online);
    expect(host.mySide, PlayerId.blue);
    expect(host.winnerSide, PlayerId.red);
    expect(host.isLoss, isTrue);
    expect(host.finishReason, FinishReason.resign);
    expect(host.opponentLabel, 'Online player');
    expect(host.plies, 2);
    expect(host.moves, ['M 7,4', 'M 1,4']);
    expect(host.movesComplete, isTrue);

    final guest = guestRecords.single;
    expect(guest.mySide, PlayerId.red);
    expect(guest.isWin, isTrue);
    expect(guest.moves, host.moves);

    // Repeated snapshots of the same finish change nothing.
    await hostView.resync();
    await guestView.resync();
    await pumpEventQueue();
    expect(await hostHistory.load(), hasLength(1));
    expect(await guestHistory.load(), hasLength(1));
  });

  test('an abandonment records with no winner on both sides', () async {
    await setUpMatch();
    now = now.add(const Duration(seconds: 121));
    final result = await matchesFor('uid-guest').claimAbandonment(code: code);
    expect(result, isA<AbandonmentClaimed>());
    await pumpEventQueue();

    for (final records in [
      await hostHistory.load(),
      await guestHistory.load(),
    ]) {
      expect(records, hasLength(1));
      final r = records.single;
      expect(r.winnerSide, isNull);
      expect(r.isAbandoned, isTrue);
      expect(r.finishReason, FinishReason.abandon);
    }
  });

  test(
    'a client that connects after the finish holds a partial list',
    () async {
      await setUpMatch();
      await matchesFor('uid-host').submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      await matchesFor('uid-guest').submitAction(
        code: code,
        expectedTurnNumber: 1,
        action: const GameAction.move(Cell(row: 1, column: 4)),
      );
      await matchesFor('uid-host').resign(code: code);
      await pumpEventQueue();

      // A fresh controller for the host, connecting only now:
      // it adopts the finished document in one two-ply jump, so
      // its move list is honestly marked partial.
      final lateHistory = InMemoryMatchHistoryRepository();
      final lateView = OnlineGameController(
        rooms: roomsFor('uid-host'),
        matches: matchesFor('uid-host'),
        uid: 'uid-host',
        code: code,
        clock: () => now,
        history: lateHistory,
      );
      addTearDown(lateView.dispose);
      await lateView.connect();
      await pumpEventQueue();

      final records = await lateHistory.load();
      expect(records, hasLength(1));
      expect(records.single.movesComplete, isFalse);
      expect(records.single.moves, isEmpty);
      expect(records.single.plies, 2);
      expect(records.single.finishReason, FinishReason.resign);
    },
  );
}
