/// Aggregate local match results, as persisted.
///
/// Deliberately minimal and derived **only** from facts the app can actually
/// produce today. Every field here has a real source:
///
/// * [matchesPlayed] — a match that reached `GameStatus.finished`.
/// * [humanWins] / [humanLosses] — the human player's outcome in those matches.
/// * [byBoardSize] / [byDifficulty] — the same, split by the match's board size
///   and, for AI matches, the difficulty that was played.
///
/// **What is deliberately absent.** There is no "AI progress" of any kind: the
/// Phase 5 AI is a stateless evaluator with no rating, no level unlocks and no
/// per-player model, so there is nothing true to record. Inventing a skill
/// rating or a progression curve would be fabricating a feature that does not
/// exist (`phase.md` Phase 6 lists "AI progress **if introduced**"). The
/// difficulty the player picks is a *setting*, not progress, and is stored in
/// [AppSettings] instead. Tracked as Q-6.3 in `memory.md`.
class MatchStatistics {
  const MatchStatistics({
    this.matchesPlayed = 0,
    this.humanWins = 0,
    this.humanLosses = 0,
    this.byBoardSize = const <String, Bucket>{},
    this.byDifficulty = const <String, Bucket>{},
  });

  /// The zero state, used when nothing is stored or the stored value is
  /// unreadable.
  static const MatchStatistics empty = MatchStatistics();

  /// Finished matches recorded, across every mode and board size.
  final int matchesPlayed;

  /// Finished matches the human player won.
  final int humanWins;

  /// Finished matches the human player lost (i.e. the AI or second player won).
  final int humanLosses;

  /// Results keyed by board size, e.g. `"9"`.
  final Map<String, Bucket> byBoardSize;

  /// Results keyed by difficulty name, e.g. `"expert"`. Local pass-and-play
  /// matches are recorded under `"local"`.
  final Map<String, Bucket> byDifficulty;

  /// Win rate in `0.0..1.0`, or null when no match has been played.
  double? get winRate => matchesPlayed == 0 ? null : humanWins / matchesPlayed;

  /// Returns a copy with one finished match folded in.
  ///
  /// [boardSize] is the match's board dimension. [difficulty] is the AI
  /// difficulty name, or `"local"` for a pass-and-play match.
  MatchStatistics recordResult({
    required int boardSize,
    required String difficulty,
    required bool humanWon,
  }) {
    final sizeKey = '$boardSize';
    return copyWith(
      matchesPlayed: matchesPlayed + 1,
      humanWins: humanWins + (humanWon ? 1 : 0),
      humanLosses: humanLosses + (humanWon ? 0 : 1),
      byBoardSize: _bump(byBoardSize, sizeKey, humanWon),
      byDifficulty: _bump(byDifficulty, difficulty, humanWon),
    );
  }

  static Map<String, Bucket> _bump(
    Map<String, Bucket> source,
    String key,
    bool humanWon,
  ) {
    final next = Map<String, Bucket>.from(source);
    final existing = next[key] ?? const Bucket();
    next[key] = existing.copyWith(
      played: existing.played + 1,
      wins: existing.wins + (humanWon ? 1 : 0),
      losses: existing.losses + (humanWon ? 0 : 1),
    );
    return next;
  }

  MatchStatistics copyWith({
    int? matchesPlayed,
    int? humanWins,
    int? humanLosses,
    Map<String, Bucket>? byBoardSize,
    Map<String, Bucket>? byDifficulty,
  }) => MatchStatistics(
    matchesPlayed: matchesPlayed ?? this.matchesPlayed,
    humanWins: humanWins ?? this.humanWins,
    humanLosses: humanLosses ?? this.humanLosses,
    byBoardSize: byBoardSize ?? this.byBoardSize,
    byDifficulty: byDifficulty ?? this.byDifficulty,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'matchesPlayed': matchesPlayed,
    'humanWins': humanWins,
    'humanLosses': humanLosses,
    'byBoardSize': byBoardSize.map((k, v) => MapEntry(k, v.toJson())),
    'byDifficulty': byDifficulty.map((k, v) => MapEntry(k, v.toJson())),
  };

  /// Rebuilds statistics from [json], substituting defaults for anything missing
  /// or malformed. Never throws, and never trusts a stored number: a corrupt or
  /// nonsensical value falls back rather than propagating.
  factory MatchStatistics.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    return MatchStatistics(
      matchesPlayed: _readCount(json['matchesPlayed']),
      humanWins: _readCount(json['humanWins']),
      humanLosses: _readCount(json['humanLosses']),
      byBoardSize: _readBuckets(json['byBoardSize']),
      byDifficulty: _readBuckets(json['byDifficulty']),
    );
  }

  static int _readCount(Object? value) {
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0) return value.toInt();
    return 0;
  }

  static Map<String, Bucket> _readBuckets(Object? value) {
    if (value is! Map) return const <String, Bucket>{};
    final out = <String, Bucket>{};
    value.forEach((key, raw) {
      if (key is String && raw is Map) {
        out[key] = Bucket.fromJson(raw.cast<String, dynamic>());
      }
    });
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is MatchStatistics &&
      other.matchesPlayed == matchesPlayed &&
      other.humanWins == humanWins &&
      other.humanLosses == humanLosses &&
      _mapsEqual(other.byBoardSize, byBoardSize) &&
      _mapsEqual(other.byDifficulty, byDifficulty);

  static bool _mapsEqual(Map<String, Bucket> a, Map<String, Bucket> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    matchesPlayed,
    humanWins,
    humanLosses,
    Object.hashAllUnordered(
      byBoardSize.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(
      byDifficulty.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() =>
      'MatchStatistics(played: $matchesPlayed, wins: $humanWins, '
      'losses: $humanLosses)';
}

/// A played / won / lost tally for one grouping key.
class Bucket {
  const Bucket({this.played = 0, this.wins = 0, this.losses = 0});

  final int played;
  final int wins;
  final int losses;

  Bucket copyWith({int? played, int? wins, int? losses}) => Bucket(
    played: played ?? this.played,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'played': played,
    'wins': wins,
    'losses': losses,
  };

  factory Bucket.fromJson(Map<String, dynamic> json) => Bucket(
    played: _count(json['played']),
    wins: _count(json['wins']),
    losses: _count(json['losses']),
  );

  static int _count(Object? value) => (value is int && value >= 0) ? value : 0;

  @override
  bool operator ==(Object other) =>
      other is Bucket &&
      other.played == played &&
      other.wins == wins &&
      other.losses == losses;

  @override
  int get hashCode => Object.hash(played, wins, losses);

  @override
  String toString() => 'Bucket(played: $played, wins: $wins, losses: $losses)';
}
