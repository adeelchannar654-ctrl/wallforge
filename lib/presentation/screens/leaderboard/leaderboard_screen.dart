import 'package:flutter/material.dart';

import '../../../app/application/account/account_controller.dart';
import '../../../app/application/achievements/achievements_service.dart';
import '../../../app/application/online/leaderboard_controller.dart';
import '../../../app/build_info.dart';
import '../../../app/router/app_router.dart';
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
import '../../../domain/repositories/auth.dart';
import '../../../domain/repositories/leaderboard.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/responsive_content.dart';
import '../account/account_copy.dart';

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

  /// Phase 16.6: the gentle sign-in prompt's audience — a guest,
  /// an unverified email account, or nobody (accounts off, or an
  /// eligible account).
  _ViewerPrompt _prompt = _ViewerPrompt.none;
  bool _promptDismissed = false;
  AccountController? _account;

  @override
  void initState() {
    super.initState();
    // The account controller, when the app installed one, is the
    // identity authority for the prompt; it is also what makes
    // the prompt follow a sign-in that happens while this screen
    // is open.
    if (kFeatureAccounts) {
      _account = AccountService.shared;
      _account?.addListener(_syncPrompt);
      _prompt = _promptFor(_account?.state);
    }
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
      injected.load();
    } else {
      _buildLive();
    }
  }

  static _ViewerPrompt _promptFor(AuthState? state) {
    if (state == null) return _ViewerPrompt.none;
    if (state.isGuest) return _ViewerPrompt.guest;
    if (state.isAccount &&
        state.providerId == AuthProviders.password &&
        !state.emailVerified) {
      return _ViewerPrompt.unverified;
    }
    return _ViewerPrompt.none;
  }

  void _syncPrompt() {
    if (!mounted) return;
    setState(() => _prompt = _promptFor(_account?.state));
  }

  Future<void> _buildLive() async {
    final auth = FirebaseAuthGateway();
    final session = await auth.signInAnonymously();
    if (kFeatureAccounts && _account == null) {
      // No account controller installed: fall back to the session
      // this screen's own sign-in reused or created.
      _prompt = _promptFor(session);
    }
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
    _account?.removeListener(_syncPrompt);
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
              ? Column(
                  children: [
                    // The account prompt shows on every board
                    // state a guest can land on, this one included
                    // (Phase 16.6, Part H journey).
                    if (_showPrompt)
                      _guestPrompt(horizontal: AppSpacing.marginMobile),
                    const Expanded(
                      child: _MessageState(
                        icon: Icons.cloud_off_outlined,
                        message:
                            'The leaderboard needs an online sign-in, '
                            'which is unavailable right now.',
                      ),
                    ),
                  ],
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
      // The account prompt belongs here too (Phase 16.6): before
      // the rules are deployed this is the branch every player
      // lands on, and a guest deciding whether to sign in needs
      // the same explanation as on an empty board.
      LeaderboardStatus.unavailable => Column(
        children: [
          _header(controller),
          if (_showPrompt) _guestPrompt(horizontal: AppSpacing.marginMobile),
          Expanded(
            child: _MessageState(
              icon: Icons.cloud_off_outlined,
              message:
                  'The leaderboard could not be loaded. If this build '
                  'has only just gained the feature, its online rules '
                  'may not be switched on yet — otherwise check your '
                  'connection and try again.',
              actionLabel: 'RETRY',
              onAction: controller.refresh,
            ),
          ),
        ],
      ),
      LeaderboardStatus.empty => Column(
        children: [
          _header(controller),
          if (_showPrompt) _guestPrompt(horizontal: AppSpacing.marginMobile),
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
          if (_showPrompt) _guestPrompt(horizontal: 0),
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

  /// Whether the Phase 16.6 sign-in prompt shows: the feature is
  /// on, the viewer is a guest or an unverified email account,
  /// and it has not been dismissed this session.
  bool get _showPrompt => _prompt != _ViewerPrompt.none && !_promptDismissed;

  /// The gentle prompt card: an offer, never a blocking modal.
  /// [horizontal] compensates for the host layout: the ready
  /// list already pads horizontally, the empty column does not.
  Widget _guestPrompt({required double horizontal}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontal, AppSpacing.md, horizontal, 0),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _prompt == _ViewerPrompt.guest
                        ? AccountCopy.leaderboardGuestPrompt
                        : AccountCopy.leaderboardUnverifiedPrompt,
                    style: AppTypography.bodyBase,
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.account),
                    child: const Text('OPEN ACCOUNT'),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Dismiss',
              onPressed: () => setState(() => _promptDismissed = true),
            ),
          ],
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
      'preventing that entirely would need a game server.'
      '${kFeatureAccounts ? AccountCopy.leaderboardAccountRule : ''}',
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

/// Who the Phase 16.6 leaderboard prompt is for.
enum _ViewerPrompt { none, guest, unverified }

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
