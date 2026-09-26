import '../models/game_state.dart';
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

  Map<String, dynamic> toJson() => <String, dynamic>{
    'boardSize': boardSize,
    'versusAi': versusAi,
    'aiDifficulty': aiDifficulty,
    'savedAtTurn': savedAtTurn,
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
    return UnfinishedMatch(
      gameState: state,
      boardSize: rawSize,
      versusAi: json['versusAi'] == true,
      aiDifficulty: rawDifficulty is String ? rawDifficulty : 'local',
      savedAtTurn: (rawTurn is int && rawTurn >= 0) ? rawTurn : 0,
    );
  }

  @override
  String toString() =>
      'UnfinishedMatch(boardSize: $boardSize, versusAi: $versusAi, '
      'aiDifficulty: $aiDifficulty, savedAtTurn: $savedAtTurn)';
}
