import 'package:flutter/material.dart';

import '../../../app/application/replay.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_history_repository.dart';
import '../../../domain/models/match_record.dart';
import '../../../domain/models/player_id.dart';
import '../../../domain/repositories/repositories.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/result_card.dart';
import 'history_screen.dart' show historyHeadline, formatHistoryDuration;

/// One history record in full (Phase 16.5, Part E): the facts
/// of the match, its move list (kept for a future replay
/// viewer — none is built in this phase), and deletion.
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({
    super.key,
    required this.record,
    this.historyRepository = const SharedPreferencesHistoryRepository(),
  });

  final MatchRecord record;
  final MatchHistoryRepository historyRepository;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this record?'),
        content: const Text(
          'The match will be removed from this device\'s history. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await historyRepository.delete(record.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Match details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete this record',
            onPressed: () => _delete(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle(historyHeadline(r).toUpperCase()),
                      const SizedBox(height: AppSpacing.md),
                      _row('Mode', r.mode.label),
                      _row('Opponent', r.opponentLabel),
                      if (r.mySide != null)
                        _row('Your side', _sideLabel(r.mySide!)),
                      if (r.winnerSide != null)
                        _row('Winner', _sideLabel(r.winnerSide!)),
                      _row('Finished by', r.finishReason.label),
                      _row(
                        'Board',
                        '${r.boardSize}×${r.boardSize} · '
                            '${r.wallsPerPlayer} walls',
                      ),
                      _row('Plies', '${r.plies}'),
                      _row('Duration', formatHistoryDuration(r.durationMs)),
                      _row(
                        'Move clock',
                        r.timeControlSeconds == 0
                            ? 'Off'
                            : '${r.timeControlSeconds} seconds per move',
                      ),
                      if (r.rematchOf != null)
                        _row('Rematch', 'Rematch of an earlier match'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SecondaryActionButton(
                  label: 'SHARE RESULT',
                  icon: Icons.share_outlined,
                  onPressed: () => shareMatchResult(
                    context,
                    record: r,
                    finalState: replayFinalState(r),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('MOVES'),
                      const SizedBox(height: AppSpacing.md),
                      if (!r.movesComplete)
                        Text(
                          'The move list is incomplete — this device '
                          'did not witness every ply of this match.',
                          style: AppTypography.bodyBase.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      else if (r.moves.isEmpty)
                        Text(
                          'No moves were played.',
                          style: AppTypography.bodyBase.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      else
                        Text(
                          [
                            for (var i = 0; i < r.moves.length; i++)
                              '${i + 1}. ${r.moves[i]}',
                          ].join('\n'),
                          style: AppTypography.bodyBase,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _sideLabel(PlayerId side) =>
      '${side.name[0].toUpperCase()}${side.name.substring(1)}';

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTypography.bodyBase)),
        ],
      ),
    );
  }
}
