import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 10: what the *waiting* player sees when the opponent goes quiet,
/// and the abandonment claim that follows.
///
/// One mutable clock drives every repository and both controllers, so
/// "the opponent has been silent for two minutes" is a line in the test,
/// not a wait. Presence is judged from the shared document standing still
/// while it is the opponent's turn — the same fact the claim transaction
/// and `firestore.rules` judge — never from this client's own connection
/// state, which is Phase 9's separate signal.
void main() {
  late InMemoryFirestoreClient store;
  late DateTime now;
  late OnlineGameController hostView;
  late OnlineGameController guestView;
  late String code;

  const hostUid = 'uid-host';
  const guestUid = 'uid-guest';

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

  setUp(() async {
    store = InMemoryFirestoreClient();
    now = DateTime.utc(2026, 10, 26, 12);

    final created = await roomsFor(hostUid).create(config: const BoardConfig());
    code = (created as RoomSuccess).room.code;
    await roomsFor(guestUid).join(code);
    await roomsFor(hostUid).setReady(code: code, ready: true);
    await roomsFor(guestUid).setReady(code: code, ready: true);
    await roomsFor(hostUid).start(code);

    hostView = OnlineGameController(
      rooms: roomsFor(hostUid),
      matches: matchesFor(hostUid),
      uid: hostUid,
      code: code,
      clock: () => now,
    );
    guestView = OnlineGameController(
      rooms: roomsFor(guestUid),
      matches: matchesFor(guestUid),
      uid: guestUid,
      code: code,
      clock: () => now,
    );
    await hostView.connect();
    await guestView.connect();
    // Let both listeners deliver the started document before any presence
    // judgement is read.
    await pumpEventQueue();
  });

  tearDown(() {
    hostView.dispose();
    guestView.dispose();
    store.closeWatchers();
  });

  test('presence is active while the opponent is demonstrably playing', () {
    expect(guestView.opponentPresence, OpponentPresence.active);
    expect(guestView.canClaimAbandonment, isFalse);
  });

  test('the player to move has no presence judgement about themselves', () {
    now = now.add(const Duration(minutes: 30));
    expect(hostView.opponentPresence, OpponentPresence.notApplicable);
  });

  test('presence flips to stalled only past the full threshold', () {
    now = now.add(opponentInactivityThreshold - const Duration(seconds: 1));
    expect(guestView.opponentPresence, OpponentPresence.active);
    now = now.add(const Duration(seconds: 1));
    expect(guestView.opponentPresence, OpponentPresence.stalled);
    expect(guestView.canClaimAbandonment, isTrue);
  });

  test(
    'an opponent move restores active presence and passes the turn',
    () async {
      now = now.add(const Duration(minutes: 5));
      expect(guestView.opponentPresence, OpponentPresence.stalled);

      await hostView.submit(const GameAction.move(Cell(row: 7, column: 4)));
      await pumpEventQueue();
      // It is now the guest's own turn: no judgement, and nothing to claim.
      expect(guestView.opponentPresence, OpponentPresence.notApplicable);
      expect(guestView.canClaimAbandonment, isFalse);
      // From the host's side the guest is present and fresh.
      expect(hostView.opponentPresence, OpponentPresence.active);
    },
  );

  test('claiming ends the match on both clients, with no winner', () async {
    now = now.add(opponentInactivityThreshold + const Duration(seconds: 1));
    await guestView.claimAbandonment();

    expect(guestView.isAbandoned, isTrue);
    expect(guestView.claimedByMe, isTrue);
    expect(guestView.claimFailure, isNull);

    expect(hostView.isAbandoned, isTrue);
    expect(hostView.claimedByMe, isFalse);
    expect(hostView.isFinished, isFalse);
    expect(hostView.winner, isNull);
    expect(hostView.isInteractionBlocked, isTrue);
    expect(hostView.inputBlockedReason, 'This match was abandoned.');
  });

  test('a claim attempted too early changes nothing', () async {
    await guestView.claimAbandonment();
    expect(guestView.isAbandoned, isFalse);
    expect(guestView.claimFailure, isNull);
    final doc = await matchesFor(hostUid).loadMatch(code: code);
    expect(Room.fromJson(doc!.fields)!.status, RoomStatus.started);
  });
}
