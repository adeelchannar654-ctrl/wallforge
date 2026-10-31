/// The weekly leaderboard (Phase 16.5, Part H): domain model,
/// week arithmetic, display-name generation and the
/// repository contract.
///
/// ## The week
///
/// A week bucket is identified by the epoch milliseconds of
/// its Monday 00:00 UTC. The epoch (1970-01-01) was a
/// Thursday, so Mondays are exactly the day-starts with
/// `ms % 604800000 == 345600000` — an identity the Security
/// Rules verify with integer arithmetic alone, no date
/// parsing: an entry's `weekStartMs` must be a Monday start
/// and must contain `request.time`. A new week simply starts
/// empty; nothing is ever reset or deleted.
///
/// ## Points
///
/// Only finished online matches between two distinct players
/// count: a win is 3 points, a loss 1. A match counts only at
/// 10+ plies, at most 20 counted matches per player per week,
/// and at most 3 counted matches against the same opponent
/// per week (anti win-trading). Abandoned matches never
/// count. The rules re-validate every one of these against
/// the finished match document.
library;

/// One player's standing in one week.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.points,
    required this.wins,
    required this.losses,
    required this.countedMatches,
    required this.opponentCounts,
  });
  final String uid;

  /// The generated display name (see [generateDisplayName]).
  final String displayName;

  /// Total points this week.
  final int points;

  /// Counted wins / losses this week.
  final int wins;
  final int losses;

  /// The matches counted toward this entry, as match id →
  /// opponent uid (≤ 20 keys). A map, not a list, because the
  /// Security Rules validate the increment with a map diff —
  /// the one shape rules can prove "exactly one new key, none
  /// changed, none removed" for.
  final Map<String, String> countedMatches;

  /// Counted matches per opponent uid (≤ 3 each).
  final Map<String, int> opponentCounts;

  /// An empty entry for a player with nothing counted yet.
  factory LeaderboardEntry.empty(String uid, String displayName) =>
      LeaderboardEntry(
        uid: uid,
        displayName: displayName,
        points: 0,
        wins: 0,
        losses: 0,
        countedMatches: const {},
        opponentCounts: const {},
      );

  /// Serialises the entry for Firestore.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'uid': uid,
    'displayName': displayName,
    'points': points,
    'wins': wins,
    'losses': losses,
    'countedMatches': countedMatches,
    'opponentCounts': opponentCounts,
  };

  /// Rebuilds an entry from a stored document, tolerantly.
  static LeaderboardEntry? fromJson(Map<String, dynamic> json) {
    final uid = json['uid'];
    final name = json['displayName'];
    if (uid is! String || uid.isEmpty || name is! String || name.isEmpty) {
      return null;
    }
    int intOr(Object? v) => (v is int && v >= 0) ? v : 0;
    final rawMatches = json['countedMatches'];
    final rawCounts = json['opponentCounts'];
    return LeaderboardEntry(
      uid: uid,
      displayName: name,
      points: intOr(json['points']),
      wins: intOr(json['wins']),
      losses: intOr(json['losses']),
      countedMatches: rawMatches is Map
          ? {
              for (final e in rawMatches.entries)
                if (e.key is String && e.value is String)
                  e.key as String: e.value as String,
            }
          : const {},
      opponentCounts: rawCounts is Map
          ? {
              for (final e in rawCounts.entries)
                if (e.key is String && e.value is int)
                  e.key as String: e.value as int,
            }
          : const {},
    );
  }

  @override
  String toString() => 'LeaderboardEntry($displayName, $points pts)';
}

/// Milliseconds in a day / a week.
const int kDayMs = 86400000;
const int kWeekMs = 604800000;

/// The Monday-start residue: Mondays 00:00 UTC are the
/// day-starts at `ms % kWeekMs == kMondayResidueMs` (the
/// epoch was a Thursday; the first Monday was day 4).
const int kMondayResidueMs = 345600000;

/// The start (Monday 00:00 UTC, epoch ms) of the week
/// containing [ms].
int weekStartMs(int ms) {
  final dayStart = ms - (ms % kDayMs);
  final residue = dayStart % kWeekMs;
  final sinceMonday = residue >= kMondayResidueMs
      ? residue - kMondayResidueMs
      : residue + (kWeekMs - kMondayResidueMs);
  return dayStart - sinceMonday;
}

/// The bucket id for the week containing [ms]: its Monday
/// start, as a decimal string.
String weekIdFor(int ms) => weekStartMs(ms).toString();

/// Points for a win / for a loss.
const int kWinPoints = 3;
const int kLossPoints = 1;

/// The counting caps (Part H design, mirrored in the rules).
const int kMinCountedPlies = 10;
const int kMaxCountedPerWeek = 20;
const int kMaxCountedPerOpponent = 3;

/// How many rows the board shows.
const int kLeaderboardTopLimit = 50;

/// The generated-name word lists. Names are Adjective + Noun
/// + a two-digit number — generated, never free text, so no
/// moderation system is needed. The Security Rules validate
/// exactly this shape.
const List<String> kNameAdjectives = [
  'Swift',
  'Silent',
  'Amber',
  'Crimson',
  'Golden',
  'Iron',
  'Velvet',
  'Clever',
  'Brave',
  'Quiet',
  'Rapid',
  'Scarlet',
  'Cobalt',
  'Jade',
  'Onyx',
  'Solar',
  'Lunar',
  'Merry',
  'Noble',
  'Astute',
];
const List<String> kNameNouns = [
  'Falcon',
  'Badger',
  'Comet',
  'Harbor',
  'Lantern',
  'Meadow',
  'Otter',
  'Pioneer',
  'Quiver',
  'Raven',
  'Summit',
  'Tempest',
  'Umbra',
  'Voyager',
  'Walnut',
  'Zephyr',
  'Anchor',
  'Bison',
  'Cipher',
  'Drift',
];

/// Generates the display name for [uid] at [generation]
/// (regenerating increments the generation and produces a
/// different name). Deterministic: the same uid + generation
/// always yields the same name, on every device.
///
/// Shape: `Swift Falcon 42` — the rules' pattern is
/// `^[A-Z][a-z]+ [A-Z][a-z]+ [0-9]{2}$`.
String generateDisplayName(String uid, int generation) {
  // FNV-1a over the uid and generation: small, stable, and
  // identical on every platform (unlike String.hashCode).
  var hash = 0x811c9dc5;
  final input = '$uid#$generation';
  for (var i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  final adjective = kNameAdjectives[hash % kNameAdjectives.length];
  final noun = kNameNouns[(hash >> 8) % kNameNouns.length];
  final number = 10 + (hash >> 16) % 90;
  return '$adjective $noun $number';
}

/// The result of asking the repository to count a match.
enum LeaderboardSubmitOutcome {
  /// The match was counted into the player's entry.
  counted,

  /// The match cannot count (too short, abandoned, unranked
  /// mode, duplicate, or a cap reached) — not an error.
  notCounted,

  /// The write failed (offline, rules not deployed, …). The
  /// result is not counted and is not retried in this phase.
  failed,
}

/// The leaderboard store: reads for the board, and the
/// entry write after a finished online match.
abstract interface class LeaderboardRepository {
  /// The top [limit] entries of the week starting at
  /// [weekStartMs], ordered by points desc, wins desc, uid
  /// asc (the deterministic tie-break).
  Future<List<LeaderboardEntry>> fetchTop(
    int weekStartMs, {
    int limit = kLeaderboardTopLimit,
  });

  /// One player's entry for the week, or null when they have
  /// none.
  Future<LeaderboardEntry?> fetchEntry(int weekStartMs, String uid);

  /// Counts a finished match into the caller's own entry for
  /// the CURRENT week (the week of [matchEndedAtMs]).
  ///
  /// The implementation re-checks eligibility locally
  /// (decisive result, 10+ plies, caps, not already counted)
  /// before writing; the Security Rules re-validate the same
  /// facts against the match document server-side. Returns
  /// the honest outcome — never throws.
  Future<LeaderboardSubmitOutcome> recordResult({
    required String matchId,
    required String opponentUid,
    required bool won,
    required int plies,
    required int matchEndedAtMs,
    required String displayName,
  });

  /// Renames the caller's current-week entry in place (a
  /// regenerated display name), preserving everything else.
  /// Returns false when there is no entry to rename or the
  /// write failed. The rules allow exactly this write and no
  /// other name-only change.
  Future<bool> renameCurrentEntry({required String displayName});
}

/// The display-name generation store: how many times the
/// player has regenerated their leaderboard name. Local only.
abstract interface class LeaderboardNameRepository {
  /// The current generation for [uid] (0 when never set).
  Future<int> loadGeneration(String uid);

  /// Persists the generation for [uid].
  Future<void> saveGeneration(String uid, int generation);
}
