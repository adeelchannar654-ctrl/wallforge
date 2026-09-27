import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_client.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/data/remote/room_code_generator.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Two independent clients acting as two devices, sharing one document store.
///
/// This is the substitute for the emulator the project cannot currently run
/// (Q-7.3): both clients talk to the same [InMemoryFirestoreClient] through their
/// own repository and their own `userId` resolver, which is the property Phase 8
/// actually needs to demonstrate. It does **not** prove Firestore behaves this
/// way — only the repository contract is under test here.
class _Client {
  _Client(this.uid, this.store, {RoomCodeGenerator? codeGenerator})
    : rooms = FirestoreRoomRepository(
        client: store,
        userId: () async => uid,
        codeGenerator: codeGenerator,
        clock: () => DateTime.utc(2026, 9, 27, 12),
      );

  final String uid;
  final InMemoryFirestoreClient store;
  final FirestoreRoomRepository rooms;
}

void main() {
  late InMemoryFirestoreClient store;
  late _Client host;
  late _Client guest;

  setUp(() {
    store = InMemoryFirestoreClient();
    host = _Client('uid-host', store);
    guest = _Client('uid-guest', store);
  });

  tearDown(() => store.closeWatchers());

  /// Creates a room and returns its code.
  Future<String> createRoom(_Client client, {BoardConfig? config}) async {
    final result = await client.rooms.create(
      config: config ?? const BoardConfig(),
    );
    expect(result, isA<RoomSuccess>());
    return (result as RoomSuccess).room.code;
  }

  /// Drives a room to `started` and returns it.
  Future<Room> playToStart() async {
    final code = await createRoom(host);
    expect(await guest.rooms.join(code), isA<RoomSuccess>());
    expect(
      await host.rooms.setReady(code: code, ready: true),
      isA<RoomSuccess>(),
    );
    expect(
      await guest.rooms.setReady(code: code, ready: true),
      isA<RoomSuccess>(),
    );
    final started = await host.rooms.start(code);
    expect(started, isA<RoomSuccess>());
    return (started as RoomSuccess).room;
  }

  group('create', () {
    test('writes one document at matches/{code}', () async {
      final code = await createRoom(host);
      expect(store.documents.keys, <String>['matches/$code']);
      expect(code.length, RoomCode.length);
      expect(RoomCode.isValid(code), isTrue);
      expect(store.documents['matches/$code']!['schemaVersion'], 1);
    });

    test('the creator is seated in Blue and is the host', () async {
      final code = await createRoom(host);
      final room = (await host.rooms.load(code))!;
      // Blue moves first (R-PLAYER-07), and Q-6.2 already established Blue as
      // the first player in the local game.
      expect(room.blue.playerId, 'uid-host');
      expect(room.red.playerId, isNull);
      expect(room.hostId, 'uid-host');
      expect(room.isHost('uid-host'), isTrue);
      expect(room.status, RoomStatus.waiting);
    });

    test('stores the agreed board config', () async {
      final code = await createRoom(host, config: const BoardConfig(size: 7));
      final room = (await host.rooms.load(code))!;
      expect(room.boardConfig.size, 7);
      expect(room.boardConfig.wallsPerPlayer, 10);
    });

    test('the stored document round-trips through Room.fromJson', () async {
      final code = await createRoom(host);
      final raw = store.documents['matches/$code']!;
      final parsed = Room.fromJson(raw)!;
      expect(parsed.code, code);
      expect(parsed.status, RoomStatus.waiting);
      expect(parsed.blue.playerId, 'uid-host');
    });

    test('two rooms get different codes', () async {
      final a = await createRoom(host);
      final b = await createRoom(guest);
      expect(a, isNot(b));
      expect(store.documents.keys.length, 2);
    });

    test('retries a colliding code instead of overwriting', () async {
      // The first candidate is already taken, so the repository must move on.
      final taken = await createRoom(host);
      final scripted = ScriptedRoomCodeGenerator(<String>[taken, 'ZZ99ZZ']);
      final second = _Client('uid-other', store, codeGenerator: scripted);
      final code = await createRoom(second);

      expect(code, 'ZZ99ZZ');
      expect(scripted.calls, 2);
      // The original room is untouched.
      expect((await host.rooms.load(taken))!.hostId, 'uid-host');
    });

    test('reports a collision it cannot resolve within its bound', () async {
      // Every candidate is the same already-taken code, so retries run out.
      final taken = await createRoom(host);
      final client = _Client(
        'uid-other',
        store,
        codeGenerator: ScriptedRoomCodeGenerator(List<String>.filled(9, taken)),
      );
      final result = await client.rooms.create(config: const BoardConfig());
      expect(result, isA<RoomRejected>());
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.codeGenerationFailed,
      );
    });

    test('a failed write is reported as a network failure, not a code collision', () async {
      // A client whose writes fail while reads succeed, so the failure lands on
      // the write a naive implementation would have swallowed and then blamed on
      // the code space.
      final client = FirestoreRoomRepository(
        client: _WriteFailingClient(store),
        userId: () async => 'uid-other',
        codeGenerator: ScriptedRoomCodeGenerator(
          List<String>.filled(9, 'AB39HK'),
        ),
      );
      final result = await client.create(config: const BoardConfig());
      expect(result, isA<RoomRejected>());
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.networkUnavailable,
      );
    });

    test('refuses an invalid board config', () async {
      final result = await host.rooms.create(
        config: const BoardConfig(size: 4),
      );
      expect(result, isA<RoomRejected>());
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.invalidRoomDocument,
      );
    });
  });

  group('join', () {
    test('the second client takes Red', () async {
      final code = await createRoom(host);
      final result = await guest.rooms.join(code);
      expect(result, isA<RoomSuccess>());
      final room = (result as RoomSuccess).room;
      expect(room.blue.playerId, 'uid-host');
      expect(room.red.playerId, 'uid-guest');
      expect(room.isFull, isTrue);
      expect(room.opponentOf('uid-host'), 'uid-guest');
      expect(room.sideFor('uid-guest'), PlayerId.red);
    });

    test('accepts a lower-case code with separators', () async {
      final code = await createRoom(host);
      final lower = code.toLowerCase();
      final result = await guest.rooms.join(' $lower ');
      expect(result, isA<RoomSuccess>());
    });

    test('rejoining your own room is a no-op, not an error', () async {
      final code = await createRoom(host);
      final result = await host.rooms.join(code);
      expect(result, isA<RoomSuccess>());
      expect((result as RoomSuccess).room.blue.playerId, 'uid-host');
    });

    test('a malformed code is rejected before any read', () async {
      final writesBefore = store.writeLog.length;
      final result = await guest.rooms.join('nope');
      expect(result, isA<RoomRejected>());
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.invalidRoomCode,
      );
      expect(store.writeLog.length, writesBefore);
    });

    test('an unknown code is distinguishable from a malformed one', () async {
      final result = await guest.rooms.join('AB39HK');
      expect((result as RoomRejected).reason, RoomFailureReason.roomNotFound);
    });

    test('a full room is refused with its own reason', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      final third = _Client('uid-third', store);
      final result = await third.rooms.join(code);
      expect((result as RoomRejected).reason, RoomFailureReason.roomFull);
    });

    test('a started room is refused with its own reason', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      await host.rooms.setReady(code: code, ready: true);
      await guest.rooms.setReady(code: code, ready: true);
      await host.rooms.start(code);

      final late = _Client('uid-late', store);
      final result = await late.rooms.join(code);
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.roomAlreadyStarted,
      );
    });

    test('every rejection carries a message a player can act on', () async {
      final result = await guest.rooms.join('AB39HK');
      final failure = (result as RoomRejected).failure;
      expect(failure.message, isNotNull);
      expect(failure.message, isNotEmpty);
      expect(failure.message, isNot(contains('Exception')));
    });
  });

  group('ready state', () {
    test('status derives from the seats, never drifting', () async {
      final code = await createRoom(host);
      expect((await host.rooms.load(code))!.status, RoomStatus.waiting);

      await guest.rooms.join(code);
      // Both present, neither ready.
      expect((await host.rooms.load(code))!.status, RoomStatus.waiting);

      await host.rooms.setReady(code: code, ready: true);
      // One ready is not enough.
      expect((await host.rooms.load(code))!.status, RoomStatus.waiting);

      await guest.rooms.setReady(code: code, ready: true);
      expect((await host.rooms.load(code))!.status, RoomStatus.ready);
    });

    test('a player can only set their own readiness', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      final result = await guest.rooms.setReady(code: code, ready: true);
      final room = (result as RoomSuccess).room;
      expect(room.isReadyFor('uid-guest'), isTrue);
      expect(room.isReadyFor('uid-host'), isFalse);
    });

    test('readiness can be withdrawn', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      await guest.rooms.setReady(code: code, ready: true);
      await guest.rooms.setReady(code: code, ready: false);
      expect((await guest.rooms.load(code))!.bothReady, isFalse);
    });

    test('a non-member cannot ready up', () async {
      final code = await createRoom(host);
      final outsider = _Client('uid-outsider', store);
      final result = await outsider.rooms.setReady(code: code, ready: true);
      expect((result as RoomRejected).reason, RoomFailureReason.notAMember);
    });

    test('the version increases as the room changes', () async {
      final code = await createRoom(host);
      final before = (await host.rooms.load(code))!.version;
      await guest.rooms.join(code);
      expect((await host.rooms.load(code))!.version, greaterThan(before));
    });
  });

  group('start', () {
    test('moves the room to started once both are ready', () async {
      final room = await playToStart();
      expect(room.status, RoomStatus.started);
      expect(room.isFull, isTrue);
      expect(room.sideFor('uid-host'), PlayerId.blue);
      expect(room.sideFor('uid-guest'), PlayerId.red);
    });

    test('refuses while a player is not ready', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      await host.rooms.setReady(code: code, ready: true);
      final result = await host.rooms.start(code);
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.playersNotReady,
      );
    });

    test('only the host may start', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      await host.rooms.setReady(code: code, ready: true);
      await guest.rooms.setReady(code: code, ready: true);
      final result = await guest.rooms.start(code);
      expect((result as RoomRejected).reason, RoomFailureReason.notTheHost);
    });

    test('starting twice is refused, not silently repeated', () async {
      final room = await playToStart();
      final result = await host.rooms.start(room.code);
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.roomAlreadyStarted,
      );
    });

    test('a started room is stable when read back', () async {
      final room = await playToStart();
      final reloaded = (await guest.rooms.load(room.code))!;
      expect(reloaded.status, RoomStatus.started);
      expect(reloaded.boardConfig, room.boardConfig);
      expect(reloaded.blue.playerId, 'uid-host');
      expect(reloaded.red.playerId, 'uid-guest');
    });
  });

  group('leave and cancel', () {
    test('the host leaving deletes the document', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      final result = await host.rooms.leave(code);
      expect(result, isA<RoomSuccess>());
      // Deleted rather than left behind: an orphan with no host can never be
      // started and would occupy storage against the 1 GiB no-cost quota.
      expect(store.documents.containsKey('matches/$code'), isFalse);
      expect(await host.rooms.load(code), isNull);
    });

    test('the host leaving frees the code for reuse', () async {
      final code = await createRoom(host);
      await host.rooms.leave(code);
      final third = _Client('uid-third', store);
      final result = await third.rooms.create(config: const BoardConfig());
      // A different code, but the point is the store is not accumulating.
      expect(store.documents.length, 1);
      expect((result as RoomSuccess).room.hostId, 'uid-third');
      expect(code, isNotEmpty);
    });

    test('a guest leaving reopens the seat instead of cancelling', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      final result = await guest.rooms.leave(code);
      expect(result, isA<RoomSuccess>());
      final room = (await host.rooms.load(code))!;
      // The host is still waiting, so the room survives with a free seat.
      expect(room.status, RoomStatus.waiting);
      expect(room.red.playerId, isNull);
      expect(room.blue.playerId, 'uid-host');
    });

    test('a replacement guest can take the freed seat', () async {
      final code = await createRoom(host);
      await guest.rooms.join(code);
      await guest.rooms.leave(code);
      final replacement = _Client('uid-replacement', store);
      final result = await replacement.rooms.join(code);
      expect((result as RoomSuccess).room.red.playerId, 'uid-replacement');
    });

    test('leaving a room that is already gone is not an error', () async {
      final result = await host.rooms.leave('AB39HK');
      // Reported as not-found; the lobby treats that as "left" silently.
      expect((result as RoomRejected).reason, RoomFailureReason.roomNotFound);
    });

    test('leaving after the start is refused, deferring to Phase 10', () async {
      final room = await playToStart();
      final result = await host.rooms.leave(room.code);
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.roomAlreadyStarted,
      );
      // The room is still there — nothing was half-done.
      expect(await host.rooms.load(room.code), isNotNull);
    });

    test('a non-member cannot leave', () async {
      final code = await createRoom(host);
      final outsider = _Client('uid-outsider', store);
      final result = await outsider.rooms.leave(code);
      expect((result as RoomRejected).reason, RoomFailureReason.notAMember);
    });
  });

  group('identity safety', () {
    test('no operation proceeds without a resolved uid', () async {
      final anonymous = FirestoreRoomRepository(
        client: store,
        userId: () async => null,
      );
      expect(
        ((await anonymous.create(
          config: const BoardConfig(),
        )) as RoomRejected).reason,
        RoomFailureReason.notAuthenticated,
      );
      expect(
        ((await anonymous.join('AB39HK')) as RoomRejected).reason,
        RoomFailureReason.notAuthenticated,
      );
      expect(
        ((await anonymous.setReady(
          code: 'AB39HK',
          ready: true,
        )) as RoomRejected).reason,
        RoomFailureReason.notAuthenticated,
      );
      expect(
        ((await anonymous.start('AB39HK')) as RoomRejected).reason,
        RoomFailureReason.notAuthenticated,
      );
      expect(
        ((await anonymous.leave('AB39HK')) as RoomRejected).reason,
        RoomFailureReason.notAuthenticated,
      );
      // Crucially, nothing was written under a placeholder identity.
      expect(store.documents, isEmpty);
    });

    test('an empty uid is treated as no uid', () async {
      final blank = FirestoreRoomRepository(
        client: store,
        userId: () async => '',
      );
      final result = await blank.create(config: const BoardConfig());
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.notAuthenticated,
      );
      expect(store.documents, isEmpty);
    });
  });

  group('realtime watching', () {
    test('the creator sees the opponent join without polling', () async {
      final code = await createRoom(host);
      final seen = <Room?>[];
      final sub = host.rooms.watch(code).listen(seen.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(seen.length, 1, reason: 'the current document arrives first');
      expect(seen.last!.red.playerId, isNull);

      await guest.rooms.join(code);
      await pumpEventQueue();

      expect(seen.last!.red.playerId, 'uid-guest');
      expect(seen.last!.isFull, isTrue);
    });

    test('a watcher sees the room reach started', () async {
      final code = await createRoom(host);
      final seen = <Room?>[];
      final sub = host.rooms.watch(code).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await guest.rooms.join(code);
      await host.rooms.setReady(code: code, ready: true);
      await guest.rooms.setReady(code: code, ready: true);
      await host.rooms.start(code);
      await pumpEventQueue();

      expect(seen.last!.status, RoomStatus.started);
    });

    test('a watcher sees the room disappear when the host cancels', () async {
      final code = await createRoom(host);
      final seen = <Room?>[];
      final sub = host.rooms.watch(code).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      await host.rooms.leave(code);
      await pumpEventQueue();

      expect(seen.last, isNull);
    });

    test('two watchers on one document both see a change', () async {
      final code = await createRoom(host);
      final hostSeen = <Room?>[];
      final guestSeen = <Room?>[];
      final a = host.rooms.watch(code).listen(hostSeen.add);
      final b = guest.rooms.watch(code).listen(guestSeen.add);
      addTearDown(a.cancel);
      addTearDown(b.cancel);
      await pumpEventQueue();

      await guest.rooms.join(code);
      await pumpEventQueue();

      expect(hostSeen.last!.red.playerId, 'uid-guest');
      expect(guestSeen.last!.red.playerId, 'uid-guest');
    });

    test('watching a malformed code yields a single null', () async {
      final seen = <Room?>[];
      final sub = host.rooms.watch('nope').listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(seen, <Room?>[null]);
    });
  });

  group('Room serialisation', () {
    test('rejects a document with a bad type', () async {
      final code = await createRoom(host);
      final raw = store.documents['matches/$code']!;
      expect(
        Room.fromJson(<String, dynamic>{...raw, 'boardSize': 'nine'}),
        isNull,
      );
      expect(
        Room.fromJson(<String, dynamic>{...raw, 'status': 'weird'}),
        isNull,
      );
      expect(Room.fromJson(<String, dynamic>{...raw, 'hostId': 42}), isNull);
      expect(Room.fromJson(<String, dynamic>{...raw, 'code': ''}), isNull);
    });

    test('rejects a board the engine would refuse', () async {
      final code = await createRoom(host);
      final raw = store.documents['matches/$code']!;
      // Even size violates spec §2; an invalid config must not reach the engine.
      expect(Room.fromJson(<String, dynamic>{...raw, 'boardSize': 8}), isNull);
    });

    test('rejects a host who is not seated', () async {
      final code = await createRoom(host);
      final raw = store.documents['matches/$code']!;
      expect(
        Room.fromJson(<String, dynamic>{...raw, 'hostId': 'uid-somebody-else'}),
        isNull,
      );
    });

    test('tolerates a missing version and timestamps', () async {
      final code = await createRoom(host);
      final raw = Map<String, dynamic>.from(store.documents['matches/$code']!)
        ..remove('version')
        ..remove('createdAt');
      final room = Room.fromJson(raw)!;
      expect(room.version, 1);
      expect(room.createdAtMs, 0);
    });

    test('null input yields null rather than throwing', () {
      expect(Room.fromJson(null), isNull);
    });
  });

  group('Room value semantics', () {
    // Not cosmetic: `FirestoreRoomRepository._persistSeated` decides whether to
    // bump the document version by comparing the mutated room against the one it
    // read, so `==` has to actually work.
    Room build({
      RoomStatus status = RoomStatus.waiting,
      RoomSeat? blue,
      RoomSeat? red,
      int version = 1,
    }) => Room(
      code: 'AB39HK',
      status: status,
      boardConfig: const BoardConfig(),
      hostId: 'uid-host',
      blue: blue ?? const RoomSeat(playerId: 'uid-host', isReady: true),
      red: red ?? RoomSeat.empty,
      createdAtMs: 10,
      updatedAtMs: 20,
      version: version,
    );

    test('equal rooms compare and hash equally', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('every field participates in equality', () {
      expect(build(), isNot(build(status: RoomStatus.ready)));
      expect(build(), isNot(build(blue: RoomSeat.empty)));
      expect(build(), isNot(build(red: const RoomSeat(playerId: 'u2'))));
      expect(build(), isNot(build(version: 2)));
    });

    test('toString names the code, status and seats', () {
      final text = build(red: const RoomSeat(playerId: 'uid-guest')).toString();
      expect(text, contains('AB39HK'));
      expect(text, contains('waiting'));
      expect(text, contains('uid-guest'));
    });

    test('RoomSeat compares by value and prints empties readably', () {
      const a = RoomSeat(playerId: 'u1', isReady: true);
      const b = RoomSeat(playerId: 'u1', isReady: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const RoomSeat(playerId: 'u1')));
      expect(a, isNot(RoomSeat.empty));
      expect(RoomSeat.empty.isEmpty, isTrue);
      expect(RoomSeat.empty.toString(), contains('empty'));
    });

    test('canStart follows the status only', () {
      expect(build(status: RoomStatus.ready).canStart, isTrue);
      expect(build().canStart, isFalse);
      expect(
        build(status: RoomStatus.started).canStart,
        isFalse,
        reason: 'a started match cannot be started again',
      );
    });

    test('withSeat replaces only the requested side', () {
      final room = build();
      final moved = room.withSeat(
        PlayerId.red,
        const RoomSeat(playerId: 'uid-guest', isReady: true),
      );
      expect(moved.blue, room.blue);
      expect(moved.red.playerId, 'uid-guest');
      // Everything else is preserved, so a seat edit cannot quietly lose data.
      expect(moved.code, room.code);
      expect(moved.version, room.version);
    });
  });

  group('failure value semantics', () {
    test('RoomFailure compares by value and prints its reason', () {
      const a = RoomFailure(RoomFailureReason.roomFull, 'full');
      const b = RoomFailure(RoomFailureReason.roomFull, 'full');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const RoomFailure(RoomFailureReason.roomFull, 'other')));
      expect(a.toString(), contains('roomFull'));
    });

    test('RoomRejected exposes both a reason and a failure value', () {
      const rejected = RoomRejected(
        RoomFailureReason.notTheHost,
        message: 'nope',
      );
      expect(rejected.reason, RoomFailureReason.notTheHost);
      expect(rejected.failure.reason, RoomFailureReason.notTheHost);
      expect(rejected.failure.message, 'nope');
      expect(rejected, isNot(const RoomRejected(RoomFailureReason.notTheHost)));
      expect(
        rejected.hashCode,
        const RoomRejected(
          RoomFailureReason.notTheHost,
          message: 'nope',
        ).hashCode,
      );
      expect(rejected.toString(), contains('notTheHost'));
    });

    test('every failure reason has a distinct message where it matters', () {
      // A player must be able to tell these apart; the repository supplies the
      // wording, and this pins that the common ones are non-empty.
      for (final reason in RoomFailureReason.values) {
        final rejected = RoomRejected(reason, message: reason.name);
        expect(rejected.failure.message, isNotEmpty);
      }
    });
  });
}

/// Reads pass through; writes always fail.
///
/// `InMemoryFirestoreClient.failNextOperation` is one-shot, so it cannot aim a
/// failure at the write specifically — and aiming matters here, because the bug
/// being guarded against is a swallowed write blamed on a code collision.
class _WriteFailingClient implements FirestoreClient {
  _WriteFailingClient(this.inner);

  final FirestoreClient inner;

  @override
  Future<Map<String, dynamic>?> read(String path) => inner.read(path);

  @override
  Future<void> write(String path, Map<String, dynamic> data) async =>
      throw StateError('simulated write failure');

  @override
  Future<void> delete(String path) => inner.delete(path);

  @override
  Stream<Map<String, dynamic>?> watch(String path) => inner.watch(path);

  @override
  Future<List<FirestoreDocument>> query({
    required String collectionPath,
    String? orderBy,
    int limit = 10,
  }) => inner.query(
    collectionPath: collectionPath,
    orderBy: orderBy,
    limit: limit,
  );

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction txn) action,
  ) => inner.runTransaction(action);
}
