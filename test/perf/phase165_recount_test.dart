import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/leaderboard_submitter.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/data/remote/firestore_leaderboard_repository.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_matchmaking_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

import 'phase15_perf_test.dart' show CountingFirestoreClient;

/// Phase 16.5, Part I: the Firestore recount, measured through
/// the real repositories over the Phase 15 counting client.
///
/// The claims under test:
/// * the clock adds ZERO operations per move (a clocked
///   move's transaction is identical to an unclocked one's —
///   the deadline rides in the same write);
/// * resign and the timeout claim are one transaction each;
/// * a leaderboard entry update is one transaction (one get,
///   one set) — plus the one rules-side get() of the match,
///   which no client can meter and the report counts by hand;
/// * a leaderboard view is two queries + one read;
/// * exactly one match listener per connected client.
void main() {
  late InMemoryFirestoreClient inner;
  late CountingFirestoreClient counting;
  late DateTime now;

  FirestoreRoomRepository roomsFor(String uid) => FirestoreRoomRepository(
    client: counting,
    userId: () async => uid,
    clock: () => now,
  );

  FirestoreMatchRepository matchesFor(String uid) => FirestoreMatchRepository(
    client: counting,
    userId: () async => uid,
    clock: () => now,
  );

  setUp(() {
    now = DateTime.utc(2026, 10, 28, 12);
    inner = InMemoryFirestoreClient(clock: () => now);
    counting = CountingFirestoreClient(inner);
  });

  tearDown(() => inner.closeWatchers());

  Future<String> startedRoom({int timeControlSeconds = 0}) async {
    final created = await roomsFor('uid-host').create(
      config: const BoardConfig(),
      timeControlSeconds: timeControlSeconds,
    );
    final code = (created as RoomSuccess).room.code;
    await roomsFor('uid-guest').join(code);
    await roomsFor('uid-host').setReady(code: code, ready: true);
    await roomsFor('uid-guest').setReady(code: code, ready: true);
    await roomsFor('uid-host').start(code);
    return code;
  }

  Future<void> playPly(String code, int turn) {
    final blue = turn.isEven;
    final forward = (turn ~/ 2).isEven;
    final action = blue
        ? GameAction.move(
            forward
                ? const Cell(row: 7, column: 4)
                : const Cell(row: 8, column: 4),
          )
        : GameAction.move(
            forward
                ? const Cell(row: 1, column: 4)
                : const Cell(row: 0, column: 4),
          );
    return matchesFor(blue ? 'uid-host' : 'uid-guest')
        .submitAction(code: code, expectedTurnNumber: turn, action: action)
        .then((r) => expect(r, isA<MoveApplied>(), reason: 'ply $turn'));
  }

  test('a clocked move costs exactly what an unclocked move costs', () async {
    final plain = await startedRoom();
    counting.reset();
    await playPly(plain, 0);
    final unclocked = (
      txns: counting.transactions,
      gets: counting.txnGets,
      sets: counting.txnSets,
      reads: counting.plainReads,
      writes: counting.plainWrites,
    );

    final clocked = await startedRoom(timeControlSeconds: 60);
    counting.reset();
    await playPly(clocked, 0);
    expect(counting.transactions, unclocked.txns);
    expect(counting.txnGets, unclocked.gets);
    expect(counting.txnSets, unclocked.sets);
    expect(counting.plainReads, unclocked.reads);
    expect(counting.plainWrites, unclocked.writes);
    // And the Phase 15 shape itself is unchanged: 1/1/2.
    expect(counting.transactions, 1);
    expect(counting.txnGets, 1);
    expect(counting.txnSets, 2);
  });

  test('resign and the timeout claim are one transaction each', () async {
    final code = await startedRoom(timeControlSeconds: 60);
    counting.reset();
    now = now.add(const Duration(seconds: 63));
    final claim = await matchesFor('uid-guest').claimTimeout(code: code);
    expect(claim, isA<TimeoutClaimed>());
    expect(counting.transactions, 1);
    expect(counting.txnGets, 1);
    expect(counting.txnSets, 1);

    final code2 = await startedRoom();
    counting.reset();
    final resign = await matchesFor('uid-host').resign(code: code2);
    expect(resign, isA<ResignSuccess>());
    expect(counting.transactions, 1);
    expect(counting.txnGets, 1);
    expect(counting.txnSets, 1);
  });

  test('a rematch claim is one transaction: three sets, two deletes', () async {
    // Finish a match first so the pairing is a rematch.
    final finished = await startedRoom();
    await matchesFor('uid-host').resign(code: finished);
    final mmHost = FirestoreMatchmakingRepository(
      client: counting,
      userId: () async => 'uid-host',
      clock: () => now,
    );
    final mmGuest = FirestoreMatchmakingRepository(
      client: counting,
      userId: () async => 'uid-guest',
      clock: () => now,
    );
    await mmHost.joinQueue(config: const BoardConfig());
    counting.reset();
    final result = await mmGuest.claimPlayer(
      config: const BoardConfig(),
      candidateUid: 'uid-host',
      timeControlSeconds: 30,
      swapSeats: true,
      rematchOfCode: finished,
    );
    expect(result, isA<MatchFound>());
    // The claim transaction: the room + two matched documents
    // are set, three queue/matched gets are read, both queue
    // entries are deleted.
    expect(counting.transactions, 1);
    expect(counting.txnSets, 3);
    expect(counting.txnDeletes, 2);
  });

  test('leaderboard: one transaction per counted match, 2 queries '
      '+ 1 read per view', () async {
    final code = await startedRoom();
    for (var turn = 0; turn < 12; turn++) {
      await playPly(code, turn);
    }
    await matchesFor('uid-host').resign(code: code);
    final room = await roomsFor('uid-host').load(code);
    final submitter = LeaderboardSubmitter(
      repository: FirestoreLeaderboardRepository(
        client: counting,
        userId: () async => 'uid-guest',
        clock: () => now,
      ),
      names: InMemoryLeaderboardNameRepository(),
      myUid: 'uid-guest',
    );
    counting.reset();
    await submitter.submit(room!);
    expect(counting.transactions, 1);
    expect(counting.txnGets, 1);
    expect(counting.txnSets, 1);
    expect(counting.plainReads, 0);
    expect(counting.plainWrites, 0);

    // A board view through the controller's repository calls:
    // fetchTop(current) + fetchEntry + fetchTop(last week).
    final repo = FirestoreLeaderboardRepository(
      client: counting,
      userId: () async => 'uid-guest',
      clock: () => now,
    );
    final week = weekStartMs(now.millisecondsSinceEpoch);
    counting.reset();
    final top = await repo.fetchTop(week);
    await repo.fetchEntry(week, 'uid-guest');
    await repo.fetchTop(week - kWeekMs, limit: 3);
    expect(top, hasLength(1));
    expect(counting.queries, 2);
    expect(counting.plainReads, 1);
    // Documents delivered: 1 (this week) + 1 (own entry) + 0
    // (last week) = 2 billed reads for this view; the worst
    // case is 50 + 1 + 3 = 54.
  });
}
