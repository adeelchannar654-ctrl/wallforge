import 'package:flutter/material.dart';

import '../../../app/application/local_game_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_elevation.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/models/game_status.dart';
import '../../../domain/models/player_id.dart';
import '../../board/board.dart';

/// Interactive local game screen — pass-and-play between two humans.
///
/// Layout:
/// - Mobile (< 768px): single-column, board above controls.
/// - Desktop (>= 768px): 3-column, 280px side rails with HUD + board center.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.controller});

  final LocalGameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isDesktop = MediaQuery.sizeOf(context).width >= 768;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Stack(
            children: [
              SafeArea(
                child: isDesktop
                    ? _buildDesktopLayout(context)
                    : _buildMobileLayout(context),
              ),
              if (controller.showingResult)
                Positioned.fill(child: _buildResultOverlay(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Left rail — P1 HUD
        SizedBox(width: 280, child: _buildPlayerRail(PlayerId.blue)),
        // Center — board + turn banner
        Expanded(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              _buildTurnBanner(),
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
        SizedBox(width: 280, child: _buildPlayerRail(PlayerId.red)),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        // P1 HUD strip (compact)
        _buildPlayerStrip(PlayerId.blue),
        const SizedBox(height: AppSpacing.sm),
        // Turn banner
        _buildTurnBanner(),
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

  Widget _buildBoardArea() {
    final pendingFailure = controller.pendingWallFailure;
    return LayoutBuilder(
      builder: (context, constraints) {
        final reservedHeight = pendingFailure == null ? 0.0 : AppSpacing.xxl;
        final boardSize = (constraints.biggest.shortestSide - reservedHeight)
            .clamp(280.0, 640.0);
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
                  wallPreview: controller.pendingWall != null
                      ? WallPreview(
                          anchor: controller.pendingWall!.anchor,
                          orientation: controller.pendingWall!.orientation,
                          isValid: pendingFailure == null,
                        )
                      : null,
                  activeGlow: controller.state.status == GameStatus.inProgress
                      ? controller.currentPlayer
                      : null,
                  onCellTap: controller.tapCell,
                  onWallSlotTap: controller.tapWallSlot,
                ),
              ),
              if (pendingFailure != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    LocalGameController.failureMessage(pendingFailure),
                    key: const ValueKey('pending-wall-failure'),
                    style: AppTypography.bodyBase.copyWith(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTurnBanner() {
    final isBlue = controller.currentPlayer == PlayerId.blue;
    final isFinished = controller.state.status == GameStatus.finished;
    final label = isFinished
        ? '${controller.winner?.name.toUpperCase() ?? "DRAW"} WINS!'
        : '${controller.currentPlayer.name.toUpperCase()}\'S TURN';

    return Container(
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
              : AppColors.secondaryContainer,
        ),
      ),
    );
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
            return const BorderSide(color: AppColors.primaryContainer);
          }
          return const BorderSide(color: AppColors.outlineVariant);
        }),
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
          Text(
            LocalGameController.failureMessage(controller.lastFailure!),
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.error,
              fontSize: 12,
            ),
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

  Widget _buildResultOverlay(BuildContext context) {
    final winner = controller.winner;
    final heading = winner == null
        ? 'MATCH COMPLETE'
        : '${winner.name.toUpperCase()} WINS!';
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            key: const ValueKey('game-result-overlay'),
            width: double.infinity,
            margin: const EdgeInsets.all(AppSpacing.lg),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.xl),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  heading,
                  key: const ValueKey('result-heading'),
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.tertiary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'MATCH COMPLETE',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'TURN ${controller.state.turnNumber}',
                  style: AppTypography.numericStat.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'BLUE ${controller.state.wallsRemaining(PlayerId.blue)} WALLS  •  '
                  'RED ${controller.state.wallsRemaining(PlayerId.red)} WALLS',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _buildButton(
                      'REMATCH',
                      AppColors.primaryContainer,
                      controller.rematch,
                    ),
                    _buildButton(
                      'HOME',
                      AppColors.onSurfaceVariant,
                      () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
