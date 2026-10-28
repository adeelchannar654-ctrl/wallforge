import 'package:flutter/material.dart';

import '../../../app/application/ai/ai_difficulty.dart';
import '../../../app/application/match_setup.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_settings_repository.dart';
import '../../../domain/models/board_config.dart';
import '../../../domain/repositories/repositories.dart';
import '../../widgets/app_chrome.dart';

/// The dedicated AI difficulty screen (`design.md` §20) — resolves Q-5.2.
///
/// The four difficulties are presented as selectable cards carrying
/// `AiDifficulty`'s own one-line descriptions verbatim: depth and breadth
/// only, with no claim of optimality or perfection (§20 forbids misleading
/// claims such as "perfect AI"). The AI always plays Red and the human
/// Blue — stated on the screen because it is true of the app (`kAiPlayer`)
/// and the player should know which pawn is theirs before the game starts.
///
/// Starting a match goes through the existing `MatchSetup` route argument —
/// the same pathway the retired dev-preview chip row used — and the chosen
/// difficulty is persisted as the `aiDifficulty` setting, which is also
/// what preselects the card on the next visit.
class AiDifficultyScreen extends StatefulWidget {
  const AiDifficultyScreen({
    super.key,
    required this.config,
    this.settingsRepository = const SharedPreferencesSettingsRepository(),
  });

  /// The board chosen on the Game Modes screen.
  final BoardConfig config;

  final SettingsRepository settingsRepository;

  @override
  State<AiDifficultyScreen> createState() => _AiDifficultyScreenState();
}

class _AiDifficultyScreenState extends State<AiDifficultyScreen> {
  AiDifficulty _selected = AiDifficulty.easy;

  @override
  void initState() {
    super.initState();
    _preselect();
  }

  Future<void> _preselect() async {
    final settings = await widget.settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _selected = AiDifficulty.values.firstWhere(
        (d) => d.name == settings.aiDifficulty,
        orElse: () => AiDifficulty.easy,
      );
    });
  }

  Future<void> _start() async {
    final settings = await widget.settingsRepository.load();
    await widget.settingsRepository.save(
      settings.copyWith(aiDifficulty: _selected.name),
    );
    if (!mounted) return;
    Navigator.of(context).pushNamed(
      AppRoutes.game,
      arguments: MatchSetup.versusAi(widget.config, _selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Vs AI'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You play Blue. The AI plays Red.',
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Board ${widget.config.size}×${widget.config.size} · '
                '${widget.config.wallsPerPlayer} walls each',
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SectionTitle('DIFFICULTY'),
              const SizedBox(height: AppSpacing.md),
              for (final difficulty in AiDifficulty.values) ...[
                _buildDifficultyCard(difficulty),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryActionButton(
                label: 'START MATCH',
                icon: Icons.play_arrow,
                onPressed: _start,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard(AiDifficulty difficulty) {
    final selected = _selected == difficulty;
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: () => setState(() => _selected = difficulty),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(difficulty.label, style: AppTypography.titleMd),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      difficulty.description,
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
