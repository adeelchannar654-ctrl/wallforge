import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part B: resign in every mode, one finish-reason
/// set, and the repository guards the rules mirror.
void main() {
  group('LocalGameController resign', () {
    test('pass-and-play: the side to move resigns, the other wins', () async {
      final stats = InMemoryStatisticsRepository();
      final unfinished = InMemoryUnfinishedMatchRepository();
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.attachPersistence(
        settings: InMemorySettingsRepository(),
        statistics: stats,
        unfinishedMatch: unfinished,
      );
      controller.startMatch();
      controller.tapCell(const Cell(row: 7, column: 4)); // Blue moves.
      expect(controller.state.turnNumber, 1);

      controller.resign(PlayerId.red); // Red to move resigns.
      expect(controller.isFinished, isTrue);
      expect(controller.showingResult, isTrue);
      expect(controller.winner, PlayerId.blue);
      expect(controller.finishReason, FinishReason.resign);
      // The engine state is untouched: resigning is not a move.
      expect(controller.state.status, GameStatus.inProgress);
      expect(controller.state.turnNumber, 1);

      await pumpEventQueue();
      final recorded = await stats.load();
      expect(recorded.matchesPlayed, 1);
      expect(recorded.humanWins, 1); // local stats key on Blue.
      expect(await unfinished.load(), isNull);
    });

    test('resign after the finish is a no-op (finish recorded once)', () async {
      final stats = InMemoryStatisticsRepository();
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.attachPersistence(
        settings: InMemorySettingsRepository(),
        statistics: stats,
        unfinishedMatch: InMemoryUnfinishedMatchRepository(),
      );
      controller.startMatch();
      controller.resign(PlayerId.blue);
      controller.resign(PlayerId.red);
      await pumpEventQueue();
      expect(controller.winner, PlayerId.red);
      expect((await stats.load()).matchesPlayed, 1);
    });

    test('no action is accepted after a resign', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.startMatch();
      controller.resign(PlayerId.blue);
      expect(
        controller.attemptAction(
          const GameAction.move(Cell(row: 7, column: 4)),
        ),
        ActionFailure.matchFinished,
      );
    });

    test('vs-AI: resigning during the AI think cancels its move', () async {
      final controller = LocalGameController(versusAi: true);
      addTearDown(controller.dispose);
      controller.startMatch(versusAi: true);
      controller.tapCell(const Cell(row: 7, column: 4)); // Human (Blue).
      expect(controller.state.turnNumber, 1); // AI is thinking now.
      controller.resign(PlayerId.blue);
      expect(controller.winner, PlayerId.red);
      // The AI think delay is 300 ms; well past it, nothing moved.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.state.turnNumber, 1);
    });
  });

  group('online resign (two client stacks, one store)', () {
    late InMemoryFirestoreClient store;
    late FirestoreRoomRepository hostRooms;
    late FirestoreRoomRepository guestRooms;
    late FirestoreMatchRepository hostMatches;
    late FirestoreMatchRepository guestMatches;
    late OnlineGameController hostView;
    late OnlineGameController guestView;
    late String code;

    setUp(() async {
      store = InMemoryFirestoreClient();
      DateTime fixed() => DateTime.utc(2026, 10, 31, 12);
      hostRooms = FirestoreRoomRepository(
        client: store,
        userId: () async => 'uid-host',
        clock: fixed,
      );
      guestRooms = FirestoreRoomRepository(
        client: store,
        userId: () async => 'uid-guest',
        clock: fixed,
      );
      hostMatches = FirestoreMatchRepository(
        client: store,
        userId: () async => 'uid-host',
        clock: fixed,
      );
      guestMatches = FirestoreMatchRepository(
        client: store,
        userId: () async => 'uid-guest',
        clock: fixed,
      );
      final created = await hostRooms.create(config: const BoardConfig());
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
      );
      guestView = OnlineGameController(
        rooms: guestRooms,
        matches: guestMatches,
        uid: 'uid-guest',
        code: code,
      );
      await hostView.connect();
      await guestView.connect();
      await pumpEventQueue();
    });

    tearDown(() {
      hostView.dispose();
      guestView.dispose();
    });

    test('host (Blue) resigns: both clients finish, Red wins', () async {
      await hostView.resign();
      await pumpEventQueue();
      for (final view in [hostView, guestView]) {
        expect(view.isFinished, isTrue);
        expect(view.winner, PlayerId.red);
        expect(view.finishReason, FinishReason.resign);
        // The board snapshot stays in progress — by design.
        expect(view.state.status, GameStatus.inProgress);
      }
      expect(hostView.resignedByMe, isTrue);
      expect(guestView.resignedByMe, isFalse);
    });

    test('a second resign after the finish is refused', () async {
      await hostView.resign();
      await pumpEventQueue();
      final again = await guestMatches.resign(code: code);
      expect(again, isA<ResignRejected>());
      expect(
        (again as ResignRejected).reason,
        ResignFailureReason.matchAlreadyOver,
      );
      // The winner is unchanged.
      final doc = await guestMatches.loadMatch(code: code);
      final room = Room.fromJson(doc!.fields);
      expect(room!.winnerId, 'uid-guest');
      expect(room.finishReason, FinishReason.resign);
    });

    test('a non-member cannot resign', () async {
      final stranger = FirestoreMatchRepository(
        client: store,
        userId: () async => 'uid-stranger',
        clock: () => DateTime.utc(2026, 10, 31, 12),
      );
      final result = await stranger.resign(code: code);
      expect(result, isA<ResignRejected>());
      expect((result as ResignRejected).reason, ResignFailureReason.notAMember);
    });

    test('resign before the start is refused', () async {
      // A separate store: the shared one already holds a started
      // match for this host (and the one-open-room guard would
      // refuse a second room).
      final store2 = InMemoryFirestoreClient();
      DateTime fixed() => DateTime.utc(2026, 10, 31, 12);
      final rooms2 = FirestoreRoomRepository(
        client: store2,
        userId: () async => 'uid-host',
        clock: fixed,
      );
      final matches2 = FirestoreMatchRepository(
        client: store2,
        userId: () async => 'uid-host',
        clock: fixed,
      );
      final created = await rooms2.create(config: const BoardConfig());
      final waitingCode = (created as RoomSuccess).room.code;
      final result = await matches2.resign(code: waitingCode);
      expect(result, isA<ResignRejected>());
      expect(
        (result as ResignRejected).reason,
        ResignFailureReason.matchNotStarted,
      );
    });
  });
}
