import '../models/action_failure.dart';
import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/player_id.dart';
import '../models/wall_orientation.dart';
import 'room.dart';

/// A shared match document exactly as stored, plus how it was obtained.
///
/// ## Why the raw fields are handed up rather than a decoded state
///
/// `PRD.md` §9: "The client must not assume that local state is authoritative
/// for another player" and `architecture.md` §12: "The client must never be
/// treated as trusted." Verification needs the *stored* bytes — the decoded
/// state's turn number, the denormalised `turnNumber` field and the declared
/// `winnerId` have to be compared against each other, and a value that fails to
/// decode must stay a failure rather than becoming a defaulted state. Decoding in
/// the repository would hide exactly the inconsistencies the check exists to
/// find, so the raw document travels to the controller, which verifies it.
class SharedMatchDocument {
  const SharedMatchDocument({
    required this.code,
    required this.fields,
    this.fromCache = false,
  });

  /// The room/match code.
  final String code;

  /// The stored document fields.
  final Map<String, dynamic> fields;

  /// Whether this came from the device cache rather than the server.
  final bool fromCache;

  /// The stored lifecycle status, or null when unparseable.
  RoomStatus? get status {
    final raw = fields['status'];
    if (raw is! String) return null;
    for (final value in RoomStatus.values) {
      if (value.name == raw) return value;
    }
    return null;
  }

  /// The authoritative board snapshot as stored, or null when absent.
  Map<String, dynamic>? get rawState {
    final raw = fields['boardState'];
    return raw is Map ? raw.cast<String, dynamic>() : null;
  }

  /// The denormalised turn number, or null when absent or not an int.
  int? get turnNumber {
    final raw = fields['turnNumber'];
    return raw is int && raw >= 0 ? raw : null;
  }

  /// The monotonic document version, or null when absent or not an int.
  int? get version {
    final raw = fields['version'];
    return raw is int && raw >= 0 ? raw : null;
  }

  /// The uid the document says has the turn, or null.
  String? get currentPlayerId {
    final raw = fields['currentPlayerId'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  /// The uid the document *declares* as winner, or null.
  ///
  /// A convenience field only. `PRD.md` §9 and `rules.md` §3.6 forbid trusting a
  /// client-declared outcome, so the winner used for display is always derived
  /// from the verified [GameState.winner]; a disagreement here is treated as
  /// corruption, not as news.
  String? get declaredWinnerId {
    final raw = fields['winnerId'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  @override
  String toString() =>
      'SharedMatchDocument($code, turn: $turnNumber, version: $version'
      '${fromCache ? ', fromCache' : ''})';
}

/// One immutable record of an accepted action.
class MatchMove {
  const MatchMove({
    required this.turnNumber,
    required this.playerId,
    required this.action,
    required this.createdAt,
    required this.resultingVersion,
  });

  /// Which turn this action completed (zero-based).
  final int turnNumber;

  /// The uid that played it.
  final String playerId;

  /// The action as stored.
  final GameAction? action;

  /// When it was recorded, milliseconds since epoch.
  final int createdAt;

  /// The match document version this action produced.
  final int resultingVersion;

  /// The move-log document id for [turnNumber].
  ///
  /// Zero-padded so lexicographic order matches numeric order, which matters
  /// because the port's `query` can only `orderBy` a field, not the document id
  /// — so recovery reads by the stored `turnNumber` instead.
  static String documentIdFor(int turnNumber) =>
      turnNumber.toString().padLeft(6, '0');

  /// Rebuilds a move from a stored document, or null when unusable.
  static MatchMove? fromJson(int turnNumber, Map<String, dynamic>? json) {
    if (json == null) return null;
    final action = json['action'];
    if (action is! Map) return null;
    final createdAt = json['createdAt'];
    final version = json['resultingVersion'];
    return MatchMove(
      turnNumber: (json['turnNumber'] is int)
          ? json['turnNumber'] as int
          : turnNumber,
      playerId: json['playerId'] is String ? json['playerId'] as String : '',
      action: decodeAction(action.cast<String, dynamic>()),
      createdAt: createdAt is int ? createdAt : 0,
      resultingVersion: version is int ? version : 0,
    );
  }

  /// Decodes a stored action, or null when it is not a known shape.
  ///
  /// Deliberately does not go through `GameAction.parse` (spec notation) and
  /// does not silently drop unknown types: a record this build cannot read is a
  /// replay blocker, and recovery must stop cleanly rather than skip a ply.
  static GameAction? decodeAction(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'move':
        final destination = json['destination'];
        if (destination is! Map) return null;
        final row = destination['row'];
        final column = destination['column'];
        if (row is! int || column is! int) return null;
        return GameAction.move(Cell(row: row, column: column));
      case 'wall':
        final anchor = json['anchor'];
        if (anchor is! Map) return null;
        final row = anchor['row'];
        final column = anchor['column'];
        final orientation = json['orientation'];
        if (row is! int || column is! int || orientation is! String) {
          return null;
        }
        final parsed = _orientationFromName(orientation);
        if (parsed == null) return null;
        return GameAction.wall(
          orientation: parsed,
          anchor: Cell(row: row, column: column),
        );
      default:
        return null;
    }
  }

  static WallOrientation? _orientationFromName(String name) {
    for (final value in WallOrientation.values) {
      if (value.name == name.toLowerCase()) return value;
    }
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'turnNumber': turnNumber,
    'playerId': playerId,
    'action': action?.toJson(),
    'notation': action?.toNotation(),
    'createdAt': createdAt,
    'resultingVersion': resultingVersion,
  };

  @override
  String toString() =>
      'MatchMove(turn $turnNumber by $playerId, version $resultingVersion)';
}

/// Why a move submission was refused.
///
/// Every expected rejection is its own value, per `rules.md` §7, because the
/// player-facing response differs: a stale turn needs a re-sync, an illegal move
/// needs a correction, a lost connection needs a retry.
enum MatchSyncFailureReason {
  /// No uid resolved, so there is nobody to move.
  notAuthenticated,

  /// The caller is not seated in this match.
  notAMember,

  /// No match document exists at that code.
  roomNotFound,

  /// The match has not started yet.
  roomNotStarted,

  /// The match is already over; no further action is accepted.
  matchFinished,

  /// It is the opponent's turn.
  notYourTurn,

  /// The caller's expected turn or version no longer matches the stored match.
  staleTurn,

  /// The engine rejected the action. The engine's own reason is carried.
  invalidAction,

  /// The stored document could not be understood, so nothing was applied.
  invalidRemoteData,

  /// Another action is already recorded for that turn.
  conflictingDuplicate,

  /// The transport failed, or the device is offline.
  ///
  /// Firestore transactions do not queue while offline, so this is a common and
  /// recoverable case rather than an exceptional one.
  networkUnavailable,
}

/// A structured match-sync failure.
class MatchSyncFailure {
  /// Creates a failure.
  const MatchSyncFailure(this.reason, {this.message, this.actionFailure});

  /// Machine-readable reason.
  final MatchSyncFailureReason reason;

  /// Player-facing explanation, safe to show.
  final String? message;

  /// The engine's reason, present only for [MatchSyncFailureReason.invalidAction].
  final ActionFailure? actionFailure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchSyncFailure &&
          reason == other.reason &&
          message == other.message &&
          actionFailure == other.actionFailure;

  @override
  int get hashCode => Object.hash(reason, message, actionFailure);

  @override
  String toString() => 'MatchSyncFailure(${reason.name}: $message)';
}

/// The outcome of submitting an action.
sealed class MoveSubmission {
  const MoveSubmission._();

  /// The action was applied and committed.
  const factory MoveSubmission.applied(Room room, GameState state) =
      MoveApplied;

  /// The same action was already recorded for this turn: a retry after a lost
  /// acknowledgement, not a conflict.
  const factory MoveSubmission.alreadyApplied(Room room, GameState state) =
      MoveAlreadyApplied;

  /// The submission was refused.
  const factory MoveSubmission.rejected(MatchSyncFailure failure) =
      MoveRejected;
}

/// A committed action.
class MoveApplied extends MoveSubmission {
  const MoveApplied(this.room, this.state) : super._();

  /// The match document after the action.
  final Room room;

  /// The authoritative state after the action.
  final GameState state;
}

/// An action that was already present, treated as success.
class MoveAlreadyApplied extends MoveSubmission {
  const MoveAlreadyApplied(this.room, this.state) : super._();

  /// The match document.
  final Room room;

  /// The authoritative state.
  final GameState state;
}

/// A refused submission.
class MoveRejected extends MoveSubmission {
  const MoveRejected(this.failure) : super._();

  /// Why it was refused.
  final MatchSyncFailure failure;

  /// The machine-readable reason.
  MatchSyncFailureReason get reason => failure.reason;
}

/// Match synchronisation, declared here and implemented in `lib/data/remote/`.
///
/// ## Scope
///
/// `phase.md` Phase 9: match state, turn number, state version, move records, a
/// Firestore listener, write validation, duplicate-move protection, *this
/// client's* reconnection and re-sync, conflict handling, and match completion.
/// Turn clocks, forfeit, abandonment and what the opponent sees when someone
/// stays gone are Phase 10, as is Security Rules (`architecture.md` §12).
abstract interface class MatchRepository {
  /// Watches the shared match document. Exactly one listener per client
  /// (`rules.md` §5: "Use one appropriate match listener").
  Stream<SharedMatchDocument> watchMatch({required String code});

  /// Reads the shared match document once, with its cache metadata.
  Future<SharedMatchDocument?> loadMatch({required String code});

  /// Submits [action] for [expectedTurnNumber] atomically.
  ///
  /// [expectedVersion] is checked when supplied, giving a caller a second guard
  /// against submitting against a stale document. Validation runs against the
  /// *stored* state inside the transaction, never against a client cache, which
  /// is the whole point: `architecture.md` §12 says the client is never trusted.
  Future<MoveSubmission> submitAction({
    required String code,
    required int expectedTurnNumber,
    required GameAction action,
    int? expectedVersion,
  });

  /// Reads the move log in bounded pages, for recovery only.
  ///
  /// Never used in steady state. A full replay costs one read per move and
  /// happens only after a snapshot failed verification.
  Future<List<MatchMove>> readMoves({required String code, int limit});

  /// There is deliberately no "start" method here. Starting a match belongs to
  /// `RoomRepository.start`, the Phase 8 host-only operation, and Phase 9 taught
  /// *it* to seed the initial snapshot. Keeping that write in one place means a
  /// room cannot become `started` without an authoritative state, whichever path
  /// reached it.
}

/// Which uid plays which colour, derived once and asserted once.
///
/// The engine speaks [PlayerId]; storage speaks uids. The mapping already lives
/// in [Room.sideFor], and this exists to make the two facts that a match depends
/// on checkable in one place: a member has exactly one side, and that side's
/// player is the one whose turn it is.
class MatchSeating {
  /// Creates a seating for [room] and the player identified by [uid].
  const MatchSeating({required this.room, required this.uid});

  /// The room.
  final Room room;

  /// The player asking.
  final String uid;

  /// The player's colour, or null when they are not seated.
  PlayerId? get mySide => room.sideFor(uid);

  /// The opponent's colour, or null when alone.
  PlayerId? get opponentSide => mySide?.opponent;

  /// The opponent's uid, or null when alone.
  String? get opponentId => room.opponentOf(uid);

  /// The uid seated on [side], or null when the seat is empty.
  String? playerIdFor(PlayerId side) => room.seatFor(side).playerId;

  /// Whether [state]'s current player is this client.
  bool isMyTurn(GameState state) => mySide == state.currentPlayer;

  @override
  String toString() =>
      'MatchSeating(${room.code}, $uid as ${mySide?.name ?? 'spectator'})';
}
