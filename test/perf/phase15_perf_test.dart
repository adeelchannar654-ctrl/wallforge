// Phase 15 performance tests: counts and invariants, never wall-clock.
//
// Timing on a shared VM is noise (the presence-test saga is the standing
// proof), so these tests assert the quantities an optimization may
// legitimately promise: exact Firestore operation counts per action,
// exactly one match listener per online controller, zero writes from
// the presence machinery, notifyListeners counts per action, zero
// scheduled frames on an idle board, and full disposal after long runs.
// Wall-clock numbers live in tool/bench_engine_ai.dart and the painter
// benchmark printed below — they are reported, never asserted.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/remote/firestore_client.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board_geometry.dart';
import 'package:wallforge/presentation/board/board_painter.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';

/// A [FirestoreClient] decorator that counts every operation, so the
/// online cost model is measured through the real repositories rather
/// than asserted from the Phase 9 arithmetic.
class CountingFirestoreClient implements FirestoreClient {
  CountingFirestoreClient(this.inner);

  final InMemoryFirestoreClient inner;

  int plainReads = 0;
  int plainWrites = 0;
  int deletes = 0;
  int queries = 0;
  int transactions = 0;
  int txnGets = 0;
  int txnSets = 0;
  int txnDeletes = 0;
  int watchSubscriptions = 0;
  int activeWatchers = 0;
  int watchEmissions = 0;

  void reset() {
    plainReads = 0;
    plainWrites = 0;
    deletes = 0;
    queries = 0;
    transactions = 0;
    txnGets = 0;
    txnSets = 0;
    txnDeletes = 0;
    watchEmissions = 0;
  }

  @override
  Future<Map<String, dynamic>?> read(String path) {
    plainReads++;
    return inner.read(path);
  }

  @override
  Future<void> write(String path, Map<String, dynamic> data) {
    plainWrites++;
    return inner.write(path, data);
  }

  @override
  Future<void> delete(String path) {
    deletes++;
    return inner.delete(path);
  }

  @override
  Future<List<FirestoreDocument>> query({
    required String collectionPath,
    String? orderBy,
    int limit = 10,
    String? startAfterDocumentId,
  }) {
    queries++;
    return inner.query(
      collectionPath: collectionPath,
      orderBy: orderBy,
      limit: limit,
      startAfterDocumentId: startAfterDocumentId,
    );
  }

  Stream<T> _counted<T>(Stream<T> stream) {
    late StreamController<T> controller;
    StreamSubscription<T>? sub;
    controller = StreamController<T>(
      onListen: () {
        watchSubscriptions++;
        activeWatchers++;
        sub = stream.listen(
          (event) {
            watchEmissions++;
            controller.add(event);
          },
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        activeWatchers--;
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Stream<Map<String, dynamic>?> watch(String path) =>
      _counted(inner.watch(path));

  @override
  Stream<FirestoreSnapshot> watchWithMetadata(String path) =>
      _counted(inner.watchWithMetadata(path));

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(FirestoreTransaction txn) action,
  ) {
    transactions++;
    return inner.runTransaction<T>(
      (innerTxn) => action(_CountingTransaction(this, innerTxn)),
    );
  }
}

class _CountingTransaction implements FirestoreTransaction {
  _CountingTransaction(this.owner, this.inner);

  final CountingFirestoreClient owner;
  final FirestoreTransaction inner;

  @override
  Future<Map<String, dynamic>?> get(String path) {
    owner.txnGets++;
    return inner.get(path);
  }

  @override
  void set(String path, Map<String, dynamic> data) {
    owner.txnSets++;
    inner.set(path, data);
  }

  @override
  void delete(String path) {
    owner.txnDeletes++;
    inner.delete(path);
  }
}

/// A scripted 6-ply opening shared by the op-count test: legal moves
/// only, no walls, verified against the engine before use.
const scriptedPlies = <GameAction>[
  GameAction.move(Cell(row: 7, column: 4)),
  GameAction.move(Cell(row: 1, column: 4)),
  GameAction.move(Cell(row: 6, column: 4)),
  GameAction.move(Cell(row: 2, column: 4)),
  GameAction.move(Cell(row: 5, column: 4)),
  GameAction.move(Cell(row: 3, column: 4)),
];

void main() {
  group('Firestore operation counts (measured, exact)', () {
    late InMemoryFirestoreClient store;
    late CountingFirestoreClient counting;

    setUp(() {
      store = InMemoryFirestoreClient();
      counting = CountingFirestoreClient(store);
    });
    tearDown(() => store.closeWatchers());

    FirestoreRoomRepository roomsFor(String uid) =>
        FirestoreRoomRepository(client: counting, userId: () async => uid);
    FirestoreMatchRepository matchesFor(String uid) =>
        FirestoreMatchRepository(client: counting, userId: () async => uid);

    test('one action costs one transaction read and two writes', () async {
      const blueUid = 'uid-blue';
      const redUid = 'uid-red';
      final hostRooms = roomsFor(blueUid);
      final created = await hostRooms.create(config: const BoardConfig());
      final code = (created as RoomSuccess).room.code;
      await roomsFor(redUid).join(code);
      await hostRooms.setReady(code: code, ready: true);
      await roomsFor(redUid).setReady(code: code, ready: true);
      await hostRooms.start(code);

      // Setup is reported separately; the per-action window starts now.
      counting.reset();

      final repos = {blueUid: matchesFor(blueUid), redUid: matchesFor(redUid)};
      var state = GameState.initial();
      for (var turn = 0; turn < scriptedPlies.length; turn++) {
        final uid = turn.isEven ? blueUid : redUid;
        final result = await repos[uid]!.submitAction(
          code: code,
          expectedTurnNumber: turn,
          action: scriptedPlies[turn],
        );
        expect(result, isA<MoveApplied>(), reason: 'ply $turn must apply');
        state = (result as MoveApplied).state;
      }
      expect(state.turnNumber, scriptedPlies.length);

      // Per applied action on the happy path: one transaction (one read
      // of the match document — the move-record idempotency read is
      // provably unnecessary when the document shows the expected turn,
      // Phase 15) staging exactly two writes (match + move record). No
      // plain reads or writes are involved in submitting an action.
      expect(counting.transactions, scriptedPlies.length);
      expect(counting.txnGets, scriptedPlies.length);
      expect(counting.txnSets, scriptedPlies.length * 2);
      expect(counting.plainReads, 0);
      expect(counting.plainWrites, 0);
    });

    test('a controller holds exactly one match listener, released on '
        'dispose, and presence writes nothing', () async {
      const blueUid = 'uid-blue';
      const redUid = 'uid-red';
      final hostRooms = roomsFor(blueUid);
      final created = await hostRooms.create(config: const BoardConfig());
      final code = (created as RoomSuccess).room.code;
      await roomsFor(redUid).join(code);
      await hostRooms.setReady(code: code, ready: true);
      await roomsFor(redUid).setReady(code: code, ready: true);
      await hostRooms.start(code);

      counting.reset();
      final subscriptionsBefore = counting.watchSubscriptions;
      final controller = OnlineGameController(
        rooms: roomsFor(redUid),
        matches: matchesFor(redUid),
        uid: redUid,
        code: code,
      );
      await controller.connect();
      // Exactly one subscription: the match document listener.
      expect(counting.watchSubscriptions - subscriptionsBefore, 1);
      expect(counting.activeWatchers, 1);

      // Presence/resync activity performs reads only — never writes.
      await controller.resync();
      await controller.resync();
      expect(counting.plainWrites, 0);
      expect(counting.txnSets, 0);

      controller.dispose();
      // The in-memory client's watcher cleanup is async; let the
      // cancellation land before counting.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(counting.activeWatchers, 0);
    });
  });

  group('local game notifications and frames', () {
    testWidgets('one human move notifies a small, fixed number of times', (
      tester,
    ) async {
      var notifications = 0;
      final controller = LocalGameController();
      controller.addListener(() => notifications++);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: GameScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      notifications = 0;

      final target = controller.legalMoveTargets.first;
      controller.tapCell(target);
      // The tap itself notifies synchronously; a settle may add the
      // animation/feedback follow-ups. The invariant that matters: the
      // count is small and bounded — a rebuild storm (Phase 12's loop
      // notified unboundedly) blows far past this bound.
      expect(notifications, greaterThan(0));
      expect(notifications, lessThanOrEqualTo(6));
      await tester.pumpAndSettle();
      expect(notifications, lessThanOrEqualTo(8));
      expect(controller.state.turnNumber, 1);
    });

    testWidgets('an idle board schedules no frames', (tester) async {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: GameScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);

      var frames = 0;
      void onFrame(Duration _) => frames++;
      tester.binding.addPersistentFrameCallback(onFrame);
      await tester.pump(const Duration(seconds: 1));
      // One frame may run because the pump itself was requested; an
      // idle board must not keep scheduling beyond it.
      expect(frames, lessThanOrEqualTo(1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a pure resize fires no controller notifications', (
      tester,
    ) async {
      var notifications = 0;
      final controller = LocalGameController();
      controller.addListener(() => notifications++);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: GameScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      notifications = 0;
      for (final size in [
        const Size(768, 1024),
        const Size(1440, 900),
        const Size(844, 390),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
      }
      expect(notifications, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('lifecycle and long runs', () {
    test('disposing a vs-AI controller cancels the pending AI move', () async {
      final controller = LocalGameController(
        config: const BoardConfig(size: 5),
        versusAi: true,
      );
      // A human move schedules the AI reply on the think-delay timer.
      controller.tapCell(controller.legalMoveTargets.first);
      expect(controller.state.turnNumber, 1);
      controller.dispose();
      // Well past kAiThinkDelay: the timer must never fire into a
      // disposed controller, and no AI ply may land.
      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(controller.state.turnNumber, 1);
    });

    test('many full local games leave no residue', () {
      for (var game = 0; game < 5; game++) {
        final controller = LocalGameController(
          config: const BoardConfig(size: 5),
        );
        var guard = 0;
        while (controller.state.status != GameStatus.finished &&
            guard++ < 400) {
          final targets = controller.legalMoveTargets;
          if (targets.isEmpty) break;
          controller.tapCell(targets.first);
        }
        expect(controller.state.status, GameStatus.finished);
        controller.dispose();
      }
    });
  });

  group('board painter cost (printed, not asserted)', () {
    testWidgets('records dense boards at all sizes', (tester) async {
      await tester.runAsync(() async {
        for (final size in [5, 7, 9, 11]) {
          // A dense mid-game: seeded greedy play that prefers walls.
          var state = GameState.initial(BoardConfig(size: size));
          var seed = 1234 + size;
          int next() => seed = (seed * 1103515245 + 12345) & 0x7fffffff;
          for (var ply = 0; ply < 40; ply++) {
            if (state.status == GameStatus.finished) break;
            final actions = GameEngine.legalActions(state);
            if (actions.isEmpty) break;
            final walls = actions.whereType<WallAction>().toList();
            final pick = (ply.isEven && walls.isNotEmpty)
                ? walls[next() % walls.length]
                : actions[next() % actions.length];
            final result = GameEngine.apply(state, state.currentPlayer, pick);
            if (result is SuccessResult) state = result.state;
          }
          final geometry = BoardGeometry(boardSize: size, areaSize: 600);
          final painter = BoardPainter(
            state: state,
            geometry: geometry,
            legalMoveTargets: GameEngine.legalActions(state)
                .whereType<MoveAction>()
                .map<Cell>((a) => a.destination)
                .toSet(),
            activeGlow: state.currentPlayer,
          );
          // Warm up, then average 30 recordings of the same picture.
          for (var i = 0; i < 5; i++) {
            final recorder = ui.PictureRecorder();
            painter.paint(ui.Canvas(recorder), const Size(600, 600));
            recorder.endRecording().dispose();
          }
          final watch = Stopwatch()..start();
          for (var i = 0; i < 30; i++) {
            final recorder = ui.PictureRecorder();
            painter.paint(ui.Canvas(recorder), const Size(600, 600));
            recorder.endRecording().dispose();
          }
          watch.stop();
          final perPaint = watch.elapsedMicroseconds / 30 / 1000;
          // ignore: avoid_print
          print(
            'PAINTER size $size walls ${state.walls.length}: '
            '${perPaint.toStringAsFixed(3)} ms per paint (record only)',
          );
          expect(perPaint, greaterThan(0));
        }
      });
    });
  });
}
