import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/leaderboard_submitter.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/data/remote/firestore_leaderboard_repository.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part H: a finished online match lands on the
/// weekly board for both players — from the game controller's
/// terminal snapshot — while a short match and an abandonment
/// never do.
void main() {
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

  LeaderboardSubmitter submitterFor(String uid) => LeaderboardSubmitter(
    repository: FirestoreLeaderboardRepository(
      client: store,
      userId: () async => uid,
      clock: () => now,
    ),
    names: InMemoryLeaderboardNameRepository(),
    myUid: uid,
  );

  setUp(() {
    now = DateTime.utc(2026, 10, 28, 12); // a Wednesday
    store = InMemoryFirestoreClient(clock: () => now);
  });

  tearDown(() => store.closeWatchers());

  Future<({OnlineGameController host, OnlineGameController guest, String code})>
  startedMatch() async {
    final created = await roomsFor('uid-host')
        .create(config: const BoardConfig());
    final code = (created as RoomSuccess).room.code;
    await roomsFor('uid-guest').join(code);
    await roomsFor('uid-host').setReady(code: code, ready: true);
    await roomsFor('uid-guest').setReady(code: code, ready: true);
    await roomsFor('uid-host').start(code);
    final host = OnlineGameController(
      rooms: roomsFor('uid-host'),
      matches: matchesFor('uid-host'),
      uid: 'uid-host',
      code: code,
      clock: () => now,
      leaderboardSubmitter: submitterFor('uid-host'),
    );
    final guest = OnlineGameController(
      rooms: roomsFor('uid-guest'),
      matches: matchesFor('uid-guest'),
      uid: 'uid-guest',
      code: code,
      clock: () => now,
      leaderboardSubmitter: submitterFor('uid-guest'),
    );
    await host.connect();
    await guest.connect();
    await pumpEventQueue();
    return (host: host, guest: guest, code: code);
  }

  /// Plays alternating pawn moves straight ahead — legal,
  /// harmless, and enough plies for the board's minimum.
  Future<void> playPlies(String code, int plies) async {
    // Pawns shuttle one step forward/back so nobody reaches a
    // goal: Blue (8,4)<->(7,4), Red (0,4)<->(1,4) on 9x9.
    for (var turn = 0; turn < plies; turn++) {
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
      final result = await matchesFor(blue ? 'uid-host' : 'uid-guest')
          .submitAction(code: code, expectedTurnNumber: turn, action: action);
      expect(result, isA<MoveApplied>(), reason: 'ply $turn');
    }
    await pumpEventQueue();
  }

  Future<List<LeaderboardEntry>> board() => FirestoreLeaderboardRepository(
    client: store,
    userId: () async => 'uid-host',
    clock: () => now,
  ).fetchTop(weekStartMs(now.millisecondsSinceEpoch));

  test('a 12-ply resign finish puts both players on the board', () async {
    final m = await startedMatch();
    addTearDown(m.host.dispose);
    addTearDown(m.guest.dispose);
    await playPlies(m.code, 12);
    await m.host.resign();
    await pumpEventQueue();

    final entries = await board();
    expect(entries, hasLength(2));
    final host = entries.firstWhere((e) => e.uid == 'uid-host');
    final guest = entries.firstWhere((e) => e.uid == 'uid-guest');
    expect(guest.points, 3); // guest won by the resign
    expect(guest.wins, 1);
    expect(host.points, 1);
    expect(host.losses, 1);
    expect(guest.countedMatches, {m.code: 'uid-host'});
    expect(host.countedMatches, {m.code: 'uid-guest'});
  });

  test('a short match and an abandonment never reach the board', () async {
    final m = await startedMatch();
    addTearDown(m.host.dispose);
    addTearDown(m.guest.dispose);
    await playPlies(m.code, 4);
    await m.host.resign();
    await pumpEventQueue();
    expect(await board(), isEmpty);

    // A fresh match, abandoned this time.
    final m2 = await startedMatch();
    addTearDown(m2.host.dispose);
    addTearDown(m2.guest.dispose);
    now = now.add(const Duration(seconds: 121));
    final claim = await matchesFor('uid-guest').claimAbandonment(code: m2.code);
    expect(claim, isA<AbandonmentClaimed>());
    await pumpEventQueue();
    expect(await board(), isEmpty);
  });
}
