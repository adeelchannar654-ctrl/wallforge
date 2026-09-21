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
          body: SafeArea(
            child: isDesktop
                ? _buildDesktopLayout(context)
                : _buildMobileLayout(context),
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
              const SizedBox(height: AppSpacing.md),
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
    return Center(
      child: BoardView(
        state: controller.state,
        legalMoveTargets: controller.legalMoveTargets,
        wallPreview: controller.pendingWall != null
            ? WallPreview(
                anchor: controller.pendingWall!.anchor,
                orientation: controller.pendingWall!.orientation,
                isValid: true,
              )
            : null,
        activeGlow: controller.state.status == GameStatus.inProgress
            ? controller.currentPlayer
            : null,
        onCellTap: controller.tapCell,
        onWallSlotTap: controller.tapWallSlot,
      ),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasFailure)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Text(
              LocalGameController.failureMessage(controller.lastFailure!),
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        if (hasPending) ...[
          _buildButton('CANCEL', AppColors.onSurfaceVariant, controller.cancel),
          const SizedBox(width: AppSpacing.sm),
          _buildButton(
            'CONFIRM',
            AppColors.primaryContainer,
            controller.confirm,
          ),
        ] else ...[
          _buildButton(
            'RESTART',
            AppColors.onSurfaceVariant,
            controller.restart,
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildButton(
            'BACK',
            AppColors.onSurfaceVariant,
            () => Navigator.of(context).pop(),
          ),
        ],
      ],
    );
  }

  Widget _buildButton(String label, Color color, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
      child: Text(label, style: AppTypography.labelCaps.copyWith(color: color)),
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
            showCount: true,
          ),
        ],
      ),
    );
  }
}
