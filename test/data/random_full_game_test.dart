import 'dart:math';

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

/// A ceiling, not an expectation.
///
/// Play is uniformly random, so neither player is trying to win and a game ends
/// only when the random walk happens to reach a goal row. Measured runs put the
/// longest such game a little over 600 plies, and a 5x5 has only 9 cells a pawn
/// can shuffle between, so 2000 is generous rather than tight. It exists to turn
/// a wedged match into a failure instead of a hang, not to describe game length.
const int kPlyLimit = 2000;

/// A rejection reason, without casting a result that may be a success.
String _describe(MoveSubmission result) => switch (result) {
  MoveApplied() => 'MoveApplied',
  MoveAlreadyApplied() => 'MoveAlreadyApplied',
  MoveRejected(:final reason) => 'MoveRejected($reason)',
};

void main() {
  group('random full games, played through the repository', () {
    for (final size in const [5, 7, 9]) {
      // 5 + 7 + 9 boards, ~67 games each, so the run covers every board without
      // any single one dominating.
      const gamesPerSize = 67;
      final config = BoardConfig(size: size, wallsPerPlayer: size - 3);

      for (var game = 0; game < gamesPerSize; game++) {
        test('${size}x$size game $game reaches a legal finish', () async {
          // A per-game seed derived from the master one. Sharing a single
          // Random across the group would make the actions depend on test
          // execution order, so a failure could not be reproduced — and "it
          // passed on my run" is not a property of a protocol.
          final random = Random(20260928 + size * 1000 + game);
          final store = InMemoryFirestoreClient();
          addTearDown(store.closeWatchers);

          final blue = _Client('uid-blue', store);
          final red = _Client('uid-red', store);
          final created = await blue.rooms.create(config: config);
          expect(created, isA<RoomSuccess>());
          final code = (created as RoomSuccess).room.code;
          await red.rooms.join(code);
          await blue.rooms.setReady(code: code, ready: true);
          await red.rooms.setReady(code: code, ready: true);
          await blue.rooms.start(code);

          // The engine's own answer, kept independently of the repository.
          var reference = GameState.initial(config);
          var plies = 0;
          var submitted = 0;
          var refused = 0;

          while (reference.status == GameStatus.inProgress) {
            expect(
              plies,
              lessThan(kPlyLimit),
              reason: 'game $game did not finish within $kPlyLimit plies',
            );

            final legal = GameEngine.legalActions(reference);
            expect(legal, isNotEmpty, reason: 'no legal action offered');
            final action = legal[random.nextInt(legal.length)];

            final mover = reference.currentPlayer == PlayerId.blue ? blue : red;
            final result = await mover.matches.submitAction(
              code: code,
              expectedTurnNumber: plies,
              action: action,
            );

            // Every action the engine offered must be accepted. A refusal
            // here is the protocol disagreeing with the rules, not a flaky
            // race, so it is a hard failure rather than a retry.
            expect(
              result,
              isA<MoveApplied>(),
              reason:
                  'ply $plies (${action.toNotation()}) was legal but the '
                  'repository returned ${_describe(result)}',
            );
            submitted++;

            reference = (GameEngine.apply(
              reference,
              mover == blue ? PlayerId.blue : PlayerId.red,
              action,
            ) as SuccessResult).state;
            plies++;

            // Every third ply, the other side's view must agree with the
            // engine before the next move is offered.
            if (plies % 3 == 0) {
              final other = mover == blue ? red : blue;
              final document = await other.matches.loadMatch(code: code);
              final stored = Room.fromJson(document!.fields)!.boardState!;
              expect(
                stored,
                reference,
                reason: 'the shared snapshot diverged on ply $plies',
              );
              expect(
                await other.matches.readMoves(code: code),
                hasLength(plies),
                reason: 'the move log must record every applied action',
              );
            }
          }

          // A finished game, and a finished game that the server agrees on.
          final document = await blue.matches.loadMatch(code: code);
          final room = Room.fromJson(document!.fields)!;
          expect(room.status, RoomStatus.finished);
          expect(room.boardState, reference);
          expect(room.winnerId, switch (reference.winner!) {
            PlayerId.blue => 'uid-blue',
            PlayerId.red => 'uid-red',
          });
          expect(room.currentPlayerId, isNull);
          expect(
            await blue.matches.readMoves(code: code),
            hasLength(submitted),
          );

          // And nothing more may be played into it.
          final afterFinish = await blue.matches.submitAction(
            code: code,
            expectedTurnNumber: plies,
            action: GameEngine.legalActions(
              reference.copyWith(status: GameStatus.inProgress),
            ).first,
          );
          expect(
            afterFinish,
            isA<MoveRejected>(),
            reason: 'a finished match must be locked',
          );
          refused++;
          expect(refused, 1);
        });
      }
    }
  });
}
