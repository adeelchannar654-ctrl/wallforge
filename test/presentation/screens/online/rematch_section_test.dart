// Phase 16 C.2: OnlineRematchSection had zero coverage despite
// being the shipped rematch UI. These widget tests drive it through
// its two user-visible flows with repository fakes (the controller's
// own logic is covered in rematch_controller_test).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/rematch_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/online/online_rematch_section.dart';

class _FakeMatchmaking implements MatchmakingRepository {
  // Closed in the tests' tearDown; the lint cannot see across the
  // setUp/tearDown pair.
  // ignore: close_sinks
  final StreamController<Room?> matched = StreamController<Room?>.broadcast();
  List<String> waitingUids = const [];
  String? claimedCandidate;

  @override
  Future<MatchmakingResult> findMatch({required BoardConfig config}) async =>
      const MatchQueued();
  @override
  Future<void> joinQueue({required BoardConfig config}) async {}
  @override
  Future<List<String>> waitingPlayerIds({required BoardConfig config}) async =>
      waitingUids;
  @override
  Future<MatchmakingResult> claimPlayer({
    required BoardConfig config,
    required String candidateUid,
  }) async {
    claimedCandidate = candidateUid;
    return MatchFound(_room(code: 'NEW123', createdAtMs: 2000));
  }

  @override
  Stream<Room?> watchForMatch({
    required BoardConfig config,
    required String uid,
  }) => matched.stream;
  @override
  Future<void> cancel({required BoardConfig config}) async {}
}

class _FakeRooms implements RoomRepository {
  @override
  Future<RoomResult> leave(String code) async =>
      RoomResult.success(_room(code: code, createdAtMs: 0));
  @override
  Future<RoomResult> create({required BoardConfig config}) =>
      throw UnimplementedError();
  @override
  Future<RoomResult> join(String code) => throw UnimplementedError();
  @override
  Future<RoomResult> setReady({required String code, required bool ready}) =>
      throw UnimplementedError();
  @override
  Future<RoomResult> start(String code) => throw UnimplementedError();
  @override
  Future<Room?> load(String code) async => null;
  @override
  Stream<Room?> watch(String code) => const Stream<Room?>.empty();
}

Room _room({required String code, required int createdAtMs}) => Room(
  code: code,
  status: RoomStatus.waiting,
  boardConfig: const BoardConfig(),
  hostId: 'uid-me',
  blue: const RoomSeat(playerId: 'uid-me'),
  red: const RoomSeat(playerId: 'uid-opp'),
  createdAtMs: createdAtMs,
  updatedAtMs: createdAtMs,
);

void main() {
  late _FakeMatchmaking matchmaking;
  late RematchController controller;
  Room? matchedRoom;

  setUp(() {
    matchmaking = _FakeMatchmaking();
    matchedRoom = null;
    controller = RematchController(
      matchmaking: matchmaking,
      rooms: _FakeRooms(),
      myUid: 'uid-me',
      opponentUid: 'uid-opp',
      config: const BoardConfig(),
      finishedCode: 'OLD123',
      finishedCreatedAtMs: 1000,
      pollInterval: const Duration(milliseconds: 30),
    );
  });
  tearDown(() async {
    controller.dispose();
    await matchmaking.matched.close();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: OnlineRematchSection(
            controller: controller,
            onMatched: (room) => matchedRoom = room,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('propose, wait, and report the matched room', (tester) async {
    await pumpSection(tester);
    expect(find.text('REMATCH'), findsOneWidget);

    await tester.tap(find.text('REMATCH'));
    await tester.pump();
    expect(find.textContaining('Rematch proposed'), findsOneWidget);
    expect(find.text('CANCEL PROPOSAL'), findsOneWidget);

    matchmaking.matched.add(_room(code: 'NEW123', createdAtMs: 2000));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
    expect(matchedRoom?.code, 'NEW123');
  });

  testWidgets('an opponent proposal can be accepted', (tester) async {
    matchmaking.waitingUids = ['uid-opp'];
    await pumpSection(tester);
    // The controller polls and surfaces the proposal.
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(find.text('Your opponent wants a rematch.'), findsOneWidget);

    await tester.tap(find.text('ACCEPT REMATCH'));
    await tester.pumpAndSettle();
    expect(matchmaking.claimedCandidate, 'uid-opp');
    expect(matchedRoom?.code, 'NEW123');
  });
}
