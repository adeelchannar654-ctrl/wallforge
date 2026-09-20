import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/player_id.dart';
import '../models/wall_orientation.dart';
import 'action_validator.dart';

/// Generates all legal actions for a player in a given state.
///
/// Candidate order matches the oracle generator exactly (spec §3.10):
/// 1. On-board moves in (row, column) ascending
/// 2. Off-board moves: (-1,0), (0,-1), (n,0), (0,n), (-1,-1), (n,n)
/// 3. Wall H anchors (0..n-1) row-major
/// 4. Wall V anchors (0..n-1) row-major
/// 5. Extra invalid walls: H(-1,0), V(0,-1)
class MoveGenerator {
  /// Returns all legal actions for [player] in [state].
  static List<GameAction> generate(GameState state, PlayerId player) {
    final actions = <GameAction>[];
    final size = state.boardConfig.size;

    for (final candidate in _allCandidates(size)) {
      final action = _candidateToAction(candidate);
      if (ActionValidator.validate(state, player, action) == null) {
        actions.add(action);
      }
    }

    return actions;
  }

  /// Returns all candidate actions in canonical order (including invalid ones).
  ///
  /// This matches the oracle generator's `candidates(n)` function.
  static List<({String kind, int r, int c, WallOrientation? orient})>
      _allCandidates(int n) {
    final cands = <({String kind, int r, int c, WallOrientation? orient})>[];

    // On-board moves row-major
    for (var r = 0; r < n; r++) {
      for (var cc = 0; cc < n; cc++) {
        cands.add((kind: 'move', r: r, c: cc, orient: null));
      }
    }
    // Off-board moves
    for (final (r, c) in [(-1, 0), (0, -1), (n, 0), (0, n), (-1, -1), (n, n)]) {
      cands.add((kind: 'move', r: r, c: c, orient: null));
    }
    // Wall H row-major (0..n-1), then V row-major (0..n-1)
    for (final orient in [WallOrientation.h, WallOrientation.v]) {
      for (var r = 0; r < n; r++) {
        for (var cc = 0; cc < n; cc++) {
          cands.add((kind: 'wall', r: r, c: cc, orient: orient));
        }
      }
    }
    // Extra invalid walls
    cands.add((kind: 'wall', r: -1, c: 0, orient: WallOrientation.h));
    cands.add((kind: 'wall', r: 0, c: -1, orient: WallOrientation.v));

    return cands;
  }

  /// Converts a candidate tuple to a GameAction.
  static GameAction _candidateToAction(
    ({String kind, int r, int c, WallOrientation? orient}) cand,
  ) {
    if (cand.kind == 'move') {
      return GameAction.move(Cell(row: cand.r, column: cand.c));
    } else {
      return GameAction.wall(
        orientation: cand.orient!,
        anchor: Cell(row: cand.r, column: cand.c),
      );
    }
  }
}
