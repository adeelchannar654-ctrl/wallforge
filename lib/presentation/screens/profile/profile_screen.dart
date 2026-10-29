import 'package:flutter/material.dart';

import '../../../app/application/ai/ai_difficulty.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_statistics_repository.dart';
import '../../../data/remote/firebase_auth_gateway.dart';
import '../../../domain/repositories/repositories.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/responsive_content.dart';

/// The Profile screen: the player's real statistics, and nothing else.
///
/// `design.md` names Profile only as a §15 card use ("Profile statistics")
/// — there is no Profile section and no field list anywhere, so this screen
/// shows exactly what the Phase 6 statistics repository actually stores:
/// matches played, wins, losses, the by-difficulty buckets (pass-and-play
/// is recorded under `local`) and the by-board-size buckets. Online matches
/// are not recorded in that repository, and the screen says so rather than
/// letting the numbers imply coverage they do not have.
///
/// No accounts, ranking or avatars (PRD §10 non-goals): the account line is
/// the anonymous sign-in state, exactly as it is.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.statisticsRepository = const SharedPreferencesStatisticsRepository(),
    this.authGateway,
  });

  final StatisticsRepository statisticsRepository;

  /// Defaults to the Firebase gateway; injectable for tests.
  final AuthGateway? authGateway;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  MatchStatistics _statistics = MatchStatistics.empty;
  AuthState _authState = const AuthState.signedOut();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final statistics = await widget.statisticsRepository.load();
    final auth = await (widget.authGateway ?? FirebaseAuthGateway()).current();
    if (!mounted) return;
    setState(() {
      _statistics = statistics;
      _authState = auth;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _statistics;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        // Phase 14: capped and centered on tablet/desktop.
        child: ResponsiveContent(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('ACCOUNT'),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _authState.isSignedIn
                            ? 'Signed in anonymously (Guest)'
                            : 'Not signed in',
                        style: AppTypography.bodyBase,
                      ),
                      if (_authState.isSignedIn && _authState.uid != null)
                        Text(
                          'Player ID ${_authState.uid}',
                          style: AppTypography.bodyBase.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('PROFILE STATISTICS'),
                      const SizedBox(height: AppSpacing.md),
                      if (_loaded && s.matchesPlayed == 0)
                        Text(
                          'No matches played yet. Finish a local or AI match '
                          'and your results will appear here.',
                          style: AppTypography.bodyBase.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        )
                      else ...[
                        _row('Matches played', '${s.matchesPlayed}'),
                        _row('Won', '${s.humanWins}'),
                        _row('Lost', '${s.humanLosses}'),
                        if (s.winRate != null)
                          _row(
                            'Win rate',
                            '${(s.winRate! * 100).toStringAsFixed(0)}%',
                          ),
                      ],
                    ],
                  ),
                ),
                if (s.byDifficulty.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('BY MODE AND DIFFICULTY'),
                        const SizedBox(height: AppSpacing.md),
                        for (final entry in _sorted(s.byDifficulty))
                          _row(
                            entry.key == 'local'
                                ? 'Local pass-and-play'
                                : 'Vs AI — ${_difficultyLabel(entry.key)}',
                            '${entry.value.played} played · '
                            '${entry.value.wins} won',
                          ),
                      ],
                    ),
                  ),
                ],
                if (s.byBoardSize.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('BY BOARD SIZE'),
                        const SizedBox(height: AppSpacing.md),
                        for (final entry in _sorted(s.byBoardSize))
                          _row(
                            '${entry.key}×${entry.key} board',
                            '${entry.value.played} played · '
                                '${entry.value.wins} won',
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Statistics cover local and AI matches on this device. '
                  'Online matches are not recorded here.',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The recorded bucket key is an [AiDifficulty] name; show its label
  /// ('Hard', not 'hard'). An unknown key — from a newer build's data —
  /// falls back to itself rather than disappearing.
  String _difficultyLabel(String key) {
    for (final difficulty in AiDifficulty.values) {
      if (difficulty.name == key) return difficulty.label;
    }
    return key;
  }

  List<MapEntry<String, Bucket>> _sorted(Map<String, Bucket> buckets) {
    final entries = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.bodyBase)),
          Text(
            value,
            style: AppTypography.numericStat.copyWith(
              color: AppColors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
