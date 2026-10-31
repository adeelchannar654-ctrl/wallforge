import 'package:flutter/material.dart';

import '../../../app/application/achievements/achievements_service.dart';
import '../../../app/application/online/leaderboard_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_achievements_repository.dart';
import '../../../data/local/shared_preferences_history_repository.dart';
import '../../../data/local/shared_preferences_leaderboard_name_repository.dart';
import '../../../data/local/shared_preferences_statistics_repository.dart';
import '../../../data/remote/cloud_firestore_client.dart';
import '../../../data/remote/firebase_auth_gateway.dart';
import '../../../data/remote/firestore_leaderboard_repository.dart';
import '../../../domain/repositories/leaderboard.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/responsive_content.dart';

/// The weekly leaderboard screen (Phase 16.5, Part H).
///
/// Flag-gated at its entry points (Home shows the card only
/// when the feature is compiled in); the screen itself also
/// fails gracefully — loading, empty and unavailable states
/// are all designed, because a leaderboard whose rules are
/// not deployed yet must say so, never crash.
///
/// The screen states its own rules and limits in plain text:
/// what counts, and the residual collusion surface that only
/// a server could fully close.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, this.controller});

  /// Injected in tests; built from the live services otherwise.
  final LeaderboardController? controller;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  LeaderboardController? _controller;
  bool _ownController = false;
  bool _failedToStart = false;

  @override
  void initState() {
    super.initState();
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      injected.load();
    } else {
      _buildLive();
    }
  }

  Future<void> _buildLive() async {
    final auth = FirebaseAuthGateway();
    await auth.signInAnonymously();
    final uid = await auth.currentUid();
    if (!mounted) return;
    if (uid == null) {
      setState(() => _failedToStart = true);
      return;
    }
    final client = CloudFirestoreClient();
    final controller = LeaderboardController(
      repository: FirestoreLeaderboardRepository(
        client: client,
        userId: auth.currentUid,
      ),
      names: const SharedPreferencesLeaderboardNameRepository(),
      myUid: uid,
      achievements: AchievementsService(
        history: const SharedPreferencesHistoryRepository(),
        statistics: const SharedPreferencesStatisticsRepository(),
        store: const SharedPreferencesAchievementsRepository(),
      ),
    );
    setState(() {
      _controller = controller;
      _ownController = true;
    });
    await controller.load();
  }

  @override
  void dispose() {
    if (_ownController) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Leaderboard'),
        actions: [
          if (_controller != null)
            ListenableBuilder(
              listenable: _controller!,
              builder: (context, _) => IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: _controller!.refreshIn > Duration.zero
                    ? 'Refresh available in ${_waitText(_controller!.refreshIn)}'
                    : 'Refresh',
                onPressed: _controller!.refreshIn > Duration.zero
                    ? null
                    : _controller!.refresh,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: _failedToStart
              ? const _MessageState(
                  icon: Icons.cloud_off_outlined,
                  message:
                      'The leaderboard needs an online sign-in, '
                      'which is unavailable right now.',
                )
              : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: _controller!,
                  builder: (context, _) => _body(_controller!),
                ),
        ),
      ),
    );
  }

  Widget _body(LeaderboardController controller) {
    return switch (controller.status) {
      LeaderboardStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      LeaderboardStatus.unavailable => _MessageState(
        icon: Icons.cloud_off_outlined,
        message:
            'The leaderboard could not be loaded. If this build '
            'has only just gained the feature, its online rules '
            'may not be switched on yet — otherwise check your '
            'connection and try again.',
        actionLabel: 'RETRY',
        onAction: controller.refresh,
      ),
      LeaderboardStatus.empty => Column(
        children: [
          _header(controller),
          const Expanded(
            child: _MessageState(
              icon: Icons.leaderboard_outlined,
              message:
                  'No counted matches yet this week. Finish an '
                  'online match of 10 or more plies to appear here.',
            ),
          ),
          _footer(),
        ],
      ),
      LeaderboardStatus.ready => ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        children: [
          _header(controller),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < controller.entries.length; i++)
            _row(controller, i, controller.entries[i]),
          if (controller.mineOutsideTop) ...[
            const SizedBox(height: AppSpacing.sm),
            _myPinnedRow(controller),
          ],
          if (controller.lastWeekTop.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionTitle('LAST WEEK'),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < controller.lastWeekTop.length; i++)
              _row(controller, i, controller.lastWeekTop[i], compact: true),
          ],
          const SizedBox(height: AppSpacing.lg),
          _footer(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    };
  }

  Widget _header(LeaderboardController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resets in ${_resetText(controller.resetIn)} · Mon 00:00 UTC',
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'You play as ${controller.displayName}',
                  style: AppTypography.bodyBase,
                ),
              ),
              TextButton(
                onPressed: controller.regenerateName,
                child: const Text('REGENERATE'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    LeaderboardController controller,
    int index,
    LeaderboardEntry entry, {
    bool compact = false,
  }) {
    final mine = entry.uid == controller.myUid;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          // "Mine" is carried by a heavier outline AND the YOU
          // tag — never by colour alone.
          color: mine ? AppColors.tertiary : AppColors.outlineVariant,
          width: mine ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Text(
          '${index + 1}',
          style: AppTypography.numericStat.copyWith(fontSize: 18),
        ),
        title: Text(
          mine ? '${entry.displayName} · YOU' : entry.displayName,
          style: AppTypography.bodyBase,
        ),
        trailing: Text('${entry.points} pts', style: AppTypography.numericStat),
        subtitle: compact
            ? null
            : Text(
                '${entry.wins} won · ${entry.losses} lost',
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }

  Widget _myPinnedRow(LeaderboardController controller) {
    final mine = controller.myEntry!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.tertiary, width: 2),
      ),
      child: ListTile(
        leading: Text(
          '50+',
          style: AppTypography.numericStat.copyWith(fontSize: 18),
        ),
        title: Text('${mine.displayName} · YOU'),
        trailing: Text('${mine.points} pts', style: AppTypography.numericStat),
        subtitle: Text(
          '${mine.wins} won · ${mine.losses} lost',
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Text(
      'Wins score 3, losses 1. Only online matches of 10+ plies '
      'count — at most 20 a week, and at most 3 against the same '
      'opponent. Scores are submitted by players\' own apps and '
      'checked against the match records, but two accounts '
      'colluding can still inflate them within those caps; '
      'preventing that entirely would need a game server.',
      style: AppTypography.bodyBase.copyWith(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }

  static String _resetText(Duration d) {
    if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
    if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
    return '${d.inMinutes} min';
  }

  static String _waitText(Duration d) =>
      d.inMinutes >= 1 ? '${d.inMinutes + 1} min' : '${d.inSeconds} s';
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
