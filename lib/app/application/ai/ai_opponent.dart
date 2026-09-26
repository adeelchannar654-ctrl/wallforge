import '../../../domain/engine/game_engine.dart';
import '../../../domain/models/cell.dart';
import '../../../domain/models/game_action.dart';
import '../../../domain/models/game_state.dart';
import '../../../domain/models/player_id.dart';
import 'ai_difficulty.dart';
import '../../../domain/models/game_status.dart';
import 'ai_evaluator.dart';

/// A candidate action together with the position it leads to.
typedef _Candidate = ({GameAction action, GameState next});

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
/// the rules â€” the v2.0.0 crossing rule included.
///
/// Determinism: no randomness, no clock, no time budget. The candidate
/// shortlist is ordered by (score descending, canonical index ascending), so the
/// same position and difficulty always yield the same action.
class AiOpponent {
  const AiOpponent._();

  /// Score penalty for moving straight back into the cell just vacated.
  ///
  /// Not a game rule â€” purely an AI tie-break, and the reason matches terminate
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
  ///    asymmetric â€” exactly one square, the one just left â€” and a *set* of
  ///    previously visited cells cannot work, especially on a cluttered board
  ///    where the pawn has legitimately passed through most of them.
  ///
  /// The penalty is soft: if a wall forces the pawn back the way it came, that
  /// remains the best available legal move and play continues.
  /// Score penalty for recreating a position that has already occurred.
  ///
  /// Not a game rule â€” purely an AI guard, and the reason matches reliably
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
  /// in. It is optional â€” the AI plays legal moves without it â€” but matches may
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
      final value = -_search(
        candidate.next,
        difficulty.searchDepth - 1,
        difficulty.candidateWidth,
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
  static double _search(GameState state, int depth, int candidateWidth) {
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
      final value = -_search(
        candidate.next,
        depth - 1,
        progressiveWidening(candidateWidth),
      );
      if (value > best) best = value;
    }
    return best;
  }

  /// The top [width] legal actions for the side to move, best first.
  ///
  /// Every candidate is produced by [GameEngine.apply], so each [GameState] here
  /// is a genuine engine state â€” no rule logic is duplicated. Ranking uses only
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
      // Score each candidate exactly once. Recomputing the score inside the
      // comparator costs two BFS per comparison, which measured ~3x slower than
      // caching it.
      var score = AiEvaluator.score(next, mover);
      if (next.pawnPosition(mover) == tabooCell) {
        score -= backtrackPenalty;
      }
      final lastSeen = visitOrder[positionKey(next)];
      scored.add((
        candidate: (action: action, next: next),
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
