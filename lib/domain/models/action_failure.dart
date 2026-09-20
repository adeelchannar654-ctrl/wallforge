/// Structured failure describing an illegal action attempt.
///
/// Mirrors spec §5.1: the 12 named failure reasons.
/// Invalid actions never throw; they return one of these.
enum ActionFailure {
  /// The game is in a terminal state (status == finished).
  matchFinished,

  /// It is not the requesting player's turn.
  wrongTurn,

  /// The destination cell is outside the board.
  moveOutOfBoard,

  /// The destination is not orthogonally adjacent to the pawn.
  moveNotAdjacent,

  /// A wall separates the current cell from the destination.
  moveBlockedByWall,

  /// The destination contains the opponent pawn and jump rules do not apply.
  moveOntoPawn,

  /// A jump is attempted but the destination is invalid per §3.5.
  moveIllegalJump,

  /// The player has no walls left in inventory.
  noWallsRemaining,

  /// The wall anchor is outside the valid anchor range.
  wallOutOfBounds,

  /// The wall overlaps an existing wall of the same orientation.
  wallOverlaps,

  /// The wall crosses an existing wall of the other orientation.
  wallCrosses,

  /// The wall would leave either player with no route to their goal.
  wallBlocksPath,
}
