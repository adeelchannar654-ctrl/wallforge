import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part C: the online clock across two client
/// stacks sharing one store and one mutable "server" clock —
/// the countdown, the deadline hand-over on a move, the
/// automatic timeout claim, and clock-skew correction.
void main() {
  late InMemoryFirestoreClient store;
  late DateTime now;
  late FirestoreRoomRepository hostRooms;
  late FirestoreRoomRepository guestRooms;
  late FirestoreMatchRepository hostMatches;
  late FirestoreMatchRepository guestMatches;
  late OnlineGameController hostView;
  late OnlineGameController guestView;
  late String code;

  void advance(Duration d) => now = now.add(d);

  Future<void> setUpMatch({
    DateTime Function()? hostClock,
    DateTime Function()? guestClock,
  }) async {
    store = InMemoryFirestoreClient(clock: () => now);
    hostRooms = FirestoreRoomRepository(
      client: store,
      userId: () async => 'uid-host',
      clock: () => now,
    );
    guestRooms = FirestoreRoomRepository(
      client: store,
      userId: () async => 'uid-guest',
      clock: () => now,
    );
    hostMatches = FirestoreMatchRepository(
      client: store,
      userId: () async => 'uid-host',
      clock: () => now,
    );
    guestMatches = FirestoreMatchRepository(
      client: store,
      userId: () async => 'uid-guest',
      clock: () => now,
    );
    final created = await hostRooms.create(
      config: const BoardConfig(),
      timeControlSeconds: 60,
    );
    code = (created as RoomSuccess).room.code;
    await guestRooms.join(code);
    await hostRooms.setReady(code: code, ready: true);
    await guestRooms.setReady(code: code, ready: true);
    await hostRooms.start(code);
    hostView = OnlineGameController(
      rooms: hostRooms,
      matches: hostMatches,
      uid: 'uid-host',
      code: code,
      clock: hostClock ?? () => now,
    );
    guestView = OnlineGameController(
      rooms: guestRooms,
      matches: guestMatches,
      uid: 'uid-guest',
      code: code,
      clock: guestClock ?? () => now,
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

  test('both clients count down the same server deadline', () async {
    await setUpMatch();
    for (final view in [hostView, guestView]) {
      expect(view.timeControlSeconds, 60);
      expect(view.clockSide, PlayerId.blue);
      expect(view.clockRemaining, const Duration(seconds: 60));
      expect(view.clockTimerActive, isTrue);
      // A clocked match offers no abandonment claim.
      expect(view.opponentPresence, OpponentPresence.notApplicable);
      expect(view.canClaimAbandonment, isFalse);
    }
    advance(const Duration(seconds: 25));
    expect(hostView.clockRemaining, const Duration(seconds: 35));
    expect(guestView.clockRemaining, const Duration(seconds: 35));
    expect(hostView.canClaimTimeout, isFalse);
  });

  test('a move hands the clock over with a fresh deadline', () async {
    await setUpMatch();
    advance(const Duration(seconds: 20));
    final result = await hostMatches.submitAction(
      code: code,
      expectedTurnNumber: 0,
      action: const GameAction.move(Cell(row: 7, column: 4)),
    );
    expect(result, isA<MoveApplied>());
    await pumpEventQueue();
    for (final view in [hostView, guestView]) {
      expect(view.state.turnNumber, 1);
      expect(view.clockSide, PlayerId.red);
      expect(view.clockRemaining, const Duration(seconds: 60));
    }
    final doc = await hostMatches.loadMatch(code: code);
    final room = Room.fromJson(doc!.fields)!;
    expect(room.turnDeadlineMs, now.millisecondsSinceEpoch + 60000);
  });

  test('the waiting client auto-claims when the clock runs out', () async {
    await setUpMatch();
    // Blue (host) never moves. 63 s: deadline + 2 s grace + 1.
    advance(const Duration(seconds: 63));
    expect(guestView.canClaimTimeout, isTrue);
    guestView.debugTickClock();
    await pumpEventQueue();
    for (final view in [hostView, guestView]) {
      expect(view.isFinished, isTrue);
      expect(view.winner, PlayerId.red);
      expect(view.finishReason, FinishReason.timeout);
      expect(view.clockRemaining, isNull);
      expect(view.clockTimerActive, isFalse);
    }
  });

  test('a device clock 30 s fast still reads the true remainder', () async {
    await setUpMatch(hostClock: () => now.add(const Duration(seconds: 30)));
    // Host's device is 30 s ahead, but the skew estimate learned
    // from the server stamp cancels it: the full minute shows.
    expect(hostView.clockRemaining, const Duration(seconds: 60));
    advance(const Duration(seconds: 35));
    expect(hostView.clockRemaining, const Duration(seconds: 25));
    expect(guestView.clockRemaining, const Duration(seconds: 25));
  });

  test('a waiting device 30 s slow still claims on server time', () async {
    await setUpMatch(
      guestClock: () => now.subtract(const Duration(seconds: 30)),
    );
    advance(const Duration(seconds: 63));
    // Guest's own clock reads only 33 s into the match, yet the
    // skew-corrected estimate knows the deadline has passed.
    expect(guestView.canClaimTimeout, isTrue);
    guestView.debugTickClock();
    await pumpEventQueue();
    expect(guestView.isFinished, isTrue);
    expect(guestView.winner, PlayerId.red);
    expect(guestView.finishReason, FinishReason.timeout);
  });
}
