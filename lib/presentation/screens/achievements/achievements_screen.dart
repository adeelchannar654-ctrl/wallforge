import 'package:flutter/material.dart';

import '../../../app/application/achievements/achievement_evaluator.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_achievements_repository.dart';
import '../../../data/local/shared_preferences_history_repository.dart';
import '../../../data/local/shared_preferences_statistics_repository.dart';
import '../../../domain/models/achievement.dart';
import '../../../domain/models/match_record.dart';
import '../../../domain/repositories/repositories.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/responsive_content.dart';
import '../history/history_screen.dart' show formatHistoryDate;

/// Achievements (Phase 16.5, Part F): the catalogue with what
/// is unlocked, when, and — for the locked ones — how far
/// along the player is, in words and numbers rather than
/// colour or a bare progress bar.
///
/// The screen also carries the anti-abuse note in plain sight:
/// achievements live on this device, are earned locally, and
/// count for nothing beyond themselves.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({
    super.key,
    this.historyRepository = const SharedPreferencesHistoryRepository(),
    this.statisticsRepository = const SharedPreferencesStatisticsRepository(),
    this.achievementsRepository =
        const SharedPreferencesAchievementsRepository(),
  });

  final MatchHistoryRepository historyRepository;
  final StatisticsRepository statisticsRepository;
  final AchievementsRepository achievementsRepository;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  Map<String, int> _unlocks = const {};
  List<MatchRecord> _records = const [];
  MatchStatistics _stats = MatchStatistics.empty;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final unlocks = await widget.achievementsRepository.loadUnlocks();
    final records = await widget.historyRepository.load();
    final stats = await widget.statisticsRepository.load();
    if (!mounted) return;
    setState(() {
      _unlocks = unlocks;
      _records = records;
      _stats = stats;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Achievements'),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: !_loaded
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.marginMobile,
                  ),
                  children: [
                    Text(
                      'Achievements are earned and kept on this '
                      'device only. They are for your own '
                      'satisfaction — they unlock nothing and are '
                      'never shared or ranked.',
                      style: AppTypography.bodyBase.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final definition in kAchievements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _AchievementRow(
                          definition: definition,
                          unlockedAtMs: _unlocks[definition.id],
                          progress: _progressFor(definition),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
        ),
      ),
    );
  }

  String? _progressFor(AchievementDefinition definition) {
    if (_unlocks.containsKey(definition.id)) return null;
    final progress = AchievementEvaluator.progress(
      definition.id,
      _records,
      _stats,
    );
    if (progress == null) return null;
    return 'Progress: ${progress.$1} of ${progress.$2}';
  }
}

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.definition,
    required this.unlockedAtMs,
    required this.progress,
  });

  final AchievementDefinition definition;
  final int? unlockedAtMs;
  final String? progress;

  @override
  Widget build(BuildContext context) {
    final unlocked = unlockedAtMs != null;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unlocked ? Icons.emoji_events : Icons.lock_outline,
            size: 22,
            color: unlocked ? AppColors.tertiary : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(definition.name, style: AppTypography.titleMd),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  definition.description,
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  unlocked
                      ? 'Unlocked · ${formatHistoryDate(unlockedAtMs!)}'
                      : progress ?? 'Locked',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
