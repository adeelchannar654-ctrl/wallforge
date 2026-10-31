import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/account/identity_guard.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

import '../support/fake_account_auth_gateway.dart';

/// Phase 16.6, Part C: the online controllers report their
/// liveness to the [IdentityGuard] — the lobby while it holds a
/// room, the game controller for its whole lifetime — and clear
/// it when they go away. Proven against the real controllers over
/// the in-memory store, not against mocks of them.
void main() {
  group('OnlineLobbyController', () {
    late InMemoryFirestoreClient store;
    late IdentityGuard guard;
    late OnlineLobbyController lobby;

    setUp(() async {
      store = InMemoryFirestoreClient();
      guard = IdentityGuard();
      final auth = FakeAccountAuthGateway();
      await auth.signInAnonymously();
      lobby = OnlineLobbyController(
        auth: auth,
        rooms: FirestoreRoomRepository(
          client: store,
          userId: () async => 'uid-lobby',
        ),
        identityGuard: guard,
      );
      await lobby.signIn();
    });

    tearDown(() {
      lobby.dispose();
      store.closeWatchers();
    });

    test('creating a room opens the guard; leaving closes it', () async {
      expect(guard.roomOpen, isFalse);
      await lobby.createRoom();
      expect(lobby.isInRoom, isTrue);
      expect(guard.roomOpen, isTrue);
      expect(guard.identityChangeBlocked, isTrue);

      await lobby.leaveRoom();
      expect(lobby.isInRoom, isFalse);
      expect(guard.roomOpen, isFalse);
    });

    test('disposing the lobby with a room open clears the guard', () async {
      // Own instance: this test disposes its controller itself.
      final auth = FakeAccountAuthGateway();
      await auth.signInAnonymously();
      final own = OnlineLobbyController(
        auth: auth,
        rooms: FirestoreRoomRepository(
          client: store,
          userId: () async => 'uid-lobby',
        ),
        identityGuard: guard,
      );
      await own.signIn();
      await own.createRoom();
      expect(guard.roomOpen, isTrue);
      own.dispose();
      expect(guard.roomOpen, isFalse);
    });
  });

  group('OnlineGameController', () {
    test('construction marks the match active; dispose clears it', () async {
      final store = InMemoryFirestoreClient();
      final guard = IdentityGuard();
      Future<String?> uid() async => 'uid-player';
      final rooms = FirestoreRoomRepository(client: store, userId: uid);
      final created = await rooms.create(config: const BoardConfig());
      final code = (created as RoomSuccess).room.code;

      expect(guard.matchActive, isFalse);
      final controller = OnlineGameController(
        rooms: rooms,
        matches: FirestoreMatchRepository(client: store, userId: uid),
        uid: 'uid-player',
        code: code,
        identityGuard: guard,
      );
      expect(guard.matchActive, isTrue);
      expect(guard.identityChangeBlocked, isTrue);
      controller.dispose();
      expect(guard.matchActive, isFalse);
      store.closeWatchers();
    });
  });
}
