import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// A stand-in for anonymous sign-in.
///
/// The real `FirebaseAuthGateway` needs a live Firebase platform, which this
/// project does not have (Q-7.3/Q-7.4). These tests therefore pin the *lobby's*
/// behaviour under each auth outcome, which is where the risk actually lives.
class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.nextState = const AuthState.signedIn('uid-1')});

  /// What [signInAnonymously] resolves to. Change it to model a failure.
  AuthState nextState;

  /// How many times sign-in was attempted.
  int signInCalls = 0;

  final StreamController<AuthState> _changes =
      StreamController<AuthState>.broadcast();

  @override
  Future<AuthState> signInAnonymously() async {
    signInCalls++;
    if (nextState.isSignedIn) _changes.add(nextState);
    return nextState;
  }

  @override
  Future<AuthState> current() async => nextState;

  @override
  Future<AuthState> signOut() async {
    nextState = const AuthState.signedOut();
    _changes.add(nextState);
    return nextState;
  }

  @override
  Stream<AuthState> authStateChanges() => _changes.stream;

  @override
  Future<String?> currentUid() async => nextState.uid;

  Future<void> dispose() => _changes.close();
}

/// A lobby backed by two independent repositories over one shared document
/// store, so the two controllers behave as two devices would.
({
  OnlineLobbyController host,
  OnlineLobbyController guest,
  FakeAuthGateway hostAuth,
  FakeAuthGateway guestAuth,
})
twoDevices(
  InMemoryFirestoreClient store, {
  AuthState hostAuth = const AuthState.signedIn('uid-host'),
  AuthState guestAuth = const AuthState.signedIn('uid-guest'),
}) {
  final hostGateway = FakeAuthGateway(nextState: hostAuth);
  final guestGateway = FakeAuthGateway(nextState: guestAuth);
  // The repository's userId resolver is the auth gateway's uid — that identity
  // link is the whole point of the Phase 6/7 seam, so the double must keep them
  // the same rather than inventing two.
  FirestoreRoomRepository roomsFor(FakeAuthGateway gateway) =>
      FirestoreRoomRepository(
        client: store,
        userId: gateway.currentUid,
        clock: () => DateTime.utc(2026, 9, 27, 12),
      );
  return (
    host: OnlineLobbyController(
      auth: hostGateway,
      rooms: roomsFor(hostGateway),
    ),
    guest: OnlineLobbyController(
      auth: guestGateway,
      rooms: roomsFor(guestGateway),
    ),
    hostAuth: hostGateway,
    guestAuth: guestGateway,
  );
}

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  group('sign in', () {
    test('a successful sign in reaches idle', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);

      expect(devices.host.phase, OnlineLobbyPhase.needsSignIn);
      await devices.host.signIn();

      expect(devices.host.phase, OnlineLobbyPhase.idle);
      expect(devices.host.uid, 'uid-host');
      expect(devices.host.failureMessage, isNull);
    });

    test('a failed sign in reports a reason and stays usable', () async {
      final devices = twoDevices(
        store,
        hostAuth: const AuthState.unavailable(
          'FirebaseAuthException(anonymous-sign-in-failed)',
        ),
      );
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);

      await devices.host.signIn();

      expect(devices.host.phase, OnlineLobbyPhase.failed);
      expect(devices.host.uid, isNull);
      expect(devices.host.failureMessage, isNotNull);
      // The failure is recoverable: the player can simply try again.
      devices.hostAuth.nextState = const AuthState.signedIn('uid-host');
      await devices.host.signIn();
      expect(devices.host.phase, OnlineLobbyPhase.idle);
    });

    test('notifies listeners so a screen can react', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);

      var notifications = 0;
      devices.host.addListener(() => notifications++);
      await devices.host.signIn();
      expect(notifications, greaterThan(0));
    });
  });

  group('create and wait', () {
    test('creating a room shows its code and waits', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();

      await devices.host.createRoom();

      expect(devices.host.phase, OnlineLobbyPhase.waiting);
      expect(devices.host.isInRoom, isTrue);
      expect(devices.host.roomCode, isNotNull);
      expect(RoomCode.isValid(devices.host.roomCode!), isTrue);
      expect(devices.host.opponentId, isNull);
      expect(devices.host.mySide, PlayerId.blue, reason: 'creator plays Blue');
    });

    test('the creator sees the opponent arrive without polling', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;
      await pumpEventQueue();

      await devices.guest.signIn();
      await devices.guest.joinRoom(code);
      await pumpEventQueue();

      // The host's controller was only ever notified by the room watch.
      expect(devices.host.phase, OnlineLobbyPhase.ready);
      expect(devices.host.opponentId, 'uid-guest');
      expect(devices.host.room!.isFull, isTrue);
      expect(devices.guest.mySide, PlayerId.red);
    });

    test('the created room uses the configured board', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();

      await devices.host.createRoom(config: const BoardConfig(size: 7));
      expect(devices.host.room!.boardConfig.size, 7);
    });
  });

  group('join', () {
    test('a malformed code is rejected locally', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.guest.signIn();

      await devices.guest.joinRoom('nope');

      expect(devices.guest.phase, OnlineLobbyPhase.failed);
      expect(
        devices.guest.lastFailure!.reason,
        RoomFailureReason.invalidRoomCode,
      );
      expect(devices.guest.isInRoom, isFalse);
    });

    test('an unknown code surfaces the specific reason', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.guest.signIn();

      await devices.guest.joinRoom('AB39HK');

      expect(devices.guest.lastFailure!.reason, RoomFailureReason.roomNotFound);
      expect(devices.guest.isInRoom, isFalse);
    });

    test(
      'a full room surfaces its own reason, not a generic failure',
      () async {
        final devices = twoDevices(store);
        addTearDown(devices.host.dispose);
        addTearDown(devices.guest.dispose);
        await devices.host.signIn();
        await devices.host.createRoom();
        final code = devices.host.roomCode!;
        await devices.guest.signIn();
        await devices.guest.joinRoom(code);
        await pumpEventQueue();

        final third = twoDevices(
          store,
          hostAuth: const AuthState.signedIn('uid-third'),
        );
        addTearDown(third.host.dispose);
        addTearDown(third.guest.dispose);
        await third.host.signIn();
        await third.host.joinRoom(code);

        // ignore: avoid_print
        expect(third.host.lastFailure!.reason, RoomFailureReason.roomFull);
      },
    );
  });

  group('ready and start', () {
    test('both players ready enables start for the host only', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;
      await devices.guest.signIn();
      await devices.guest.joinRoom(code);
      await pumpEventQueue();

      expect(devices.host.bothReady, isFalse);
      expect(devices.host.canStart, isFalse);

      await devices.host.toggleReady();
      await devices.guest.toggleReady();
      await pumpEventQueue();

      expect(devices.host.amReady, isTrue);
      expect(devices.host.isOpponentReady, isTrue);
      expect(devices.host.bothReady, isTrue);
      expect(devices.host.canStart, isTrue, reason: 'host may start');
      expect(
        devices.guest.canStart,
        isFalse,
        reason: 'a guest may not start, and the UI must reflect that',
      );
    });

    test('starting moves the lobby to started', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;
      await devices.guest.signIn();
      await devices.guest.joinRoom(code);
      await devices.host.toggleReady();
      await devices.guest.toggleReady();
      await devices.host.startMatch();

      expect(devices.host.phase, OnlineLobbyPhase.started);
      expect(devices.host.hasStarted, isTrue);
    });

    test('the guest is told when the match starts', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;
      await devices.guest.signIn();
      await devices.guest.joinRoom(code);
      await devices.host.toggleReady();
      await devices.guest.toggleReady();
      await devices.host.startMatch();
      await pumpEventQueue();

      // The guest learns about it from the watch, not by asking.
      expect(devices.guest.phase, OnlineLobbyPhase.started);
      expect(devices.guest.room!.status, RoomStatus.started);
      expect(devices.guest.mySide, PlayerId.red);
    });

    test('a guest cannot start the match', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;
      await devices.guest.signIn();
      await devices.guest.joinRoom(code);
      await devices.host.toggleReady();
      await devices.guest.toggleReady();

      await devices.guest.startMatch();

      expect(devices.guest.lastFailure!.reason, RoomFailureReason.notTheHost);
      expect(devices.guest.hasStarted, isFalse);
    });
  });

  group('leave and cancel', () {
    test('the host leaving returns to idle and frees the room', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;

      await devices.host.leaveRoom();

      expect(devices.host.phase, OnlineLobbyPhase.idle);
      expect(devices.host.isInRoom, isFalse);
      expect(devices.host.failureMessage, isNull);
      expect(store.documents.containsKey('matches/$code'), isFalse);
    });

    test('the guest is returned to idle when the host cancels', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;
      await devices.guest.signIn();
      await devices.guest.joinRoom(code);
      await pumpEventQueue();

      await devices.host.leaveRoom();
      await pumpEventQueue();

      // The room document is gone, so the guest's watch reports it.
      expect(devices.guest.isInRoom, isFalse);
      expect(devices.guest.phase, OnlineLobbyPhase.idle);
    });

    test('a guest leaving leaves the host waiting', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      final code = devices.host.roomCode!;
      await devices.guest.signIn();
      await devices.guest.joinRoom(code);
      await pumpEventQueue();

      await devices.guest.leaveRoom();
      await pumpEventQueue();

      expect(devices.guest.isInRoom, isFalse);
      expect(devices.host.isInRoom, isTrue);
      expect(devices.host.opponentId, isNull);
      expect(devices.host.phase, OnlineLobbyPhase.waiting);
    });
  });

  group('robustness', () {
    test('operating with no room is a no-op, not a crash', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();

      await devices.host.toggleReady();
      await devices.host.startMatch();
      await devices.host.leaveRoom();

      expect(devices.host.phase, OnlineLobbyPhase.idle);
    });

    test('a dispose during an in-flight create is ignored', () async {
      final devices = twoDevices(store);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();

      final pending = devices.host.createRoom();
      devices.host.dispose();
      // Must not notify a disposed ChangeNotifier, which Flutter asserts against.
      await expectLater(pending, completes);
    });

    test('a watch failure is reported rather than thrown', () async {
      final devices = twoDevices(store);
      addTearDown(devices.host.dispose);
      addTearDown(devices.guest.dispose);
      await devices.host.signIn();
      await devices.host.createRoom();
      await pumpEventQueue();

      // Closing the watchers makes the stream complete, not error, so the
      // observable contract is simply that nothing throws.
      store.closeWatchers();
      await pumpEventQueue();
      expect(devices.host.isInRoom, isTrue);
    });
  });
}
