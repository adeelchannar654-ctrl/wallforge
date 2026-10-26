import 'package:flutter/material.dart';

import '../../../app/application/online/rematch_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/repositories/room.dart';
import '../../widgets/app_chrome.dart';

/// The rematch consent controls on the online Result screen (Q-9.2).
///
/// Both players must explicitly agree: one proposes, the other accepts,
/// and only then does a brand-new room exist. Declining is doing nothing —
/// or tapping Decline, which dismisses the proposal on this screen. The
/// section owns no navigation except reporting the agreed room through
/// [onMatched]; the game screen routes both players into the new room's
/// lobby from there.
class OnlineRematchSection extends StatefulWidget {
  const OnlineRematchSection({
    super.key,
    required this.controller,
    required this.onMatched,
  });

  final RematchController controller;

  /// Called once when both players have consented and the new room exists.
  final ValueChanged<Room> onMatched;

  @override
  State<OnlineRematchSection> createState() => _OnlineRematchSectionState();
}

class _OnlineRematchSectionState extends State<OnlineRematchSection> {
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    widget.controller.start();
    widget.controller.addListener(_checkMatched);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkMatched);
    super.dispose();
  }

  void _checkMatched() {
    final controller = widget.controller;
    if (_reported || controller.phase != RematchPhase.matched) return;
    final room = controller.matchedRoom;
    if (room == null) return;
    _reported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMatched(room);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.message != null) ...[
              Text(
                controller.message!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            switch (controller.phase) {
              RematchPhase.idle => PrimaryActionButton(
                label: 'REMATCH',
                icon: Icons.replay,
                onPressed: controller.propose,
              ),
              RematchPhase.proposing => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rematch proposed — waiting for your opponent to accept.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyBase.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryActionButton(
                    label: 'CANCEL PROPOSAL',
                    icon: Icons.close,
                    onPressed: controller.cancelProposal,
                  ),
                ],
              ),
              RematchPhase.proposalAvailable => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Your opponent wants a rematch.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyBase,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryActionButton(
                    label: 'ACCEPT REMATCH',
                    icon: Icons.replay,
                    onPressed: controller.accept,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: controller.decline,
                    child: const Text('Decline'),
                  ),
                ],
              ),
              RematchPhase.matched => Text(
                'Rematch agreed — entering the new room…',
                textAlign: TextAlign.center,
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
              RematchPhase.unavailable => const SizedBox.shrink(),
            },
            if (controller.phase == RematchPhase.idle)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'A rematch starts a new room. Both players must agree — '
                  'nobody is moved automatically.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
