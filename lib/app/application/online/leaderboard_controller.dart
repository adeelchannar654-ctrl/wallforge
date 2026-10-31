import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/repositories/leaderboard.dart';
import '../achievements/achievements_service.dart';

/// What the leaderboard screen should show.
enum LeaderboardStatus {
  /// A load is in flight.
  loading,

  /// Entries are on screen.
  ready,

  /// The load succeeded and the week is genuinely empty.
  empty,

  /// The load failed (transport, or — through a client that
  /// propagates — a ruleset that is not deployed yet).
  unavailable,
}

/// Drives the weekly leaderboard screen (Phase 16.5, Part H).
///
/// Read discipline (the Spark free quota is the budget):
/// one load costs at most 54 document reads — the top 50,
/// the player's own entry (1), and last week's top 3 — and
/// loads are cached in memory for five minutes, shared across
/// screen visits through a static cache. The manual refresh
/// honours the same interval; [refreshIn] tells the UI how
/// long is left, so the button can say so instead of silently
/// doing nothing.
///
/// The "Top 10 of the Week" achievement is fed from HERE —
/// from the fetched board, after a load — never from local
/// state, exactly as Part F's contract requires.
class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required this.repository,
    required this.names,
    required this.myUid,
    this.achievements,
    DateTime Function()? clock,
    this.cacheTtl = const Duration(minutes: 5),
  }) : _clock = clock ?? DateTime.now;

  /// The leaderboard store.
  final LeaderboardRepository repository;

  /// The display-name generation store.
  final LeaderboardNameRepository names;

  /// This player's uid.
  final String myUid;

  /// The achievements service, for the top-10 hook.
  final AchievementsService? achievements;

  /// The minimum interval between network loads.
  final Duration cacheTtl;

  final DateTime Function() _clock;

  /// Loads shared across controller instances (screen visits),
  /// keyed by week start. In-memory only: a cold app start
  /// always fetches.
  static final Map<int, _CachedBoard> _cache = {};

  /// Clears the shared cache (tests).
  @visibleForTesting
  static void clearCache() => _cache.clear();

  LeaderboardStatus _status = LeaderboardStatus.loading;
  List<LeaderboardEntry> _entries = const [];
  LeaderboardEntry? _myEntry;
  List<LeaderboardEntry> _lastWeekTop = const [];
  String _displayName = '';
  DateTime? _fetchedAt;
  bool _disposed = false;

  /// The current display state.
  LeaderboardStatus get status => _status;

  /// The fetched top entries (≤ 50), best first.
  List<LeaderboardEntry> get entries => _entries;

  /// This player's entry, or null when they have none.
  LeaderboardEntry? get myEntry => _myEntry;

  /// Last week's top three, for the podium section.
  List<LeaderboardEntry> get lastWeekTop => _lastWeekTop;

  /// This player's generated display name.
  String get displayName => _displayName;

  /// This player's rank within the fetched board (1-based),
  /// or null when they are not on it.
  int? get myRank {
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].uid == myUid) return i + 1;
    }
    return null;
  }

  /// Whether the player has an entry that did not make the
  /// fetched top 50 (shown as "50+").
  bool get mineOutsideTop => _myEntry != null && myRank == null;

  /// The current week's start (Monday 00:00 UTC, epoch ms).
  int get currentWeekStart => weekStartMs(_clock().millisecondsSinceEpoch);

  /// Time until the weekly reset (Monday 00:00 UTC).
  Duration get resetIn {
    final nowMs = _clock().millisecondsSinceEpoch;
    return Duration(milliseconds: currentWeekStart + kWeekMs - nowMs);
  }

  /// How long until a refresh will hit the network again
  /// (zero when a refresh now would fetch).
  Duration get refreshIn {
    final fetchedAt = _fetchedAt;
    if (fetchedAt == null) return Duration.zero;
    final remaining = cacheTtl - _clock().difference(fetchedAt);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Loads the board, from cache when it is still fresh.
  Future<void> load() async {
    _displayName = generateDisplayName(
      myUid,
      await names.loadGeneration(myUid),
    );
    final week = currentWeekStart;
    final cached = _cache[week];
    if (cached != null && _clock().difference(cached.fetchedAt) < cacheTtl) {
      _apply(cached);
      return;
    }
    await _fetch(week);
  }

  /// The manual refresh: identical to [load] — the cache
  /// interval applies, and [refreshIn] says how long is left
  /// when it does.
  Future<void> refresh() => load();

  Future<void> _fetch(int week) async {
    _status = LeaderboardStatus.loading;
    notifyListeners();
    try {
      final top = await repository.fetchTop(week);
      final mine = await repository.fetchEntry(week, myUid);
      final lastWeek = await repository.fetchTop(week - kWeekMs, limit: 3);
      final board = _CachedBoard(
        fetchedAt: _clock(),
        entries: top,
        myEntry: mine,
        lastWeekTop: lastWeek,
      );
      _cache[week] = board;
      _apply(board);
      // The top-10 achievement hook: fetched data only.
      final rank = myRank;
      final service = achievements;
      if (rank != null && service != null) {
        unawaited(service.onLeaderboardRank(rank));
      }
    } on Object {
      if (_disposed) return;
      _status = LeaderboardStatus.unavailable;
      notifyListeners();
    }
  }

  void _apply(_CachedBoard board) {
    if (_disposed) return;
    _entries = board.entries;
    _myEntry = board.myEntry;
    _lastWeekTop = board.lastWeekTop;
    _fetchedAt = board.fetchedAt;
    _status = board.entries.isEmpty && board.myEntry == null
        ? LeaderboardStatus.empty
        : LeaderboardStatus.ready;
    notifyListeners();
  }

  /// Regenerates this player's display name and pushes it to
  /// their current entry (a rename-only write the rules
  /// allow). Future counted matches carry the new name too.
  Future<void> regenerateName() async {
    final generation = await names.loadGeneration(myUid);
    await names.saveGeneration(myUid, generation + 1);
    _displayName = generateDisplayName(myUid, generation + 1);
    await repository.renameCurrentEntry(displayName: _displayName);
    final mine = _myEntry;
    if (mine != null && !_disposed) {
      _myEntry = LeaderboardEntry(
        uid: mine.uid,
        displayName: _displayName,
        points: mine.points,
        wins: mine.wins,
        losses: mine.losses,
        countedMatches: mine.countedMatches,
        opponentCounts: mine.opponentCounts,
      );
      // Keep the cached board honest about the rename.
      _entries = [for (final e in _entries) e.uid == myUid ? _myEntry! : e];
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _CachedBoard {
  const _CachedBoard({
    required this.fetchedAt,
    required this.entries,
    required this.myEntry,
    required this.lastWeekTop,
  });

  final DateTime fetchedAt;
  final List<LeaderboardEntry> entries;
  final LeaderboardEntry? myEntry;
  final List<LeaderboardEntry> lastWeekTop;
}
