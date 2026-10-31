import 'dart:async';

import '../../../domain/repositories/leaderboard.dart';
import '../../../domain/repositories/repositories.dart';

/// Keeps the small cloud profile in step with the device
/// (Phase 16.6, Part E), under a strict operation budget:
///
/// * **Sign-in**: one read; at most one write (only when the
///   merge actually changes the stored profile).
/// * **Each finished match**: at most one write, debounced, and
///   only when the snapshot changed. Never per move.
/// * **Guests**: nothing. No read, no write, ever.
///
/// ## The merge (D16.6-8) — deterministic, idempotent, and
/// unable to double-count
///
/// Achievements merge as a union, earliest unlock time winning.
/// The name generation takes the maximum. Statistics are the
/// interesting case, and the finish gate is what makes them
/// safe: every snapshot carries the ids of the matches it
/// counts, and each device's gate knows every id it counted.
///
/// * Cloud ids ⊆ local gate → the local snapshot already covers
///   everything the cloud counted: local wins, nothing adopted.
/// * Local gate ⊆ cloud ids → the cloud snapshot covers
///   everything this device counted and more: adopt it whole.
/// * Diverged (each side counted matches the other has not) →
///   the snapshot with more matches played wins; ties break on
///   the later write, then on local. The merged id set is the
///   **union**: ids only the loser counted are marked counted
///   without being in the totals — a deliberate undercount,
///   chosen over the alternative, because a match counted twice
///   would corrupt the totals permanently while an undercounted
///   match is merely conservative.
///
/// The design is self-healing because of one invariant: a local
/// store is only ever replaced by a snapshot that provably
/// covers it (the subset cases above). Anything a post-match
/// write overwrites in the cloud still lives in the other
/// device's local store and is unioned back at its next sign-in
/// merge. A corrupt or newer-schema profile is ignored
/// wholesale; a newer-schema *local* store stops the merge
/// entirely — local data is never touched on a guess.
///
/// Post-match writes do not re-read (that is the budget), so two
/// devices playing at once can overwrite each other's snapshot;
/// the next sign-in merge on either device reconciles from the
/// local stores, as described. Recorded as the accepted race in
/// §13ab.
class ProfileSyncService {
  ProfileSyncService({
    required this.cloud,
    required this.history,
    required this.statistics,
    required this.achievements,
    required this.names,
    required this.currentAuth,
    DateTime Function()? clock,
    this.debounce = const Duration(seconds: 3),
  }) : _clock = clock ?? DateTime.now;

  /// The cloud profile store.
  final CloudProfileRepository cloud;

  /// The device finish gate + history.
  final MatchHistoryRepository history;

  /// The device statistics.
  final StatisticsRepository statistics;

  /// The device achievement unlocks.
  final AchievementsRepository achievements;

  /// The device display-name generations.
  final LeaderboardNameRepository names;

  /// Reads the current identity (the account gateway's
  /// `current`), so a post-match sync writes under whoever is
  /// signed in *then*, and does nothing for a guest.
  final Future<AuthState> Function() currentAuth;

  /// How long after the last finished match the post-match sync
  /// waits, so a match's own achievement evaluation lands first
  /// and a burst of finishes costs one write. Injectable.
  final Duration debounce;

  final DateTime Function() _clock;
  CloudProfile? _lastSynced;
  Timer? _timer;

  /// Whether a sign-in sync has run for an account in this
  /// service's lifetime. Post-match syncs are scheduled only
  /// when armed: a guest's finished match must not schedule
  /// cloud work at all — not even a timer that later no-ops
  /// (the budget is "guests: nothing", and an unowned pending
  /// timer is a lifecycle bug in its own right, as the app's
  /// journey tests demonstrated).
  bool _armed = false;

  // --- The wiring seam -------------------------------------------------------

  static ProfileSyncService? _shared;

  /// The app's sync service, used by the history decorator the
  /// persistence factory installs. Null when accounts are off.
  static ProfileSyncService? get shared => _shared;

  /// Installs (or clears) the shared service. Called by the
  /// account factory when the app builds its controller.
  static void install(ProfileSyncService? service) => _shared = service;

  // --- Snapshot ----------------------------------------------------------------

  /// Builds the local snapshot for [uid] from the device stores.
  Future<CloudProfile> buildLocalProfile(String uid) async {
    final generation = await names.loadGeneration(uid);
    final gate = await history.recordedIds();
    return CloudProfile(
      displayName: generateDisplayName(uid, generation),
      nameGeneration: generation,
      achievements: await achievements.loadUnlocks(),
      statistics: await statistics.load(),
      statisticsRecordIds: gate?.toList() ?? const [],
      updatedAtMs: _clock().millisecondsSinceEpoch,
    );
  }

  // --- The merge (pure) -----------------------------------------------------------

  /// Merges [local] with the stored [remote] profile. Pure and
  /// deterministic: the same inputs always produce the same
  /// output, and merging a merged profile changes nothing
  /// (idempotence is tested, not assumed).
  static CloudProfile merge({
    required CloudProfile local,
    required CloudProfile remote,
    required int nowMs,
  }) {
    // Achievements: union, earliest unlock wins.
    final achievements = <String, int>{...local.achievements};
    for (final entry in remote.achievements.entries) {
      final existing = achievements[entry.key];
      if (existing == null || entry.value < existing) {
        achievements[entry.key] = entry.value;
      }
    }
    // Name: the higher generation wins; its name goes with it.
    final nameWinner = local.nameGeneration >= remote.nameGeneration
        ? local
        : remote;
    // Statistics: the subset rules first, then the size rule.
    final localIds = local.statisticsRecordIds.toSet();
    final remoteIds = remote.statisticsRecordIds.toSet();
    final MatchStatistics statistics;
    final List<String> winnerIds;
    final List<String> loserIds;
    if (remoteIds.difference(localIds).isEmpty) {
      statistics = local.statistics;
      winnerIds = local.statisticsRecordIds;
      loserIds = remote.statisticsRecordIds;
    } else if (localIds.difference(remoteIds).isEmpty) {
      statistics = remote.statistics;
      winnerIds = remote.statisticsRecordIds;
      loserIds = local.statisticsRecordIds;
    } else {
      final localWins =
          local.statistics.matchesPlayed > remote.statistics.matchesPlayed ||
          (local.statistics.matchesPlayed == remote.statistics.matchesPlayed &&
              local.updatedAtMs >= remote.updatedAtMs);
      statistics = localWins ? local.statistics : remote.statistics;
      winnerIds = localWins
          ? local.statisticsRecordIds
          : remote.statisticsRecordIds;
      loserIds = localWins
          ? remote.statisticsRecordIds
          : local.statisticsRecordIds;
    }
    // The merged id set is the union, winner first, bounded.
    final mergedIds = <String>[
      ...winnerIds,
      for (final id in loserIds)
        if (!winnerIds.contains(id)) id,
    ].take(CloudProfile.maxRecordIds).toList();
    return CloudProfile(
      displayName: nameWinner.displayName,
      nameGeneration: nameWinner.nameGeneration,
      achievements: achievements,
      statistics: statistics,
      statisticsRecordIds: mergedIds,
      updatedAtMs: nowMs,
    );
  }

  // --- Sign-in sync -----------------------------------------------------------------

  /// The sign-in merge: read the cloud profile, reconcile it
  /// with this device, write back only if the merge changed
  /// what is stored. Runs on every landing on an account state
  /// (link, sign-in, conflict resolution, app start).
  Future<void> syncOnSignIn(AuthState state) async {
    if (!state.isAccount) {
      _armed = false;
      _lastSynced = null;
      return;
    }
    final uid = state.uid;
    if (uid == null) return;
    _armed = true;
    try {
      final gate = await history.recordedIds();
      if (gate == null) return; // Newer local schema: hands off.
      final local = await buildLocalProfile(uid);
      final remote = await cloud.load();
      if (remote == null) {
        // First sign-in for this account (or an unreadable
        // profile): the device's snapshot becomes the profile.
        if (await cloud.save(local)) _lastSynced = local;
        return;
      }
      final merged = merge(
        local: local,
        remote: remote,
        nowMs: _clock().millisecondsSinceEpoch,
      );
      // Adopt the merged truth locally, where it differs.
      if (!_sameStatistics(merged.statistics, local.statistics)) {
        await statistics.replace(merged.statistics);
      }
      if (!_sameUnlocks(merged.achievements, local.achievements)) {
        await achievements.saveUnlocks(merged.achievements);
      }
      if (merged.nameGeneration != local.nameGeneration) {
        await names.saveGeneration(uid, merged.nameGeneration);
      }
      final absorb = merged.statisticsRecordIds.toSet().difference(gate);
      if (absorb.isNotEmpty) await history.absorbRecordedIds(absorb);
      if (merged.sameContentAs(remote)) {
        _lastSynced = merged;
      } else if (await cloud.save(merged)) {
        _lastSynced = merged;
      }
    } on Object {
      // Sync is best-effort by design: a failed merge is retried
      // at the next sign-in or match, and never breaks play.
    }
  }

  // --- Post-match sync ---------------------------------------------------------------

  /// Notes that a match finished (the history decorator calls
  /// this). The write itself is debounced and skipped entirely
  /// when the snapshot is unchanged or the player is a guest —
  /// and nothing is even scheduled until a sign-in sync has
  /// armed the service for an account (see [_armed]).
  void noteMatchFinished() {
    if (!_armed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_syncAfterMatch()));
  }

  Future<void> _syncAfterMatch() async {
    try {
      final state = await currentAuth();
      if (!state.isAccount || state.uid == null) return;
      final gate = await history.recordedIds();
      if (gate == null) return;
      final local = await buildLocalProfile(state.uid!);
      final last = _lastSynced;
      if (last != null && local.sameContentAs(last)) return;
      if (await cloud.save(local)) _lastSynced = local;
    } on Object {
      // Best-effort, as above.
    }
  }

  // --- Deletion -------------------------------------------------------------------------

  /// Deletes the cloud profile (Part F's callback): while still
  /// authenticated, ahead of the Auth user itself.
  Future<bool> deleteProfile() async {
    try {
      return await cloud.delete();
    } on Object {
      return false;
    }
  }

  /// Cancels any pending post-match write.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  static bool _sameStatistics(MatchStatistics a, MatchStatistics b) =>
      a.toJson().toString() == b.toJson().toString();

  static bool _sameUnlocks(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
