import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';

/// Confirmation dialogs for ending or leaving an active match
/// (Phase 16.5).
///
/// Two distinct acts are kept distinct in the wording, because
/// they are distinct in effect:
///
/// * **Resign** ends the match now; the opponent wins. There is
///   no undo and nothing to resume.
/// * **Leave** (local modes only) walks away from the screen;
///   the match is saved and can be resumed from Home.
///
/// Both dialogs are plain `AlertDialog`s: they trap focus
/// correctly, are announced by screen readers as dialogs, and
/// every action is a labelled text button (never colour alone).

/// Asks whether the player really wants to resign. Returns true
/// only on an explicit Resign tap.
Future<bool> showResignDialog(
  BuildContext context, {
  required bool online,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Resign this match?',
        style: AppTypography.titleMd.copyWith(color: AppColors.onSurface),
      ),
      content: Text(
        online
            ? 'Your opponent wins immediately. This cannot be undone.'
            : 'The other player wins immediately. This cannot be undone.',
        style: AppTypography.bodyBase.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('KEEP PLAYING'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('RESIGN'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// What the player chose in the leave-match dialog.
enum LeaveChoice {
  /// Stay in the match.
  keepPlaying,

  /// Leave the screen; the local match stays saved for resume.
  leaveSaved,

  /// Resign: the match ends now and the opponent wins.
  resign,
}

/// The confirm dialog shown when leaving an active **local**
/// match: it makes the leave-vs-resign distinction explicit
/// instead of letting a back tap silently abandon the game.
Future<LeaveChoice> showLeaveMatchDialog(BuildContext context) async {
  final result = await showDialog<LeaveChoice>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(
        'Leave this match?',
        style: AppTypography.titleMd.copyWith(color: AppColors.onSurface),
      ),
      content: Text(
        'The match is saved — you can resume it from Home. '
        'Or resign now, and the other player wins.',
        style: AppTypography.bodyBase.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(LeaveChoice.keepPlaying),
          child: const Text('KEEP PLAYING'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(LeaveChoice.leaveSaved),
          child: const Text('LEAVE (SAVED)'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(LeaveChoice.resign),
          child: const Text('RESIGN'),
        ),
      ],
    ),
  );
  return result ?? LeaveChoice.keepPlaying;
}
