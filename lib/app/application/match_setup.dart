import '../../domain/models/board_config.dart';
import 'ai/ai_difficulty.dart';

/// What a game route was asked to start.
///
/// Passed as the `/game` route argument. A bare [BoardConfig] is still accepted
/// for pass-and-play so existing call sites and tests keep working.
class MatchSetup {
  const MatchSetup({
    this.config = const BoardConfig(),
    this.versusAi = false,
    this.aiDifficulty = AiDifficulty.easy,
  });

  /// Board size and walls per player.
  final BoardConfig config;

  /// Whether the opponent is the offline AI rather than a second human.
  final bool versusAi;

  /// Difficulty the AI plays at. Ignored when [versusAi] is false.
  final AiDifficulty aiDifficulty;

  /// Pass-and-play match on [config].
  const MatchSetup.local(this.config)
    : versusAi = false,
      aiDifficulty = AiDifficulty.easy;

  /// Match against the AI at [aiDifficulty] on [config].
  const MatchSetup.versusAi(this.config, this.aiDifficulty) : versusAi = true;
}
