import '../../../domain/engine/pathfinder.dart';
import '../../../domain/models/game_state.dart';
import '../../../domain/models/game_status.dart';
import '../../../domain/models/player_id.dart';
import '../../../domain/models/wall.dart';

/// Static evaluation of a position from one player's point of view.
///
/// Implements the four inputs `phase.md` §Phase 5 "Version 1" asks for, using
/// the domain pathfinder rather than a private BFS:
///
/// * **Shortest path** — [ownRouteLength] for the evaluated player.
/// * **Opponent shortest path** — [opponentRouteLength].
/// * **Wall impact** — the opponent's route length already reflects every wall
///   on the board, including the one just placed, so a wall is scored by the
///   route length it forces on the opponent. [wallCost] additionally charges a
///   small fee per wall spent so a useless wall is never preferred over a move.
/// * **Immediate tactical opportunities** — [hasImmediateWin] and
///   [hasImmediateLoss] see whether the position is already decided on either
///   side, which the search turns into a decisive score.
///
/// No game rules live here: this class only *scores* states produced by
/// `GameEngine`. Rule evaluation is never duplicated (`architecture.md` §9).
class AiEvaluator {
  const AiEvaluator._();

  /// Weight on the evaluated player's remaining *row distance* to the goal row.
  ///
  /// This is the race itself, and unlike [ownRouteLength] it is strictly
  /// monotone: stepping toward the goal always lowers it and no wall can raise
  /// it. That matters more than it looks. Route length alone is not monotone —
  /// once the opponent walls a detour in, the shortest route can *grow* while
  /// the pawn is standing still, and a purely route-greedy player then finds
  /// sideways shuffles and backward steps scoring equal to real progress and
  /// oscillates forever without ever reaching its goal. (Observed while building
  /// this: both sides bounced between two cells until the ply cap.) Anchoring on
  /// row distance guarantees the AI keeps closing on its goal, so matches end.
  static const double progressWeight = 1.0;

  /// Weight on the evaluated player's remaining route length.
  ///
  /// Two jobs. It breaks ties between moves that make equal progress by
  /// preferring the shorter detour, and — more importantly — it is what makes the
  /// player *walk a detour* when its direct route has been walled off, since
  /// every step along that detour shortens the remaining route.
  ///
  /// Tuned up from a much smaller value after observing the AI wall itself into
  /// a corner: with self-harm almost free, blocking the opponent was always
  /// worth it even when the same wall made the AI's own route longer, and both
  /// sides ended up sealed in opposite corners with every wall spent and no way
  /// out. At this weight a wall that costs the AI a step while gaining the
  /// opponent one is no longer clearly worth playing.
  static const double ownRouteWeight = 0.5;

  /// Weight on the opponent's remaining route length. Longer is better for the
  /// evaluated player.
  static const double opponentRouteWeight = 1.0;

  /// Fee charged for each wall the evaluated player has spent.
  ///
  /// `architecture.md` §9 lists "wall cost" as an evaluation input. The value is
  /// deliberately high enough that a wall is only played when it buys the
  /// opponent clearly more than it costs, which has two effects:
  ///
  /// * Walls become purposeful instead of spam, so a match plays like a race
  ///   with real blocking rather than a board buried under 20 walls in 40 plies.
  /// * **It is what guarantees the AI can always escape a trap.** With all ten
  ///   walls gone, a pawn reduced to two or three legal moves whose every option
  ///   recreates a seen position is genuinely trapped: passing is illegal, and
  ///   no evaluation can help, because the *only* way to change the position is
  ///   to place a wall. Conserving inventory keeps that hatch open. Raising this
  ///   from 0.1 to 0.4 is what made Hard self-play terminate on 9x9.
  static const double wallCost = 0.4;

  /// Score awarded for a position the evaluated player has already won.
  static const double winScore = 1000;

  /// Score for a position the evaluated player has already lost.
  static const double lossScore = -1000;

  /// The evaluated player's remaining row distance to their own goal row.
  ///
  /// `0` means the pawn is on the goal row (a finished win). Unlike
  /// [ownRouteLength] this never increases while walls are being placed.
  static int progress(GameState state, PlayerId player) {
    final row = state.pawnPosition(player).row;
    final goal = _goalRow(state, player);
    return (row - goal).abs();
  }

  /// The evaluated player's shortest route length to their own goal row.
  ///
  /// `0` means the pawn is already on the goal row (a finished win).
  /// `null` means no route exists, which the engine forbids (R-PATH-01).
  static int? ownRouteLength(GameState state, PlayerId player) =>
      Pathfinder.shortestRouteLength(
        from: state.pawnPosition(player),
        goalRow: _goalRow(state, player),
        walls: state.walls,
        size: state.boardConfig.size,
      );

  /// The opponent's shortest route length to their own goal row, as seen from
  /// [player]'s point of view. Longer is better for [player].
  static int? opponentRouteLength(GameState state, PlayerId player) =>
      Pathfinder.shortestRouteLength(
        from: state.pawnPosition(player.opponent),
        goalRow: _goalRow(state, player.opponent),
        walls: state.walls,
        size: state.boardConfig.size,
      );

  /// The goal row for [player].
  static int _goalRow(GameState state, PlayerId player) =>
      player == PlayerId.blue
      ? state.boardConfig.blueGoalRow
      : state.boardConfig.redGoalRow;

  /// Number of walls owned by [player] in [state].
  static int wallsOwnedBy(GameState state, PlayerId player) =>
      state.walls.where((w) => w.owner == player).length;

  /// How much a wall at [wall] costs [player] in evaluation points.
  ///
  /// This is the "wall impact" term in isolation: the route-length difference
  /// the wall produces, less the flat [wallCost] fee. Exposed separately so it
  /// can be unit-tested on its own; the search itself obtains the same
  /// information implicitly through [opponentRouteLength].
  static double wallImpact({
    required GameState state,
    required PlayerId player,
    required Wall wall,
  }) {
    final size = state.boardConfig.size;
    final opponent = player.opponent;
    final before = Pathfinder.shortestRouteLength(
      from: state.pawnPosition(opponent),
      goalRow: _goalRow(state, opponent),
      walls: state.walls,
      size: size,
    );
    final after = Pathfinder.shortestRouteLength(
      from: state.pawnPosition(opponent),
      goalRow: _goalRow(state, opponent),
      walls: [...state.walls, wall],
      size: size,
    );
    if (before == null || after == null) return 0;
    return opponentRouteWeight * (after - before) - wallCost;
  }

  /// Whether [player] can win on their very next action.
  ///
  /// Detected from the position alone (a pawn already on the goal row, i.e. a
  /// finished game) rather than by re-running the search, so it stays a cheap
  /// guard that the search can consult at any depth.
  static bool hasImmediateWin(GameState state, PlayerId player) =>
      state.status == GameStatus.finished && state.winner == player;

  /// Whether [player] has already been beaten by a finished position.
  static bool hasImmediateLoss(GameState state, PlayerId player) =>
      state.status == GameStatus.finished && state.winner == player.opponent;

  /// The static score of [state] from [player]'s point of view.
  ///
  /// Higher is better. A finished position is decisive and outranks any
  /// positional score, which is what lets the search treat a forced win or loss
  /// correctly at any depth.
  static double score(GameState state, PlayerId player) {
    if (hasImmediateWin(state, player)) return winScore;
    if (hasImmediateLoss(state, player)) return lossScore;
    final own = ownRouteLength(state, player) ?? sizeFallback(state);
    final opponent = opponentRouteLength(state, player) ?? sizeFallback(state);
    final spent = wallsOwnedBy(state, player);

    return -progressWeight * progress(state, player) -
        ownRouteWeight * own +
        opponentRouteWeight * opponent -
        wallCost * spent;
  }

  /// Defensive route-length stand-in if a route is somehow absent.
  ///
  /// R-PATH-01 makes an absent route unreachable through legal play, so this
  /// only guards against a hand-built state. It uses the largest possible route
  /// on the board, which is the worst case for the player being scored.
  static int sizeFallback(GameState state) => state.boardConfig.size;
}
