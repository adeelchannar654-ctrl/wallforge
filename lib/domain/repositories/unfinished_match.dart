import '../models/game_state.dart';
import '../models/player_id.dart';
import '../serialization/game_state_serializer.dart';

/// A match the player can resume, as persisted.
///
/// **Optional** in `phase.md` Phase 6, and implemented here because the data is
/// already available: [GameState] has a versioned JSON round-trip in
/// [GameStateSerializer], so resuming reuses the engine's own serialisation
/// rather than a parallel format that could drift.
///
/// The board configuration is stored twice on purpose — once implicitly inside
/// [gameState] and once as [boardSize] — because the entry screen needs the size
/// to label the resume affordance *before* the state is decoded.
class UnfinishedMatch {
  const UnfinishedMatch({
    required this.gameState,
    required this.boardSize,
    required this.versusAi,
    required this.aiDifficulty,
    this.savedAtTurn = 0,
    this.timeControlSeconds = 0,
    this.humanSide = PlayerId.blue,
    this.matchId,
    this.moves = const <String>[],
    this.elapsedMs = 0,
    this.rematchOf,
  });

  /// The live match state, restored through [GameStateSerializer].
  final GameState gameState;

  /// The board dimension, for labelling the resume affordance.
  final int boardSize;

  /// Whether the opponent was the offline AI.
  final bool versusAi;

  /// The AI difficulty, by name. `"local"` is used for pass-and-play.
  final String aiDifficulty;

  /// The match's turn number when saved, for display and staleness checks.
  final int savedAtTurn;

  /// The per-move clock the match was played under, in seconds
  /// (Phase 16.5; 0 = off). A resumed match restarts the current
  /// turn at a full clock (D16.5-4) — no deadline is stored.
  final int timeControlSeconds;

  /// The side the human plays in a vs-AI match (Phase 16.5).
  ///
  /// Blue for every match started fresh; Red for a rematch in
  /// progress, where the sides were swapped. Without it a
  /// resumed rematch would hand the human's pawn to the AI.
  /// Saves written before the field existed default to Blue,
  /// which is what they all were.
  final PlayerId humanSide;

  /// The match's history identity (Phase 16.5), minted when
  /// the match started. Null in saves written before the field
  /// existed; the controller mints one on resume in that case.
  final String? matchId;

  /// The moves played so far, in spec notation (Phase 16.5):
  /// carried so a resumed match's history record still holds
  /// the complete move list.
  final List<String> moves;

  /// Milliseconds of play accumulated before the current
  /// session (Phase 16.5), so a resumed match's recorded
  /// duration spans its sessions instead of restarting.
  final int elapsedMs;

  /// The match this one is a rematch of, when it is one
  /// (Phase 16.5): carried so a resumed rematch's history
  /// record keeps its link.
  final String? rematchOf;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'boardSize': boardSize,
    'versusAi': versusAi,
    'aiDifficulty': aiDifficulty,
    'savedAtTurn': savedAtTurn,
    'timeControlSeconds': timeControlSeconds,
    'humanSide': humanSide.name,
    'matchId': matchId,
    'moves': moves,
    'elapsedMs': elapsedMs,
    'rematchOf': rematchOf,
    'gameState': GameStateSerializer.toJson(gameState),
  };

  /// Rebuilds an unfinished match from [json], or returns null when it cannot be
  /// used — malformed JSON, an unknown schema version, or a state that fails the
  /// engine's own invariant checks.
  ///
  /// Returning null rather than throwing is deliberate: a corrupt save must
  /// never stop the app from starting, it just means "no match to resume".
  static UnfinishedMatch? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final rawSize = json['boardSize'];
    final rawTurn = json['savedAtTurn'];
    if (rawSize is! int || rawSize < 5) return null;
    final rawState = json['gameState'];
    if (rawState is! Map) return null;

    final result = GameStateSerializer.fromJson(
      rawState.cast<String, dynamic>(),
    );
    // Uses the engine's own decoder, so a state that violates a spec invariant
    // is rejected here exactly as it would be anywhere else.
    final state = result.stateOrNull;
    if (state == null) return null;

    final rawDifficulty = json['aiDifficulty'];
    final rawTimeControl = json['timeControlSeconds'];
    return UnfinishedMatch(
      gameState: state,
      boardSize: rawSize,
      versusAi: json['versusAi'] == true,
      aiDifficulty: rawDifficulty is String ? rawDifficulty : 'local',
      savedAtTurn: (rawTurn is int && rawTurn >= 0) ? rawTurn : 0,
      timeControlSeconds: (rawTimeControl is int && rawTimeControl >= 0)
          ? rawTimeControl
          : 0,
      humanSide: json['humanSide'] == 'red' ? PlayerId.red : PlayerId.blue,
      matchId:
          (json['matchId'] is String && (json['matchId'] as String).isNotEmpty)
          ? json['matchId'] as String
          : null,
      moves: json['moves'] is List
          ? (json['moves'] as List).whereType<String>().toList()
          : const <String>[],
      elapsedMs: (json['elapsedMs'] is int && (json['elapsedMs'] as int) >= 0)
          ? json['elapsedMs'] as int
          : 0,
      rematchOf:
          (json['rematchOf'] is String &&
              (json['rematchOf'] as String).isNotEmpty)
          ? json['rematchOf'] as String
          : null,
    );
  }

  @override
  String toString() =>
      'UnfinishedMatch(boardSize: $boardSize, versusAi: $versusAi, '
      'aiDifficulty: $aiDifficulty, savedAtTurn: $savedAtTurn)';
}
