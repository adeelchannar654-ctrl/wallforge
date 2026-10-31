import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Phase 16.5: the per-move countdown, shown beside the player
/// whose turn is being timed.
///
/// The low-time state is carried by more than colour: the icon
/// changes to a warning triangle and the semantic label says
/// "low time", so the cue survives colour assistance and a
/// screen reader. Threshold announcements (10 s / 5 s) travel
/// through a visually hidden live region — announced, never
/// shown, and never fired per second.
class ClockChip extends StatelessWidget {
  const ClockChip({
    super.key,
    required this.remaining,
    required this.lowTime,
    this.announcement,
  });

  /// Time left on the running turn's clock.
  final Duration remaining;

  /// Whether the clock is in its last five seconds.
  final bool lowTime;

  /// The latest threshold announcement, or null.
  final String? announcement;

  /// Formats a remaining duration as `m:ss`.
  static String format(Duration value) {
    final total = value.inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final seconds = remaining.inSeconds;
    final color = lowTime ? AppColors.error : AppColors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: 'Time left $seconds seconds${lowTime ? ', low time' : ''}',
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  lowTime ? Icons.warning_amber_rounded : Icons.timer_outlined,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  format(remaining),
                  style: AppTypography.numericStat.copyWith(
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        // The announcement node: present in the semantics tree
        // as a live region, invisible on screen.
        Semantics(
          liveRegion: true,
          label: announcement ?? '',
          child: const SizedBox(width: 1, height: 1),
        ),
      ],
    );
  }
}
