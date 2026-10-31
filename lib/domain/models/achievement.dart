/// One achievement in the catalogue (Phase 16.5, Part F).
///
/// Achievements are **local and deterministic**: each is a pure
/// predicate over the player's match history (plus the legacy
/// statistics snapshot, so play from before history existed is
/// honoured where the counters carry the fact). They are
/// evaluated after a match is recorded, unlock at most once,
/// and never feed anything else — in particular they never
/// feed the leaderboard. They are also, by construction,
/// fakeable (the store is on the player's own device); that
/// is accepted and stated, not hidden.
///
/// The catalogue is data; the predicates live in the
/// application layer's evaluator, keyed by [id].
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    this.external = false,
  });

  /// Stable identity; the unlock store keys on it.
  final String id;

  /// Player-facing name.
  final String name;

  /// Player-facing explanation of how it is earned.
  final String description;

  /// Whether this achievement can only be unlocked from
  /// outside the record evaluator — the weekly leaderboard's
  /// "Top 10" placing, which must come from fetched
  /// leaderboard data, never from local state.
  final bool external;
}

/// The achievement catalogue: sixteen earned from match
/// records, plus the leaderboard's one external entry.
const List<AchievementDefinition> kAchievements = <AchievementDefinition>[
  AchievementDefinition(
    id: 'first-win',
    name: 'First Win',
    description: 'Win a match, in any mode.',
  ),
  AchievementDefinition(
    id: 'streak-3',
    name: 'On a Roll',
    description: 'Win 3 matches in a row.',
  ),
  AchievementDefinition(
    id: 'streak-5',
    name: 'Unstoppable',
    description: 'Win 5 matches in a row.',
  ),
  AchievementDefinition(
    id: 'streak-10',
    name: 'Dominant',
    description: 'Win 10 matches in a row.',
  ),
  AchievementDefinition(
    id: 'beat-easy',
    name: 'Warm-Up',
    description: 'Beat the AI on Easy.',
  ),
  AchievementDefinition(
    id: 'beat-medium',
    name: 'Holding Your Own',
    description: 'Beat the AI on Medium.',
  ),
  AchievementDefinition(
    id: 'beat-hard',
    name: 'Tactician',
    description: 'Beat the AI on Hard.',
  ),
  AchievementDefinition(
    id: 'beat-expert',
    name: 'Mastermind',
    description: 'Beat the AI on Expert.',
  ),
  AchievementDefinition(
    id: 'all-boards',
    name: 'Every Board',
    description: 'Win on every board size: 5, 7, 9 and 11.',
  ),
  AchievementDefinition(
    id: 'no-walls-win',
    name: 'Minimalist',
    description: 'Win a match without placing a single wall.',
  ),
  AchievementDefinition(
    id: 'fully-walled',
    name: 'Wall Builder',
    description: 'Win a match having placed every one of your walls.',
  ),
  AchievementDefinition(
    id: 'fast-win',
    name: 'Blitz',
    description: 'Win a match in 25 plies or fewer.',
  ),
  AchievementDefinition(
    id: 'comeback',
    name: 'Comeback',
    description: 'Win a match after trailing by 3 or more steps at some point.',
  ),
  AchievementDefinition(
    id: 'timeout-win',
    name: 'On Time',
    description: 'Win a match because the other clock ran out.',
  ),
  AchievementDefinition(
    id: 'online-win',
    name: 'Online Victor',
    description: 'Win an online match.',
  ),
  AchievementDefinition(
    id: 'rematch-win',
    name: 'Run It Back',
    description: 'Win a rematch.',
  ),
  AchievementDefinition(
    id: 'top-10-week',
    name: 'Top of the Week',
    description: 'Finish in the weekly leaderboard\'s top 10.',
    external: true,
  ),
];

/// Looks up a catalogue entry by id.
AchievementDefinition? achievementById(String id) {
  for (final definition in kAchievements) {
    if (definition.id == id) return definition;
  }
  return null;
}
