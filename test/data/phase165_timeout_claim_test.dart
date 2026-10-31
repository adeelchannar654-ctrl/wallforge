import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part C: the timeout claim and the stamped
/// deadline, exercised against the in-memory Firestore double
/// with one shared mutable clock standing in for server time.
///
/// The claim is the waiting player's remedy when the player to
/// move lets their clock run out. The repository's device-clock
/// pre-checks are proven here; the authoritative judgement is
/// the Security Rules' (`request.time`), covered by the JS
/// rules tests the owner runs against the emulator.
void main() {
  late InMemoryFirestoreClient store;
  late DateTime now;

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

  const hostUid = 'uid-host';
  const guestUid = 'uid-guest';
  const strangerUid = 'uid-stranger';

  late String code;

  Future<void> startClockedRoom({int seconds = 60}) async {
    final created = await roomsFor(hostUid)
        .create(config: const BoardConfig(), timeControlSeconds: seconds);
    code = (created as RoomSuccess).room.code;
    await roomsFor(guestUid).join(code);
    await roomsFor(hostUid).setReady(code: code, ready: true);
    await roomsFor(guestUid).setReady(code: code, ready: true);
    await roomsFor(hostUid).start(code);
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 31, 12);
    store = InMemoryFirestoreClient(clock: () => now);
  });

  tearDown(() => store.closeWatchers());

  Future<Room> storedRoom() async {
    final doc = await matchesFor(hostUid).loadMatch(code: code);
    return Room.fromJson(doc!.fields)!;
  }

  void advance(Duration d) => now = now.add(d);

  group('the deadline on the document', () {
    test('start seeds it at now + the limit, server-stamped', () async {
      await startClockedRoom();
      final room = await storedRoom();
      expect(room.timeControlSeconds, 60);
      expect(room.turnDeadlineMs, now.millisecondsSinceEpoch + 60000);
      expect(room.serverUpdatedAtMs, now.millisecondsSinceEpoch);
    });

    test('a move re-stamps and sets the next deadline in one write', () async {
      await startClockedRoom();
      advance(const Duration(seconds: 20));
      final result = await matchesFor(hostUid).submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      expect(result, isA<MoveApplied>());
      final room = await storedRoom();
      expect(room.turnDeadlineMs, now.millisecondsSinceEpoch + 60000);
      expect(room.serverUpdatedAtMs, now.millisecondsSinceEpoch);
      expect(room.finishReason, isNull);
    });

    test('an unclocked match carries no deadline', () async {
      await startClockedRoom(seconds: 0);
      final room = await storedRoom();
      expect(room.timeControlSeconds, 0);
      expect(room.turnDeadlineMs, isNull);
    });
  });

  group('claim eligibility', () {
    setUp(startClockedRoom);

    test('before the deadline the claim is refused', () async {
      advance(const Duration(seconds: 30));
      final result = await matchesFor(guestUid).claimTimeout(code: code);
      expect(result, isA<TimeoutClaimRejected>());
      expect(
        (result as TimeoutClaimRejected).reason,
        TimeoutClaimFailureReason.clockNotExpired,
      );
      expect((await storedRoom()).status, RoomStatus.started);
    });

    test('inside the grace window the claim is still refused', () async {
      // Deadline + 1 s: past the deadline, inside the 2 s grace.
      advance(const Duration(seconds: 61));
      final result = await matchesFor(guestUid).claimTimeout(code: code);
      expect(
        (result as TimeoutClaimRejected).reason,
        TimeoutClaimFailureReason.clockNotExpired,
      );
    });

    test('the player to move cannot claim their own clock', () async {
      advance(const Duration(seconds: 90));
      final result = await matchesFor(hostUid).claimTimeout(code: code);
      expect(
        (result as TimeoutClaimRejected).reason,
        TimeoutClaimFailureReason.notOpponentTurn,
      );
    });

    test('a non-member cannot claim', () async {
      advance(const Duration(seconds: 90));
      final result = await matchesFor(strangerUid).claimTimeout(code: code);
      expect(
        (result as TimeoutClaimRejected).reason,
        TimeoutClaimFailureReason.notAMember,
      );
    });
  });

  test('a claim on an unclocked match is refused as noClock', () async {
    await startClockedRoom(seconds: 0);
    advance(const Duration(minutes: 10));
    final result = await matchesFor(guestUid).claimTimeout(code: code);
    expect(
      (result as TimeoutClaimRejected).reason,
      TimeoutClaimFailureReason.noClock,
    );
  });

  group('a landed claim', () {
    setUp(startClockedRoom);

    test('ends the match: claimant wins, reason timeout', () async {
      advance(const Duration(seconds: 63)); // deadline + grace + 1.
      final result = await matchesFor(guestUid).claimTimeout(code: code);
      expect(result, isA<TimeoutClaimed>());

      final room = await storedRoom();
      expect(room.status, RoomStatus.finished);
      expect(room.winnerId, guestUid);
      expect(room.finishReason, FinishReason.timeout);
      expect(room.turnDeadlineMs, isNull);
      // The board is frozen exactly as it stood.
      expect(room.boardState!.turnNumber, 0);
    });

    test('a second claim finds the match already over', () async {
      advance(const Duration(seconds: 63));
      await matchesFor(guestUid).claimTimeout(code: code);
      final again = await matchesFor(hostUid).claimTimeout(code: code);
      expect(
        (again as TimeoutClaimRejected).reason,
        TimeoutClaimFailureReason.matchAlreadyOver,
      );
      final room = await storedRoom();
      expect(room.winnerId, guestUid);
    });

    test('a move after the claim is refused: the match is over', () async {
      advance(const Duration(seconds: 63));
      await matchesFor(guestUid).claimTimeout(code: code);
      final move = await matchesFor(hostUid).submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      expect(move, isA<MoveRejected>());
    });
  });

  test('a clocked match refuses the abandonment claim', () async {
    await startClockedRoom();
    advance(const Duration(minutes: 10));
    final result = await matchesFor(guestUid).claimAbandonment(code: code);
    expect(result, isA<AbandonmentRejected>());
    expect(
      (result as AbandonmentRejected).reason,
      AbandonmentFailureReason.clockedMatch,
    );
    expect((await storedRoom()).status, RoomStatus.started);
  });
}
