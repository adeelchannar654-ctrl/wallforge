import 'dart:async';

import '../../domain/models/board_config.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/player_id.dart';
import '../../domain/repositories/repositories.dart';
import 'firestore_client.dart';
import 'firestore_settings_repository.dart' show UserIdResolver;
import 'room_code_generator.dart';

/// Firestore-backed [RoomRepository].
///
/// ## Document layout
///
/// One document per room, at `matches/{code}`, extending `architecture.md` §11's
/// conceptual `matches/{matchId}` structure with the Phase 8 lifecycle fields.
/// The room code is the document id, so joining is a single document read: no
/// query, no index, no collection scan.
///
/// ## Free-tier discipline
///
/// Verified against current Firestore documentation rather than assumed:
/// real-time listeners are billed as document reads, one per document added or
/// updated in the listener's result set. So the lobby holds exactly one listener
/// on one document, and every write below is a real state change a player asked
/// for — there is no polling and no periodic write in this file. The no-cost
/// quota is 50,000 reads/day and 20,000 writes/day.
class FirestoreRoomRepository implements RoomRepository {
  FirestoreRoomRepository({
    required this.client,
    required this.userId,
    RoomCodeGenerator? codeGenerator,
    this.collection = 'matches',
    this.maxCodeAttempts = 5,
    DateTime Function()? clock,
  }) : codeGenerator = codeGenerator ?? RandomRoomCodeGenerator(),
       _clock = clock ?? DateTime.now;

  /// Document transport.
  final FirestoreClient client;

  /// Resolves the caller. This is the Phase 6/7 `UserIdResolver` seam, now fed a
  /// real authenticated uid.
  final UserIdResolver userId;

  /// Source of candidate codes; injectable so collisions are testable.
  final RoomCodeGenerator codeGenerator;

  /// Top-level collection name, per `architecture.md` §11.
  final String collection;

  /// How many codes to try before giving up on a collision-free room.
  final int maxCodeAttempts;

  final DateTime Function() _clock;

  int get _nowMs => _clock().millisecondsSinceEpoch;

  /// The document path for a code, or null when the code is malformed.
  String? _path(String code) {
    final parsed = RoomCode.tryParse(code);
    if (parsed == null) return null;
    return '$collection/${parsed.value}';
  }

  @override
  Future<RoomResult> create({required BoardConfig config}) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return _notAuthenticated;
    if (!config.isValid) {
      return RoomResult.failure(
        RoomFailureReason.invalidRoomDocument,
        message: config.failure?.message,
      );
    }

    // A read-then-write cannot be made atomic without a transaction or a Cloud
    // Function, and Cloud Functions would need the Blaze plan (`architecture.md`
    // §10 forbids depending on them). So rather than pretend the check is
    // atomic, the write is *verified* afterwards: if another creator took the
    // same code between our read and our write, the confirming re-read shows a
    // different host and we try again. That closes the race instead of
    // documenting it away.
    for (var attempt = 0; attempt < maxCodeAttempts; attempt++) {
      final parsed = RoomCode.tryParse(codeGenerator.generate());
      if (parsed == null) continue; // generator misbehaved; skip the candidate
      final path = '$collection/${parsed.value}';

      if (await _read(path) != null) continue; // taken, try another

      final now = _nowMs;
      final room = Room(
        code: parsed.value,
        status: RoomStatus.waiting,
        boardConfig: config,
        hostId: uid,
        // The creator takes Blue: Blue moves first (R-PLAYER-07), and the
        // existing local code already treats Blue as the first player (Q-6.2).
        blue: RoomSeat(playerId: uid),
        red: RoomSeat.empty,
        createdAtMs: now,
        updatedAtMs: now,
      );
      // A transport failure is not a collision, so it is reported as such rather
      // than burning the remaining attempts and blaming the code space.
      if (!await _write(path, room.toJson())) return _networkFailure;

      final confirmed = Room.fromJson(await _read(path));
      if (confirmed != null && confirmed.hostId == uid) {
        return RoomResult.success(confirmed);
      }
      // Lost a race with another creator, or the write did not land. Try again.
    }

    return const RoomResult.failure(
      RoomFailureReason.codeGenerationFailed,
      message: 'Could not find a free room code. Please try again.',
    );
  }

  @override
  Future<RoomResult> join(String code) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return _notAuthenticated;
    final path = _path(code);
    if (path == null) return _invalidCode;

    final data = await _read(path);
    if (data == null) {
      return const RoomResult.failure(
        RoomFailureReason.roomNotFound,
        message: 'No room with that code. Check it and try again.',
      );
    }
    final room = Room.fromJson(data);
    if (room == null) {
      return const RoomResult.failure(
        RoomFailureReason.invalidRoomDocument,
        message: 'That room could not be read. Please try again.',
      );
    }

    // Re-joining a room you are already in is a no-op, not an error: the lobby
    // re-reads on reconnect and must not punish a returning player.
    if (room.isMember(uid)) return RoomResult.success(room);

    switch (room.status) {
      case RoomStatus.cancelled:
        return const RoomResult.failure(
          RoomFailureReason.roomCancelled,
          message: 'That room was cancelled.',
        );
      case RoomStatus.started:
      case RoomStatus.finished:
        // A finished match cannot be joined either; same reason, same message.
        return const RoomResult.failure(
          RoomFailureReason.roomAlreadyStarted,
          message: 'That match has already started.',
        );
      case RoomStatus.waiting:
      case RoomStatus.ready:
        break;
    }
    if (room.isFull) {
      return const RoomResult.failure(
        RoomFailureReason.roomFull,
        message: 'That room already has two players.',
      );
    }

    final seated = room.red.isEmpty
        ? room.copyWith(red: RoomSeat(playerId: uid))
        : room.copyWith(blue: RoomSeat(playerId: uid));
    return _persistSeated(room, seated);
  }

  @override
  Future<RoomResult> setReady({
    required String code,
    required bool ready,
  }) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return _notAuthenticated;
    final path = _path(code);
    if (path == null) return _invalidCode;

    final room = await _loadRoomOrNull(path);
    if (room == null) return _gone;
    if (!room.isMember(uid)) return _notAMember;
    if (room.status != RoomStatus.waiting && room.status != RoomStatus.ready) {
      return const RoomResult.failure(
        RoomFailureReason.roomAlreadyStarted,
        message: 'The match has already started.',
      );
    }

    final updated = room.withSeat(
      room.sideFor(uid)!,
      RoomSeat(playerId: uid, isReady: ready),
    );
    return _persistSeated(room, _withDerivedStatus(updated));
  }

  @override
  Future<RoomResult> start(String code) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return _notAuthenticated;
    final path = _path(code);
    if (path == null) return _invalidCode;

    final room = await _loadRoomOrNull(path);
    if (room == null) return _gone;
    if (!room.isMember(uid)) return _notAMember;
    if (!room.isHost(uid)) {
      return const RoomResult.failure(
        RoomFailureReason.notTheHost,
        message: 'Only the player who created the room can start it.',
      );
    }
    if (room.status == RoomStatus.started) {
      return const RoomResult.failure(
        RoomFailureReason.roomAlreadyStarted,
        message: 'The match has already started.',
      );
    }
    if (!room.bothReady) {
      return const RoomResult.failure(
        RoomFailureReason.playersNotReady,
        message: 'Waiting for both players to be ready.',
      );
    }

    // Phase 9: starting a match also seeds its authoritative snapshot, here
    // rather than in a separate call so a room can never be `started` without
    // one. The rule is uniform for both room kinds: whoever is seated in Blue
    // plays first, because Blue moves first (`game_spec.md` R-PLAYER-07). For a
    // code room Blue is the creator; for a Phase 8.1 quick-matched room Blue is
    // whoever was already waiting. One rule, no per-flow special case.
    final initial = GameState.initial(room.boardConfig);
    final bluePlayerId = room.seatFor(PlayerId.blue).playerId;
    final started = room.copyWith(
      status: RoomStatus.started,
      boardState: initial,
      turnNumber: initial.turnNumber,
      currentPlayerId: bluePlayerId,
      updatedAtMs: _nowMs,
      version: room.version + 1,
    );
    if (!await _write(path, started.toJson())) return _networkFailure;
    final confirmed = Room.fromJson(await _read(path));
    return RoomResult.success(confirmed ?? started);
  }

  @override
  Future<RoomResult> leave(String code) async {
    final uid = await userId();
    if (uid == null || uid.isEmpty) return _notAuthenticated;
    final path = _path(code);
    if (path == null) return _invalidCode;

    final room = await _loadRoomOrNull(path);
    if (room == null) {
      // Already gone — which is the state the caller asked for. Reported as
      // `roomNotFound` rather than a fabricated room, and the lobby treats it as
      // "left" without showing an error.
      return _gone;
    }
    if (!room.isMember(uid)) return _notAMember;
    if (room.status == RoomStatus.started) {
      // Leaving after the start is a disconnect. That belongs to Phase 10
      // (`phase.md`: "reconnection", "timeout/disconnect UX"), so it is reported
      // plainly rather than half-implemented here.
      return const RoomResult.failure(
        RoomFailureReason.roomAlreadyStarted,
        message: 'The match already started. Disconnect handling comes later.',
      );
    }

    // Deliberately asymmetric, because the two situations are not the same:
    //
    // * The host leaving leaves a room with no host, nothing able to start it,
    //   and nobody to maintain it. The document is deleted, which also frees the
    //   code and stops it occupying the 1 GiB no-cost storage quota forever.
    // * A guest leaving leaves a healthy room the host is still waiting on, so
    //   the seat is simply reopened for the next player.
    if (room.isHost(uid)) {
      if (!await _delete(path)) return _networkFailure;
      return RoomResult.success(room.copyWith(status: RoomStatus.cancelled));
    }

    final reopened = room.withSeat(room.sideFor(uid)!, RoomSeat.empty);
    return _persistSeated(room, _withDerivedStatus(reopened));
  }

  @override
  Future<Room?> load(String code) async {
    final path = _path(code);
    if (path == null) return null;
    return Room.fromJson(await _read(path));
  }

  @override
  Stream<Room?> watch(String code) {
    final path = _path(code);
    if (path == null) return Stream<Room?>.value(null);
    return client.watch(path).map(Room.fromJson);
  }

  /// Writes [next] in place of [previous], re-deriving the status first.
  ///
  /// Taking both rooms is what makes the version honest: [next] differs from
  /// [previous] precisely when a seat or a ready flag actually moved, which is
  /// exactly when the document version should advance. Comparing [next] against
  /// itself — the earlier mistake — never detected a change.
  ///
  /// The re-read afterwards is not paranoia: without it a write that silently
  /// failed would return a room the other player never sees.
  Future<RoomResult> _persistSeated(Room previous, Room next) async {
    final derived = _withDerivedStatus(next);
    // Phase 9 will use the version for optimistic concurrency, so a change that
    // does not alter the status — a join filling a seat, say — must still bump it.
    final changed = derived != previous;
    final updated = changed
        ? derived.copyWith(version: previous.version + 1, updatedAtMs: _nowMs)
        : next;
    final path = '$collection/${updated.code}';
    if (!await _write(path, updated.toJson())) return _networkFailure;
    final confirmed = Room.fromJson(await _read(path));
    return RoomResult.success(confirmed ?? updated);
  }

  /// `waiting` until both players are present and ready, then `ready`.
  ///
  /// Derived on every write, so the status can never drift out of step with the
  /// seats: there is no path that reaches `ready` without the seats justifying
  /// it.
  Room _withDerivedStatus(Room room) => room.copyWith(
    status: room.bothReady ? RoomStatus.ready : RoomStatus.waiting,
  );

  Future<Room?> _loadRoomOrNull(String path) async =>
      Room.fromJson(await _read(path));

  // --- Transport, total like every other Phase 6/7 repository -----------------

  Future<Map<String, dynamic>?> _read(String path) async {
    try {
      return await client.read(path);
    } on Object {
      return null;
    }
  }

  /// Returns whether the write landed.
  ///
  /// Unlike the Phase 6/7 persistence repositories, a swallowed write matters
  /// here: it would report a room that does not exist, or a ready state the
  /// opponent never received. So a transport failure has to surface as
  /// [RoomFailureReason.networkUnavailable].
  Future<bool> _write(String path, Map<String, dynamic> data) async {
    try {
      await client.write(path, data);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> _delete(String path) async {
    try {
      await client.delete(path);
      return true;
    } on Object {
      return false;
    }
  }

  static const RoomResult _notAuthenticated = RoomResult.failure(
    RoomFailureReason.notAuthenticated,
    message: 'Sign in to play online.',
  );
  static const RoomResult _invalidCode = RoomResult.failure(
    RoomFailureReason.invalidRoomCode,
    message: 'That does not look like a room code.',
  );
  static const RoomResult _notAMember = RoomResult.failure(
    RoomFailureReason.notAMember,
    message: 'You are not in that room.',
  );
  static const RoomResult _gone = RoomResult.failure(
    RoomFailureReason.roomNotFound,
    message: 'That room is no longer available.',
  );
  static const RoomResult _networkFailure = RoomResult.failure(
    RoomFailureReason.networkUnavailable,
    message: 'Could not reach the server. Check your connection and try again.',
  );
}
