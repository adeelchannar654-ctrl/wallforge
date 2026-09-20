/// Structured failure describing an illegal action attempt.
///
/// Mirrors spec §7: every illegal action returns one of these; no exceptions.
sealed class ActionFailure {
  const ActionFailure._();

  /// Not this player's turn.
  const factory ActionFailure.wrongTurn() = WrongTurnFailure;

  /// Game is not active.
  const factory ActionFailure.gameNotActive() = GameNotActiveFailure;

  /// Target cell occupied by own pawn.
  const factory ActionFailure.occupiedByOwnPawn() = OccupiedByOwnPawnFailure;

  /// Not orthogonal or adjacent (for moves/jumps).
  const factory ActionFailure.notAdjacent() = NotAdjacentFailure;

  /// Jump target not directly behind opponent.
  const factory ActionFailure.jumpTargetNotBehind() =
      JumpTargetNotBehindFailure;

  /// No opponent adjacent in the required direction.
  const factory ActionFailure.noOpponentToJumpOver() =
      NoOpponentToJumpOverFailure;

  /// Must jump when a jump is available.
  const factory ActionFailure.mustJump() = MustJumpFailure;

  /// Player has no walls remaining.
  const factory ActionFailure.noWallsRemaining() = NoWallsRemainingFailure;

  /// Wall origin out of board bounds.
  const factory ActionFailure.wallOutOfBounds() = WallOutOfBoundsFailure;

  /// Wall overlaps another wall.
  const factory ActionFailure.wallOverlap() = WallOverlapFailure;

  /// Wall overlaps a pawn.
  const factory ActionFailure.wallOverlapPawn() = WallOverlapPawnFailure;

  /// Wall blocks all paths for a player to reach goal.
  const factory ActionFailure.wallBlocksPath() = WallBlocksPathFailure;

  /// Wall placed directly on a player's forward path.
  const factory ActionFailure.wallOnForwardPath() = WallOnForwardPathFailure;

  /// Wall orientation invalid for this board.
  const factory ActionFailure.invalidWallOrientation() =
      InvalidWallOrientationFailure;
}

class WrongTurnFailure extends ActionFailure {
  const WrongTurnFailure() : super._();
  @override
  String toString() => 'WrongTurn';
}

class GameNotActiveFailure extends ActionFailure {
  const GameNotActiveFailure() : super._();
  @override
  String toString() => 'GameNotActive';
}

class OccupiedByOwnPawnFailure extends ActionFailure {
  const OccupiedByOwnPawnFailure() : super._();
  @override
  String toString() => 'OccupiedByOwnPawn';
}

class NotAdjacentFailure extends ActionFailure {
  const NotAdjacentFailure() : super._();
  @override
  String toString() => 'NotAdjacent';
}

class JumpTargetNotBehindFailure extends ActionFailure {
  const JumpTargetNotBehindFailure() : super._();
  @override
  String toString() => 'JumpTargetNotBehind';
}

class NoOpponentToJumpOverFailure extends ActionFailure {
  const NoOpponentToJumpOverFailure() : super._();
  @override
  String toString() => 'NoOpponentToJumpOver';
}

class MustJumpFailure extends ActionFailure {
  const MustJumpFailure() : super._();
  @override
  String toString() => 'MustJump';
}

class NoWallsRemainingFailure extends ActionFailure {
  const NoWallsRemainingFailure() : super._();
  @override
  String toString() => 'NoWallsRemaining';
}

class WallOutOfBoundsFailure extends ActionFailure {
  const WallOutOfBoundsFailure() : super._();
  @override
  String toString() => 'WallOutOfBounds';
}

class WallOverlapFailure extends ActionFailure {
  const WallOverlapFailure() : super._();
  @override
  String toString() => 'WallOverlap';
}

class WallOverlapPawnFailure extends ActionFailure {
  const WallOverlapPawnFailure() : super._();
  @override
  String toString() => 'WallOverlapPawn';
}

class WallBlocksPathFailure extends ActionFailure {
  const WallBlocksPathFailure() : super._();
  @override
  String toString() => 'WallBlocksPath';
}

class WallOnForwardPathFailure extends ActionFailure {
  const WallOnForwardPathFailure() : super._();
  @override
  String toString() => 'WallOnForwardPath';
}

class InvalidWallOrientationFailure extends ActionFailure {
  const InvalidWallOrientationFailure() : super._();
  @override
  String toString() => 'InvalidWallOrientation';
}
