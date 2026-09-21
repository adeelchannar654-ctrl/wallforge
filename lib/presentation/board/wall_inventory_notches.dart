import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Wall inventory notch display.
///
/// A row of micro luminous vertical notches. Lit notches = remaining walls.
/// Unlit notches = spent walls (dark slate).
///
/// Matches `main_gameplay_screen/code.html` L257-267:
/// `w-1.5 h-3 rounded-full bg-primary-container shadow-[...]`.
class WallInventoryNotches extends StatelessWidget {
  const WallInventoryNotches({
    super.key,
    required this.total,
    required this.remaining,
    required this.playerColor,
    this.spacing = 4,
    this.notchWidth = 6,
    this.notchHeight = 12,
    this.showCount = true,
  });

  /// Total walls per player.
  final int total;

  /// Walls remaining.
  final int remaining;

  /// Player accent colour (cyan for P1, crimson for P2).
  final Color playerColor;

  /// Spacing between notches.
  final double spacing;

  /// Width of each notch.
  final double notchWidth;

  /// Height of each notch.
  final double notchHeight;

  /// Whether to show the "X Walls" text count.
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? spacing : 0),
            child: _Notch(
              lit: i < remaining,
              color: playerColor,
              width: notchWidth,
              height: notchHeight,
            ),
          ),
        if (showCount) ...[
          const SizedBox(width: 6),
          Text(
            '$remaining',
            style: TextStyle(
              color: playerColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.06,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({
    required this.lit,
    required this.color,
    required this.width,
    required this.height,
  });

  final bool lit;
  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: lit ? color : AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(width / 2),
        boxShadow: lit
            ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
            : null,
      ),
    );
  }
}
