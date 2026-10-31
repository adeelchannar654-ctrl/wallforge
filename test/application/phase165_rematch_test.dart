import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/online/rematch_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_matchmaking_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part D: the completed rematch — same settings,
/// swapped sides — in every mode.
void main() {
  group('local / vs-AI rematch', () {
    LocalGameController controller({
      InMemoryStatisticsRepository? stats,
      InMemoryUnfinishedMatchRepository? unfinished,
    }) {
      final c = LocalGameController();
      addTearDown(c.dispose);
      c.attachPersistence(
        settings: InMemorySettingsRepository(),
        statistics: stats ?? InMemoryStatisticsRepository(),
        unfinishedMatch: unfinished ?? InMemoryUnfinishedMatchRepository(),
      );
      return c;
    }

    Future<void> untilTurn(LocalGameController c, int turn) async {
      final watch = Stopwatch()..start();
      while (c.state.turnNumber != turn &&
          watch.elapsed < const Duration(seconds: 20)) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      expect(c.state.turnNumber, turn);
    }

    test('vs-AI: a rematch swaps the human to Red and the AI opens', () async {
      final c = controller();
      c.startMatch(versusAi: true, aiDifficulty: AiDifficulty.hard);
      expect(c.humanSide, PlayerId.blue);
      expect(c.aiSide, PlayerId.red);
      c.resign(PlayerId.blue); // finish the first game
      expect(c.isFinished, isTrue);

      c.rematch();
      expect(c.humanSide, PlayerId.red);
      expect(c.aiSide, PlayerId.blue);
      expect(c.aiDifficulty, AiDifficulty.hard);
      // Blue moves first (R-PLAYER-07) — and Blue is now the AI.
      expect(c.isAiTurn, isTrue);
      await untilTurn(c, 1);
      expect(c.state.currentPlayer, PlayerId.red); // the human

      // A second rematch swaps back.
      c.resign(PlayerId.red);
      c.rematch();
      expect(c.humanSide, PlayerId.blue);
      expect(c.aiSide, PlayerId.red);
      expect(c.isAiTurn, isFalse);
    });

    test('restart keeps the sides; only a rematch swaps', () {
      final c = controller();
      c.startMatch(versusAi: true);
      c.resign(PlayerId.blue);
      c.rematch();
      expect(c.humanSide, PlayerId.red);
      c.restart();
      expect(c.humanSide, PlayerId.red);
      expect(c.aiSide, PlayerId.blue);
    });

    test('a rematch carries board, difficulty and clock', () {
      final c = controller();
      c.startMatch(
        config: const BoardConfig(size: 7, wallsPerPlayer: 5),
        versusAi: true,
        aiDifficulty: AiDifficulty.expert,
        timeControlSeconds: 30,
      );
      c.resign(PlayerId.blue);
      c.rematch();
      expect(c.state.boardConfig.size, 7);
      expect(c.state.boardConfig.wallsPerPlayer, 5);
      expect(c.aiDifficulty, AiDifficulty.expert);
      expect(c.timeControlSeconds, 30);
    });

    test('pass-and-play: a rematch restarts with the same settings', () {
      final c = controller();
      c.startMatch(
        config: const BoardConfig(size: 11, wallsPerPlayer: 12),
        timeControlSeconds: 15,
      );
      c.tapCell(const Cell(row: 9, column: 5)); // Blue moves on 11x11.
      c.resign(PlayerId.red);
      c.rematch();
      expect(c.state.turnNumber, 0);
      expect(c.state.boardConfig.size, 11);
      expect(c.timeControlSeconds, 15);
      expect(c.isFinished, isFalse);
    });

    test('statistics follow the human across the swap', () async {
      final stats = InMemoryStatisticsRepository();
      final c = controller(stats: stats);
      c.startMatch(versusAi: true);
      c.resign(PlayerId.blue);
      c.rematch(); // human is Red now
      c.resign(PlayerId.blue); // the AI (Blue) concedes: human wins
      await pumpEventQueue();
      final recorded = await stats.load();
      expect(recorded.matchesPlayed, 2);
      expect(recorded.humanWins, 1);
    });

    test('a rematch in progress resumes with its swapped sides', () async {
      final unfinished = InMemoryUnfinishedMatchRepository();
      final first = controller(unfinished: unfinished);
      first.startMatch(versusAi: true);
      first.resign(PlayerId.blue);
      first.rematch(); // human Red; AI (Blue) opens
      await untilTurn(first, 1);
      await pumpEventQueue();
      final saved = await unfinished.load();
      expect(saved, isNotNull);
      expect(saved!.humanSide, PlayerId.red);

      final second = controller(unfinished: unfinished);
      expect(second.resumeMatch(saved), isTrue);
      expect(second.humanSide, PlayerId.red);
      expect(second.aiSide, PlayerId.blue);
      expect(second.isAiTurn, isFalse); // Red to move: the human
      // The AI must not touch the human's pawn while it waits.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(second.state.turnNumber, 1);
    });
  });

  group('online rematch', () {
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

    FirestoreMatchmakingRepository matchmakingFor(String uid) =>
        FirestoreMatchmakingRepository(
          client: store,
          userId: () async => uid,
          clock: () => now,
        );

    /// Plays a clocked code-room match to a resign finish and
    /// returns its code. Host is Blue, guest Red, 30 s clock.
    Future<String> finishedMatch() async {
      final created = await roomsFor('uid-host')
          .create(config: const BoardConfig(), timeControlSeconds: 30);
      final code = (created as RoomSuccess).room.code;
      await roomsFor('uid-guest').join(code);
      await roomsFor('uid-host').setReady(code: code, ready: true);
      await roomsFor('uid-guest').setReady(code: code, ready: true);
      await roomsFor('uid-host').start(code);
      final result = await matchesFor('uid-host').resign(code: code);
      expect(result, isA<ResignSuccess>());
      return code;
    }

    setUp(() {
      now = DateTime.utc(2026, 10, 31, 12);
      store = InMemoryFirestoreClient(clock: () => now);
    });

    tearDown(() => store.closeWatchers());

    test(
      'claimPlayer with swap seats the claimer in Blue and links the room',
      () async {
        final finishedCode = await finishedMatch();
        await matchmakingFor('uid-host').joinQueue(config: const BoardConfig());
        final result = await matchmakingFor('uid-guest').claimPlayer(
          config: const BoardConfig(),
          candidateUid: 'uid-host',
          timeControlSeconds: 30,
          swapSeats: true,
          rematchOfCode: finishedCode,
        );
        final room = (result as MatchFound).room;
        // The finished match's Red (guest) now plays Blue and
        // hosts; the finished Blue (host) takes Red.
        expect(room.blue.playerId, 'uid-guest');
        expect(room.red.playerId, 'uid-host');
        expect(room.hostId, 'uid-guest');
        expect(room.timeControlSeconds, 30);
        expect(room.rematchOf, finishedCode);
        expect(room.code, isNot(finishedCode));
      },
    );

    test(
      'both controllers complete the flow into the same swapped room',
      () async {
        final finishedCode = await finishedMatch();
        final hostRematch = RematchController(
          matchmaking: matchmakingFor('uid-host'),
          rooms: roomsFor('uid-host'),
          myUid: 'uid-host',
          opponentUid: 'uid-guest',
          config: const BoardConfig(),
          finishedCode: finishedCode,
          finishedCreatedAtMs: now.millisecondsSinceEpoch,
          finishedTimeControlSeconds: 30,
          pollInterval: const Duration(milliseconds: 30),
        );
        final guestRematch = RematchController(
          matchmaking: matchmakingFor('uid-guest'),
          rooms: roomsFor('uid-guest'),
          myUid: 'uid-guest',
          opponentUid: 'uid-host',
          config: const BoardConfig(),
          finishedCode: finishedCode,
          finishedCreatedAtMs: now.millisecondsSinceEpoch,
          finishedTimeControlSeconds: 30,
          pollInterval: const Duration(milliseconds: 30),
        );
        addTearDown(hostRematch.dispose);
        addTearDown(guestRematch.dispose);
        hostRematch.start();
        guestRematch.start();

        await hostRematch.propose();
        // The guest notices the proposal on its poll.
        final watch = Stopwatch()..start();
        while (guestRematch.phase != RematchPhase.proposalAvailable &&
            watch.elapsed < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(guestRematch.phase, RematchPhase.proposalAvailable);

        // The rematch room is created after the finished match.
        now = now.add(const Duration(seconds: 1));
        await guestRematch.accept();
        expect(guestRematch.phase, RematchPhase.matched);
        final room = guestRematch.matchedRoom!;
        expect(room.blue.playerId, 'uid-guest');
        expect(room.red.playerId, 'uid-host');
        expect(room.rematchOf, finishedCode);
        expect(room.timeControlSeconds, 30);

        // The proposer's watcher delivers the same room.
        final watch2 = Stopwatch()..start();
        while (hostRematch.phase != RematchPhase.matched &&
            watch2.elapsed < const Duration(seconds: 10)) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        expect(hostRematch.phase, RematchPhase.matched);
        expect(hostRematch.matchedRoom!.code, room.code);
      },
    );

    test('declining creates nothing and the proposal can lapse', () async {
      await finishedMatch();
      await matchmakingFor('uid-host').joinQueue(config: const BoardConfig());
      var waiting = await matchmakingFor('uid-guest')
          .waitingPlayerIds(config: const BoardConfig());
      expect(waiting, contains('uid-host'));
      // Decline = never claiming. After the 60 s staleness
      // window the entry is reaped from the waiting list…
      now = now.add(const Duration(seconds: 61));
      waiting = await matchmakingFor('uid-guest')
          .waitingPlayerIds(config: const BoardConfig());
      expect(waiting, isNot(contains('uid-host')));
      // …and a late accept is refused outright.
      final late = await matchmakingFor('uid-guest').claimPlayer(
        config: const BoardConfig(),
        candidateUid: 'uid-host',
        swapSeats: true,
      );
      expect(late, isA<MatchRejected>());
    });

    test('a double accept reports the same room, never a second', () async {
      final finishedCode = await finishedMatch();
      await matchmakingFor('uid-host').joinQueue(config: const BoardConfig());
      final guest = matchmakingFor('uid-guest');
      final first = await guest.claimPlayer(
        config: const BoardConfig(),
        candidateUid: 'uid-host',
        timeControlSeconds: 30,
        swapSeats: true,
        rematchOfCode: finishedCode,
      );
      final second = await guest.claimPlayer(
        config: const BoardConfig(),
        candidateUid: 'uid-host',
        timeControlSeconds: 30,
        swapSeats: true,
        rematchOfCode: finishedCode,
      );
      expect(first, isA<MatchFound>());
      expect(second, isA<MatchFound>());
      expect((second as MatchFound).room.code, (first as MatchFound).room.code);
    });

    test('a rematch after a timeout finish carries the clock too', () async {
      // Build a clocked match and finish it by timeout instead.
      final created = await roomsFor('uid-host')
          .create(config: const BoardConfig(), timeControlSeconds: 15);
      final code = (created as RoomSuccess).room.code;
      await roomsFor('uid-guest').join(code);
      await roomsFor('uid-host').setReady(code: code, ready: true);
      await roomsFor('uid-guest').setReady(code: code, ready: true);
      await roomsFor('uid-host').start(code);
      now = now.add(const Duration(seconds: 20));
      final claim = await matchesFor('uid-guest').claimTimeout(code: code);
      expect(claim, isA<TimeoutClaimed>());

      await matchmakingFor('uid-host').joinQueue(config: const BoardConfig());
      final result = await matchmakingFor('uid-guest').claimPlayer(
        config: const BoardConfig(),
        candidateUid: 'uid-host',
        timeControlSeconds: 15,
        swapSeats: true,
        rematchOfCode: code,
      );
      final room = (result as MatchFound).room;
      expect(room.rematchOf, code);
      expect(room.timeControlSeconds, 15);
      expect(room.blue.playerId, 'uid-guest');
    });
  });
}
