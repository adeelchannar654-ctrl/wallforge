import 'package:flutter/material.dart';

import '../../../app/application/game_interaction.dart';
import '../../../app/application/online/online_game_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/wallforge_domain.dart';
import '../../board/board.dart';

/// Online match screen — one player, one board, one opponent.
///
/// ## Design
///
/// `design.md` §19 requires connection state, opponent status and the room code;
/// this adds those to the Phase 4 board and HUD rather than inventing a new
/// visual language. The board keeps the canonical orientation for both players
/// (Blue at the bottom, goals as today) and marks your own side with a YOU badge
/// — flipping the board for Red would touch the `BoardGeometry` and hit-testing
/// that Phases 3-4.3 hardened, and no source document asks for it. Recorded as
/// Q-9.1.
///
/// Accessibility follows `design.md` §26: the turn, the connection state and any
/// failure are exposed as semantics labels and never carried by colour alone.
class OnlineGameScreen extends StatelessWidget {
  const OnlineGameScreen({
    super.key,
    required this.controller,
    this.ownsController = false,
  });

  /// The match being played.
  final OnlineGameController controller;

  /// Whether this widget disposes the controller with the route.
  final bool ownsController;

  @override
  Widget build(BuildContext context) {
    return _Owner(
      controller: controller,
      owns: ownsController,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _build(context),
      ),
    );
  }

  Widget _build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: isDesktop
            ? Row(
                children: [
                  SizedBox(width: 280, child: _buildRail(PlayerId.blue)),
                  Expanded(child: _buildCenter()),
                  SizedBox(width: 280, child: _buildRail(PlayerId.red)),
                ],
              )
            : Column(
                children: [
                  _buildStrip(PlayerId.blue),
                  _buildBanner(),
                  Expanded(child: _buildBoardArea()),
                  _buildBanner(),
                  _buildStrip(PlayerId.red),
                ],
              ),
      ),
    );
  }

  // --- App bar: code, connection chip, and back -----------------------------

  PreferredSizeWidget _buildAppBar(BuildContext context) => AppBar(
    backgroundColor: AppColors.background,
    foregroundColor: AppColors.onSurface,
    titleSpacing: AppSpacing.lg,
    title: Text(
      controller.room.code.isEmpty ? 'MATCH' : controller.room.code,
      style: AppTypography.labelCaps.copyWith(letterSpacing: 3),
    ),
    actions: [
      _ConnectionChip(state: controller.connection, sync: controller.sync),
      const SizedBox(width: AppSpacing.md),
    ],
  );

  // --- Player HUD ------------------------------------------------------------

  Widget _buildStrip(PlayerId side) => _playerBar(side, compact: true);

  Widget _buildRail(PlayerId side) => _playerBar(side, compact: false);

  Widget _playerBar(PlayerId side, {required bool compact}) {
    final isMine = controller.mySide == side;
    final colour = side == PlayerId.blue
        ? AppColors.primaryContainer
        : AppColors.secondaryContainer;
    final seat = controller.room.seatFor(side);
    // The row says *which seat you occupy*; the banner below says *whose turn
    // it is*. They used to overlap — "YOUR TURN" appeared in both — which is
    // why the wording is split rather than merely repeated.
    final label = side.name.toUpperCase();
    final detail = seat.isEmpty
        ? 'WAITING'
        : isMine
        ? 'YOU'
        : 'OPPONENT';

    return Container(
      margin: EdgeInsets.all(compact ? AppSpacing.xs : AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          // An outline as well as a colour, so "mine" is not colour-only.
          color: isMine ? colour : AppColors.outlineVariant,
          width: isMine ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.labelCaps.copyWith(
                color: isMine ? colour : AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Semantics(
            label: '$label seat, $detail',
            child: Text(
              detail,
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Turn banner -----------------------------------------------------------

  Widget _buildBanner() {
    final finished = controller.isFinished;
    final label = finished
        ? '${controller.winner?.name.toUpperCase() ?? 'DRAW'} WINS!'
        : controller.isMyTurn
        ? 'YOUR TURN'
        : "OPPONENT'S TURN";
    final colour = finished
        ? AppColors.tertiary
        : controller.currentPlayer == PlayerId.blue
        ? AppColors.primaryContainer
        : AppColors.secondaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            label: label,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Text(
                label,
                style: AppTypography.labelCaps.copyWith(color: colour),
              ),
            ),
          ),
          // Why input is refused, stated in words rather than only greyed out.
          if (controller.inputBlockedReason != null && !finished)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                controller.inputBlockedReason!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          if (controller.sync != OnlineSyncState.inSync)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                controller.statusMessage ??
                    'The shared board could not be verified.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyBase.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  // --- Board -----------------------------------------------------------------

  Widget _buildCenter() => Column(
    children: [
      const SizedBox(height: AppSpacing.lg),
      _buildBanner(),
      const SizedBox(height: AppSpacing.md),
      Expanded(child: _buildBoardArea()),
      const SizedBox(height: AppSpacing.md),
      _buildModeToggle(),
      const SizedBox(height: AppSpacing.sm),
      _buildActions(),
      const SizedBox(height: AppSpacing.lg),
    ],
  );

  Widget _buildBoardArea() => LayoutBuilder(
    builder: (context, constraints) {
      final pendingFailure = controller.pendingWallFailure;
      final reserved = pendingFailure == null ? 0.0 : AppSpacing.xxl;
      final size = (constraints.biggest.shortestSide - reserved).clamp(
        240.0,
        640.0,
      );
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: BoardView(
                state: controller.state,
                // Empty when it is not this player's turn, so no target is
                // drawn and nothing looks tappable.
                legalMoveTargets: controller.legalMoveTargets,
                wallPreview: controller.pendingWall == null
                    ? null
                    : WallPreview(
                        anchor: controller.pendingWall!.anchor,
                        orientation: controller.pendingWall!.orientation,
                        isValid: pendingFailure == null,
                      ),
                activeGlow: controller.isMyTurn
                    ? controller.currentPlayer
                    : null,
              ),
            ),
            if (pendingFailure != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'That wall is not allowed here.',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _buildModeToggle() => Opacity(
    opacity: controller.isMyTurn ? 1 : 0.4,
    child: SegmentedButton<InteractionMode>(
      segments: const [
        ButtonSegment(
          value: InteractionMode.move,
          label: Text('MOVE'),
          icon: Icon(Icons.open_with, size: 16),
        ),
        ButtonSegment(
          value: InteractionMode.wall,
          label: Text('WALL'),
          icon: Icon(Icons.horizontal_rule, size: 16),
        ),
      ],
      selected: {controller.mode},
      onSelectionChanged: controller.isMyTurn
          ? (modes) => controller.setMode(modes.first)
          : null,
    ),
  );

  Widget _buildActions() => Opacity(
    opacity: controller.isMyTurn ? 1 : 0.4,
    child: controller.pendingWall == null
        ? Text(
            controller.mode == InteractionMode.wall
                ? 'Tap a wall slot, then confirm.'
                : 'Tap a highlighted cell to move.',
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: controller.isMyTurn ? controller.cancel : null,
                child: const Text('CANCEL', style: AppTypography.labelCaps),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton(
                onPressed:
                    controller.isMyTurn && controller.pendingWallFailure == null
                    ? controller.confirm
                    : null,
                child: const Text('PLACE WALL', style: AppTypography.labelCaps),
              ),
            ],
          ),
  );
}

/// The five `design.md` §19 connection states, plus a sync warning when the shown
/// board could not be verified.
class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state, required this.sync});

  final OnlineConnectionState state;
  final OnlineSyncState sync;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = switch (state) {
      OnlineConnectionState.connecting => (
        'CONNECTING',
        AppColors.textSecondary,
      ),
      OnlineConnectionState.waiting => ('WAITING', AppColors.textSecondary),
      OnlineConnectionState.connected when sync != OnlineSyncState.inSync => (
        'CHECKING',
        AppColors.error,
      ),
      OnlineConnectionState.connected => (
        'CONNECTED',
        AppColors.primaryContainer,
      ),
      OnlineConnectionState.reconnecting => ('RECONNECTING', AppColors.error),
      OnlineConnectionState.disconnected => ('DISCONNECTED', AppColors.error),
    };
    // A dot as well as a word, so the state is not colour-only.
    return Semantics(
      label: 'Connection $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadii.full),
          border: Border.all(color: colour),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(label, style: AppTypography.labelCaps.copyWith(color: colour)),
          ],
        ),
      ),
    );
  }
}

/// Disposes the controller with the route when it owns it.
class _Owner extends StatefulWidget {
  const _Owner({
    required this.controller,
    required this.owns,
    required this.child,
  });

  final OnlineGameController controller;
  final bool owns;
  final Widget child;

  @override
  State<_Owner> createState() => _OwnerState();
}

class _OwnerState extends State<_Owner> {
  @override
  void dispose() {
    if (widget.owns) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
