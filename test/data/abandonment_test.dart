import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 10: the abandonment claim, exercised against the in-memory
/// Firestore double with one shared, mutable clock.
///
/// The claim is the waiting player's remedy when the player to move goes
/// silent. The properties that matter are all here: it is refused while the
/// opponent is demonstrably active, refused on the claimer's own turn,
/// refused for non-members, final once landed — and the race with the
/// opponent's return has a defined outcome in both orders, because the
/// claim and the move are transactions on the same document.
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

  setUp(() async {
    store = InMemoryFirestoreClient();
    now = DateTime.utc(2026, 10, 26, 12);
    final created = await roomsFor(hostUid).create(config: const BoardConfig());
    code = (created as RoomSuccess).room.code;
    await roomsFor(guestUid).join(code);
    await roomsFor(hostUid).setReady(code: code, ready: true);
    await roomsFor(guestUid).setReady(code: code, ready: true);
    await roomsFor(hostUid).start(code);
  });

  tearDown(() => store.closeWatchers());

  Future<Room> storedRoom() async {
    final doc = await matchesFor(hostUid).loadMatch(code: code);
    return Room.fromJson(doc!.fields)!;
  }

  void goSilentFor(Duration duration) => now = now.add(duration);

  group('claim eligibility', () {
    test(
      'a fresh match refuses the claim: the opponent is still active',
      () async {
        final result = await matchesFor(guestUid).claimAbandonment(code: code);
        expect(result, isA<AbandonmentRejected>());
        expect(
          (result as AbandonmentRejected).reason,
          AbandonmentFailureReason.opponentStillActive,
        );
        expect((await storedRoom()).status, RoomStatus.started);
      },
    );

    test('the player to move cannot claim: it is their own turn', () async {
      goSilentFor(const Duration(minutes: 10));
      final result = await matchesFor(hostUid).claimAbandonment(code: code);
      expect(
        (result as AbandonmentRejected).reason,
        AbandonmentFailureReason.notOpponentTurn,
      );
    });

    test('a non-member cannot claim, however stale the match', () async {
      goSilentFor(const Duration(minutes: 10));
      final result = await matchesFor(strangerUid).claimAbandonment(code: code);
      expect(
        (result as AbandonmentRejected).reason,
        AbandonmentFailureReason.notAMember,
      );
    });

    test('just under the threshold still refuses', () async {
      goSilentFor(opponentInactivityThreshold - const Duration(seconds: 1));
      final result = await matchesFor(guestUid).claimAbandonment(code: code);
      expect(
        (result as AbandonmentRejected).reason,
        AbandonmentFailureReason.opponentStillActive,
      );
    });
  });

  group('a landed claim', () {
    test('ends the match with the claimant recorded and no winner', () async {
      goSilentFor(opponentInactivityThreshold + const Duration(seconds: 1));
      final result = await matchesFor(guestUid).claimAbandonment(code: code);
      expect(result, isA<AbandonmentClaimed>());

      final room = await storedRoom();
      expect(room.status, RoomStatus.abandoned);
      expect(room.abandonedById, guestUid);
      expect(room.winnerId, isNull);
      // The board is frozen exactly as it stood.
      expect(room.turnNumber, 0);
      expect(room.boardState, isNotNull);
    });

    test('the returning opponent finds the match over', () async {
      goSilentFor(opponentInactivityThreshold + const Duration(seconds: 1));
      await matchesFor(guestUid).claimAbandonment(code: code);

      final move = await matchesFor(hostUid).submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      expect(move, isA<MoveRejected>());
      expect(
        (move as MoveRejected).reason,
        MatchSyncFailureReason.matchFinished,
      );
    });

    test('a second claim is refused: the match is already over', () async {
      goSilentFor(opponentInactivityThreshold + const Duration(seconds: 1));
      await matchesFor(guestUid).claimAbandonment(code: code);
      final again = await matchesFor(guestUid).claimAbandonment(code: code);
      expect(
        (again as AbandonmentRejected).reason,
        AbandonmentFailureReason.matchAlreadyOver,
      );
    });
  });

  group('the race with the opponent returning', () {
    test(
      'a move that lands first refuses the claim and play continues',
      () async {
        // The document goes stale, then Blue returns and moves *before* the
        // waiting player's claim is attempted. The claim must lose: the turn
        // has passed to the claimant, so there is nobody left to wait for.
        goSilentFor(opponentInactivityThreshold + const Duration(seconds: 1));
        final move = await matchesFor(hostUid).submitAction(
          code: code,
          expectedTurnNumber: 0,
          action: const GameAction.move(Cell(row: 7, column: 4)),
        );
        expect(move, isA<MoveApplied>());

        final claim = await matchesFor(guestUid).claimAbandonment(code: code);
        expect(claim, isA<AbandonmentRejected>());
        expect(
          (claim as AbandonmentRejected).reason,
          AbandonmentFailureReason.notOpponentTurn,
        );
        expect((await storedRoom()).status, RoomStatus.started);
      },
    );

    test('play advancing back to the silent player re-arms the wait', () async {
      // Both players move, so the turn returns to Blue with a fresh
      // timestamp. Blue goes silent again; only a *full* new threshold of
      // silence makes the match claimable again.
      await matchesFor(hostUid).submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      await matchesFor(guestUid).submitAction(
        code: code,
        expectedTurnNumber: 1,
        action: const GameAction.move(Cell(row: 1, column: 4)),
      );
      // Just under a fresh threshold since the last move: still active.
      goSilentFor(opponentInactivityThreshold - const Duration(seconds: 1));
      final early = await matchesFor(guestUid).claimAbandonment(code: code);
      expect(
        (early as AbandonmentRejected).reason,
        AbandonmentFailureReason.opponentStillActive,
      );
      // Past it: the claim lands.
      goSilentFor(const Duration(seconds: 2));
      final claim = await matchesFor(guestUid).claimAbandonment(code: code);
      expect(claim, isA<AbandonmentClaimed>());
    });
  });

  group('before the match starts', () {
    test('a waiting room cannot be claimed', () async {
      final created = await roomsFor(strangerUid)
          .create(config: const BoardConfig());
      final waitingCode = (created as RoomSuccess).room.code;
      final result = await matchesFor(strangerUid)
          .claimAbandonment(code: waitingCode);
      // The stranger is the room's host and only member; the match simply
      // has not started, which is reported before any turn question.
      expect(
        (result as AbandonmentRejected).reason,
        AbandonmentFailureReason.matchNotStarted,
      );
    });
  });
}
