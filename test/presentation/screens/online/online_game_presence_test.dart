import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/online/online_game_screen.dart';

/// Phase 10's opponent-presence UI: the stalled banner, the claim action
/// with its confirmation, and the abandoned terminal state.
///
/// The in-memory store's document is rewritten with an old `updatedAt` to
/// put the match into the stalled state the controller derives — the same
/// fact the live system would present after two silent minutes.
void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  const blueUid = 'uid-blue';
  const redUid = 'uid-red';

  FirestoreRoomRepository roomsFor(String uid) =>
      FirestoreRoomRepository(client: store, userId: () async => uid);

  FirestoreMatchRepository matchesFor(String uid) =>
      FirestoreMatchRepository(client: store, userId: () async => uid);

  /// A started match, aged so Blue (to move) looks long gone to Red.
  Future<({OnlineGameController blue, OnlineGameController red, String code})>
  stalledMatch() async {
    final hostRooms = roomsFor(blueUid);
    final created = await hostRooms.create(config: const BoardConfig());
    final code = (created as RoomSuccess).room.code;
    final guestRooms = roomsFor(redUid);
    await guestRooms.join(code);
    await hostRooms.setReady(code: code, ready: true);
    await guestRooms.setReady(code: code, ready: true);
    await hostRooms.start(code);

    // Age the stored document past the inactivity threshold. Same version,
    // same state — only the timestamp moves, exactly what two silent
    // minutes would produce.
    final stored = await matchesFor(blueUid).loadMatch(code: code);
    final room = Room.fromJson(stored!.fields)!;
    final aged = room.copyWith(
      updatedAtMs:
          DateTime.now().millisecondsSinceEpoch -
          opponentInactivityThreshold.inMilliseconds -
          1000,
    );
    await store.write('matches/$code', aged.toJson());

    OnlineGameController attach(String uid) => OnlineGameController(
      rooms: roomsFor(uid),
      matches: matchesFor(uid),
      uid: uid,
      code: code,
    );
    final blue = attach(blueUid);
    final red = attach(redUid);
    return (blue: blue, red: red, code: code);
  }

  /// The controllers own a presence timer, which the widget-test binding
  /// requires to be gone before the test body ends — so disposal is an
  /// explicit last step in each test, not a tearDown.
  void disposeMatch(
    ({OnlineGameController blue, OnlineGameController red, String code}) match,
  ) {
    match.blue.dispose();
    match.red.dispose();
  }

  // Controllers this helper has already connected. `connect()` awaits the
  // previous subscription's cancellation, which never completes inside a
  // fake-async test zone when the underlying watch stream is idle — so a
  // second connect on the same controller deadlocks the test. (In the app
  // each controller is connected exactly once, so this is a harness rule,
  // not an app workaround.) The size-loop test resizes one live controller,
  // which is also the realistic case: a resize is not a reconnect.
  final connectedOnce = <OnlineGameController>{};

  Future<void> pump(
    WidgetTester tester,
    OnlineGameController controller,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (connectedOnce.add(controller)) await controller.connect();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnlineGameScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The project's standard layout sizes, matching the online screen's own
  // layout test group.
  const sizes = [
    Size(320, 568),
    Size(390, 844),
    Size(768, 1024),
    Size(1440, 900),
  ];

  testWidgets('the stalled banner and claim action show at every size', (
    tester,
  ) async {
    final match = await stalledMatch();
    for (final size in sizes) {
      await pump(tester, match.red, size);
      expect(
        find.text('Your opponent seems to have disconnected.'),
        findsWidgets,
        reason: 'size $size',
      );
      expect(
        find.text('CLAIM MATCH AS ABANDONED'),
        findsWidgets,
        reason: 'size $size',
      );
      expect(tester.takeException(), isNull, reason: 'size $size');
    }
    disposeMatch(match);
  });

  testWidgets('the banner is absent while the opponent is active', (
    tester,
  ) async {
    final hostRooms = roomsFor(blueUid);
    final created = await hostRooms.create(config: const BoardConfig());
    final code = (created as RoomSuccess).room.code;
    await roomsFor(redUid).join(code);
    await hostRooms.setReady(code: code, ready: true);
    await roomsFor(redUid).setReady(code: code, ready: true);
    await hostRooms.start(code);
    final red = OnlineGameController(
      rooms: roomsFor(redUid),
      matches: matchesFor(redUid),
      uid: redUid,
      code: code,
    );
    await pump(tester, red, const Size(390, 844));
    expect(
      find.text('Your opponent seems to have disconnected.'),
      findsNothing,
    );
    expect(find.text('CLAIM MATCH AS ABANDONED'), findsNothing);
    red.dispose();
  });

  testWidgets('claiming through the confirmation ends the match', (
    tester,
  ) async {
    final match = await stalledMatch();
    await pump(tester, match.red, const Size(390, 844));

    await tester.tap(find.text('CLAIM MATCH AS ABANDONED').first);
    await tester.pumpAndSettle();
    expect(find.text('Claim match as abandoned?'), findsOneWidget);

    await tester.tap(find.text('CLAIM'));
    await tester.pumpAndSettle();

    expect(find.text('MATCH ABANDONED'), findsWidgets);
    expect(
      find.textContaining('You claimed this match as abandoned'),
      findsWidgets,
    );
    final stored = await matchesFor(blueUid).loadMatch(code: match.code);
    expect(Room.fromJson(stored!.fields)!.status, RoomStatus.abandoned);
    disposeMatch(match);
  });

  testWidgets('cancelling the confirmation leaves the match running', (
    tester,
  ) async {
    final match = await stalledMatch();
    await pump(tester, match.red, const Size(1024, 900));

    await tester.tap(find.text('CLAIM MATCH AS ABANDONED').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('KEEP WAITING'));
    await tester.pumpAndSettle();

    expect(find.text('MATCH ABANDONED'), findsNothing);
    final stored = await matchesFor(blueUid).loadMatch(code: match.code);
    expect(Room.fromJson(stored!.fields)!.status, RoomStatus.started);
    disposeMatch(match);
  });

  testWidgets('the claimed player sees the abandoned state, not a win', (
    tester,
  ) async {
    final match = await stalledMatch();
    await matchesFor(redUid).claimAbandonment(code: match.code);
    await pump(tester, match.blue, const Size(390, 844));

    expect(find.text('MATCH ABANDONED'), findsWidgets);
    expect(
      find.text('Your opponent claimed this match as abandoned.'),
      findsWidgets,
    );
    expect(find.textContaining('WINS!'), findsNothing);
    disposeMatch(match);
  });
}
