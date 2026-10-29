import 'package:flutter/material.dart';

import '../../../app/application/game_interaction.dart';
import '../../../app/application/online/online_game_controller.dart';
import '../../../core/feedback/feedback_scope.dart';
import '../../../core/feedback/feedback_timing.dart';
import '../../../app/application/online/rematch_controller.dart';
import '../../../app/application/shortest_path.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/wallforge_domain.dart';
import '../../board/board.dart';
import '../result/result_screen.dart';
import 'online_rematch_section.dart';

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

/// The narrow layout's minimum content height; see the use site in
/// [OnlineGameScreen._build] for what composes it and why it exists.
const double _narrowMinHeight = 680;

class OnlineGameScreen extends StatelessWidget {
  const OnlineGameScreen({
    super.key,
    required this.controller,
    this.ownsController = false,
    this.rematch,
  });

  /// The match being played.
  final OnlineGameController controller;

  /// Whether this widget disposes the controller with the route.
  final bool ownsController;

  /// The rematch negotiation for this match (Phase 11, Q-9.2), built by the
  /// lobby alongside the match controller. Null when the screen was reached
  /// without one — the Result screen then simply offers no rematch section.
  final RematchController? rematch;

  @override
  Widget build(BuildContext context) {
    return _Owner(
      controller: controller,
      rematch: rematch,
      owns: ownsController,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _build(context),
      ),
    );
  }

  /// The shared Result screen's data, from the real finished state.
  MatchResultData _resultData() {
    final state = controller.state;
    final config = state.boardConfig;
    return MatchResultData(
      mode: ResultMode.online,
      winner: controller.isAbandoned ? null : controller.winner,
      turnsPlayed: state.turnNumber,
      wallsUsedBlue:
          config.wallsPerPlayer - state.wallsRemaining(PlayerId.blue),
      wallsUsedRed: config.wallsPerPlayer - state.wallsRemaining(PlayerId.red),
      config: config,
      mySide: controller.mySide,
      opponentLeft: controller.isAbandoned,
      roomCode: controller.room.code,
      note: controller.isAbandoned
          ? controller.claimedByMe
                ? 'You claimed this match as abandoned.'
                : 'Your opponent claimed this match as abandoned.'
          : null,
    );
  }

  Widget _build(BuildContext context) {
    // Phase 11: a finished or abandoned match hands the body to the shared
    // Result screen (§21) — the same component the local game uses — with
    // the rematch consent section in place of a plain Rematch button.
    if (controller.isFinished || controller.isAbandoned) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(context),
        body: ResultScreen(
          data: _resultData(),
          onHome: () =>
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
          rematchSection: rematch == null
              ? null
              : OnlineRematchSection(
                  controller: rematch!,
                  onMatched: (room) =>
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.online,
                        (route) => route.settings.name == AppRoutes.home,
                        arguments: room,
                      ),
                ),
        ),
      );
    }
    final tier = AppBreakpoints.of(context);
    final landscapePhone = AppBreakpoints.isLandscapePhoneOf(context);
    final railWidth = landscapePhone ? 200.0 : 280.0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: tier.isDesktop || landscapePhone
            ? Row(
                children: [
                  SizedBox(width: railWidth, child: _buildRail(PlayerId.blue)),
                  Expanded(child: _buildCenter(context)),
                  SizedBox(width: railWidth, child: _buildRail(PlayerId.red)),
                ],
              )
            : tier.isTablet
            // The tablet hybrid (Phase 14): the narrow single column,
            // centered under a width cap — the board grows relative
            // to a phone's, the panels keep their strip arrangement
            // instead of inheriting desktop's rails.
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppBreakpoints.tabletGameContentMaxWidth,
                  ),
                  child: LayoutBuilder(builder: _narrowScrollColumn),
                ),
              )
            : LayoutBuilder(builder: _narrowScrollColumn),
      ),
    );
  }

  /// The narrow (phone/tablet) single column, scrollable below its
  /// minimum height. Extracted in Phase 14 so the phone and tablet
  /// tiers share exactly one implementation of it.
  Widget _narrowScrollColumn(
    BuildContext context,
    BoxConstraints constraints,
  ) => SingleChildScrollView(
    child: SizedBox(
      // The narrow column has a real minimum height: two
      // player strips, two banners, the toggle and actions,
      // and the board at its 240px floor — about 680px in
      // the tallest state (the waiting player, whose banner
      // carries the reason text, plus Phase 10's presence
      // notice). A viewport shorter than that — 320x568 is
      // in the project's layout test set — cannot hold it,
      // and a plain Column overflows there (the waiting
      // player's view already did, before Phase 10; the
      // layout tests only ever rendered the mover's). So
      // below the minimum the column scrolls instead; at or
      // above it, this is exactly the previous layout.
      height: constraints.maxHeight < _narrowMinHeight
          ? _narrowMinHeight
          : constraints.maxHeight,
      child: Column(
        children: [
          _buildStrip(PlayerId.blue),
          _buildBanner(context),
          Expanded(child: _buildBoardArea()),
          // The mode toggle and wall actions must exist on
          // narrow layouts too: without them a phone-width
          // player could move (the default mode) but never
          // switch to WALL mode or confirm a staged wall.
          // The local game screen's mobile layout includes
          // both for the same reason.
          _buildModeToggle(),
          const SizedBox(height: AppSpacing.sm),
          _buildActions(),
          const SizedBox(height: AppSpacing.sm),
          // The banner is built twice on the narrow layout
          // (above the board and below the actions); the
          // presence notice rides only on the first, to keep
          // the minimum height above as low as it is.
          _buildBanner(context, presenceNotice: false),
          _buildStrip(PlayerId.red),
        ],
      ),
    ),
  );

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

  Widget _buildBanner(BuildContext context, {bool presenceNotice = true}) {
    final finished = controller.isFinished;
    final abandoned = controller.isAbandoned;
    final label = abandoned
        ? 'MATCH ABANDONED'
        : finished
        ? '${controller.winner?.name.toUpperCase() ?? 'DRAW'} WINS!'
        : controller.isMyTurn
        ? 'YOUR TURN'
        : "OPPONENT'S TURN";
    final colour = finished && !abandoned
        ? AppColors.tertiary
        : controller.currentPlayer == PlayerId.blue
        ? AppColors.primaryContainer
        // Banner identity text uses the light tint token for WCAG AA
        // contrast, as in the local game screen (Phase 13).
        : AppColors.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            label: label,
            // Phase 12: cross-fade on turn change (§24 state-change
            // transition), instant under reduced motion. The Semantics
            // wrapper stays outside the switcher so the live region's
            // identity is stable.
            child: AnimatedSwitcher(
              duration: FeedbackScope.durationOf(
                context,
                FeedbackTiming.uiTransition,
              ),
              child: Container(
                key: ValueKey(label),
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
          if (presenceNotice) _buildOpponentNotice(context),
        ],
      ),
    );
  }

  // --- Opponent presence (Phase 10) ------------------------------------------
  //
  // Distinct from the connection chip in the app bar: the chip is about
  // *this* client's network (Phase 9); this is about the *opponent* having
  // gone quiet on their own turn, judged from the shared document standing
  // still. Conflating the two would tell a player with a perfect connection
  // that they are the ones who dropped.

  Widget _buildOpponentNotice(BuildContext context) {
    if (controller.isAbandoned) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Semantics(
          liveRegion: true,
          label: 'Match abandoned',
          child: Text(
            controller.claimedByMe
                ? 'You claimed this match as abandoned. '
                      'Your opponent did not return.'
                : 'Your opponent claimed this match as abandoned.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    if (controller.opponentPresence != OpponentPresence.stalled) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        children: [
          Semantics(
            liveRegion: true,
            label: 'Opponent seems to have disconnected',
            child: Text(
              'Your opponent seems to have disconnected.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyBase.copyWith(color: AppColors.error),
            ),
          ),
          TextButton(
            onPressed: controller.canClaimAbandonment
                ? () => _confirmClaim(context)
                : null,
            child: Text(
              controller.isClaiming ? 'CLAIMING…' : 'CLAIM MATCH AS ABANDONED',
            ),
          ),
          if (controller.claimFailure != null)
            Text(
              controller.claimFailure!.message ??
                  'The claim could not be made.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyBase.copyWith(color: AppColors.error),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmClaim(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Claim match as abandoned?'),
        content: const Text(
          'Your opponent has not moved for over two minutes. Claiming ends '
          'the match now, with no winner.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('KEEP WAITING'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('CLAIM'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.claimAbandonment();
    }
  }

  // --- Board -----------------------------------------------------------------

  Widget _buildCenter(BuildContext context) => Column(
    children: [
      const SizedBox(height: AppSpacing.lg),
      _buildBanner(context),
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
                // Movement assistance (§23): this player's shortest route,
                // only on their turn with Move selected.
                pathCells:
                    controller.movementAssistance &&
                        controller.mode == InteractionMode.move &&
                        controller.isMyTurn &&
                        controller.mySide != null
                    ? shortestRoute(controller.state, controller.mySide!)
                    : const [],
                wallPreview: controller.pendingWall == null
                    ? null
                    : WallPreview(
                        anchor: controller.pendingWall!.anchor,
                        orientation: controller.pendingWall!.orientation,
                        isValid: pendingFailure == null,
                      ),
                // §8's Selected state (see the local game screen).
                selectedCell: controller.selectedCell,
                activeGlow: controller.isMyTurn
                    ? controller.currentPlayer
                    : null,
                onCellTap: controller.mode == InteractionMode.move
                    ? controller.tapCell
                    : null,
                onWallSlotTap: controller.mode == InteractionMode.wall
                    ? controller.tapWallSlot
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
    this.rematch,
  });

  final OnlineGameController controller;
  final RematchController? rematch;
  final bool owns;
  final Widget child;

  @override
  State<_Owner> createState() => _OwnerState();
}

class _OwnerState extends State<_Owner> {
  @override
  void dispose() {
    if (widget.owns) {
      widget.controller.dispose();
      widget.rematch?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
