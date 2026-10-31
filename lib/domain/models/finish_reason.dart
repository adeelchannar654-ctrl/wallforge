/// Why a match ended (Phase 16.5).
///
/// This is an **application-layer** concept: the engine's
/// `GameState` knows only `inProgress` / `finished` and a winner
/// (`game_spec.md` §6.1). How the finish came about — reaching
/// the goal, a resignation, a clock timeout, an abandonment
/// claim — is a fact about the match, not about move legality,
/// so it lives here and in the match record, never in the
/// engine. `game_spec.md` §12's Phase 16.5 decision record
/// adopts the clock the same way: application layer only.
///
/// The wire form is the enum [name]; it is what the match
/// document's `finishReason` field and the local history store
/// persist.
enum FinishReason {
  /// The engine declared a winner: a pawn reached its goal row.
  goal,

  /// A player resigned; the opponent wins.
  resign,

  /// A player's per-move clock ran out; the opponent wins.
  timeout,

  /// The waiting player claimed the match as abandoned
  /// (Phase 10). No winner is declared.
  abandon;

  /// The persisted form.
  String get wireName => name;

  /// Parses a persisted value, or returns null for anything
  /// unrecognised (absent, mistyped, or from a newer build) —
  /// readers are tolerant by design and never throw.
  static FinishReason? fromWire(Object? value) {
    if (value is! String) return null;
    for (final reason in values) {
      if (reason.name == value) return reason;
    }
    return null;
  }

  /// Player-facing label for result and history surfaces.
  String get label => switch (this) {
    FinishReason.goal => 'Goal',
    FinishReason.resign => 'Resignation',
    FinishReason.timeout => 'Timeout',
    FinishReason.abandon => 'Abandoned',
  };

  /// Whether this finish declares a winner (all but [abandon]).
  bool get hasWinner => this != FinishReason.abandon;
}
