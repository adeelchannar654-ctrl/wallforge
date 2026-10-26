import 'package:flutter/material.dart';

import '../../../app/application/ai/ai_difficulty.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/models/board_config.dart';
import '../../../domain/models/player_id.dart';
import '../../widgets/app_chrome.dart';

/// Which kind of match ended — drives the heading and the summary line.
enum ResultMode { local, versusAi, online }

/// Everything the Result screen shows, derived by the caller from the real
/// finished `GameState` (never invented):
///
/// * [turnsPlayed] is the finished state's `turnNumber` — the engine
///   increments it once per applied action, so it is exactly the number of
///   actions played.
/// * walls used per player is the match's configured walls minus the
///   finished state's remaining walls.
class MatchResultData {
  const MatchResultData({
    required this.mode,
    required this.winner,
    required this.turnsPlayed,
    required this.wallsUsedBlue,
    required this.wallsUsedRed,
    required this.config,
    this.mySide,
    this.aiDifficulty,
    this.opponentLeft = false,
    this.roomCode,
    this.note,
  });

  final ResultMode mode;

  /// The winning player, or null when the match ended without one (an
  /// online match claimed as abandoned).
  final PlayerId? winner;

  final int turnsPlayed;
  final int wallsUsedBlue;
  final int wallsUsedRed;
  final BoardConfig config;

  /// The local player's seat, for the AI and online modes. Null for a local
  /// pass-and-play match, where both players share the screen.
  final PlayerId? mySide;

  /// The difficulty played, for the AI mode's summary line.
  final AiDifficulty? aiDifficulty;

  /// Online only: the match ended because a player claimed abandonment.
  final bool opponentLeft;

  /// Online only: the room the match was played in.
  final String? roomCode;

  /// Online only: a specific ending note (e.g. who claimed abandonment),
  /// shown in the summary instead of the generic opponent-left line.
  final String? note;

  /// Whether the local viewer won (always true in local mode when there is
  /// a winner — the screen is shared by both players).
  bool get viewerWon =>
      winner != null && (mode == ResultMode.local || mySide == winner);
}

/// The shared Result screen (`design.md` §21) — one component for local, AI
/// and online endings, not three forks.
///
/// §21 for the winner: a victory heading, the player piece, statistics,
/// Rematch, Home. For the loser: "Match complete.", statistics, Rematch,
/// Home. No humiliating language, and no score/XP/rating — statistics are
/// the finished game's own facts (turns played, walls used per player, the
/// result). The victory heading follows the app's established result
/// convention ("BLUE WINS!" / "RED WINS!"); §21 names no exact string.
///
/// This widget is the screen *body*: the game screens present it in place
/// of the board when a match ends (their controllers own the rematch), and
/// the `/result` route wraps it in a scaffold for direct addressability.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.data,
    required this.onHome,
    this.onRematch,
    this.rematchSection,
  });

  final MatchResultData data;

  /// Starts the same match again. Ignored when [rematchSection] is given
  /// (the online consent flow brings its own controls).
  final VoidCallback? onRematch;

  /// Returns to Home. Always present — §21 requires it on both sides.
  final VoidCallback onHome;

  /// The online rematch consent section (Phase 11, Q-9.2), replacing the
  /// plain Rematch button for online matches.
  final Widget? rematchSection;

  String get _heading {
    final winner = data.winner;
    if (winner != null && data.viewerWon) {
      return '${winner.name.toUpperCase()} WINS!';
    }
    return 'Match complete.';
  }

  String get _resultText {
    final winner = data.winner;
    if (winner == null) return 'Abandoned';
    return winner == PlayerId.blue ? 'Blue wins' : 'Red wins';
  }

  String? get _summary {
    switch (data.mode) {
      case ResultMode.local:
        return null;
      case ResultMode.versusAi:
        final d = data.aiDifficulty;
        return d == null ? null : 'Difficulty: ${d.label}';
      case ResultMode.online:
        final parts = <String>[
          if (data.roomCode != null) 'Room ${data.roomCode}',
          if (data.note != null)
            data.note!
          else if (data.opponentLeft)
            'Your opponent left the match.',
        ];
        return parts.isEmpty ? null : parts.join(' · ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xxl),
            if (data.winner != null) ...[
              Center(child: PlayerPawnDisc(player: data.winner!, size: 72)),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              _heading,
              textAlign: TextAlign.center,
              style: AppTypography.headlineLgMobile.copyWith(
                color: data.viewerWon
                    ? AppColors.tertiary
                    : AppColors.onSurface,
              ),
            ),
            if (_summary != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _summary!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              child: Column(
                children: [
                  _statRow('Turns played', '${data.turnsPlayed}'),
                  const Divider(color: AppColors.outlineVariant),
                  _statRow('Walls used — Blue', '${data.wallsUsedBlue}'),
                  const Divider(color: AppColors.outlineVariant),
                  _statRow('Walls used — Red', '${data.wallsUsedRed}'),
                  const Divider(color: AppColors.outlineVariant),
                  _statRow('Result', _resultText),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (rematchSection != null)
              rematchSection!
            else if (onRematch != null)
              PrimaryActionButton(
                label: 'REMATCH',
                icon: Icons.replay,
                onPressed: onRematch,
              ),
            const SizedBox(height: AppSpacing.md),
            SecondaryActionButton(
              label: 'RETURN TO HOME',
              icon: Icons.home_outlined,
              onPressed: onHome,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.bodyBase)),
          Text(
            value,
            style: AppTypography.numericStat.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
