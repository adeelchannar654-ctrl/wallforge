import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/data/remote/firestore_matchmaking_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Always-succeeds identity, so these tests exercise matchmaking rather than the
/// auth failure path (covered in the Phase 8 auth tests).
class _StubAuth implements AuthGateway {
  const _StubAuth(this.uid);
  final String uid;
  @override
  Future<AuthState> signInAnonymously() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> current() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => uid;
}

/// A lobby wired to matchmaking, sharing one document store.
OnlineLobbyController lobby(InMemoryFirestoreClient store, String uid) {
  final auth = _StubAuth(uid);
  return OnlineLobbyController(
    auth: auth,
    rooms: FirestoreRoomRepository(client: store, userId: auth.currentUid),
    matchmaking: FirestoreMatchmakingRepository(
      client: store,
      userId: auth.currentUid,
    ),
  );
}

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  const board = BoardConfig();

  group('quick match through the controller', () {
    test('a lone player reaches the searching state', () async {
      final a = lobby(store, 'uid-a');
      addTearDown(a.dispose);
      await a.signIn();

      await a.quickMatch();

      expect(a.phase, OnlineLobbyPhase.searching);
      expect(a.isInRoom, isFalse);
      expect(a.failureMessage, isNull);
    });

    test('the waiting player is seated when an opponent arrives', () async {
      final a = lobby(store, 'uid-a');
      final b = lobby(store, 'uid-b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.signIn();
      await b.signIn();

      await a.quickMatch();
      expect(a.phase, OnlineLobbyPhase.searching);

      await b.quickMatch();
      // Let the waiting player's match notification arrive.
      await pumpEventQueue();
      await testerPump();

      expect(b.phase, OnlineLobbyPhase.ready, reason: 'b claimed a room');
      expect(
        a.phase,
        OnlineLobbyPhase.ready,
        reason: 'a was notified, both in',
      );
      expect(a.roomCode, isNotNull);
      expect(a.roomCode, b.roomCode, reason: 'both in the same room');
      expect(a.mySide, PlayerId.blue, reason: 'the waiting player hosts');
      expect(b.mySide, PlayerId.red);
    });

    test('two simultaneous requests both land in one room', () async {
      final a = lobby(store, 'uid-a');
      final b = lobby(store, 'uid-b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.signIn();
      await b.signIn();

      await Future.wait([a.quickMatch(), b.quickMatch()]);
      await pumpEventQueue();
      await testerPump();

      expect(a.roomCode, isNotNull);
      expect(a.roomCode, b.roomCode);
      final rooms = store.documents.keys.where((k) => k.startsWith('matches/'));
      expect(rooms, hasLength(1));
    });

    test(
      'cancelling leaves the queue and returns to the entry state',
      () async {
        final a = lobby(store, 'uid-a');
        addTearDown(a.dispose);
        await a.signIn();
        await a.quickMatch();
        expect(a.phase, OnlineLobbyPhase.searching);

        await a.cancelQuickMatch();

        expect(a.phase, OnlineLobbyPhase.idle);
        expect(
          store.documents.keys.where((k) => k.contains('/waiting/')),
          isEmpty,
        );
      },
    );

    test('a cancelled player is not paired with a later arrival', () async {
      final a = lobby(store, 'uid-a');
      final b = lobby(store, 'uid-b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.signIn();
      await b.signIn();
      await a.quickMatch();
      await a.cancelQuickMatch();

      await b.quickMatch();
      await pumpEventQueue();
      await testerPump();

      expect(
        b.phase,
        OnlineLobbyPhase.searching,
        reason: 'nobody to pair with',
      );
      expect(b.isInRoom, isFalse);
    });

    test(
      'quick match is refused, not silently ignored, without matchmaking',
      () async {
        const auth = _StubAuth('uid-a');
        final controller = OnlineLobbyController(
          auth: auth,
          rooms: FirestoreRoomRepository(
            client: store,
            userId: auth.currentUid,
          ),
        );
        addTearDown(controller.dispose);
        await controller.signIn();

        await controller.quickMatch();

        expect(controller.phase, OnlineLobbyPhase.failed);
        expect(controller.failureMessage, contains('not available'));
      },
    );

    test('quick match without an identity fails safely', () async {
      final offline = FirestoreMatchmakingRepository(
        client: store,
        userId: () async => null,
      );
      const auth = _StubAuth('uid-a');
      final controller = OnlineLobbyController(
        auth: auth,
        rooms: FirestoreRoomRepository(client: store, userId: () async => null),
        matchmaking: offline,
      );
      addTearDown(controller.dispose);
      await controller.signIn();

      await controller.quickMatch();

      expect(controller.phase, OnlineLobbyPhase.failed);
      expect(store.documents, isEmpty);
    });
  });

  group('a matched room behaves exactly like a code-joined one', () {
    test('ready up and start works on a quick-matched room', () async {
      final a = lobby(store, 'uid-a');
      final b = lobby(store, 'uid-b');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.signIn();
      await b.signIn();

      await a.quickMatch();
      await b.quickMatch();
      await pumpEventQueue();
      await testerPump();

      expect(a.roomCode, isNotNull);
      expect(a.room!.isFull, isTrue);
      expect(a.room!.status, RoomStatus.waiting);

      // Phase 8's own flow, unchanged, on a room found by matchmaking.
      await a.toggleReady();
      await pumpEventQueue();
      expect(
        b.isOpponentReady,
        isTrue,
        reason: 'the other side saw the change',
      );

      await b.toggleReady();
      await pumpEventQueue();
      expect(a.bothReady, isTrue);
      expect(a.canStart, isTrue);
      expect(b.canStart, isFalse, reason: 'only the host starts');

      await a.startMatch();
      await pumpEventQueue();

      expect(a.hasStarted, isTrue);
      expect(b.hasStarted, isTrue, reason: 'the other side saw the start');
      expect(a.room!.status, RoomStatus.started);
      expect(a.room!.sideFor('uid-a'), PlayerId.blue);
      expect(a.room!.sideFor('uid-b'), PlayerId.red);
      expect(a.room!.boardConfig, board);
    });

    test(
      'a quick-matched room has the same stored shape as a code room',
      () async {
        // Two players, so a room actually exists: one queues, one claims.
        final waiting = FirestoreMatchmakingRepository(
          client: store,
          userId: () async => 'uid-a',
        );
        await waiting.findMatch(config: board);
        final claimer = FirestoreMatchmakingRepository(
          client: store,
          userId: () async => 'uid-b',
        );
        final room =
            (await claimer.findMatch(config: board) as MatchFound).room;

        final fresh = FirestoreRoomRepository(
          client: store,
          userId: () async => 'uid-a',
        );
        final codeRoom =
            (await fresh.create(config: board) as RoomSuccess).room;

        // Same stored document shape: identical key set, and identical field
        // types and defaults. Only the values matchmaking necessarily fills differ.
        final matched = store.documents['matches/${room.code}']!;
        final coded = store.documents['matches/${codeRoom.code}']!;
        expect(matched.keys.toSet(), coded.keys.toSet());
        expect(matched['schemaVersion'], coded['schemaVersion']);
        expect(matched['boardSize'], coded['boardSize']);
        expect(matched['status'], coded['status']);
        expect(
          matched['blue'] is Map<String, dynamic>,
          isTrue,
          reason: 'seats are the same nested shape as a code room',
        );

        // And the Phase 8 repository loads and mutates it like any other room.
        expect((await fresh.load(room.code))!.code, room.code);
        final reloaded = (await fresh.load(room.code))!;
        expect(reloaded.sideFor('uid-a'), PlayerId.blue);
        expect(reloaded.sideFor('uid-b'), PlayerId.red);
      },
    );

    test(
      'leaving a quick-matched room behaves like leaving any room',
      () async {
        final a = lobby(store, 'uid-a');
        final b = lobby(store, 'uid-b');
        addTearDown(a.dispose);
        addTearDown(b.dispose);
        await a.signIn();
        await b.signIn();
        await a.quickMatch();
        await b.quickMatch();
        await pumpEventQueue();
        await testerPump();

        final code = a.roomCode!;
        await a.leaveRoom();
        await pumpEventQueue();
        await testerPump();

        // a was the host, so the room is deleted and b is returned to idle.
        expect(store.documents.containsKey('matches/$code'), isFalse);
        expect(b.isInRoom, isFalse);
        expect(b.phase, OnlineLobbyPhase.idle);
      },
    );
  });

  group('robustness', () {
    test('a dispose during an in-flight quick match is ignored', () async {
      final a = lobby(store, 'uid-a');
      await a.signIn();

      final pending = a.quickMatch();
      a.dispose();
      await expectLater(pending, completes);
    });
  });
}

/// Lets queued microtasks and stream events settle inside a fake-async test.
Future<void> testerPump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
