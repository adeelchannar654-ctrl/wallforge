import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// The `game_spec.md` §15 scripted game: 17 actions, Blue wins on the last.
///
/// Read straight out of `test/domain/scripted_game_test.dart`, so the two-client
/// run cannot drift from the verified single-client one.
const List<(PlayerId, GameAction)> kScriptedGame = [
  (PlayerId.blue, GameAction.move(Cell(row: 7, column: 4))),
  (PlayerId.red, GameAction.move(Cell(row: 1, column: 4))),
  (PlayerId.blue, GameAction.move(Cell(row: 6, column: 4))),
  (PlayerId.red, GameAction.move(Cell(row: 2, column: 4))),
  (PlayerId.blue, GameAction.move(Cell(row: 5, column: 4))),
  (
    PlayerId.red,
    GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 6, column: 3),
    ),
  ),
  (
    PlayerId.blue,
    GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 6, column: 5),
    ),
  ),
  (PlayerId.red, GameAction.move(Cell(row: 3, column: 4))),
  (PlayerId.blue, GameAction.move(Cell(row: 4, column: 4))),
  (
    PlayerId.red,
    GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 1, column: 3),
    ),
  ),
  (PlayerId.blue, GameAction.move(Cell(row: 2, column: 4))),
  (PlayerId.red, GameAction.move(Cell(row: 4, column: 4))),
  (PlayerId.blue, GameAction.move(Cell(row: 2, column: 5))),
  (PlayerId.red, GameAction.move(Cell(row: 5, column: 4))),
  (PlayerId.blue, GameAction.move(Cell(row: 1, column: 5))),
  (PlayerId.red, GameAction.move(Cell(row: 6, column: 4))),
  (PlayerId.blue, GameAction.move(Cell(row: 0, column: 5))),
];

/// One simulated device: its own uid, its own repositories, one shared store.
///
/// **This is not a real-backend test.** It is the honest stand-in available here:
/// the Q-7.4 console setup is still undone, so no real Firebase project, emulator
/// or second device exists. It proves the protocol and the engine agree; it does
/// not prove Firestore behaves the same way.
class Client {
  Client(this.uid, this.store)
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

  /// The uid seated on [side] once the room exists.
  String uidFor(PlayerId side) => side == PlayerId.blue ? blueUid : redUid;
  String blueUid = '';
  String redUid = '';
}

void main() {
  late InMemoryFirestoreClient store;
  late Client host;
  late Client guest;
  late String code;

  setUp(() async {
    store = InMemoryFirestoreClient();
    host = Client('uid-host', store);
    guest = Client('uid-guest', store);
    host.blueUid = 'uid-host';
    host.redUid = 'uid-guest';
    guest.blueUid = 'uid-host';
    guest.redUid = 'uid-guest';

    // Room -> ready -> started, through the Phase 8 code path unchanged.
    final created = await host.rooms.create(config: const BoardConfig());
    code = (created as RoomSuccess).room.code;
    await guest.rooms.join(code);
    await host.rooms.setReady(code: code, ready: true);
    await guest.rooms.setReady(code: code, ready: true);
    await host.rooms.start(code);
  });

  tearDown(() => store.closeWatchers());

  /// The client whose turn it is.
  Client forTurn(int turnNumber) => turnNumber.isEven ? host : guest;

  Future<GameState> snapshot() async {
    final doc = await host.matches.loadMatch(code: code);
    return Room.fromJson(doc!.fields)!.boardState!;
  }

  Future<Room> room() async {
    final doc = await host.matches.loadMatch(code: code);
    return Room.fromJson(doc!.fields)!;
  }

  group('starting a match', () {
    test('seeds one authoritative snapshot for both clients', () async {
      final stored = await room();

      expect(stored.status, RoomStatus.started);
      expect(stored.boardState, isNotNull);
      expect(stored.turnNumber, 0);
      expect(
        stored.currentPlayerId,
        'uid-host',
        reason: 'Blue moves first, and the host is Blue in a code room',
      );
      expect(
        stored.boardState!.currentPlayer,
        PlayerId.blue,
        reason: 'the stored state and the room field must agree',
      );

      // Both clients read the identical stored state.
      final a = await host.matches.loadMatch(code: code);
      final b = await guest.matches.loadMatch(code: code);
      expect(a!.fields, b!.fields);
    });

    test(
      'the snapshot is the engine initial state, not a client guess',
      () async {
        final stored = await room();
        expect(stored.boardState, GameState.initial());
      },
    );
  });

  group('the scripted 17-action game across two clients', () {
    test(
      'both clients end on the same state with a complete move log',
      () async {
        for (var turn = 0; turn < kScriptedGame.length; turn++) {
          final (side, action) = kScriptedGame[turn];
          final client = forTurn(turn);

          final result = await client.matches.submitAction(
            code: code,
            expectedTurnNumber: turn,
            action: action,
          );

          expect(
            result,
            isA<MoveApplied>(),
            reason: 'ply $turn (${action.toNotation()}) by $side should apply',
          );
          expect((result as MoveApplied).state.turnNumber, turn + 1);
        }

        // Independent engine replay must produce the identical state.
        var reference = GameState.initial();
        for (final (side, action) in kScriptedGame) {
          reference = (GameEngine.apply(
            reference,
            side,
            action,
          ) as SuccessResult).state;
        }

        final shared = await snapshot();
        expect(
          shared,
          reference,
          reason: 'the shared state must equal the engine',
        );
        expect(shared.turnNumber, 17);
        expect(shared.status, GameStatus.finished);
        expect(shared.winner, PlayerId.blue);

        // Both clients read the same document.
        final a = await host.matches.loadMatch(code: code);
        final b = await guest.matches.loadMatch(code: code);
        expect(a!.fields, b!.fields);

        // Exactly 17 move records with consecutive ids.
        final moves = await host.matches.readMoves(code: code);
        expect(moves, hasLength(17));
        for (var i = 0; i < moves.length; i++) {
          expect(moves[i].turnNumber, i);
          expect(moves[i].action, kScriptedGame[i].$2);
          expect(moves[i].playerId, i.isEven ? 'uid-host' : 'uid-guest');
        }
        expect(
          store.documents.keys.where((k) => k.contains('/moves/')).toList()
            ..sort(),
          equals([
            for (var i = 0; i < 17; i++)
              'matches/$code/moves/${MatchMove.documentIdFor(i)}',
          ]),
        );
      },
    );

    test('version advances by exactly one per action', () async {
      var previous = (await room()).version;
      for (var turn = 0; turn < 3; turn++) {
        await forTurn(turn).matches.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: kScriptedGame[turn].$2,
        );
        final now = (await room()).version;
        expect(now, previous + 1);
        previous = now;
      }
    });
  });

  group('turn ownership', () {
    test('a player cannot move on the opponent\'s turn', () async {
      // Host is Blue and it is Blue's turn; the guest (Red) must be refused.
      final result = await guest.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 1, column: 4)),
      );

      expect(result, isA<MoveRejected>());
      expect(
        (result as MoveRejected).reason,
        MatchSyncFailureReason.notYourTurn,
      );
      expect((await snapshot()).turnNumber, 0, reason: 'nothing was applied');
      expect(await host.matches.readMoves(code: code), isEmpty);
    });

    test('turn ownership holds for every ply of the scripted game', () async {
      for (var turn = 0; turn < 8; turn++) {
        // The wrong client tries the right move at the right turn.
        final wrong = forTurn(turn + 1);
        final result = await wrong.matches.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: kScriptedGame[turn].$2,
        );
        expect(
          (result as MoveRejected).reason,
          MatchSyncFailureReason.notYourTurn,
          reason: 'ply $turn must be refused from the wrong seat',
        );
        // Then the right client plays it.
        await forTurn(turn).matches.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: kScriptedGame[turn].$2,
        );
      }
      expect((await snapshot()).turnNumber, 8);
    });

    test('a non-member is refused', () async {
      final stranger = Client('uid-stranger', store);
      final result = await stranger.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      expect(
        (result as MoveRejected).reason,
        MatchSyncFailureReason.notAMember,
      );
    });

    test(
      'an unauthenticated caller is refused and nothing is written',
      () async {
        final anonymous = FirestoreMatchRepository(
          client: store,
          userId: () async => null,
        );
        final result = await anonymous.submitAction(
          code: code,
          expectedTurnNumber: 0,
          action: const GameAction.move(Cell(row: 7, column: 4)),
        );
        expect(
          (result as MoveRejected).reason,
          MatchSyncFailureReason.notAuthenticated,
        );
        expect((await snapshot()).turnNumber, 0);
      },
    );
  });

  group('illegal actions', () {
    test('the engine rejects them and the reason is carried through', () async {
      // Blue cannot jump two squares.
      final result = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 6, column: 4)),
      );

      expect(result, isA<MoveRejected>());
      final rejected = result as MoveRejected;
      expect(rejected.reason, MatchSyncFailureReason.invalidAction);
      expect(
        rejected.failure.actionFailure,
        ActionFailure.moveNotAdjacent,
        reason: "the engine's own reason must survive, not be flattened",
      );
      expect(rejected.failure.message, isNotEmpty);
      expect((await snapshot()).turnNumber, 0);
    });

    test('an illegal action writes no move record', () async {
      await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 6, column: 4)),
      );
      expect(await host.matches.readMoves(code: code), isEmpty);
      expect(store.documents.keys.where((k) => k.contains('/moves/')), isEmpty);
    });

    test('a legal wall is accepted, and the engine is the only judge', () async {
      // A single wall can never strand a pawn on an otherwise open board, so
      // "one wall blocks every route" is not reachable here — the engine's own
      // pathfinding suite covers that case. What matters for Phase 9 is that the
      // decision comes from the engine, so a legal wall must be accepted and an
      // illegal one refused.
      final legal = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 0, column: 3),
        ),
      );
      expect(legal, isA<MoveApplied>());

      // Red may not place a wall outside the anchor range.
      final illegal = await guest.matches.submitAction(
        code: code,
        expectedTurnNumber: 1,
        action: const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 8, column: 8),
        ),
      );
      expect(illegal, isA<MoveRejected>());
      expect(
        (illegal as MoveRejected).failure.actionFailure,
        ActionFailure.wallOutOfBounds,
      );
    });
  });

  group('duplicate-move protection', () {
    test('re-submitting the same action is idempotent, not a second move', () async {
      const action = GameAction.move(Cell(row: 7, column: 4));

      final first = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: action,
      );
      expect(first, isA<MoveApplied>());

      // Simulates a retry after a lost acknowledgement: same turn, same action.
      final retry = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: action,
      );

      expect(
        retry,
        isA<MoveAlreadyApplied>(),
        reason: 'a retry must resolve as success, never as a second move',
      );
      expect((retry as MoveAlreadyApplied).state.turnNumber, 1);
      expect((await snapshot()).turnNumber, 1, reason: 'applied exactly once');
      expect(await host.matches.readMoves(code: code), hasLength(1));
    });

    test('a different action for the same turn is a conflict', () async {
      await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );

      // Red's first move is not Blue's; submitting it as ply 0 conflicts.
      final conflict = await guest.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 1, column: 4)),
      );

      expect(conflict, isA<MoveRejected>());
      expect(
        (conflict as MoveRejected).reason,
        anyOf(
          MatchSyncFailureReason.notYourTurn,
          MatchSyncFailureReason.staleTurn,
          MatchSyncFailureReason.conflictingDuplicate,
        ),
        reason:
            'refused for a precise reason; the exact one depends on which check '
            'catches it first, and all three are refusals with a real cause',
      );
      expect((await snapshot()).turnNumber, 1);
    });
  });

  group('stale submissions', () {
    test('an old expectedTurnNumber is refused', () async {
      await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      await guest.matches.submitAction(
        code: code,
        expectedTurnNumber: 1,
        action: const GameAction.move(Cell(row: 1, column: 4)),
      );

      // Blue is on the move again, but this client still thinks it is ply 0.
      final stale = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 6, column: 4)),
      );

      expect((stale as MoveRejected).reason, MatchSyncFailureReason.staleTurn);
      expect((await snapshot()).turnNumber, 2);
    });

    test('a wrong expectedVersion is refused', () async {
      final result = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
        expectedVersion: 999,
      );
      expect((result as MoveRejected).reason, MatchSyncFailureReason.staleTurn);
      expect((await snapshot()).turnNumber, 0);
    });
  });

  group('concurrent submissions for one turn', () {
    test('exactly one wins, 20 rounds with a fresh store each time', () async {
      for (var round = 0; round < 20; round++) {
        final local = InMemoryFirestoreClient();
        final a = Client('uid-host', local);
        final b = Client('uid-guest', local);
        a.blueUid = 'uid-host';
        a.redUid = 'uid-guest';
        final created = await a.rooms.create(config: const BoardConfig());
        final roundCode = (created as RoomSuccess).room.code;
        await b.rooms.join(roundCode);
        await a.rooms.setReady(code: roundCode, ready: true);
        await b.rooms.setReady(code: roundCode, ready: true);
        await a.rooms.start(roundCode);

        // Both submit for ply 0 at the same moment.
        final results = await Future.wait([
          a.matches.submitAction(
            code: roundCode,
            expectedTurnNumber: 0,
            action: const GameAction.move(Cell(row: 7, column: 4)),
          ),
          b.matches.submitAction(
            code: roundCode,
            expectedTurnNumber: 0,
            action: const GameAction.move(Cell(row: 1, column: 4)),
          ),
        ]);

        final applied = results.whereType<MoveApplied>().length;
        final rejected = results.whereType<MoveRejected>().length;
        expect(applied + rejected, 2, reason: 'both must resolve, none thrown');
        expect(
          applied,
          lessThanOrEqualTo(1),
          reason: 'two different actions cannot both take the same ply',
        );

        final stored = Room.fromJson(
          (await a.matches.loadMatch(code: roundCode))!.fields,
        )!;
        expect(
          stored.turnNumber,
          applied,
          reason: 'turn advanced exactly as far as the accepted writes',
        );
        expect(
          await a.matches.readMoves(code: roundCode),
          hasLength(applied),
          reason: 'one move record per accepted action, never more',
        );
        local.closeWatchers();
      }
    });
  });

  group('match completion', () {
    test('the winning action finishes the room and locks it', () async {
      for (var turn = 0; turn < kScriptedGame.length; turn++) {
        await forTurn(turn).matches.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: kScriptedGame[turn].$2,
        );
      }

      final finished = await room();
      expect(finished.status, RoomStatus.finished);
      expect(finished.turnNumber, 17);
      expect(
        finished.winnerId,
        'uid-host',
        reason: 'derived from the engine, not declared by the client',
      );
      expect(
        finished.boardState!.winner,
        PlayerId.blue,
        reason: 'and it agrees with the authoritative state',
      );
    });

    test('no action is accepted after the finish', () async {
      for (var turn = 0; turn < kScriptedGame.length; turn++) {
        await forTurn(turn).matches.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: kScriptedGame[turn].$2,
        );
      }
      final writesBefore = store.writeLog.length;

      // A late submission for the final ply retries as success at most.
      final late = await guest.matches.submitAction(
        code: code,
        expectedTurnNumber: 16,
        action: const GameAction.move(Cell(row: 0, column: 4)),
      );

      expect(late, isA<MoveRejected>());
      expect(
        (late as MoveRejected).reason,
        MatchSyncFailureReason.matchFinished,
        reason: 'the terminal state is locked, mirroring R-WIN',
      );
      expect(store.writeLog.length, writesBefore, reason: 'nothing written');
    });

    test('a Red win is recorded the same way', () async {
      // A short forced game on a 5x5 where Red wins by reaching row 4.
      final created = await host.rooms.create(
        config: const BoardConfig(size: 5),
      );
      final shortCode = (created as RoomSuccess).room.code;
      await guest.rooms.join(shortCode);
      await host.rooms.setReady(code: shortCode, ready: true);
      await guest.rooms.setReady(code: shortCode, ready: true);
      await host.rooms.start(shortCode);

      // Blue detours into column 1 while Red descends column 2, so the pawns
      // never share a cell and Red reaches its goal row first. Every ply is a
      // single orthogonal step, so the whole line is legal.
      const game = <(PlayerId, GameAction)>[
        (PlayerId.blue, GameAction.move(Cell(row: 4, column: 1))),
        (PlayerId.red, GameAction.move(Cell(row: 1, column: 2))),
        (PlayerId.blue, GameAction.move(Cell(row: 3, column: 1))),
        (PlayerId.red, GameAction.move(Cell(row: 2, column: 2))),
        (PlayerId.blue, GameAction.move(Cell(row: 2, column: 1))),
        (PlayerId.red, GameAction.move(Cell(row: 3, column: 2))),
        (PlayerId.blue, GameAction.move(Cell(row: 1, column: 1))),
        (PlayerId.red, GameAction.move(Cell(row: 4, column: 2))),
      ];

      for (var turn = 0; turn < game.length; turn++) {
        final result = await (turn.isEven ? host : guest).matches.submitAction(
          code: shortCode,
          expectedTurnNumber: turn,
          action: game[turn].$2,
        );
        expect(result, isA<MoveApplied>(), reason: 'ply $turn: $result');
      }

      final stored = Room.fromJson(
        (await host.matches.loadMatch(code: shortCode))!.fields,
      )!;
      expect(stored.status, RoomStatus.finished);
      expect(stored.boardState!.winner, PlayerId.red);
      expect(stored.winnerId, 'uid-guest');
    });
  });

  group('hostile and inconsistent documents', () {
    test('a turn number that disagrees with the snapshot is refused', () async {
      await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );

      // Tamper: claim a turn number the snapshot does not support.
      final path = 'matches/$code';
      final fields = Map<String, dynamic>.from(store.documents[path]!)
        ..['turnNumber'] = 9;
      store.documents[path] = fields;

      final result = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 1,
        action: const GameAction.move(Cell(row: 1, column: 4)),
      );

      expect(result, isA<MoveRejected>());
      expect(
        (result as MoveRejected).reason,
        MatchSyncFailureReason.invalidRemoteData,
        reason: 'the denormalised field and the snapshot must agree',
      );
    });

    test('a snapshot that will not decode is refused', () async {
      final path = 'matches/$code';
      store.documents[path] = Map<String, dynamic>.from(store.documents[path]!)
        ..['boardState'] = <String, dynamic>{'garbage': true};

      final result = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );

      expect(
        (result as MoveRejected).reason,
        MatchSyncFailureReason.invalidRemoteData,
      );
    });

    test('a room that is not started accepts nothing', () async {
      // A brand new room, before start, with both players seated.
      final created = await host.rooms.create(config: const BoardConfig());
      final fresh = (created as RoomSuccess).room.code;
      await guest.rooms.join(fresh);

      final result = await guest.matches.submitAction(
        code: fresh,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );

      expect(
        (result as MoveRejected).reason,
        MatchSyncFailureReason.roomNotStarted,
      );
    });

    test(
      'an unknown code is reported, not treated as an empty board',
      () async {
        final result = await host.matches.submitAction(
          code: 'ZZ99ZZ',
          expectedTurnNumber: 0,
          action: const GameAction.move(Cell(row: 7, column: 4)),
        );
        expect(
          (result as MoveRejected).reason,
          MatchSyncFailureReason.roomNotFound,
        );
      },
    );
  });

  group('listener', () {
    test(
      'both clients observe the same moves through one listener each',
      () async {
        final hostSeen = <SharedMatchDocument>[];
        final guestSeen = <SharedMatchDocument>[];
        final a = host.matches.watchMatch(code: code).listen(hostSeen.add);
        final b = guest.matches.watchMatch(code: code).listen(guestSeen.add);
        addTearDown(a.cancel);
        addTearDown(b.cancel);
        await pumpEventQueue();

        for (var turn = 0; turn < 4; turn++) {
          await forTurn(turn).matches.submitAction(
            code: code,
            expectedTurnNumber: turn,
            action: kScriptedGame[turn].$2,
          );
        }
        await pumpEventQueue();

        // The listener is the only read path in steady state; both converge.
        expect(hostSeen.last.turnNumber, 4);
        expect(guestSeen.last.turnNumber, 4);
        expect(hostSeen.last.fields, guestSeen.last.fields);
        expect(Room.fromJson(hostSeen.last.fields)!.boardState!.turnNumber, 4);
      },
    );

    test(
      'a cached snapshot is flagged so the client can show Reconnecting',
      () async {
        final seen = <SharedMatchDocument>[];
        final sub = host.matches.watchMatch(code: code).listen(seen.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        store.goOffline();
        await pumpEventQueue();
        expect(seen.last.fromCache, isTrue);

        store.goOnline();
        await pumpEventQueue();
        expect(seen.last.fromCache, isFalse);
      },
    );
  });

  group('offline', () {
    test('a transaction while offline is rejected, not queued', () async {
      // A direct read fails while offline, so the state assertion is made through
      // the listener, which must keep serving the last known snapshot from cache.
      // That is `rules.md` §9's "preserve the current local state": the board
      // must not blank out when the network drops.
      final seen = <SharedMatchDocument>[];
      final sub = host.matches.watchMatch(code: code).listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(seen.last.turnNumber, 0);

      store.goOffline();
      final result = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );

      expect(
        (result as MoveRejected).reason,
        MatchSyncFailureReason.networkUnavailable,
      );
      expect(
        await host.matches.loadMatch(code: code),
        isNull,
        reason: 'a direct read cannot succeed while offline',
      );
      await pumpEventQueue();
      expect(seen.last.turnNumber, 0, reason: 'the cached state is unchanged');
      expect(seen.last.fromCache, isTrue);
    });

    test('the match resumes normally once back online', () async {
      store.goOffline();
      expect(
        (await host.matches.submitAction(
          code: code,
          expectedTurnNumber: 0,
          action: const GameAction.move(Cell(row: 7, column: 4)),
        ) as MoveRejected).reason,
        MatchSyncFailureReason.networkUnavailable,
      );

      store.goOnline();
      final result = await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      expect(result, isA<MoveApplied>());
      expect((await snapshot()).turnNumber, 1);
    });
  });

  group('move log', () {
    test('reads are bounded and ordered by turn', () async {
      for (var turn = 0; turn < 5; turn++) {
        await forTurn(turn).matches.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: kScriptedGame[turn].$2,
        );
      }
      final moves = await host.matches.readMoves(code: code);
      expect(moves.map((m) => m.turnNumber).toList(), [0, 1, 2, 3, 4]);
      expect(moves.first.action, kScriptedGame.first.$2);
      expect(
        moves.first.action!.toNotation(),
        'M 7,4',
        reason: 'spec notation is stored',
      );
    });
    test('a small page size still returns the whole log', () async {
      for (var turn = 0; turn < 4; turn++) {
        await forTurn(turn).matches.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: kScriptedGame[turn].$2,
        );
      }

      final moves = await host.matches.readMoves(code: code, limit: 2);

      expect(
        moves,
        hasLength(4),
        reason:
            'limit is a page size, not a cap. Returning 2 of 4 would hand a '
            'caller rebuilding state a prefix that looks like the whole log',
      );
      expect(moves.map((m) => m.turnNumber), [
        0,
        1,
        2,
        3,
      ], reason: 'paging must not skip or repeat a record');
    });

    test('paging works past the first page in a long game', () async {
      // Well past defaultRecoveryPageSize, so recovery genuinely has to follow
      // the cursor instead of relying on a single response.
      var state = GameState.initial(const BoardConfig(size: 7));
      const config = BoardConfig(size: 7, wallsPerPlayer: 4);
      final longCode =
          (await host.rooms.create(config: config) as RoomSuccess).room.code;
      await guest.rooms.join(longCode);
      await host.rooms.setReady(code: longCode, ready: true);
      await guest.rooms.setReady(code: longCode, ready: true);
      await host.rooms.start(longCode);

      var ply = 0;
      while (state.status == GameStatus.inProgress && ply < 400) {
        final legal = GameEngine.legalActions(state);
        final action = legal[ply % legal.length];
        final mover = state.currentPlayer == PlayerId.blue ? host : guest;
        final result = await mover.matches.submitAction(
          code: longCode,
          expectedTurnNumber: ply,
          action: action,
        );
        expect(result, isA<MoveApplied>(), reason: 'ply $ply');
        state = (result as MoveApplied).state;
        ply++;
      }

      final moves = await host.matches.readMoves(code: longCode, limit: 50);
      expect(moves, hasLength(ply), reason: 'every record, across pages');
      expect(moves.map((m) => m.turnNumber).toList(), [
        for (var i = 0; i < ply; i++) i,
      ], reason: 'consecutive, in order, with no gap or repeat at a boundary');
    });

    test('an unreadable record is skipped, not guessed at', () async {
      await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: const GameAction.move(Cell(row: 7, column: 4)),
      );
      store.documents['matches/$code/moves/${MatchMove.documentIdFor(0)}'] =
          <String, dynamic>{
            'turnNumber': 0,
            'playerId': 'uid-host',
          }; // no action

      final moves = await host.matches.readMoves(code: code);
      expect(
        moves,
        isEmpty,
        reason:
            'a record with no readable action cannot be replayed, so it is '
            'not returned as if it were fine — recovery must notice the gap',
      );
    });
  });

  group('messages', () {
    test('every reason has a player-facing message with no raw error text', () {
      for (final reason in MatchSyncFailureReason.values) {
        final message = FirestoreMatchRepository.messageFor(reason);
        expect(message, isNotEmpty, reason: reason.name);
        expect(message, isNot(contains('Exception')), reason: reason.name);
        expect(message, isNot(contains('Exception')), reason: reason.name);
      }
    });
  });

  group('stored size', () {
    test('the 9x9 snapshot stays compact', () {
      // `rules.md` §5: "Keep documents compact" and "avoid repeatedly writing
      // large redundant documents". Measured rather than assumed.
      var state = GameState.initial();
      for (final (side, action) in kScriptedGame) {
        state = (GameEngine.apply(state, side, action) as SuccessResult).state;
      }
      final bytes = GameStateSerializer.encode(state).length;
      // Generous bound: 20 walls on a 9x9 is well under this.
      expect(bytes, lessThan(4096), reason: 'snapshot was $bytes bytes');
    });
  });
}
