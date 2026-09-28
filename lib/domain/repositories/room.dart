import '../models/board_config.dart';
import '../models/game_state.dart';
import '../models/player_id.dart';
import '../serialization/game_state_serializer.dart';

/// Lifecycle of an online room.
///
/// ## Why this is not `GameStatus`
///
/// A room exists *before* any `GameState` does, so reusing `GameStatus` would
/// force a room to pretend to be a game. `GameStatus` is `inProgress` /
/// `finished` (`game_spec.md` §6.1) and says nothing about waiting for an
/// opponent. This is a separate application/data-layer concept, as
/// `architecture.md` §11's `matches/{matchId}.status` field implies.
enum RoomStatus {
  /// Created; one or both seats may still be empty.
  waiting,

  /// Both seats are filled and both players have readied up. Startable.
  ready,

  /// The match has started. Phase 9 attaches move synchronisation from here;
  /// Phase 8 only records that both players are placed.
  started,

  /// Explicitly abandoned before the start.
  ///
  /// Not used by the shipped leave paths — see `FirestoreRoomRepository.leave`
  /// for why deletion is preferred — but kept so a future "cancel" affordance and
  /// Phase 10's timeout handling have a state to move to. Q-8.3 still records that
  /// it has no producer; Phase 9 deliberately did **not** repurpose it for match
  /// completion, because "cancelled before starting" and "played to a finish" are
  /// different facts and collapsing them would lose the distinction Phase 8
  /// established between a room and a game.
  cancelled,

  /// The match reached a conclusion.
  ///
  /// Added in Phase 9, and separate from `GameStatus.finished` for the reason
  /// Phase 8 separated the two enums: a room's lifecycle and a game's outcome are
  /// different questions. Set only by the transaction that applies a game-ending
  /// action, and terminal — no action is accepted afterwards.
  finished,
}

/// One seat in a room.
class RoomSeat {
  const RoomSeat({required this.playerId, this.isReady = false});

  /// The uid in this seat, or null when the seat is empty.
  final String? playerId;

  /// Whether this player has readied up.
  final bool isReady;

  /// Whether nobody is in this seat.
  bool get isEmpty => playerId == null;

  /// A seat with nobody in it.
  static const RoomSeat empty = RoomSeat(playerId: null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomSeat &&
          playerId == other.playerId &&
          isReady == other.isReady;

  @override
  int get hashCode => Object.hash(playerId, isReady);

  @override
  String toString() => 'RoomSeat(${playerId ?? 'empty'}, ready: $isReady)';
}

/// A shared online room: two players, an agreed board, and a ready state.
///
/// ## Storage shape
///
/// One document per room, at `matches/{code}`, following
/// `architecture.md` §11's conceptual structure. The room code *is* the match id
/// — see [RoomCode] — so joining needs no query, no index and no collection
/// scan, which is what keeps this inside the Spark no-cost quota.
///
/// ## What Phase 8 does not store
///
/// `architecture.md` §11 also lists `currentPlayerId`, `turnNumber`, `version`,
/// `winnerId` and `boardState`. `version` is seeded at 1 here because it is
/// monotonic bookkeeping that Phase 9 will extend and `PRD.md` §9 asks for
/// monotonic turn/version values. The rest are deliberately absent: writing a
/// `boardState` before moves are exchanged would imply synchronisation that does
/// not exist yet.
class Room {
  const Room({
    required this.code,
    required this.status,
    required this.boardConfig,
    required this.hostId,
    required this.blue,
    required this.red,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.version = 1,
    this.boardState,
    this.turnNumber = 0,
    this.currentPlayerId,
    this.winnerId,
  });

  /// The shareable room code, also the document id.
  final String code;

  /// Current lifecycle state.
  final RoomStatus status;

  /// The board both players agreed to before the match starts.
  final BoardConfig boardConfig;

  /// The uid that created the room. Only the host may start the match.
  final String hostId;

  /// The Blue seat. Blue moves first (`game_spec.md` R-PLAYER-07).
  final RoomSeat blue;

  /// The Red seat.
  final RoomSeat red;

  /// Creation time, milliseconds since epoch.
  final int createdAtMs;

  /// Last write time, milliseconds since epoch.
  final int updatedAtMs;

  /// Monotonic document version, seeded at 1.
  ///
  /// Advanced by **every** write that changes shared state (Phase 9), including
  /// each accepted action. Phase 9 uses it as a second guard against submitting
  /// against a stale document.
  final int version;

  // --- Phase 9: shared match state -------------------------------------------

  /// The authoritative board snapshot, or null when the match has not started.
  ///
  /// This is the "compact authoritative snapshot" of `architecture.md` §11: what
  /// clients read on every change, and the single source both players render
  /// from. The `moves` sub-collection is the audit trail and the recovery source,
  /// not the steady-state read path.
  final GameState? boardState;

  /// Denormalised copy of [GameState.turnNumber], or 0 before the match starts.
  ///
  /// Duplicated so a reader can check turn ownership with one cheap field read,
  /// and so a disagreement with [boardState] is detectable — a client verifying
  /// the document compares the two rather than trusting either.
  final int turnNumber;

  /// The uid whose turn it is, or null before the match starts.
  ///
  /// Derived from [GameState.currentPlayer], which is itself derived from turn
  /// parity (R-STATE-05), so this is a convenience for rules and a cross-check —
  /// never the authority.
  final String? currentPlayerId;

  /// The uid the document declares as winner, or null.
  ///
  /// A convenience field only. `rules.md` §3.6 forbids trusting a client-declared
  /// outcome, so the winner shown to players is always derived from the verified
  /// [GameState.winner]; a disagreement here is treated as corruption.
  final String? winnerId;

  /// The seat for [side].
  RoomSeat seatFor(PlayerId side) => side == PlayerId.blue ? blue : red;

  /// The side [uid] occupies, or null when they are not a member.
  PlayerId? sideFor(String uid) {
    if (blue.playerId == uid) return PlayerId.blue;
    if (red.playerId == uid) return PlayerId.red;
    return null;
  }

  /// Whether [uid] occupies either seat.
  bool isMember(String uid) => sideFor(uid) != null;

  /// Whether [uid] is the host.
  bool isHost(String uid) => hostId == uid;

  /// The opponent of [uid], or null when [uid] is alone or not a member.
  String? opponentOf(String uid) {
    final side = sideFor(uid);
    if (side == null) return null;
    return seatFor(side.opponent).playerId;
  }

  /// Whether [uid] has readied up.
  bool isReadyFor(String uid) {
    final side = sideFor(uid);
    if (side == null) return false;
    return seatFor(side).isReady;
  }

  /// Whether both seats are filled.
  bool get isFull => !blue.isEmpty && !red.isEmpty;

  /// Whether both players are present and readied up.
  bool get bothReady => isFull && blue.isReady && red.isReady;

  /// Whether the match can start right now.
  ///
  /// Depends on the derived [RoomStatus] rather than recomputing from the seats,
  /// so the lobby's button and the stored document can never disagree.
  bool get canStart => status == RoomStatus.ready;

  /// A copy with the seat on [side] replaced.
  ///
  /// Separate from [copyWith] because the side to change depends on *whose* seat
  /// is being edited, which the value itself cannot know — the caller resolves
  /// it with [sideFor] first. Keeping that explicit stops a seat edit from
  /// silently defaulting to Blue.
  Room withSeat(PlayerId side, RoomSeat seat) => Room(
    code: code,
    status: status,
    boardConfig: boardConfig,
    hostId: hostId,
    blue: side == PlayerId.blue ? seat : blue,
    red: side == PlayerId.red ? seat : red,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs,
    version: version,
    boardState: boardState,
    turnNumber: turnNumber,
    currentPlayerId: currentPlayerId,
    winnerId: winnerId,
  );

  /// A copy with the given fields replaced.
  ///
  /// Used by the repository to build the next document version from a freshly
  /// read one, so a write is always derived from observed state rather than from
  /// whatever the caller happened to be holding.
  Room copyWith({
    RoomStatus? status,
    RoomSeat? blue,
    RoomSeat? red,
    int? updatedAtMs,
    int? version,
    GameState? boardState,
    int? turnNumber,
    String? currentPlayerId,
    String? winnerId,
  }) => Room(
    code: code,
    status: status ?? this.status,
    boardConfig: boardConfig,
    hostId: hostId,
    blue: blue ?? this.blue,
    red: red ?? this.red,
    createdAtMs: createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    version: version ?? this.version,
    boardState: boardState ?? this.boardState,
    turnNumber: turnNumber ?? this.turnNumber,
    currentPlayerId: currentPlayerId ?? this.currentPlayerId,
    winnerId: winnerId ?? this.winnerId,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'status': status.name,
    'boardSize': boardConfig.size,
    'wallsPerPlayer': boardConfig.wallsPerPlayer,
    'hostId': hostId,
    'blue': _seatToJson(blue),
    'red': _seatToJson(red),
    'createdAt': createdAtMs,
    'updatedAt': updatedAtMs,
    'version': version,
    'schemaVersion': schemaVersion,
    // Phase 9 fields. Written as null before the match starts so the shape is
    // stable and a reader never has to distinguish "absent" from "null".
    'boardState': boardState == null
        ? null
        : GameStateSerializer.toJson(boardState!),
    'turnNumber': turnNumber,
    'currentPlayerId': currentPlayerId,
    'winnerId': winnerId,
  };

  static Map<String, dynamic> _seatToJson(RoomSeat seat) => <String, dynamic>{
    'playerId': seat.playerId,
    'ready': seat.isReady,
  };

  /// Rebuilds a room from [json], or returns null when the document cannot be
  /// trusted.
  ///
  /// Returning null rather than throwing follows `UnfinishedMatch.fromJson`: a
  /// document that fails validation is treated as "no such room" so a corrupt
  /// write cannot crash the lobby. Every field is type-checked because
  /// `architecture.md` §12 requires "match state fields have expected types".
  static Room? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final rawCode = json['code'];
    final rawStatus = json['status'];
    final rawSize = json['boardSize'];
    final rawWalls = json['wallsPerPlayer'];
    final rawHost = json['hostId'];
    if (rawCode is! String || rawCode.isEmpty) return null;
    if (rawStatus is! String) return null;
    if (rawSize is! int || rawWalls is! int) return null;
    if (rawHost is! String || rawHost.isEmpty) return null;

    // Reject an invalid board rather than carrying a config the engine would
    // refuse; BoardConfig.check is the engine's own rule.
    if (BoardConfig.check(rawSize, rawWalls) != null) return null;

    final status = _statusFromName(rawStatus);
    if (status == null) return null;

    final blue = _seatFromJson(json['blue']);
    final red = _seatFromJson(json['red']);
    if (blue == null || red == null) return null;

    // The host must actually be seated, or "start" has no defined meaning.
    if (blue.playerId != rawHost && red.playerId != rawHost) return null;

    // --- Phase 9 fields, read leniently so a Phase 8 document still parses ---
    //
    // `schemaVersion` 1 documents predate the match state and simply lack these
    // keys, which is legal: a room that has not started has no snapshot, turn
    // number 0 and no current player. Rejecting them would strand every room
    // created before this phase, and `PRD.md` §9 asks for version compatibility
    // rather than version rigidity.
    final rawTurnNumber = json['turnNumber'];
    final rawWinner = json['winnerId'];
    final rawCurrent = json['currentPlayerId'];
    final rawBoard = json['boardState'];
    GameState? boardState;
    if (rawBoard is Map) {
      // A stored snapshot that the engine refuses is *not* silently dropped: the
      // document is returned with a null state and the caller sees turnNumber > 0
      // with no state, which its verification rejects. Decoding it away here would
      // hide exactly the corruption the check exists to catch.
      boardState = GameStateSerializer.fromJson(
        rawBoard.cast<String, dynamic>(),
      ).stateOrNull;
    }

    return Room(
      code: rawCode,
      status: status,
      boardConfig: BoardConfig(size: rawSize, wallsPerPlayer: rawWalls),
      hostId: rawHost,
      blue: blue,
      red: red,
      createdAtMs: _intOr(json['createdAt'], 0),
      updatedAtMs: _intOr(json['updatedAt'], 0),
      version: _intOr(json['version'], 1),
      boardState: boardState,
      turnNumber: (rawTurnNumber is int && rawTurnNumber >= 0)
          ? rawTurnNumber
          : 0,
      currentPlayerId: (rawCurrent is String && rawCurrent.isNotEmpty)
          ? rawCurrent
          : null,
      winnerId: (rawWinner is String && rawWinner.isNotEmpty)
          ? rawWinner
          : null,
    );
  }

  static RoomStatus? _statusFromName(String name) {
    for (final value in RoomStatus.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static RoomSeat? _seatFromJson(Object? raw) {
    if (raw is! Map) return null;
    final playerId = raw['playerId'];
    if (playerId != null && playerId is! String) return null;
    return RoomSeat(
      playerId: playerId as String?,
      isReady: raw['ready'] == true,
    );
  }

  static int _intOr(Object? raw, int fallback) =>
      (raw is int && raw >= 0) ? raw : fallback;

  /// Storage layout version, so a later migration is detectable.
  ///
  /// Bumped to 2 by Phase 9, which added `boardState`, `turnNumber`,
  /// `currentPlayerId` and `winnerId`. The change is purely additive, so
  /// [supportedSchemaVersions] still accepts 1: a Phase 8 room document parses
  /// unchanged, with the new fields read as their pre-start values.
  static const int schemaVersion = 2;

  /// Versions this build can read.
  static const Set<int> supportedSchemaVersions = {1, 2};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Room &&
          code == other.code &&
          status == other.status &&
          boardConfig == other.boardConfig &&
          hostId == other.hostId &&
          blue == other.blue &&
          red == other.red &&
          createdAtMs == other.createdAtMs &&
          updatedAtMs == other.updatedAtMs &&
          version == other.version &&
          boardState == other.boardState &&
          turnNumber == other.turnNumber &&
          currentPlayerId == other.currentPlayerId &&
          winnerId == other.winnerId;

  @override
  int get hashCode => Object.hash(
    code,
    status,
    boardConfig,
    hostId,
    blue,
    red,
    createdAtMs,
    updatedAtMs,
    version,
    boardState,
    turnNumber,
    currentPlayerId,
    winnerId,
  );

  @override
  String toString() =>
      'Room($code, ${status.name}, ${boardConfig.size}x${boardConfig.size}, '
      'blue: ${blue.playerId ?? '-'}, red: ${red.playerId ?? '-'})';
}

/// A short, human-shareable room code — also the Firestore document id.
///
/// ## Format, and why
///
/// Six characters from a 32-symbol alphabet that omits the visually ambiguous
/// `0/O` and `1/I`, giving 32^6 ≈ 1.07e9 combinations. No format is specified
/// anywhere in the source documents — `PRD.md` §6.4 and `design.md` §19 both
/// list only "Room code" — so this is a reasoned default, chosen so a code read
/// aloud or typed from a screenshot is unambiguous.
///
/// The code is upper-cased on the way in and out so a lower-case entry is
/// accepted, and characters outside the alphabet are stripped rather than
/// rejected, so a stray space or hyphen cannot turn a valid code into a
/// different failure from the one the player deserves.
class RoomCode {
  const RoomCode._(this.value);

  /// Wraps an already-valid [value].
  const RoomCode.valid(String value) : this._(value);

  /// The symbols used, excluding `0`, `O`, `1` and `I`.
  static const String alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Number of symbols in a code.
  static const int length = 6;

  /// The normalised code.
  final String value;

  /// Normalises arbitrary user input into a code, or null when it cannot be one.
  ///
  /// Case is ignored and separators are dropped, so `"ab3-9hk"`, `"AB39HK"` and
  /// `"ab39hk"` are the same room.
  static RoomCode? tryParse(String input) {
    final cleaned = input
        .trim()
        .toUpperCase()
        .split('')
        .where((char) => alphabet.contains(char))
        .toList();
    if (cleaned.length != length) return null;
    return RoomCode.valid(cleaned.join());
  }

  /// Whether [input] normalises to a valid code.
  static bool isValid(String input) => tryParse(input) != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RoomCode && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Machine-readable reason an online room operation was rejected.
///
/// Every expected invalid state gets its own value, because `rules.md` §7
/// requires structured failures rather than thrown exceptions, and because a
/// player needs a *specific* message: "that room is full" and "that room does
/// not exist" call for different actions.
enum RoomFailureReason {
  /// No uid is resolved, so there is nobody to seat.
  notAuthenticated,

  /// The entered code is not a well-formed room code.
  invalidRoomCode,

  /// No room exists with that code.
  roomNotFound,

  /// Both seats are already taken.
  roomFull,

  /// The room was cancelled.
  roomCancelled,

  /// The match has already started, so the lobby no longer applies.
  roomAlreadyStarted,

  /// The caller is not seated in this room.
  notAMember,

  /// Not every player has readied up yet.
  playersNotReady,

  /// Only the host may start the match.
  notTheHost,

  /// The room document could not be understood.
  invalidRoomDocument,

  /// A code could not be generated without colliding. See
  /// `FirestoreRoomRepository.create`.
  codeGenerationFailed,

  /// The transport failed or Firebase is unreachable.
  ///
  /// The data-layer counterpart of `rules.md` §7's "Firebase unavailable".
  networkUnavailable,
}

/// A structured room-operation failure.
class RoomFailure {
  /// Creates a room failure.
  const RoomFailure(this.reason, this.message);

  /// Machine-readable reason.
  final RoomFailureReason reason;

  /// Human-readable explanation, safe to show a player.
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomFailure &&
          reason == other.reason &&
          message == other.message;

  @override
  int get hashCode => Object.hash(reason, message);

  @override
  String toString() => 'RoomFailure(${reason.name}: $message)';
}

/// The outcome of a room operation.
///
/// Shaped like `ActionResult` in `lib/domain/engine/game_engine.dart` — a
/// sealed union of success and failure — so a rejected expected state is a
/// value, never an exception.
sealed class RoomResult {
  const RoomResult._();

  /// The operation succeeded and produced this room.
  const factory RoomResult.success(Room room) = RoomSuccess;

  /// The operation was rejected for this reason.
  const factory RoomResult.failure(
    RoomFailureReason reason, {
    String? message,
  }) = RoomRejected;
}

/// A successful room operation.
class RoomSuccess extends RoomResult {
  const RoomSuccess(this.room) : super._();

  /// The room as it now stands on the server.
  final Room room;
}

/// A rejected room operation.
class RoomRejected extends RoomResult {
  const RoomRejected(this.reason, {this.message}) : super._();

  /// The machine-readable reason.
  final RoomFailureReason reason;

  /// Human-readable explanation, safe to show a player.
  final String? message;

  /// The same information as a [RoomFailure] value.
  RoomFailure get failure => RoomFailure(reason, message);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomRejected &&
          reason == other.reason &&
          message == other.message;

  @override
  int get hashCode => Object.hash(reason, message);

  @override
  String toString() => 'RoomRejected(${reason.name}: $message)';
}
