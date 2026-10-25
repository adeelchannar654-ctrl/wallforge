import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 10's abuse limit for rooms: one player, one open room.
///
/// "Open" means waiting or ready — a room whose match has not started. The
/// guard is the `playerRooms/{uid}` pointer the repository maintains: it is
/// consulted on create and on join, set when a room opens for the player,
/// and cleared when the room starts or the player leaves. These tests pin
/// the behaviour, including the self-healing cases (a pointer naming a room
/// that started, finished or vanished must not lock the player out).
void main() {
  late InMemoryFirestoreClient store;

  FirestoreRoomRepository roomsFor(String uid) =>
      FirestoreRoomRepository(client: store, userId: () async => uid);

  const hostUid = 'uid-host';
  const guestUid = 'uid-guest';
  const otherUid = 'uid-other';

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  Future<String> createRoom(String uid) async {
    final result = await roomsFor(uid).create(config: const BoardConfig());
    return (result as RoomSuccess).room.code;
  }

  test('creating a second open room is refused, naming the first', () async {
    final first = await createRoom(hostUid);
    final second = await roomsFor(hostUid).create(config: const BoardConfig());
    expect(second, isA<RoomRejected>());
    final rejected = second as RoomRejected;
    expect(rejected.reason, RoomFailureReason.alreadyHasOpenRoom);
    expect(rejected.message, contains(first));
  });

  test('the limit is per player: another player can still create', () async {
    await createRoom(hostUid);
    final result = await roomsFor(guestUid).create(config: const BoardConfig());
    expect(result, isA<RoomSuccess>());
  });

  test('leaving the open room frees the player to create again', () async {
    final first = await createRoom(hostUid);
    await roomsFor(hostUid).leave(first);
    final result = await roomsFor(hostUid).create(config: const BoardConfig());
    expect(result, isA<RoomSuccess>());
  });

  test(
    'joining a second open room is refused; rejoining your own is not',
    () async {
      final mine = await createRoom(hostUid);
      final theirs = await createRoom(otherUid);

      final joined = await roomsFor(guestUid).join(mine);
      expect(joined, isA<RoomSuccess>());

      // The guest is now in an open room; a second one is refused.
      final second = await roomsFor(guestUid).join(theirs);
      expect(second, isA<RoomRejected>());
      expect(
        (second as RoomRejected).reason,
        RoomFailureReason.alreadyHasOpenRoom,
      );

      // Rejoining the same room stays the Phase 8 no-op.
      final rejoined = await roomsFor(guestUid).join(mine);
      expect(rejoined, isA<RoomSuccess>());

      // And creating is equally refused while seated in an open room.
      final created = await roomsFor(guestUid)
          .create(config: const BoardConfig());
      expect(created, isA<RoomRejected>());
    },
  );

  test(
    'a started room no longer blocks: the pointer clears at start',
    () async {
      final code = await createRoom(hostUid);
      await roomsFor(guestUid).join(code);
      await roomsFor(hostUid).setReady(code: code, ready: true);
      await roomsFor(guestUid).setReady(code: code, ready: true);
      await roomsFor(hostUid).start(code);

      final result = await roomsFor(hostUid)
          .create(config: const BoardConfig());
      expect(result, isA<RoomSuccess>());
    },
  );

  test('a pointer naming a vanished room heals itself', () async {
    final code = await createRoom(hostUid);
    // The room document disappears behind the player's back (the host-side
    // delete in another session, say) without the pointer being cleared.
    await store.delete('matches/$code');
    final result = await roomsFor(hostUid).create(config: const BoardConfig());
    expect(result, isA<RoomSuccess>());
  });

  test(
    'a guest who leaves frees themselves; the host room stays open',
    () async {
      final code = await createRoom(hostUid);
      final other = await createRoom(otherUid);
      await roomsFor(guestUid).join(code);
      await roomsFor(guestUid).leave(code);
      final joined = await roomsFor(guestUid).join(other);
      expect(joined, isA<RoomSuccess>());
    },
  );
}
