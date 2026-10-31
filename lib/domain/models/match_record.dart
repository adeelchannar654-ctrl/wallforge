import 'finish_reason.dart';
import 'player_id.dart';

/// Which kind of match a [MatchRecord] describes.
enum MatchMode {
  /// Pass-and-play on one device.
  local,

  /// Against the offline AI.
  versusAi,

  /// An online match against another player.
  online;

  /// The wire name used in the stored JSON.
  String get wireName => switch (this) {
    MatchMode.local => 'local',
    MatchMode.versusAi => 'ai',
    MatchMode.online => 'online',
  };

  /// Parses a wire name, or null when it is not one.
  static MatchMode? fromWire(Object? raw) => switch (raw) {
    'local' => MatchMode.local,
    'ai' => MatchMode.versusAi,
    'online' => MatchMode.online,
    _ => null,
  };

  /// The player-facing label.
  String get label => switch (this) {
    MatchMode.local => 'Local',
    MatchMode.versusAi => 'Vs AI',
    MatchMode.online => 'Online',
  };
}

/// One finished match, recorded locally exactly once when the
/// match ends (Phase 16.5, Part E).
///
/// History is **per-device**: records live in the history
/// repository's local store, are never written online, and are
/// lost on uninstall. Online matches are recorded from the
/// final snapshot the client already holds — recording one
/// costs no reads or writes beyond the match itself.
///
/// The [moves] list (spec notation, in order) is stored so
/// replay and richer achievements can be built on it later;
/// [movesComplete] says whether the recording client actually
/// witnessed every ply (a client that joined an online match
/// late, or reconnected across a gap, holds a partial list and
/// must not present it as complete).
class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.mode,
    required this.boardSize,
    required this.wallsPerPlayer,
    required this.mySide,
    required this.winnerSide,
    required this.finishReason,
    required this.opponentLabel,
    required this.plies,
    required this.durationMs,
    required this.endedAtMs,
    required this.timeControlSeconds,
    required this.moves,
    required this.movesComplete,
    required this.rematchOf,
  });

  /// The match's identity: the room code for an online match,
  /// a controller-minted id for a local one. The history
  /// store's finish gate keys on it — a match is recorded at
  /// most once, however many times its finish is observed.
  final String id;

  /// The kind of match.
  final MatchMode mode;

  /// The board dimension (5, 7, 9, 11…).
  final int boardSize;

  /// Walls each player started with.
  final int wallsPerPlayer;

  /// The side this device's player held, or null for
  /// pass-and-play (both players share the device, so the
  /// record belongs to no single side).
  final PlayerId? mySide;

  /// The winning side, or null when the match was abandoned
  /// (no winner was declared).
  final PlayerId? winnerSide;

  /// Why the match ended.
  final FinishReason finishReason;

  /// Who the opponent was, in player-facing words: an AI
  /// difficulty ("AI · Hard"), "Local player", or "Online
  /// player". Never an identifier.
  final String opponentLabel;

  /// How many plies were played.
  final int plies;

  /// How long the match ran, in milliseconds (best effort:
  /// for a resumed local match it accumulates across saves;
  /// for an online match it spans from the start write to the
  /// terminal write).
  final int durationMs;

  /// When the match ended, epoch milliseconds.
  final int endedAtMs;

  /// The per-move clock the match was played under (0 = off).
  final int timeControlSeconds;

  /// The move list in spec notation, in play order.
  final List<String> moves;

  /// Whether [moves] is the complete list (see the class doc).
  final bool movesComplete;

  /// The match this one was a rematch of: the finished room's
  /// code online, the previous local match's id locally, or
  /// null for a first match.
  final String? rematchOf;

  /// Whether this device's player won (false for pass-and-play,
  /// where the record has no single owner — use [winnerSide]).
  bool get isWin => mySide != null && winnerSide == mySide;

  /// Whether this device's player lost.
  bool get isLoss =>
      mySide != null && winnerSide != null && winnerSide != mySide;

  /// Whether the match ended by abandonment (no winner).
  bool get isAbandoned => winnerSide == null;

  /// Serialises the record for the history store.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'mode': mode.wireName,
    'boardSize': boardSize,
    'wallsPerPlayer': wallsPerPlayer,
    'mySide': mySide?.name,
    'winnerSide': winnerSide?.name,
    'finishReason': finishReason.name,
    'opponentLabel': opponentLabel,
    'plies': plies,
    'durationMs': durationMs,
    'endedAtMs': endedAtMs,
    'timeControlSeconds': timeControlSeconds,
    'moves': moves,
    'movesComplete': movesComplete,
    'rematchOf': rematchOf,
  };

  /// Rebuilds a record from stored JSON, tolerantly: returns
  /// null only when the entry is unusable (no id, an unknown
  /// mode or finish reason); every other field falls back to a
  /// safe default, so one damaged record never loses the rest
  /// of the history.
  static MatchRecord? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final mode = MatchMode.fromWire(json['mode']);
    final reason = FinishReason.fromWire(json['finishReason']);
    if (id is! String || id.isEmpty || mode == null || reason == null) {
      return null;
    }
    final rawMoves = json['moves'];
    return MatchRecord(
      id: id,
      mode: mode,
      boardSize: _intOr(json['boardSize'], 9),
      wallsPerPlayer: _intOr(json['wallsPerPlayer'], 10),
      mySide: _sideOrNull(json['mySide']),
      winnerSide: _sideOrNull(json['winnerSide']),
      finishReason: reason,
      opponentLabel: json['opponentLabel'] is String
          ? json['opponentLabel'] as String
          : 'Opponent',
      plies: _intOr(json['plies'], 0),
      durationMs: _intOr(json['durationMs'], 0),
      endedAtMs: _intOr(json['endedAtMs'], 0),
      timeControlSeconds: _intOr(json['timeControlSeconds'], 0),
      moves: rawMoves is List
          ? rawMoves.whereType<String>().toList(growable: false)
          : const <String>[],
      movesComplete: json['movesComplete'] != false,
      rematchOf:
          (json['rematchOf'] is String &&
              (json['rematchOf'] as String).isNotEmpty)
          ? json['rematchOf'] as String
          : null,
    );
  }

  static int _intOr(Object? raw, int fallback) =>
      (raw is int && raw >= 0) ? raw : fallback;

  static PlayerId? _sideOrNull(Object? raw) => switch (raw) {
    'blue' => PlayerId.blue,
    'red' => PlayerId.red,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchRecord &&
          id == other.id &&
          mode == other.mode &&
          boardSize == other.boardSize &&
          wallsPerPlayer == other.wallsPerPlayer &&
          mySide == other.mySide &&
          winnerSide == other.winnerSide &&
          finishReason == other.finishReason &&
          opponentLabel == other.opponentLabel &&
          plies == other.plies &&
          durationMs == other.durationMs &&
          endedAtMs == other.endedAtMs &&
          timeControlSeconds == other.timeControlSeconds &&
          _movesEqual(moves, other.moves) &&
          movesComplete == other.movesComplete &&
          rematchOf == other.rematchOf;

  static bool _movesEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    mode,
    boardSize,
    wallsPerPlayer,
    mySide,
    winnerSide,
    finishReason,
    opponentLabel,
    plies,
    durationMs,
    endedAtMs,
    timeControlSeconds,
    Object.hashAll(moves),
    movesComplete,
    rematchOf,
  );

  @override
  String toString() =>
      'MatchRecord($id, ${mode.wireName}, ${boardSize}x$boardSize, '
      'winner: ${winnerSide?.name ?? 'none'}, ${finishReason.name})';
}
