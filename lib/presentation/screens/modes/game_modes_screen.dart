import 'package:flutter/material.dart';

import '../../../app/application/match_setup.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/models/board_config.dart';
import '../../widgets/app_chrome.dart';

/// The three ways to play, as route arguments and mode-card identity.
enum GameMode { local, versusAi, online }

/// The Game Modes screen (`design.md` §18 + the Stitch `game_setup_modes`
/// mock's legitimate parts).
///
/// Three mode cards, each with icon, title, the §18 one-line description and
/// an action. The board-size and wall-count pickers come from the Stitch
/// mock and are wired to real `BoardConfig` values, carried forward to the
/// next screen in memory (never persisted — they are match choices, not
/// settings). The mock's turn-clock selector and "Fair Path Integrity"
/// toggle are not features of this app and are not shown: there is no clock
/// anywhere in the project, and a mandatory rule never appears as a switch.
class GameModesScreen extends StatefulWidget {
  const GameModesScreen({super.key, this.initialMode = GameMode.local});

  final GameMode initialMode;

  @override
  State<GameModesScreen> createState() => _GameModesScreenState();
}

class _GameModesScreenState extends State<GameModesScreen> {
  late GameMode _mode = widget.initialMode;
  int _size = 9;
  int _walls = 10;

  BoardConfig get _config => BoardConfig(size: _size, wallsPerPlayer: _walls);

  void _proceed() {
    switch (_mode) {
      case GameMode.local:
        Navigator.of(context)
            .pushNamed(AppRoutes.game, arguments: MatchSetup.local(_config));
      case GameMode.versusAi:
        Navigator.of(context).pushNamed(AppRoutes.ai, arguments: _config);
      case GameMode.online:
        Navigator.of(context).pushNamed(AppRoutes.online, arguments: _config);
    }
  }

  String get _actionLabel => switch (_mode) {
    GameMode.local => 'START LOCAL MATCH',
    GameMode.versusAi => 'CHOOSE DIFFICULTY',
    GameMode.online => 'OPEN ONLINE LOBBY',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Game Modes'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildModeCard(
                mode: GameMode.local,
                icon: Icons.people_outline,
                title: 'Local',
                description: 'Two players on one device.',
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildModeCard(
                mode: GameMode.versusAi,
                icon: Icons.smart_toy_outlined,
                title: 'Vs AI',
                description: 'Single player against AI.',
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildModeCard(
                mode: GameMode.online,
                icon: Icons.public,
                title: 'Online',
                description: 'Remote two-player match.',
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('PARAMETERS'),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Board size', style: AppTypography.bodyBase),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final size in const [5, 7, 9, 11])
                          ChoiceChip(
                            label: Text('$size×$size'),
                            selected: _size == size,
                            onSelected: (_) => setState(() => _size = size),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Walls per player',
                      style: AppTypography.bodyBase,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final walls in const [8, 10, 12])
                          ChoiceChip(
                            label: Text('$walls walls'),
                            selected: _walls == walls,
                            onSelected: (_) => setState(() => _walls = walls),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryActionButton(
                label: _actionLabel,
                icon: Icons.arrow_forward,
                onPressed: _proceed,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required GameMode mode,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final selected = _mode == mode;
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: () => setState(() => _mode = mode),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: selected
                  ? AppColors.primaryContainer
                  : AppColors.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: selected
                    ? AppColors.primaryContainer
                    : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleMd),
                    Text(
                      description,
                      style: AppTypography.bodyBase.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: AppColors.primaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
