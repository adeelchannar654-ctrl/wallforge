import 'package:flutter/material.dart';

import '../../app/router/app_router.dart';
import '../../domain/models/achievement.dart';

/// Shows the achievement unlock toast (Phase 16.5, Part F).
///
/// A SnackBar: non-modal, auto-dismissing, and announced by
/// the platform's accessibility layer — it never blocks play
/// and never takes focus. When several achievements unlock
/// from one match they are summarised in a single toast
/// rather than queued one behind another. The VIEW action
/// opens the Achievements screen.
void showAchievementUnlocks(
  BuildContext context,
  List<AchievementDefinition> unlocked,
) {
  if (unlocked.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final label = unlocked.length == 1
      ? 'Achievement unlocked: ${unlocked.single.name}'
      : '${unlocked.length} achievements unlocked';
  messenger.showSnackBar(
    SnackBar(
      content: Semantics(
        liveRegion: true,
        label: label,
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      ),
      action: SnackBarAction(
        label: 'VIEW',
        onPressed: () =>
            Navigator.of(context).pushNamed(AppRoutes.achievements),
      ),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
