import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/rematch_controller.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 11, Q-9.2: the rematch negotiation.
///
/// The contract under test: a rematch is a NEW room with fresh seats and an
/// explicit consent step from both players; nobody is moved automatically;
/// a proposal can lapse; and a stranger's Quick Match claim on a proposal
/// is detected and reported instead of silently seating the wrong opponent.
class _FakeMatchmaking implements MatchmakingRepository {
  // Closed in the test's tearDown; the sink outlives any single method.
  // ignore: close_sinks
  final StreamController<Room?> matched = StreamController<Room?>.broadcast();
  Set<String> waitingUids = <String>{};
  MatchmakingResult claimResult = const MatchmakingResult.rejected(
    MatchmakingFailure(MatchmakingFailureReason.pairingFailed, 'not set'),
  );
  String? claimedCandidate;
  int joinQueueCalls = 0;
  int cancelCalls = 0;

  @override
  Future<MatchmakingResult> findMatch({required BoardConfig config}) async =>
      const MatchQueued();

  @override
  Future<void> joinQueue({required BoardConfig config}) async {
    joinQueueCalls++;
  }

  @override
  Future<List<String>> waitingPlayerIds({required BoardConfig config}) async =>
      waitingUids.toList();

  @override
  Future<MatchmakingResult> claimPlayer({
    required BoardConfig config,
    required String candidateUid,
  }) async {
    claimedCandidate = candidateUid;
    return claimResult;
  }

  @override
  Stream<Room?> watchForMatch({
    required BoardConfig config,
    required String uid,
  }) => matched.stream;

  @override
  Future<void> cancel({required BoardConfig config}) async {
    cancelCalls++;
  }
}

class _FakeRooms implements RoomRepository {
  final List<String> leftCodes = <String>[];

  @override
  Future<RoomResult> leave(String code) async {
    leftCodes.add(code);
    return RoomResult.success(_room(code: code, createdAtMs: 0));
  }

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

Room _room({
  required String code,
  required int createdAtMs,
  String blue = 'uid-me',
  String red = 'uid-opp',
  RoomStatus status = RoomStatus.waiting,
}) {
  return Room(
    code: code,
    status: status,
    boardConfig: const BoardConfig(),
    hostId: blue,
    blue: RoomSeat(playerId: blue),
    red: RoomSeat(playerId: red),
    createdAtMs: createdAtMs,
    updatedAtMs: createdAtMs,
  );
}

void main() {
  late _FakeMatchmaking matchmaking;
  late _FakeRooms rooms;
  late RematchController controller;

  setUp(() {
    matchmaking = _FakeMatchmaking();
    rooms = _FakeRooms();
    controller = RematchController(
      matchmaking: matchmaking,
      rooms: rooms,
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

  Future<void> tick([int times = 3]) async {
    for (var i = 0; i < times; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  test('an opponent already waiting reads as a proposal', () async {
    matchmaking.waitingUids = <String>{'uid-opp'};
    controller.start();
    await tick();
    expect(controller.phase, RematchPhase.proposalAvailable);
  });

  test('accept claims the opponent and reports the new room', () async {
    final fresh = _room(code: 'NEW456', createdAtMs: 2000, blue: 'uid-opp');
    matchmaking.claimResult = MatchFound(fresh);
    matchmaking.waitingUids = <String>{'uid-opp'};
    controller.start();
    await tick();
    expect(controller.phase, RematchPhase.proposalAvailable);

    await controller.accept();
    expect(matchmaking.claimedCandidate, 'uid-opp');
    expect(controller.phase, RematchPhase.matched);
    expect(controller.matchedRoom, fresh);
  });

  test('propose announces, then a pairing on the watch completes it', () async {
    controller.start();
    await controller.propose();
    expect(matchmaking.joinQueueCalls, 1);
    expect(controller.phase, RematchPhase.proposing);

    final fresh = _room(
      code: 'NEW456',
      createdAtMs: 2000,
      blue: 'uid-opp',
      red: 'uid-me',
    );
    matchmaking.matched.add(fresh);
    await tick();
    expect(controller.phase, RematchPhase.matched);
    expect(controller.matchedRoom?.code, 'NEW456');
  });

  test('decline is remembered: the same proposal does not resurface', () async {
    matchmaking.waitingUids = <String>{'uid-opp'};
    controller.start();
    await tick();
    expect(controller.phase, RematchPhase.proposalAvailable);

    controller.decline();
    expect(controller.phase, RematchPhase.idle);
    await tick(4);
    expect(
      controller.phase,
      RematchPhase.idle,
      reason: 'a declined proposal stays declined for this result screen',
    );
  });

  test('a proposal lapses when the opponent leaves the queue', () async {
    matchmaking.waitingUids = <String>{'uid-opp'};
    controller.start();
    await tick();
    expect(controller.phase, RematchPhase.proposalAvailable);

    matchmaking.waitingUids = <String>{};
    await tick(4);
    expect(controller.phase, RematchPhase.idle);
  });

  test('cancelProposal withdraws the queue entry', () async {
    controller.start();
    await controller.propose();
    expect(controller.phase, RematchPhase.proposing);
    await controller.cancelProposal();
    expect(matchmaking.cancelCalls, 1);
    expect(controller.phase, RematchPhase.idle);
  });

  test(
    'the finished room on the watch is ignored, as are older rooms',
    () async {
      controller.start();
      await controller.propose();
      matchmaking.matched.add(_room(code: 'OLD123', createdAtMs: 1000));
      matchmaking.matched.add(_room(code: 'OLDER9', createdAtMs: 500));
      await tick();
      expect(controller.phase, RematchPhase.proposing);
      expect(controller.matchedRoom, isNull);
    },
  );

  test('a stranger claiming the proposal is detected and left', () async {
    controller.start();
    await controller.propose();
    final hijacked = _room(
      code: 'HIJACK',
      createdAtMs: 2000,
      red: 'uid-stranger',
    );
    matchmaking.matched.add(hijacked);
    await tick();
    expect(rooms.leftCodes, <String>['HIJACK']);
    expect(controller.phase, RematchPhase.unavailable);
    expect(controller.message, isNotNull);
  });

  test('an unrelated matched room while idle is ignored', () async {
    controller.start();
    matchmaking.matched.add(
      _room(code: 'OTHER1', createdAtMs: 2000, red: 'uid-stranger'),
    );
    await tick();
    expect(controller.phase, RematchPhase.idle);
    expect(rooms.leftCodes, isEmpty);
  });
}
