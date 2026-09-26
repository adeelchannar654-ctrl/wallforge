/// The four AI difficulty levels required by `phase.md` §Phase 5 and
/// `design.md` §20.
///
/// Difficulty is achieved through **controlled search/evaluation complexity**,
/// never through randomness or deliberately weakened play (`phase.md`
/// §Difficulty). Each level is a strict superset of the level below it:
/// a strictly greater search depth *and* a strictly wider shortlist of
/// candidate actions. There is no randomness anywhere in the AI, so a given
/// position always produces the same move.
enum AiDifficulty {
  /// Ranked candidates, no look-ahead. Sees only the immediate consequence of
  /// each action and cannot answer an opponent threat.
  easy(
    searchDepth: 0,
    candidateWidth: 6,
    label: 'Easy',
    description: 'Looks one move ahead. Reacts to what it can see right now.',
  ),

  /// One reply of look-ahead, so it can dodge an immediate threat.
  medium(
    searchDepth: 1,
    candidateWidth: 8,
    label: 'Medium',
    description: 'Looks one move ahead, then checks your best reply.',
  ),

  /// Two replies of look-ahead plus a wider shortlist.
  hard(
    searchDepth: 2,
    candidateWidth: 10,
    label: 'Hard',
    description: 'Looks two moves ahead over a wider set of choices.',
  ),

  /// Three replies of look-ahead, the widest shortlist, and the same evaluation
  /// function. Deliberately not described as unbeatable or perfect.
  expert(
    searchDepth: 3,
    candidateWidth: 12,
    label: 'Expert',
    description: 'Looks three moves ahead over the widest set of choices.',
  );

  const AiDifficulty({
    required this.searchDepth,
    required this.candidateWidth,
    required this.label,
    required this.description,
  });

  /// How many opponent replies ahead of the AI's own move are searched.
  ///
  /// `0` means the AI evaluates only the position directly after its move.
  final int searchDepth;

  /// How many top-ranked legal actions are carried into the search.
  ///
  /// Candidates are ranked by the same evaluation every level uses, so a
  /// larger value can only ever add candidates to the previous level's set.
  final int candidateWidth;

  /// Short display name, used by the UI selector.
  final String label;

  /// One-line honest explanation shown under the selector
  /// (`design.md` §20 "Explain difficulty briefly", and no "perfect AI" claims).
  final String description;
}
