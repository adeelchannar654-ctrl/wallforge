import 'dart:collection';

import '../../../domain/engine/blocked_edges.dart';
import '../../../domain/engine/game_engine.dart';
import '../../../domain/engine/pathfinder.dart';
import '../../../domain/models/cell.dart';
import '../../../domain/models/game_action.dart';
import '../../../domain/models/game_state.dart';
import '../../../domain/models/player_id.dart';

import '../../../domain/models/wall_orientation.dart';
import 'ai_difficulty.dart';
import '../../../domain/models/game_status.dart';
import 'ai_evaluator.dart';

/// A candidate action together with the position it leads to, and the
/// two route lengths of that position (for the mover and for the
/// opponent), computed once while shortlisting so the depth-1 leaf
/// evaluation can reuse them instead of running more pathfinding
/// (Phase 16).
typedef _Candidate = ({
  GameAction action,
  GameState next,
  int routeMover,
  int routeOpponent,
});

/// Goal-distance fields for one position: for each player, the exact
/// shortest-route length from every cell to that player's goal row,
/// over the position's walls.
///
/// This is what makes candidate scoring cheap (Phase 16). The old code
/// ran two BFS pathfinds for *every* candidate (~130 per node); a
/// search node now runs exactly two BFS total and answers most
/// candidates in O(1):
///
/// * a pawn move never changes the opponent's route (the pathfinder
///   ignores pawn positions), and the mover's new route is a field
///   lookup at the pawn's new cell, because the walls are unchanged;
/// * a wall can only lengthen a player's route if it blocks an edge
///   that *descends* that player's distance field — every shortest
///   path descends the field by exactly one per step, so if no
///   descending edge is blocked, an old shortest path survives and the
///   length is unchanged. Otherwise the route is recomputed exactly
///   with [Pathfinder].
///
/// Every number produced is identical to what [AiEvaluator.score]
/// computes; this class only avoids recomputing them. The Phase 16
/// choices fixture (test/fixtures/ai_choices_v1.json) and the field
/// cross-check test prove the equivalence.
class _GoalFields {
  _GoalFields(GameState state)
    : size = state.boardConfig.size,
      _toBlueGoal = _distances(state, PlayerId.blue),
      _toRedGoal = _distances(state, PlayerId.red);

  final int size;
  final List<int> _toBlueGoal;
  final List<int> _toRedGoal;

  static List<int> _distances(GameState state, PlayerId player) {
    final size = state.boardConfig.size;
    final goalRow = player == PlayerId.blue
        ? state.boardConfig.blueGoalRow
        : state.boardConfig.redGoalRow;
    final board = BlockedEdges.fromWalls(state.walls, size);
    final dist = List<int>.filled(size * size, -1);
    final queue = Queue<Cell>();
    for (var column = 0; column < size; column++) {
      dist[goalRow * size + column] = 0;
      queue.add(Cell(row: goalRow, column: column));
    }
    while (queue.isNotEmpty) {
      final cell = queue.removeFirst();
      final next = dist[cell.row * size + cell.column] + 1;
      for (final neighbor in board.neighborsOf(cell)) {
        if (board.isBlocked(cell, neighbor)) continue;
        final index = neighbor.row * size + neighbor.column;
        if (dist[index] != -1) continue;
        dist[index] = next;
        queue.add(neighbor);
      }
    }
    return dist;
  }

  List<int> _field(PlayerId player) =>
      player == PlayerId.blue ? _toBlueGoal : _toRedGoal;

  /// The route length for [player] standing on [cell] — exactly
  /// [Pathfinder.shortestRouteLength]'s answer, with [AiEvaluator]'s
  /// size fallback for a sealed cell (unreachable in legal play).
  int routeFrom(Cell cell, PlayerId player) {
    final d = _field(player)[cell.row * size + cell.column];
    return d < 0 ? size : d;
  }

  /// Whether a wall with the given orientation and anchor could
  /// lengthen [player]'s shortest route from the position these
  /// fields were built for. Conservative: any doubt (an unreachable
  /// cell beside the wall) answers true, and the caller recomputes
  /// exactly.
  bool wallMayLengthen(
    WallOrientation orientation,
    int anchorRow,
    int anchorColumn,
    PlayerId player,
  ) {
    final field = _field(player);
    bool descends(int r1, int c1, int r2, int c2) {
      final a = field[r1 * size + c1];
      final b = field[r2 * size + c2];
      if (a < 0 || b < 0) return true;
      return (a - b).abs() == 1;
    }

    final r = anchorRow;
    final c = anchorColumn;
    if (orientation == WallOrientation.h) {
      return descends(r, c, r + 1, c) || descends(r, c + 1, r + 1, c + 1);
    }
    return descends(r, c, r, c + 1) || descends(r + 1, c, r + 1, c + 1);
  }
}

/// Depth-limited negamax search over the domain's own legal-action API.
///
/// Follows the `architecture.md` §9 pipeline exactly:
///
/// ```text
/// Current State -> Generate legal actions -> Evaluate actions
///              -> Choose action -> Apply through Game Engine
/// ```
///
/// Legality is never re-implemented. Candidates come from
/// [GameEngine.legalActions], which is the validated set, and the chosen action
/// is re-applied through [GameEngine.apply], so an AI action can never bypass
/// the rules — the v2.0.0 crossing rule included.
///
/// Determinism: no randomness, no clock, no time budget. The candidate
/// shortlist is ordered by (score descending, canonical index ascending), so the
/// same position and difficulty always yield the same action.
class AiOpponent {
  const AiOpponent._();

  /// Score penalty for moving straight back into the cell just vacated.
  ///
  /// Not a game rule — purely an AI tie-break, and the reason matches terminate
  /// at all. `game_spec.md` Q-01 (a draw/repetition rule) is still Unresolved,
  /// so the engine legitimately allows a position to repeat forever.
  ///
  /// Two failure modes showed up while building this, and they need different
  /// fixes:
  ///
  /// 1. *Local minimum / two-cell shuffle.* Once a detour exists, every move out
  ///    of the best cell can worsen the route while passing is still illegal, so
  ///    a route-greedy search oscillates between two cells forever. Fixed here
  ///    by refusing to step straight back into the square just vacated, which
  ///    breaks every two-cycle by construction.
  /// 2. *Symmetric penalties don't discriminate.* Both a 6-cell recent-visit
  ///    window and a whole-game taboo set were tried first and both failed on the
  ///    same game: when the pawn is down to two legal moves and **both** are
  ///    already visited, every candidate carries the same penalty, the ranking is
  ///    unchanged, and the shuffle continues. The penalty therefore has to be
  ///    asymmetric — exactly one square, the one just left — and a *set* of
  ///    previously visited cells cannot work, especially on a cluttered board
  ///    where the pawn has legitimately passed through most of them.
  ///
  /// The penalty is soft: if a wall forces the pawn back the way it came, that
  /// remains the best available legal move and play continues.
  /// Score penalty for recreating a position that has already occurred.
  ///
  /// Not a game rule — purely an AI guard, and the reason matches reliably
  /// terminate. `game_spec.md` Q-01 (a draw/repetition rule) is still
  /// Unresolved, so the engine legitimately allows a position to repeat forever,
  /// and nothing forces a game to end. A heuristic evaluator alone does not
  /// guarantee termination: three separate mechanisms were tried and each fixed
  /// one observed loop while another survived.
  ///
  /// 1. *Route-greedy only.* Both sides oscillated vertically, then sideways,
  ///    then in three-cell loops, forever.
  /// 2. *Penalise the cell just vacated* ([backtrackPenalty]). This killed every
  ///    two-cell loop, and the survivors were three-cell loops that stepped out
  ///    and back without ever immediately reversing.
  /// 3. *Penalise a symmetric set of previously visited cells.* This failed
  ///    outright: in a cluttered endgame the pawn often has only two or three
  ///    legal moves and **all** of them are already visited, so every candidate
  ///    took the same penalty, nothing was discriminated, and the loop continued.
  ///
  /// Keying on the whole *position* rather than on cells is what makes this
  /// work. In any cycle the positions repeat exactly, so precisely the action
  /// that closes the loop is penalised and the pawn is pushed onto the other
  /// branch. Because R-PATH-01 guarantees a route to the goal always exists, a
  /// route-following walk is finite, so there is always a non-repeating action
  /// available and the penalty can never trap the pawn.
  /// Score penalty for moving straight back into the cell just vacated.
  ///
  /// A cheap first line of defence that keeps the pawn from dithering on the
  /// spot. Position-level repetition handling in [_shortlist] is the real
  /// loop guard; this one just makes the common two-cell case obvious and is
  /// cheaper to reason about.
  static const double backtrackPenalty = 2.0;

  /// A compact, stable key for a game position.
  ///
  /// Only the parts that define the position are included: both pawn cells, the
  /// wall set and whose turn it is. Used to detect a repeated position; it is an
  /// AI-internal detail and is not a game rule.
  static String positionKey(GameState state) {
    final walls =
        state.walls
            .map(
              (w) =>
                  '${w.orientation.name[0]}${w.anchorRow},${w.anchorColumn},${w.owner.name[0]}',
            )
            .toList()
          ..sort();
    return '${state.pawnPosition(PlayerId.blue)}|'
        '${state.pawnPosition(PlayerId.red)}|'
        '${state.currentPlayer.name}|${walls.join(';')}';
  }

  /// Smallest candidate width used at any interior node.
  ///
  /// Combined with [progressiveWidening] this keeps the search bounded: an
  /// Expert move costs roughly 12 + 72 + 288 node expansions rather than the
  /// ~1900 a flat 12-wide depth-3 tree would need, which is the difference
  /// between an AI that can be run from a Flutter `Timer` and one that cannot.
  static const int minBranchWidth = 4;

  /// The candidate width to use one level deeper than [width].
  static int progressiveWidening(int width) {
    final halved = width ~/ 2;
    return halved < minBranchWidth ? minBranchWidth : halved;
  }

  /// How many wall candidates an interior node examines.
  ///
  /// The root scans every legal action, because that is the decision that
  /// actually gets played. Interior nodes only have to *rank* replies, and each
  /// one otherwise pays the full ~10 ms of `GameEngine.legalActions` plus an
  /// apply and a two-BFS score for all 128 wall slots. Capping the wall scan
  /// (moves are always all scanned; there are at most four of them) keeps an
  /// Expert move near a second instead of several. The cap takes the canonically
  /// first wall slots, which are ordered row-major, so the sample stays spread
  /// across the board rather than clustered in one corner.
  static const int interiorWallScan = 16;

  /// Chooses [aiPlayer]'s action in [state], or null if the match is over.
  ///
  /// [previousCell] is the cell [aiPlayer] occupied on their own previous turn.
  ///
  /// [visitOrder] maps [positionKey] to the ply at which that position was last
  /// occupied, and is how the AI avoids replaying a position it has already been
  /// in. It is optional — the AI plays legal moves without it — but matches may
  /// then fail to terminate, because `game_spec.md` Q-01 leaves the draw /
  /// repetition rule Unresolved and the engine therefore allows a position to
  /// repeat forever.
  ///
  /// The returned action is guaranteed to be accepted by
  /// `GameEngine.validate(state, aiPlayer, action)`.
  static GameAction? chooseAction(
    GameState state,
    AiDifficulty difficulty,
    PlayerId aiPlayer, {
    Cell? previousCell,
    Map<String, int> visitOrder = const {},
  }) {
    if (state.status == GameStatus.finished) return null;

    // Only the side to move can act, and the AI is only ever asked on its turn.
    if (state.currentPlayer != aiPlayer) return null;

    final root = _shortlist(
      state,
      aiPlayer,
      difficulty.candidateWidth,
      previousCell,
      visitOrder,
    );
    if (root.isEmpty) return null;

    var best = root.first;
    var bestScore = double.negativeInfinity;

    for (final candidate in root) {
      // Alpha-beta at the root: each later candidate only has to
      // prove it beats the current best, so its subtree is searched
      // with beta = -bestScore. A candidate is adopted only when the
      // returned value lies strictly inside the window, where
      // fail-soft alpha-beta is exact — so the chosen action and the
      // tie-breaking are identical to a full-window search (proven by
      // the Phase 16 choices fixture).
      final value = -_search(
        candidate.next,
        difficulty.searchDepth - 1,
        difficulty.candidateWidth,
        double.negativeInfinity,
        -bestScore,
      );
      if (value > bestScore) {
        bestScore = value;
        best = candidate;
      }
    }

    return best.action;
  }

  /// The asynchronous twin of [chooseAction] (Phase 15): identical
  /// shortlist, identical per-candidate search, identical tie-breaking —
  /// the only difference is that it yields to the event loop between
  /// root candidates, so a long Expert search no longer blocks the UI
  /// thread for its full duration (Q-5.3's "run on a timer so no frame
  /// blocks" was wrong: a timer delays the start of synchronous work,
  /// it does not make it non-blocking). The chosen action is the same
  /// one [chooseAction] returns for the same position and difficulty;
  /// the Phase 15 determinism corpus proves that on seeded positions
  /// for every difficulty.
  static Future<GameAction?> chooseActionAsync(
    GameState state,
    AiDifficulty difficulty,
    PlayerId aiPlayer, {
    Cell? previousCell,
    Map<String, int> visitOrder = const {},
  }) async {
    if (state.status == GameStatus.finished) return null;
    if (state.currentPlayer != aiPlayer) return null;

    final root = _shortlist(
      state,
      aiPlayer,
      difficulty.candidateWidth,
      previousCell,
      visitOrder,
    );
    if (root.isEmpty) return null;

    var best = root.first;
    var bestScore = double.negativeInfinity;

    for (final candidate in root) {
      // One yield per root candidate: frames, input and timers run
      // between candidate evaluations instead of after all of them.
      await Future<void>.delayed(Duration.zero);
      // Same alpha-beta window discipline as chooseAction.
      final value = -_search(
        candidate.next,
        difficulty.searchDepth - 1,
        difficulty.candidateWidth,
        double.negativeInfinity,
        -bestScore,
      );
      if (value > bestScore) {
        bestScore = value;
        best = candidate;
      }
    }

    return best.action;
  }

  /// Negamax value of [state] **for the player to move in it**.
  ///
  /// One recursion serves both sides because the sign flips each ply, so the
  /// leaf score must be taken from the side-to-move's point of view. (An earlier
  /// version scored leaves from the AI's fixed perspective and negated that at
  /// the root, which made the AI maximise the *opponent's* score and therefore
  /// pick its worst move at every depth.)
  static double _search(
    GameState state,
    int depth,
    int candidateWidth,
    double alpha,
    double beta,
  ) {
    final mover = state.currentPlayer;

    if (state.status == GameStatus.finished) {
      return state.winner == mover
          ? AiEvaluator.winScore
          : AiEvaluator.lossScore;
    }
    if (depth <= 0) {
      return AiEvaluator.score(state, mover);
    }

    final candidates = _shortlist(
      state,
      mover,
      candidateWidth,
      null,
      const {},
      interiorWallScan,
    );
    if (candidates.isEmpty) {
      // R-NOLEGAL-01 guarantees a legal action exists while a match is in
      // progress; this only guards a hand-built state.
      return AiEvaluator.score(state, mover);
    }

    var best = double.negativeInfinity;
    for (final candidate in candidates) {
      final double value;
      if (depth == 1) {
        // The child is a leaf: its value is its static score, whose
        // two route lengths are exactly the pair _shortlist already
        // computed for this candidate (Phase 16) — no second
        // pathfinding pass per leaf.
        value = -_leafScore(candidate, state, mover);
      } else {
        value = -_search(
          candidate.next,
          depth - 1,
          progressiveWidening(candidateWidth),
          -beta,
          -alpha,
        );
      }
      if (value > best) best = value;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break; // the opponent will not allow this line
    }
    return best;
  }

  /// [AiEvaluator.score] of [candidate]'s position from the point of
  /// view of the player to move in it (the opponent of [mover]),
  /// reusing the candidate's route lengths. The opponent's pawn and
  /// wall count do not change during [mover]'s action, so their terms
  /// come from [state] directly.
  static double _leafScore(
    _Candidate candidate,
    GameState state,
    PlayerId mover,
  ) {
    final next = candidate.next;
    final opponent = mover.opponent;
    if (next.status == GameStatus.finished) {
      // Only the mover's action can finish a match, so the side to
      // move in [next] has lost.
      return AiEvaluator.lossScore;
    }
    return -AiEvaluator.progressWeight * AiEvaluator.progress(next, opponent) -
        AiEvaluator.ownRouteWeight * candidate.routeOpponent +
        AiEvaluator.opponentRouteWeight * candidate.routeMover -
        AiEvaluator.wallCost * AiEvaluator.wallsOwnedBy(state, opponent);
  }

  /// [AiEvaluator.score] with the two route lengths supplied instead
  /// of recomputed — arithmetically the same expression.
  static double _staticScore(
    GameState state,
    PlayerId player,
    int ownRoute,
    int opponentRoute,
  ) {
    if (AiEvaluator.hasImmediateWin(state, player)) {
      return AiEvaluator.winScore;
    }
    if (AiEvaluator.hasImmediateLoss(state, player)) {
      return AiEvaluator.lossScore;
    }
    return -AiEvaluator.progressWeight * AiEvaluator.progress(state, player) -
        AiEvaluator.ownRouteWeight * ownRoute +
        AiEvaluator.opponentRouteWeight * opponentRoute -
        AiEvaluator.wallCost * AiEvaluator.wallsOwnedBy(state, player);
  }

  /// The exact route length for [player] in [state], via the domain
  /// pathfinder, with [AiEvaluator]'s size fallback.
  static int _exactRoute(GameState state, PlayerId player) =>
      Pathfinder.shortestRouteLength(
        from: state.pawnPosition(player),
        goalRow: player == PlayerId.blue
            ? state.boardConfig.blueGoalRow
            : state.boardConfig.redGoalRow,
        walls: state.walls,
        size: state.boardConfig.size,
      ) ??
      state.boardConfig.size;

  /// The top [width] legal actions for the side to move, best first.
  ///
  /// Every candidate is produced by [GameEngine.apply], so each [GameState] here
  /// is a genuine engine state — no rule logic is duplicated. Ranking uses only
  /// the depth-0 evaluation, which is what makes a wider shortlist a strict
  /// superset of a narrower one at the same depth.
  static List<_Candidate> _shortlist(
    GameState state,
    PlayerId mover,
    int width, [
    Cell? tabooCell,
    Map<String, int> visitOrder = const {},
    int? wallScanLimit,
  ]) {
    final legal = GameEngine.legalActions(state);
    if (legal.isEmpty) return const [];

    // Phase 16: two BFS for the whole node, then O(1) route answers
    // per candidate (see _GoalFields). The scores produced are
    // identical to AiEvaluator.score's; only the recomputation is gone.
    final fields = _GoalFields(state);
    final parentRouteMover = fields.routeFrom(state.pawnPosition(mover), mover);
    final parentRouteOpponent = fields.routeFrom(
      state.pawnPosition(mover.opponent),
      mover.opponent,
    );

    final scored =
        <({_Candidate candidate, double score, int order, int lastSeen})>[];
    var wallsScanned = 0;
    for (var i = 0; i < legal.length; i++) {
      final action = legal[i];
      if (action is WallAction) {
        if (wallScanLimit != null && wallsScanned >= wallScanLimit) continue;
        wallsScanned++;
      }
      final result = GameEngine.apply(state, mover, action);
      if (result is! SuccessResult) continue;
      final next = result.state;
      final int routeMover;
      final int routeOpponent;
      if (action is MoveAction) {
        routeMover = fields.routeFrom(next.pawnPosition(mover), mover);
        routeOpponent = parentRouteOpponent;
      } else if (action is WallAction) {
        routeMover =
            fields.wallMayLengthen(
              action.orientation,
              action.anchor.row,
              action.anchor.column,
              mover,
            )
            ? _exactRoute(next, mover)
            : parentRouteMover;
        routeOpponent =
            fields.wallMayLengthen(
              action.orientation,
              action.anchor.row,
              action.anchor.column,
              mover.opponent,
            )
            ? _exactRoute(next, mover.opponent)
            : parentRouteOpponent;
      } else {
        routeMover = _exactRoute(next, mover);
        routeOpponent = _exactRoute(next, mover.opponent);
      }
      // Score each candidate exactly once. Recomputing the score inside the
      // comparator costs two BFS per comparison, which measured ~3x slower than
      // caching it.
      var score = _staticScore(next, mover, routeMover, routeOpponent);
      if (next.pawnPosition(mover) == tabooCell) {
        score -= backtrackPenalty;
      }
      final lastSeen = visitOrder[positionKey(next)];
      scored.add((
        candidate: (
          action: action,
          next: next,
          routeMover: routeMover,
          routeOpponent: routeOpponent,
        ),
        score: score,
        order: i,
        // -1 means "never seen", which must outrank any previously seen ply.
        lastSeen: lastSeen ?? -1,
      ));
    }
    if (scored.isEmpty) return const [];

    // Deterministic ordering, and the loop guard.
    //
    // Repetition is handled as a *ranking* rule rather than a score penalty,
    // because a penalty cannot work: in a cluttered endgame the pawn often has
    // only two or three legal moves and all of them recreate a position already
    // seen, so every candidate takes the same penalty, nothing is discriminated
    // and the loop continues (observed on Hard self-play, 9x9). Ranking by
    // "unseen first" always finds the way out when one exists, and only when
    // every move repeats does it fall back to score — preferring the position
    // seen longest ago, which walks the cycle in reverse and escapes it.
    scored.sort((a, b) {
      final aSeen = a.lastSeen >= 0;
      final bSeen = b.lastSeen >= 0;
      if (aSeen != bSeen) return aSeen ? 1 : -1; // unseen first
      if (aSeen && a.lastSeen != b.lastSeen) {
        return a.lastSeen.compareTo(b.lastSeen); // least recently seen first
      }
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.order.compareTo(b.order);
    });

    final kept = scored.length <= width ? scored : scored.sublist(0, width);
    return [for (final entry in kept) entry.candidate];
  }
}
