import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_history_repository.dart';
import '../../../domain/models/match_record.dart';
import '../../../domain/repositories/repositories.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/responsive_content.dart';

/// Match history (Phase 16.5, Part E): every finished match
/// recorded on this device — local, vs-AI and online.
///
/// The screen states its own limits where the player can see
/// them: history lives on this device only, is never synced,
/// and is lost on uninstall. Filters are by mode and by
/// result; pass-and-play records belong to no single player,
/// so they appear under "All" results with the winning side
/// named instead of a won/lost verdict.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.historyRepository = const SharedPreferencesHistoryRepository(),
  });

  final MatchHistoryRepository historyRepository;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with RouteAware {
  List<MatchRecord> _records = const [];
  bool _loaded = false;
  MatchMode? _modeFilter;
  _ResultFilter _resultFilter = _ResultFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      AppRouter.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppRouter.routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Returning from a record's detail (where it may have been
  /// deleted) reloads the list — the Phase 16 Home lesson.
  @override
  void didPopNext() => _load();

  Future<void> _load() async {
    final records = await widget.historyRepository.load();
    if (!mounted) return;
    setState(() {
      _records = records;
      _loaded = true;
    });
  }

  List<MatchRecord> get _visible => _records.where((r) {
    if (_modeFilter != null && r.mode != _modeFilter) return false;
    return switch (_resultFilter) {
      _ResultFilter.all => true,
      _ResultFilter.won => r.isWin,
      _ResultFilter.lost => r.isLoss,
    };
  }).toList();

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear match history?'),
        content: const Text(
          'Every recorded match on this device will be removed. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CLEAR ALL'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.historyRepository.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Match history'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all history',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                child: Text(
                  'Stored on this device only — never synced, and '
                  'lost if the app is uninstalled.',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _filterRow(),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All modes'),
            selected: _modeFilter == null,
            onSelected: (_) => setState(() => _modeFilter = null),
          ),
          for (final mode in MatchMode.values) ...[
            const SizedBox(width: AppSpacing.sm),
            ChoiceChip(
              label: Text(mode.label),
              selected: _modeFilter == mode,
              onSelected: (_) => setState(() => _modeFilter = mode),
            ),
          ],
          const SizedBox(width: AppSpacing.lg),
          ChoiceChip(
            label: const Text('All results'),
            selected: _resultFilter == _ResultFilter.all,
            onSelected: (_) =>
                setState(() => _resultFilter = _ResultFilter.all),
          ),
          const SizedBox(width: AppSpacing.sm),
          ChoiceChip(
            label: const Text('Won'),
            selected: _resultFilter == _ResultFilter.won,
            onSelected: (_) =>
                setState(() => _resultFilter = _ResultFilter.won),
          ),
          const SizedBox(width: AppSpacing.sm),
          ChoiceChip(
            label: const Text('Lost'),
            selected: _resultFilter == _ResultFilter.lost,
            onSelected: (_) =>
                setState(() => _resultFilter = _ResultFilter.lost),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_loaded) return const SizedBox.shrink();
    if (_records.isEmpty) {
      return const _EmptyState(
        message:
            'No matches recorded yet. Finish a match — local, '
            'vs AI or online — and it will appear here.',
      );
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return const _EmptyState(message: 'No matches match these filters.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.marginMobile,
        vertical: AppSpacing.sm,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _HistoryRow(
          record: visible[index],
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.historyDetail, arguments: visible[index]),
        ),
      ),
    );
  }
}

enum _ResultFilter { all, won, lost }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.onTap});

  final MatchRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = record;
    return AppCard(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  r.isAbandoned
                      ? Icons.flag_outlined
                      : r.mySide == null
                      ? Icons.people_outline
                      : r.isWin
                      ? Icons.emoji_events_outlined
                      : Icons.sentiment_dissatisfied_outlined,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(historyHeadline(r), style: AppTypography.titleMd),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              historyMetaLine(r),
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The row/detail headline for a record, in words — never
/// colour alone: "Won vs AI", "Lost online", "Blue won ·
/// Local", "Abandoned · Online".
String historyHeadline(MatchRecord r) {
  if (r.isAbandoned) return 'Abandoned · ${r.mode.label}';
  if (r.mySide == null) {
    final winner = r.winnerSide!.name;
    return '${winner[0].toUpperCase()}${winner.substring(1)} won · '
        '${r.mode.label}';
  }
  return r.isWin ? 'Won · ${r.mode.label}' : 'Lost · ${r.mode.label}';
}

/// The secondary line: board, plies, clock and finish reason
/// (when it was not a plain goal), plus opponent and date.
String historyMetaLine(MatchRecord r) {
  final parts = <String>[
    '${r.boardSize}×${r.boardSize}',
    '${r.plies} plies',
    r.opponentLabel,
    if (r.timeControlSeconds > 0) '${r.timeControlSeconds}s clock',
    if (r.finishReason.name != 'goal') r.finishReason.label,
    formatHistoryDate(r.endedAtMs),
  ];
  return parts.join(' · ');
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Oct 31, 2026 · 9:41 PM" in the device's local time.
String formatHistoryDate(int endedAtMs) {
  final t = DateTime.fromMillisecondsSinceEpoch(endedAtMs);
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final amPm = t.hour < 12 ? 'AM' : 'PM';
  final minute = t.minute.toString().padLeft(2, '0');
  return '${_months[t.month - 1]} ${t.day}, ${t.year} · $hour12:$minute $amPm';
}

/// "45 s", "12 min", "1 h 05 min".
String formatHistoryDuration(int durationMs) {
  final seconds = durationMs ~/ 1000;
  if (seconds < 60) return '$seconds s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = (minutes % 60).toString().padLeft(2, '0');
  return '$hours h $rest min';
}
