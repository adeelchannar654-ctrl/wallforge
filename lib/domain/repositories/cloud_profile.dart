import 'match_statistics.dart';

/// The small cloud profile (Phase 16.6, Part E): the *only* new
/// document an account adds, at `users/{uid}/profile`.
///
/// It carries exactly what an account is for — a stable identity
/// across devices — and nothing heavier:
///
/// * the generated display name (never a Google name, never an
///   email; there is deliberately **no email field**),
/// * the unlocked achievement ids with their unlock times,
/// * a compact lifetime statistics snapshot, plus the ids of the
///   matches that snapshot covers — the field that makes the
///   merge provably unable to double-count (D16.6-8).
///
/// Full match history is **not** in here and is never synced;
/// the UI says so. The whole document is a few KB at most, and
/// the Security Rules bound its shape and size (Part G).
class CloudProfile {
  const CloudProfile({
    required this.displayName,
    required this.nameGeneration,
    required this.achievements,
    required this.statistics,
    required this.statisticsRecordIds,
    required this.updatedAtMs,
  });

  /// The document schema this build reads and writes. A document
  /// from a newer schema is ignored wholesale by [fromJson] —
  /// never partially read, never overwritten by a merge.
  static const int schemaVersion = 1;

  /// Upper bound on stored unlocks (the catalogue has 17; the
  /// headroom is for future achievements, and the rules enforce
  /// the same cap server-side).
  static const int maxAchievements = 64;

  /// Upper bound on covered match ids — the history gate's own
  /// bound (`MatchHistoryRepository.maxRecords`), so a snapshot
  /// never claims more than the gate holds.
  static const int maxRecordIds = 100;

  /// The generated display name for this account's uid.
  final String displayName;

  /// The name generation the display name was derived from.
  final int nameGeneration;

  /// Achievement id → unlock time (epoch ms).
  final Map<String, int> achievements;

  /// The compact lifetime statistics snapshot.
  final MatchStatistics statistics;

  /// Ids of the matches [statistics] already counts. The merge
  /// compares this set against each device's finish gate.
  final List<String> statisticsRecordIds;

  /// When this snapshot was written (epoch ms, device clock —
  /// a merge tie-breaker only, never a security input).
  final int updatedAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'displayName': displayName,
    'nameGeneration': nameGeneration,
    'achievements': achievements,
    'statistics': statistics.toJson(),
    'statisticsRecordIds': statisticsRecordIds,
    'updatedAtMs': updatedAtMs,
  };

  /// Tolerant reader: null for anything malformed, mistyped or
  /// from a newer schema — a bad profile is ignored, never
  /// repaired by guessing, and local data is never touched on
  /// its account.
  static CloudProfile? fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! int || version > schemaVersion) return null;
    final name = json['displayName'];
    final generation = json['nameGeneration'];
    final rawAchievements = json['achievements'];
    final rawStatistics = json['statistics'];
    final rawIds = json['statisticsRecordIds'];
    final updatedAtMs = json['updatedAtMs'];
    if (name is! String || name.isEmpty) return null;
    if (generation is! int || generation < 0) return null;
    if (rawAchievements is! Map) return null;
    if (rawStatistics is! Map) return null;
    if (rawIds is! List) return null;
    if (updatedAtMs is! int) return null;
    final achievements = <String, int>{};
    for (final entry in rawAchievements.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! int) return null;
      achievements[key] = value;
    }
    if (achievements.length > maxAchievements) return null;
    final ids = <String>[];
    for (final id in rawIds) {
      if (id is! String) return null;
      ids.add(id);
    }
    if (ids.length > maxRecordIds) return null;
    return CloudProfile(
      displayName: name,
      nameGeneration: generation,
      achievements: achievements,
      statistics: MatchStatistics.fromJson(
        rawStatistics.cast<String, dynamic>(),
      ),
      statisticsRecordIds: ids,
      updatedAtMs: updatedAtMs,
    );
  }

  /// Whether two profiles carry the same content, ignoring
  /// [updatedAtMs] — the sync service's "unchanged, skip the
  /// write" test.
  bool sameContentAs(CloudProfile other) {
    if (displayName != other.displayName ||
        nameGeneration != other.nameGeneration ||
        statisticsRecordIds.length != other.statisticsRecordIds.length ||
        achievements.length != other.achievements.length) {
      return false;
    }
    for (final id in statisticsRecordIds) {
      if (!other.statisticsRecordIds.contains(id)) return false;
    }
    for (final entry in achievements.entries) {
      if (other.achievements[entry.key] != entry.value) return false;
    }
    return statistics.toJson().toString() ==
        other.statistics.toJson().toString();
  }
}

/// Storage for the one cloud profile document, scoped to the
/// signed-in account. Guests never touch it — the profile is
/// precisely what an account buys.
abstract interface class CloudProfileRepository {
  /// The stored profile, or null when none exists or the stored
  /// document is unreadable/corrupt/from a newer schema.
  /// Never throws.
  Future<CloudProfile?> load();

  /// Writes the profile. False on failure (offline, no owner).
  /// Never throws.
  Future<bool> save(CloudProfile profile);

  /// Deletes the profile (account deletion, Part F). False on
  /// failure. Never throws.
  Future<bool> delete();
}
