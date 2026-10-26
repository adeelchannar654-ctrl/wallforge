import 'package:flutter/material.dart';

import '../../../app/application/local_game_controller.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_info.dart';
import '../../../data/local/shared_preferences_settings_repository.dart';
import '../../../data/local/shared_preferences_statistics_repository.dart';
import '../../../data/local/shared_preferences_unfinished_match_repository.dart';
import '../../../domain/models/board_config.dart';
import '../../../domain/models/game_state.dart';
import '../../../domain/repositories/repositories.dart';
import '../../board/board.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/wallforge_logo.dart';
import '../../widgets/wallforge_wordmark.dart';
import '../modes/game_modes_screen.dart';

/// The product home screen (`design.md` §17): logo, tagline, the main Play
/// action, mode options, profile/settings access, and a small board visual.
///
/// Everything data-shaped on this screen is real: the resume card appears
/// only when the unfinished-match repository actually holds a match, and
/// the statistics summary only when the statistics repository holds at
/// least one finished match. The Stitch home mock's ranked ladder, ELO,
/// streaks, event banner and daily puzzle are fabricated product data and
/// are not shown (recorded in `memory.md` §13s).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.settingsRepository = const SharedPreferencesSettingsRepository(),
    this.statisticsRepository = const SharedPreferencesStatisticsRepository(),
    this.unfinishedMatchRepository =
        const SharedPreferencesUnfinishedMatchRepository(),
  });

  final SettingsRepository settingsRepository;
  final StatisticsRepository statisticsRepository;
  final UnfinishedMatchRepository unfinishedMatchRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppSettings _settings = AppSettings.defaults;
  MatchStatistics _statistics = MatchStatistics.empty;
  UnfinishedMatch? _unfinished;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.settingsRepository.load();
    final statistics = await widget.statisticsRepository.load();
    final unfinished = await widget.unfinishedMatchRepository.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _statistics = statistics;
      _unfinished = unfinished;
      _loaded = true;
    });
  }

  Future<void> _resume() async {
    final saved = _unfinished;
    if (saved == null) return;
    final controller = LocalGameController(
      config: BoardConfig(size: saved.boardSize),
    );
    controller.attachPersistence(
      settings: widget.settingsRepository,
      statistics: widget.statisticsRepository,
      unfinishedMatch: widget.unfinishedMatchRepository,
    );
    await controller.refreshResumableMatch();
    final match = controller.resumableMatch;
    if (match == null || !controller.resumeMatch(match)) {
      controller.dispose();
      if (mounted) setState(() => _unfinished = null);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context)
        .pushNamed(AppRoutes.game, arguments: controller);
    // Returning from the match: the saved slot may have changed.
    if (mounted) _load();
  }

  void _openModes(GameMode mode) {
    Navigator.of(context).pushNamed(AppRoutes.modes, arguments: mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              const Center(child: WallforgeLogo(size: 84)),
              const Center(child: WallforgeWordmark(fontSize: 34)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppInfo.tagline,
                textAlign: TextAlign.center,
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // The small board visual (§17): a real initial position,
              // rendered by the real BoardView, not an image.
              Center(
                child: SizedBox(
                  width: 176,
                  height: 176,
                  child: BoardView(
                    state: GameState.initial(),
                    showCoordinates: false,
                    maxSize: 176,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryActionButton(
                label: 'PLAY',
                icon: Icons.play_arrow,
                onPressed: () => _openModes(GameMode.local),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_unfinished != null) ...[
                _buildResumeCard(_unfinished!),
                const SizedBox(height: AppSpacing.md),
              ],
              _buildModeRow(
                icon: Icons.people_outline,
                title: 'Local Match',
                subtitle: 'Two players on one device.',
                onTap: () => _openModes(GameMode.local),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildModeRow(
                icon: Icons.smart_toy_outlined,
                title: 'Vs AI',
                subtitle: 'Single player against AI.',
                onTap: () => _openModes(GameMode.versusAi),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildModeRow(
                icon: Icons.public,
                title: 'Online Match',
                subtitle: 'Remote two-player match.',
                onTap: () => _openModes(GameMode.online),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildTutorialCard(),
              if (_loaded && _statistics.matchesPlayed > 0) ...[
                const SizedBox(height: AppSpacing.md),
                _buildStatisticsCard(),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumeCard(UnfinishedMatch match) {
    final mode = match.versusAi
        ? 'vs AI (${match.aiDifficulty})'
        : 'local match';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('UNFINISHED MATCH'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${match.boardSize}×${match.boardSize} $mode — turn '
            '${match.savedAtTurn + 1}',
            style: AppTypography.bodyBase,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryActionButton(
            label: 'RESUME MATCH',
            icon: Icons.play_arrow,
            onPressed: _resume,
          ),
        ],
      ),
    );
  }

  Widget _buildModeRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryContainer, size: 28),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.titleMd),
                    Text(
                      subtitle,
                      style: AppTypography.bodyBase.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialCard() {
    final completed = _settings.tutorialCompleted;
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.school_outlined,
            color: AppColors.primaryContainer,
            size: 28,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completed ? 'Tutorial' : 'Learn to play',
                  style: AppTypography.titleMd,
                ),
                Text(
                  completed
                      ? 'Replay the guided tour any time.'
                      : 'A short guided tour on a real board.',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.tutorial),
            child: Text(completed ? 'REPLAY' : 'START'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final s = _statistics;
    return AppCard(
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('YOUR MATCHES'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${s.matchesPlayed} played · ${s.humanWins} won · '
              '${s.humanLosses} lost',
              style: AppTypography.bodyBase,
            ),
          ],
        ),
      ),
    );
  }
}
