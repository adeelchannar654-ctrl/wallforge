import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// The `game_spec.md` §15 scripted game, 17 actions, Blue wins.
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

/// One device's whole stack: its own uid, repositories and controller, over one
/// shared document store.
///
/// **Not a real-backend test.** The Q-7.4 console setup is still undone, so there
/// is no Firebase project, emulator or second device. This proves two independent
/// client stacks stay in agreement with the engine and with each other; it does
/// not prove Firestore behaves the same way.
class Device {
  Device(this.uid, this.store)
    : rooms = FirestoreRoomRepository(
        client: store,
        userId: () async => uid,
        clock: () => DateTime.utc(2026, 9, 29, 10),
      ),
      matches = FirestoreMatchRepository(
        client: store,
        userId: () async => uid,
        clock: () => DateTime.utc(2026, 9, 29, 10, 0, 30),
      );

  final String uid;
  final InMemoryFirestoreClient store;
  final FirestoreRoomRepository rooms;
  final FirestoreMatchRepository matches;
}

void main() {
  late InMemoryFirestoreClient store;
  late Device host;
  late Device guest;
  late OnlineGameController hostView;
  late OnlineGameController guestView;
  late String code;

  setUp(() async {
    store = InMemoryFirestoreClient();
    host = Device('uid-host', store);
    guest = Device('uid-guest', store);

    final created = await host.rooms.create(config: const BoardConfig());
    code = (created as RoomSuccess).room.code;
    await guest.rooms.join(code);
    await host.rooms.setReady(code: code, ready: true);
    await guest.rooms.setReady(code: code, ready: true);
    await host.rooms.start(code);

    hostView = OnlineGameController(
      rooms: host.rooms,
      matches: host.matches,
      uid: host.uid,
      code: code,
    );
    guestView = OnlineGameController(
      rooms: guest.rooms,
      matches: guest.matches,
      uid: guest.uid,
      code: code,
    );
    await hostView.connect();
    await guestView.connect();
    await pumpEventQueue();
  });

  tearDown(() {
    hostView.dispose();
    guestView.dispose();
    store.closeWatchers();
  });

  /// The view whose turn it currently is.
  OnlineGameController whoseTurn() =>
      hostView.state.currentPlayer == PlayerId.blue ? hostView : guestView;

  /// The view that is *not* on turn.
  OnlineGameController notOnTurn() =>
      hostView.state.currentPlayer == PlayerId.blue ? guestView : hostView;

  group('starting up', () {
    test('both clients render the same authoritative start', () {
      expect(hostView.state, GameState.initial());
      expect(guestView.state, GameState.initial());
      expect(hostView.isMyTurn, isTrue, reason: 'Blue, the host, moves first');
      expect(guestView.isMyTurn, isFalse);
      expect(hostView.mySide, PlayerId.blue);
      expect(guestView.mySide, PlayerId.red);
      expect(hostView.opponentId, 'uid-guest');
      expect(hostView.isBlue, isTrue);
    });

    test('input is refused on the opponent turn with a reason', () {
      expect(guestView.isMyTurn, isFalse);
      expect(guestView.inputBlockedReason, isNotNull);
      expect(guestView.isInteractionBlocked, isTrue);
    });
  });

  group('playing the scripted game across two clients', () {
    test('both views converge on the engine result', () async {
      for (var turn = 0; turn < kScriptedGame.length; turn++) {
        final (_, action) = kScriptedGame[turn];
        final failure = await whoseTurn().submit(action);
        expect(failure, isNull, reason: 'ply $turn should be accepted');
        await pumpEventQueue();
      }

      var reference = GameState.initial();
      for (final (side, action) in kScriptedGame) {
        reference =
            (GameEngine.apply(reference, side, action) as SuccessResult).state;
      }

      expect(hostView.state, reference);
      expect(guestView.state, reference);
      expect(hostView.isFinished, isTrue);
      expect(hostView.winner, PlayerId.blue);
      expect(guestView.winner, PlayerId.blue);
      expect(guestView.room.winnerId, 'uid-host');
    });

    test('the opponent cannot move out of turn', () async {
      final idle = notOnTurn();
      expect(idle.isMyTurn, isFalse);
      // Input is refused before anything is sent, so the store is untouched.
      idle.tapCell(const Cell(row: 1, column: 4));
      await pumpEventQueue();

      expect(hostView.state.turnNumber, 0);
      expect(
        store.documents.keys.where((k) => k.contains('/moves/')),
        isEmpty,
        reason: 'nothing may be written from the wrong seat',
      );
    });

    test('the board only offers targets on your own turn', () async {
      expect(hostView.legalMoveTargets, isNotEmpty);
      expect(guestView.legalMoveTargets, isEmpty);
    });
  });

  group('reconnection', () {
    test(
      'losing the connection shows Reconnecting and keeps the board',
      () async {
        await whoseTurn().submit(kScriptedGame.first.$2);
        await pumpEventQueue();
        final turnBefore = hostView.state.turnNumber;
        expect(turnBefore, 1);

        store.goOffline();
        await pumpEventQueue();

        expect(hostView.connection, OnlineConnectionState.reconnecting);
        expect(hostView.state.turnNumber, 1, reason: 'the board is preserved');
        expect(hostView.inputBlockedReason, contains('Reconnecting'));
        expect(
          hostView.isInteractionBlocked,
          isTrue,
          reason: 'input is disabled while reconnecting',
        );
      },
    );

    test('coming back online converges without double-applying', () async {
      await whoseTurn().submit(kScriptedGame.first.$2);
      await pumpEventQueue();

      store.goOffline();
      await pumpEventQueue();
      expect(hostView.connection, OnlineConnectionState.reconnecting);

      store.goOnline();
      await pumpEventQueue();

      expect(hostView.connection, OnlineConnectionState.connected);
      expect(hostView.state.turnNumber, 1, reason: 'applied exactly once');
      expect(await host.matches.readMoves(code: code), hasLength(1));
    });

    test('a client that was away catches up on the authoritative snapshot', () async {
      // "Away" is modelled by connecting *after* the moves rather than by the
      // offline switch, which is process-wide in the double and would take the
      // other device offline too.
      final away = OnlineGameController(
        rooms: guest.rooms,
        matches: guest.matches,
        uid: guest.uid,
        code: code,
      );
      addTearDown(away.dispose);

      // Blue plays the first ply and Red the second, each through its own
      // repository — submitting Red's ply through the host's would be refused
      // for turn ownership, which is the rule under test everywhere else.
      await host.matches.submitAction(
        code: code,
        expectedTurnNumber: 0,
        action: kScriptedGame[0].$2,
      );
      await guest.matches.submitAction(
        code: code,
        expectedTurnNumber: 1,
        action: kScriptedGame[1].$2,
      );

      expect(away.state.turnNumber, 0, reason: 'it has not caught up yet');
      await away.connect();
      await pumpEventQueue();

      expect(
        away.state.turnNumber,
        2,
        reason: 'the authoritative snapshot catches it up in one step',
      );
      expect(away.mySide, PlayerId.red, reason: 'it is still the guest device');
      expect(
        away.isMyTurn,
        isFalse,
        reason:
            'two plies have passed, so it is Blue to play again '
            '(R-STATE-05: Blue when turnNumber is even)',
      );
      expect(away.state.currentPlayer, PlayerId.blue);
      expect(away.sync, OnlineSyncState.inSync);
    });

    test('a move held while offline is resubmitted on reconnect', () async {
      // Host is Blue and on turn. The network drops before it submits.
      store.goOffline();
      await pumpEventQueue();

      final failure = await hostView.submit(kScriptedGame[0].$2);
      expect(failure, isNull);
      await pumpEventQueue();
      expect(hostView.connection, OnlineConnectionState.reconnecting);
      expect(
        hostView.pendingAction,
        isNotNull,
        reason: 'the action is held, not lost and not applied locally',
      );
      expect(
        hostView.state.turnNumber,
        0,
        reason: 'never applied speculatively',
      );

      store.goOnline();
      await pumpEventQueue();
      // The reconnect resends the identical action, which is idempotent.
      await pumpEventQueue();

      expect(hostView.state.turnNumber, 1);
      expect(
        await host.matches.readMoves(code: code),
        hasLength(1),
        reason: 'exactly one move despite the retry',
      );
    });
  });

  group('hostile remote data', () {
    Future<void> tamperWith(
      void Function(Map<String, dynamic> fields) change,
    ) async {
      final path = 'matches/$code';
      final fields = Map<String, dynamic>.from(store.documents[path]!);
      change(fields);
      store.documents[path] = fields;
    }

    test(
      'a snapshot that moves backwards is never shown, and is repaired',
      () async {
        await whoseTurn().submit(kScriptedGame.first.$2);
        await pumpEventQueue();
        final good = hostView.state;
        expect(good.turnNumber, 1);

        // Re-serialise the pre-move ply as if it were the newest document.
        await tamperWith((f) {
          f['boardState'] = GameStateSerializer.toJson(GameState.initial());
          f['turnNumber'] = 0;
        });
        await hostView.resync();
        await pumpEventQueue();

        // The board never regressed, because the move log replayed it back.
        expect(hostView.state, good, reason: 'a backwards turn is never shown');
        expect(hostView.sync, OnlineSyncState.inSync);
        expect(hostView.statusMessage, contains('move history'));
      },
    );

    test('a turn jump of two with no version growth is rejected', () async {
      // A genuine catch-up has written the document more than once, so a large
      // turn jump with an unchanged version cannot be one.
      await tamperWith((f) {
        f['boardState'] = GameStateSerializer.toJson(
          GameState.initial().copyWith(turnNumber: 2),
        );
        f['turnNumber'] = 2;
      });
      await hostView.resync();
      await pumpEventQueue();

      expect(
        hostView.state.turnNumber,
        0,
        reason: 'the forged jump is not shown',
      );
      expect(
        hostView.sync,
        anyOf(OnlineSyncState.desynced, OnlineSyncState.syncError),
      );
    });

    test('a single ply that no legal action produces is rejected', () async {
      // One ply ahead, but the transition is impossible: this is the check the
      // single-turn reachability test exists for.
      await tamperWith((f) {
        f['boardState'] = GameStateSerializer.toJson(
          GameState.initial().copyWith(
            turnNumber: 1,
            pawnPositions: {
              PlayerId.blue: const Cell(row: 0, column: 0),
              PlayerId.red: const Cell(row: 0, column: 4),
            },
          ),
        );
        f['turnNumber'] = 1;
        f['version'] = (f['version'] as int) + 1;
      });
      await hostView.resync();
      await pumpEventQueue();

      expect(
        hostView.state.pawnPosition(PlayerId.blue),
        const Cell(row: 8, column: 4),
        reason: 'the impossible single step is not adopted',
      );
    });

    test('an illegal transition is rejected', () async {
      // Blue's pawn teleported: a state no legal action from the start produces.
      await tamperWith((f) {
        final snap = Room.fromJson(f)!.boardState!;
        f['boardState'] = GameStateSerializer.toJson(
          snap.copyWith(
            turnNumber: 1,
            pawnPositions: {
              PlayerId.blue: const Cell(row: 0, column: 0),
              PlayerId.red: const Cell(row: 0, column: 4),
            },
          ),
        );
        f['turnNumber'] = 1;
      });
      await hostView.resync();
      await pumpEventQueue();

      expect(
        hostView.state.pawnPosition(PlayerId.blue),
        const Cell(row: 8, column: 4),
        reason: 'the unreachable state must not be displayed',
      );
      expect(hostView.sync, isNot(OnlineSyncState.inSync));
    });

    test('a declared winner that disagrees with the state is treated as '
        'corruption', () async {
      await tamperWith((f) => f['winnerId'] = 'uid-guest');
      await hostView.resync();
      await pumpEventQueue();

      expect(
        hostView.winner,
        isNull,
        reason: 'a declared winner is never believed while the game is running',
      );
      expect(hostView.sync, isNot(OnlineSyncState.inSync));
    });

    test(
      'malformed JSON leaves the board alone and reports the problem',
      () async {
        final good = hostView.state;
        await tamperWith((f) => f['boardState'] = <String, dynamic>{'nope': 1});
        await hostView.resync();
        await pumpEventQueue();

        expect(hostView.state, good, reason: 'nothing is shown from bad data');
        expect(hostView.sync, isNot(OnlineSyncState.inSync));
        expect(hostView.statusMessage, isNotNull);
      },
    );

    test('a wrong wall inventory is rejected by the engine decoder', () async {
      // A state whose inventories contradict the walls breaks R-STATE-02, which
      // the serializer's invariant check must catch.
      await tamperWith((f) {
        f['boardState'] = <String, dynamic>{
          ...GameStateSerializer.toJson(GameState.initial()),
          'remainingWalls': <String, dynamic>{'blue': 3, 'red': 10},
        };
      });
      await hostView.resync();
      await pumpEventQueue();

      expect(hostView.state.turnNumber, 0, reason: 'the board is unchanged');
      expect(hostView.sync, isNot(OnlineSyncState.inSync));
    });
  });

  group('recovery by replay', () {
    test('a valid move log repairs a desynchronised board', () async {
      // Play three real plies, so the log has content.
      for (var turn = 0; turn < 3; turn++) {
        await whoseTurn().submit(kScriptedGame[turn].$2);
        await pumpEventQueue();
      }
      final repaired = hostView.state;
      expect(repaired.turnNumber, 3);

      // Corrupt the stored snapshot so verification fails, leaving the log good.
      final path = 'matches/$code';
      store.documents[path] = Map<String, dynamic>.from(store.documents[path]!)
        ..['boardState'] = <String, dynamic>{'corrupt': true};

      await hostView.resync();
      await pumpEventQueue();

      expect(hostView.sync, OnlineSyncState.inSync);
      expect(
        hostView.state,
        repaired,
        reason:
            'rebuilt from the move log, which is the authority for recovery',
      );
    });

    test(
      'an inconsistent log stops in syncError rather than guessing',
      () async {
        // One real ply, then a log entry the engine refuses.
        await whoseTurn().submit(kScriptedGame[0].$2);
        await pumpEventQueue();
        store.documents['matches/$code/moves/${MatchMove.documentIdFor(1)}'] =
            <String, dynamic>{
              'turnNumber': 1,
              'playerId': 'uid-guest',
              'action': <String, dynamic>{
                'type': 'move',
                'destination': <String, dynamic>{'row': 0, 'column': 0},
              },
              'createdAt': 0,
              'resultingVersion': 99,
            };
        final path = 'matches/$code';
        store.documents[path] = Map<String, dynamic>.from(
          store.documents[path]!,
        )..['boardState'] = <String, dynamic>{'corrupt': true};

        await hostView.resync();
        await pumpEventQueue();

        expect(
          hostView.sync,
          OnlineSyncState.syncError,
          reason: 'a log the engine refuses cannot repair anything',
        );
        expect(hostView.inputBlockedReason, isNotNull);
      },
    );

    test('an empty log stops cleanly', () async {
      final path = 'matches/$code';
      store.documents[path] = Map<String, dynamic>.from(store.documents[path]!)
        ..['boardState'] = <String, dynamic>{'corrupt': true};

      await hostView.resync();
      await pumpEventQueue();

      expect(hostView.sync, OnlineSyncState.syncError);
    });
  });

  group('completion', () {
    test('both views show the same result and lock input', () async {
      for (var turn = 0; turn < kScriptedGame.length; turn++) {
        await whoseTurn().submit(kScriptedGame[turn].$2);
        await pumpEventQueue();
      }

      for (final view in [hostView, guestView]) {
        expect(view.isFinished, isTrue);
        expect(view.winner, PlayerId.blue);
        expect(view.isInteractionBlocked, isTrue);
        expect(view.inputBlockedReason, 'This match is over.');
        expect(view.legalMoveTargets, isEmpty);
      }
    });

    test('the winner comes from the engine, not the document field', () async {
      for (var turn = 0; turn < kScriptedGame.length; turn++) {
        await whoseTurn().submit(kScriptedGame[turn].$2);
        await pumpEventQueue();
      }
      // Forge the declared winner and re-read.
      final path = 'matches/$code';
      store.documents[path] = Map<String, dynamic>.from(store.documents[path]!)
        ..['winnerId'] = 'uid-guest';

      await hostView.resync();
      await pumpEventQueue();

      expect(
        hostView.winner,
        PlayerId.blue,
        reason: 'the state says Blue won, so a forged field is corruption',
      );
    });
  });

  group('disposal', () {
    test('disposing mid-match does not throw', () async {
      final view = OnlineGameController(
        rooms: host.rooms,
        matches: host.matches,
        uid: host.uid,
        code: code,
      );
      await view.connect();
      await view.submit(kScriptedGame.first.$2);
      view.dispose();
      await pumpEventQueue();
      expect(tester0(), isNull);
    });
  });
}

/// Placeholder so the disposal test can assert the absence of a pending error
/// frame without importing test bindings.
Object? tester0() => null;
