import 'package:flutter/material.dart';

import '../../../app/application/game_interaction.dart';
import '../../../app/application/local_game_controller.dart';
import '../../../core/feedback/feedback_scope.dart';
import '../../../core/feedback/feedback_timing.dart';
import '../../../app/application/shortest_path.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_elevation.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/engine/game_engine.dart';
import '../../../domain/models/game_action.dart';
import '../../../domain/models/game_status.dart';
import '../../../domain/models/player_id.dart';
import '../../board/board.dart';
import '../result/result_screen.dart';

/// Interactive local game screen — pass-and-play between two humans.
///
/// Layout (Phase 14, `AppBreakpoints` — design.md §27):
/// - Phone: single-column, board above controls.
/// - Tablet: the balanced hybrid — the same single column, centered
///   and capped, so the board grows relative to a phone's while the
///   panels keep their strip arrangement instead of desktop's rails.
/// - Desktop: 3-column, 280px side rails with HUD + board center.
/// - Landscape phones borrow the desktop arrangement with compact
///   200px rails (the recorded portrait-first exception, §13w).
class GameScreen extends StatelessWidget {
  const GameScreen({
    super.key,
    required this.controller,
    this.ownsController = false,
  });

  final LocalGameController controller;

  /// Whether this widget disposes [controller] when the route is popped.
  ///
  /// Fixes Q-8.6: since Phase 4 the `/game` route built a controller per push
  /// and nothing ever disposed it, so every game left a `ChangeNotifier` — and
  /// its persistence subscriptions — alive for the life of the process. The
  /// route therefore sets this.
  ///
  /// It is opt-in rather than automatic because a test that injects a controller
  /// usually wants to assert on it after the route is gone, and disposing it
  /// behind the test's back would break that. A test that passes `true` is
  /// declaring that the screen owns the controller's lifetime.
  final bool ownsController;

  @override
  Widget build(BuildContext context) {
    return _ControllerOwnership(
      controller: controller,
      owns: ownsController,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          // Phase 11: a finished match hands the whole screen to the shared
          // Result screen (§21) — the same component the online game uses —
          // instead of the Phase 4 overlay this screen used to draw.
          if (controller.showingResult) {
            return Scaffold(
              backgroundColor: AppColors.background,
              body: ResultScreen(
                data: _resultData(),
                onRematch: controller.rematch,
                onHome: () =>
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
              ),
            );
          }
          final tier = AppBreakpoints.of(context);
          final landscapePhone = AppBreakpoints.isLandscapePhoneOf(context);
          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: tier.isDesktop || landscapePhone
                  ? _buildDesktopLayout(
                      context,
                      railWidth: landscapePhone ? 200 : 280,
                    )
                  : tier.isTablet
                  ? _buildTabletLayout(context)
                  : _buildMobileLayout(context),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, {double railWidth = 280}) {
    return Row(
      children: [
        // Left rail — P1 HUD
        SizedBox(width: railWidth, child: _buildPlayerRail(PlayerId.blue)),
        // Center — board + turn banner
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              _buildTurnBanner(context),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _buildBoardArea()),
              const SizedBox(height: AppSpacing.sm),
              _buildModeToggle(),
              const SizedBox(height: AppSpacing.sm),
              _buildActionButtons(context),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
        // Right rail — P2 HUD
        SizedBox(width: railWidth, child: _buildPlayerRail(PlayerId.red)),
      ],
    );
  }

  /// The tablet hybrid (Phase 14): the phone's single column —
  /// strips, banner, board, controls — centered under a width cap,
  /// so on a portrait tablet the board is substantially larger than
  /// on a phone while the information panels keep the strip layout
  /// rather than inheriting desktop's side rails (§27: panels change
  /// layout, the board changes relative size; nothing is merely
  /// scaled up).
  Widget _buildTabletLayout(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppBreakpoints.tabletGameContentMaxWidth,
        ),
        child: _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // P1 HUD strip (compact)
        _buildPlayerStrip(PlayerId.blue),
        const SizedBox(height: AppSpacing.sm),
        // Turn banner
        _buildTurnBanner(context),
        const SizedBox(height: AppSpacing.sm),
        // Board
        Expanded(child: _buildBoardArea()),
        const SizedBox(height: AppSpacing.sm),
        // Mode toggle
        _buildModeToggle(),
        const SizedBox(height: AppSpacing.sm),
        // Action buttons
        _buildActionButtons(context),
        const SizedBox(height: AppSpacing.sm),
        // P2 HUD strip (compact)
        _buildPlayerStrip(PlayerId.red),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  /// The shared Result screen's data, from the real finished state.
  MatchResultData _resultData() {
    final state = controller.state;
    final config = state.boardConfig;
    return MatchResultData(
      mode: controller.versusAi ? ResultMode.versusAi : ResultMode.local,
      winner: controller.winner,
      turnsPlayed: state.turnNumber,
      wallsUsedBlue:
          config.wallsPerPlayer - state.wallsRemaining(PlayerId.blue),
      wallsUsedRed: config.wallsPerPlayer - state.wallsRemaining(PlayerId.red),
      config: config,
      mySide: controller.versusAi ? PlayerId.blue : null,
      aiDifficulty: controller.versusAi ? controller.aiDifficulty : null,
    );
  }

  Widget _buildBoardArea() {
    final pendingFailure = controller.pendingWallFailure;
    return LayoutBuilder(
      builder: (context, constraints) {
        final reservedHeight = pendingFailure == null ? 0.0 : AppSpacing.xxl;
        final offered = constraints.biggest.shortestSide - reservedHeight;
        // The 280 floor keeps the board playable — but it must never
        // overflow the slot (Phase 14: in the landscape-phone rails
        // layout the center column is height-constrained and forcing
        // 280 overflowed it by exactly the difference). Below the
        // floor, the board takes what the slot offers.
        final boardSize = offered < 280.0
            ? offered.clamp(0.0, 640.0)
            : offered.clamp(280.0, 640.0);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: boardSize,
                height: boardSize,
                child: BoardView(
                  state: controller.state,
                  legalMoveTargets: controller.legalMoveTargets,
                  // Movement assistance (§23): the current player's
                  // shortest route, only while Move is selected.
                  pathCells:
                      controller.settings.movementAssistance &&
                          controller.mode == InteractionMode.move &&
                          controller.state.status == GameStatus.inProgress
                      ? shortestRoute(
                          controller.state,
                          controller.currentPlayer,
                        )
                      : const [],
                  wallPreview: controller.pendingWall != null
                      ? WallPreview(
                          anchor: controller.pendingWall!.anchor,
                          orientation: controller.pendingWall!.orientation,
                          isValid: pendingFailure == null,
                        )
                      : null,
                  // §8's Selected state: the tapped cell's ring. The
                  // controller has carried this since Phase 4 and the
                  // painter plumbed it, but no screen ever passed it —
                  // Phase 12 verification found and closed that gap.
                  selectedCell: controller.selectedCell,
                  activeGlow: controller.state.status == GameStatus.inProgress
                      ? controller.currentPlayer
                      : null,
                  onCellTap: controller.mode == InteractionMode.move
                      ? controller.tapCell
                      : null,
                  onWallSlotTap: controller.mode == InteractionMode.wall
                      ? controller.tapWallSlot
                      : null,
                  // Phase 14 (§28): mouse users get the ghost preview
                  // on hover, before committing to a click. Validity
                  // is the engine's own validate — the same call the
                  // staged preview makes, so they can never disagree.
                  hoverWallPreviewFor: controller.mode == InteractionMode.wall
                      ? (anchor, orientation) => WallPreview(
                          anchor: anchor,
                          orientation: orientation,
                          isValid:
                              GameEngine.validate(
                                controller.state,
                                controller.currentPlayer,
                                GameAction.wall(
                                  orientation: orientation,
                                  anchor: anchor,
                                ),
                              ) ==
                              null,
                        )
                      : null,
                ),
              ),
              if (pendingFailure != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: _failureText(
                    LocalGameController.failureMessage(pendingFailure),
                    key: const ValueKey('pending-wall-failure'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTurnBanner(BuildContext context) {
    final isBlue = controller.currentPlayer == PlayerId.blue;
    final isFinished = controller.state.status == GameStatus.finished;
    final label = isFinished
        ? '${controller.winner?.name.toUpperCase() ?? "DRAW"} WINS!'
        : '${controller.currentPlayer.name.toUpperCase()}\'S TURN';

    // Phase 12: the banner cross-fades when the turn changes — a UI
    // transition communicating a state change (§24), at the shared
    // duration, and instant under reduced motion.
    final banner = AnimatedSwitcher(
      duration: FeedbackScope.durationOf(context, FeedbackTiming.uiTransition),
      child: Container(
        key: ValueKey(label),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(
          label,
          style: AppTypography.labelCaps.copyWith(
            color: isFinished
                ? AppColors.tertiary
                : isBlue
                ? AppColors.primaryContainer
                // The banner is identity *text*: the light tint token,
                // not the deep container crimson, so the words meet
                // WCAG AA contrast on the banner surface (Phase 13).
                : AppColors.secondary,
          ),
        ),
      ),
    );

    // While the AI is deciding, say so (§20's thinking indicator, Phase 11).
    // Phase 13: the turn banner is a live region — whose turn it is (and
    // who won) is announced to assistive technology as it changes, the
    // treatment the online game screen already had.
    final liveBanner = Semantics(liveRegion: true, child: banner);
    // Board input is already blocked by the controller during its turn;
    // this only names that state.
    if (controller.versusAi && controller.isAiTurn && !isFinished) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          liveBanner,
          const SizedBox(height: AppSpacing.xs),
          // Phase 16: the thinking state is its own live region, so
          // its appearance is announced; the cue is text, never
          // colour alone.
          Semantics(
            liveRegion: true,
            child: Text(
              'AI is thinking…',
              key: const ValueKey('ai-thinking'),
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }
    return liveBanner;
  }

  Widget _buildModeToggle() {
    return SegmentedButton<InteractionMode>(
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
      onSelectionChanged: (modes) {
        controller.setMode(modes.first);
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryContainer.withValues(alpha: 0.2);
          }
          return AppColors.surfaceContainer;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryContainer;
          }
          return AppColors.onSurfaceVariant;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: AppColors.primaryContainer);
          }
          return BorderSide(color: AppColors.outlineVariant);
        }),
      ),
    );
  }

  /// A failure message the way `design.md` §26 requires: icon + text
  /// (never colour alone), announced to assistive technology as a live
  /// region (Phase 13). The wording itself comes from the engine's
  /// plain-language failure messages.
  Widget _failureText(String message, {Key? key}) {
    return Semantics(
      key: key,
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 14),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              message,
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final hasPending = controller.pendingWall != null;
    final hasFailure = controller.lastFailure != null;
    final pendingFailure = controller.pendingWallFailure;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        if (hasFailure)
          _failureText(
            LocalGameController.failureMessage(controller.lastFailure!),
          ),
        if (hasPending) ...[
          _buildButton('CANCEL', AppColors.onSurfaceVariant, controller.cancel),
          _buildButton(
            'CONFIRM',
            AppColors.primaryContainer,
            controller.confirm,
            enabled: pendingFailure == null,
          ),
        ] else ...[
          _buildButton(
            'RESTART',
            AppColors.onSurfaceVariant,
            controller.restart,
          ),
          _buildButton(
            'BACK',
            AppColors.onSurfaceVariant,
            () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }

  Widget _buildButton(
    String label,
    Color color,
    VoidCallback onPressed, {
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : AppColors.onSurfaceVariant;
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        backgroundColor: effectiveColor.withValues(
          alpha: enabled ? 0.15 : 0.08,
        ),
        foregroundColor: effectiveColor,
        disabledForegroundColor: AppColors.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: effectiveColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelCaps.copyWith(color: effectiveColor),
      ),
    );
  }

  Widget _buildPlayerRail(PlayerId player) {
    final isBlue = player == PlayerId.blue;
    final label = isBlue ? 'PLAYER 1' : 'PLAYER 2';
    final color = isBlue
        ? AppColors.primaryContainer
        : AppColors.secondaryContainer;
    final pos = controller.state.pawnPosition(player);
    final size = controller.state.boardConfig.size;
    final file = String.fromCharCode(0x61 + pos.column);
    final rank = size - pos.row;
    final walls = controller.state.wallsRemaining(player);
    final isActive =
        controller.currentPlayer == player &&
        controller.state.status == GameStatus.inProgress;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(
          color: isActive ? color : AppColors.outlineVariant,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive ? AppElevation.hudShadow : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.labelCaps.copyWith(color: color)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$file$rank',
            style: AppTypography.numericStat.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          WallInventoryNotches(
            total: controller.state.boardConfig.wallsPerPlayer,
            remaining: walls,
            playerColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStrip(PlayerId player) {
    final isBlue = player == PlayerId.blue;
    final label = isBlue ? 'P1' : 'P2';
    final color = isBlue
        ? AppColors.primaryContainer
        : AppColors.secondaryContainer;
    final walls = controller.state.wallsRemaining(player);
    final isActive =
        controller.currentPlayer == player &&
        controller.state.status == GameStatus.inProgress;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: isActive ? color : AppColors.outlineVariant,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Text(label, style: AppTypography.labelCaps.copyWith(color: color)),
          const Spacer(),
          WallInventoryNotches(
            total: controller.state.boardConfig.wallsPerPlayer,
            remaining: walls,
            playerColor: color,
            notchWidth: 4,
            notchHeight: 8,
          ),
        ],
      ),
    );
  }
}

/// Disposes a controller when the screen is torn down, if it owns it.
///
/// A private `StatefulWidget` rather than making [GameScreen] itself stateful:
/// it keeps the public widget shape and the rendered tree byte-identical, so
/// the Phase 3–4 golden tests cannot be affected by a lifetime fix.
class _ControllerOwnership extends StatefulWidget {
  const _ControllerOwnership({
    required this.controller,
    required this.owns,
    required this.child,
  });

  final LocalGameController controller;
  final bool owns;
  final Widget child;

  @override
  State<_ControllerOwnership> createState() => _ControllerOwnershipState();
}

class _ControllerOwnershipState extends State<_ControllerOwnership> {
  @override
  void dispose() {
    if (widget.owns) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
