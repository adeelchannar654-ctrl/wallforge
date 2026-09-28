import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

class _Client {
  _Client(this.uid, this.store)
    : rooms = FirestoreRoomRepository(
        client: store,
        userId: () async => uid,
        clock: () => DateTime.utc(2026, 9, 28, 9),
      ),
      matches = FirestoreMatchRepository(
        client: store,
        userId: () async => uid,
        clock: () => DateTime.utc(2026, 9, 28, 9, 0, 30),
      );

  final String uid;
  final InMemoryFirestoreClient store;
  final FirestoreRoomRepository rooms;
  final FirestoreMatchRepository matches;
}

void main() {
  late InMemoryFirestoreClient store;
  late _Client host;
  late _Client guest;
  late String code;

  setUp(() async {
    store = InMemoryFirestoreClient();
    host = _Client('uid-host', store);
    guest = _Client('uid-guest', store);
    final created = await host.rooms.create(config: const BoardConfig());
    code = (created as RoomSuccess).room.code;
    await guest.rooms.join(code);
    await host.rooms.setReady(code: code, ready: true);
    await guest.rooms.setReady(code: code, ready: true);
    await host.rooms.start(code);
  });

  tearDown(() => store.closeWatchers());

  Future<Room> room() async {
    final doc = await host.matches.loadMatch(code: code);
    return Room.fromJson(doc!.fields)!;
  }

  /// Plays legal moves alternately until the engine ends the game.
  ///
  /// The move choice is arbitrary; only the *legality* of every submission and
  /// the final state matter here.
  Future<void> playToCompletion() async {
    for (var turn = 0; turn < 400; turn++) {
      final current = await room();
      if (current.boardState!.status == GameStatus.finished) return;

      final state = current.boardState!;
      final mover = state.currentPlayer == PlayerId.blue ? host : guest;
      final targets = GameEngine.legalActions(state)
          .whereType<MoveAction>()
          .map((a) => a.destination)
          .toList();
      expect(
        targets,
        isNotEmpty,
        reason: 'the engine must offer a move on turn $turn',
      );

      final result = await mover.matches.submitAction(
        code: code,
        expectedTurnNumber: turn,
        action: GameAction.move(targets.first),
      );
      expect(
        result,
        isA<MoveApplied>(),
        reason: 'turn $turn was legal but was refused: $result',
      );
    }
    fail('the game did not finish within 400 plies');
  }

  group('a finished match is a record, not a lobby', () {
    test('the host cannot delete it by leaving', () async {
      await playToCompletion();

      final result = await host.rooms.leave(code);

      expect(result, isA<RoomRejected>());
      expect(
        (result as RoomRejected).reason,
        RoomFailureReason.roomAlreadyStarted,
      );
      expect(
        await host.rooms.load(code),
        isNotNull,
        reason: 'a completed game must survive the player leaving',
      );
    });

    test('the host seat is not reopened to a third player', () async {
      await playToCompletion();
      await host.rooms.leave(code);

      final stranger = _Client('uid-stranger', store);
      final join = await stranger.rooms.join(code);

      expect(join, isA<RoomRejected>());
      expect(
        (join as RoomRejected).reason,
        RoomFailureReason.roomAlreadyStarted,
      );
      final reloaded = await room();
      expect(reloaded.blue.playerId, 'uid-host');
      expect(reloaded.winnerId, isNotNull);
    });

    test('leaving still works before the start', () async {
      final created = await host.rooms.create(config: const BoardConfig());
      final waiting = (created as RoomSuccess).room.code;
      await guest.rooms.join(waiting);

      final result = await host.rooms.leave(waiting);

      expect(result, isA<RoomSuccess>());
      expect(await host.rooms.load(waiting), isNull);
    });
  });

  group('completion clears the turn pointer', () {
    test('currentPlayerId is null once the game is over', () async {
      await playToCompletion();

      final finished = await room();

      expect(finished.status, RoomStatus.finished);
      expect(
        finished.currentPlayerId,
        isNull,
        reason:
            'a nullable copyWith parameter silently kept the last mover, so '
            'the finished document still named a player to act',
      );
      expect(finished.winnerId, isNotNull);
    });

    test('copyWith still keeps a value it was not asked to change', () {
      const room = Room(
        code: 'ABC123',
        status: RoomStatus.started,
        boardConfig: BoardConfig(),
        hostId: 'host',
        blue: RoomSeat(playerId: 'host'),
        red: RoomSeat(playerId: 'guest'),
        createdAtMs: 0,
        updatedAtMs: 0,
        currentPlayerId: 'guest',
      );

      expect(room.copyWith(version: 4).currentPlayerId, 'guest');
      expect(room.copyWith(currentPlayerId: null).currentPlayerId, isNull);
    });
  });
}
