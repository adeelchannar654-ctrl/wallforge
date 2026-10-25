import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_game_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/remote/firestore_match_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board.dart';
import 'package:wallforge/presentation/screens/online/online_game_screen.dart';

class _StubAuth implements AuthGateway {
  const _StubAuth(this.uid);
  final String uid;
  @override
  Future<AuthState> signInAnonymously() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> current() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => uid;
}

const String kBlue = 'uid-blue';
const String kRed = 'uid-red';

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  FirestoreRoomRepository roomsFor(String uid) =>
      FirestoreRoomRepository(client: store, userId: _StubAuth(uid).currentUid);

  FirestoreMatchRepository matchesFor(String uid) => FirestoreMatchRepository(
    client: store,
    userId: _StubAuth(uid).currentUid,
  );

  /// One started room with a controller per seat.
  ///
  /// A single room shared by both controllers, because creating a room per
  /// controller would make every caller the host — and so Blue, and therefore
  /// always on turn — which is exactly what these tests must be able to see.
  Future<({OnlineGameController blue, OnlineGameController red, String code})>
  startedMatch({BoardConfig config = const BoardConfig()}) async {
    final hostRooms = roomsFor(kBlue);
    final created = await hostRooms.create(config: config);
    final code = (created as RoomSuccess).room.code;
    final guestRooms = roomsFor(kRed);
    await guestRooms.join(code);
    await hostRooms.setReady(code: code, ready: true);
    await guestRooms.setReady(code: code, ready: true);
    await hostRooms.start(code);

    OnlineGameController attach(String uid) => OnlineGameController(
      rooms: roomsFor(uid),
      matches: matchesFor(uid),
      uid: uid,
      code: code,
    );

    return (blue: attach(kBlue), red: attach(kRed), code: code);
  }

  Future<void> pump(
    WidgetTester tester,
    OnlineGameController controller,
  ) async {
    await controller.connect();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnlineGameScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapBoard(WidgetTester tester, Offset localPosition) async {
    final gestureFinder = find.descendant(
      of: find.byType(BoardView),
      matching: find.byType(GestureDetector),
    );
    await tester.tapAt(tester.getTopLeft(gestureFinder) + localPosition);
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
  }

  group('both seats of one room', () {
    testWidgets('Blue is told it is their turn', (tester) async {
      final seats = await startedMatch();
      await pump(tester, seats.blue);

      expect(find.text('YOUR TURN'), findsOneWidget);
      expect(find.text("OPPONENT'S TURN"), findsNothing);
      expect(find.text('BLUE'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
      seats.blue.dispose();
      seats.red.dispose();
    });

    testWidgets('Red is told to wait, with the reason stated', (tester) async {
      final seats = await startedMatch();
      await pump(tester, seats.red);

      expect(find.text('YOUR TURN'), findsNothing);
      expect(find.text("OPPONENT'S TURN"), findsOneWidget);
      expect(
        find.textContaining("your opponent's turn"),
        findsWidgets,
        reason: 'the reason is stated, not just greyed out',
      );
      expect(find.text('RED'), findsOneWidget);
      expect(find.text('YOU'), findsOneWidget);
      seats.blue.dispose();
      seats.red.dispose();
    });

    testWidgets('input is offered only on your own turn', (tester) async {
      final seats = await startedMatch();

      await pump(tester, seats.blue);
      expect(seats.blue.legalMoveTargets, isNotEmpty);

      await pump(tester, seats.red);
      expect(
        seats.red.legalMoveTargets,
        isEmpty,
        reason: 'no move targets when it is not your turn',
      );
      seats.blue.dispose();
      seats.red.dispose();
    });

    testWidgets('tapping a legal board cell submits and applies a move', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final seats = await startedMatch();
      await pump(tester, seats.blue);

      const destination = Cell(row: 7, column: 4);
      final geometry = BoardGeometry(
        boardSize: seats.blue.state.boardConfig.size,
        areaSize: tester
            .getSize(
              find.descendant(
                of: find.byType(BoardView),
                matching: find.byType(CustomPaint),
              ),
            )
            .width,
      );
      expect(seats.blue.isMyTurn, isTrue);
      expect(seats.blue.isInteractionBlocked, isFalse);
      expect(
        tester.widget<BoardView>(find.byType(BoardView)).onCellTap,
        isNotNull,
      );
      await tapBoard(tester, geometry.cellCenterFromModel(destination));

      expect(seats.blue.state.pawnPosition(PlayerId.blue), destination);
      expect(seats.blue.state.turnNumber, 1);
      seats.blue.dispose();
      seats.red.dispose();
    });

    testWidgets('tapping and confirming a wall slot places the wall', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final seats = await startedMatch();
      await pump(tester, seats.blue);
      await tester.tap(find.text('WALL'));
      await tester.pumpAndSettle();

      final canvasFinder = find.descendant(
        of: find.byType(BoardView),
        matching: find.byType(CustomPaint),
      );
      const anchor = Cell(row: 3, column: 3);
      final geometry = BoardGeometry(
        boardSize: seats.blue.state.boardConfig.size,
        areaSize: tester.getSize(canvasFinder).width,
      );
      await tapBoard(
        tester,
        geometry.wallRect(anchor.row, anchor.column, WallOrientation.h).center,
      );

      expect(seats.blue.pendingWall, isNotNull);
      expect(find.text('PLACE WALL'), findsOneWidget);
      await tester.tap(find.text('PLACE WALL'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(
        seats.blue.state.wallsRemaining(PlayerId.blue),
        seats.blue.state.boardConfig.wallsPerPlayer - 1,
      );
      expect(seats.blue.state.turnNumber, 1);
      seats.blue.dispose();
      seats.red.dispose();
    });

    testWidgets('wall placement works at a phone-width layout', (tester) async {
      // Below the 768px breakpoint the screen uses its narrow layout, which
      // must still offer the WALL toggle and the PLACE WALL action —
      // otherwise a phone-width player can move but can never place a wall.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final seats = await startedMatch();
      await pump(tester, seats.blue);

      expect(find.text('WALL'), findsOneWidget);
      await tester.tap(find.text('WALL'));
      await tester.pumpAndSettle();

      final canvasFinder = find.descendant(
        of: find.byType(BoardView),
        matching: find.byType(CustomPaint),
      );
      const anchor = Cell(row: 3, column: 3);
      final geometry = BoardGeometry(
        boardSize: seats.blue.state.boardConfig.size,
        areaSize: tester.getSize(canvasFinder).width,
      );
      await tapBoard(
        tester,
        geometry.wallRect(anchor.row, anchor.column, WallOrientation.h).center,
      );

      expect(seats.blue.pendingWall, isNotNull);
      expect(find.text('PLACE WALL'), findsOneWidget);
      await tester.tap(find.text('PLACE WALL'));
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(
        seats.blue.state.wallsRemaining(PlayerId.blue),
        seats.blue.state.boardConfig.wallsPerPlayer - 1,
      );
      expect(seats.blue.state.turnNumber, 1);
      seats.blue.dispose();
      seats.red.dispose();
    });

    testWidgets('a real board tap is ignored when it is not your turn', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final seats = await startedMatch();
      await seats.blue.submit(const GameAction.move(Cell(row: 7, column: 4)));
      await pump(tester, seats.blue);

      final before = seats.blue.state;
      final geometry = BoardGeometry(
        boardSize: before.boardConfig.size,
        areaSize: tester
            .getSize(
              find.descendant(
                of: find.byType(BoardView),
                matching: find.byType(CustomPaint),
              ),
            )
            .width,
      );
      await tapBoard(tester, geometry.cellCenter(6, 4));

      expect(seats.blue.isMyTurn, isFalse);
      expect(seats.blue.state, before);
      seats.blue.dispose();
      seats.red.dispose();
    });

    testWidgets('the room code is shown so players can agree they are in the '
        'same match', (tester) async {
      final seats = await startedMatch();
      await pump(tester, seats.blue);
      expect(find.text(seats.code), findsOneWidget);
      seats.blue.dispose();
      seats.red.dispose();
    });
  });

  group('connection chip', () {
    testWidgets('CONNECTED once the match is live', (tester) async {
      final seats = await startedMatch();
      await pump(tester, seats.blue);
      expect(find.text('CONNECTED'), findsOneWidget);
      seats.blue.dispose();
    });

    testWidgets('RECONNECTING when the snapshot is cached', (tester) async {
      final seats = await startedMatch();
      await pump(tester, seats.blue);
      store.goOffline();
      await tester.pumpAndSettle();
      expect(find.text('RECONNECTING'), findsOneWidget);
      seats.blue.dispose();
    });

    testWidgets('the state is exposed to assistive technology', (tester) async {
      final seats = await startedMatch();
      await pump(tester, seats.blue);
      expect(
        find.bySemanticsLabel(RegExp('Connection')),
        findsOneWidget,
        reason: 'the state must not be conveyed by colour alone',
      );
      seats.blue.dispose();
    });
  });

  group('layout', () {
    for (final size in <(String, Size)>[
      ('320x568', const Size(320, 568)),
      ('390x844', const Size(390, 844)),
      ('768x1024', const Size(768, 1024)),
      ('1440x900', const Size(1440, 900)),
    ]) {
      testWidgets('no overflow at ${size.$1}', (tester) async {
        tester.view.physicalSize = size.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final seats = await startedMatch();
        await pump(tester, seats.blue);
        expect(tester.takeException(), isNull);
        seats.blue.dispose();
      });
    }
  });

  group('ownership', () {
    testWidgets('a screen that owns its controller disposes it', (
      tester,
    ) async {
      final controller = (await startedMatch()).blue;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: OnlineGameScreen(controller: controller, ownsController: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // A disposed ChangeNotifier refuses further use in debug builds.
      expect(() => controller.addListener(() {}), throwsA(anything));
    });
  });
}
