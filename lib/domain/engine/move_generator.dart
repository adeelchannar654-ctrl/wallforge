import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall_orientation.dart';
import 'action_validator.dart';

/// Generates all legal actions for a player in a given state.
///
/// Canonical order matches the oracle generator exactly (spec §3.10):
/// 1. Moves in (row, column) ascending.
/// 2. Walls: all `H` anchors row-major, then all `V` anchors row-major.
///
/// [ActionValidator] remains the single source of truth for legality; this
/// class only prunes candidates that are provably illegal (off-board moves and
/// out-of-bounds / overlapping walls) before asking the validator.
/// Pruning is behaviour-preserving: every pruned candidate would have been
/// rejected by the validator for the same reason.
class MoveGenerator {
  /// Returns all legal actions for [player] in [state].
  static List<GameAction> generate(GameState state, PlayerId player) {
    // A finished match has no legal actions (§5.2.1).
    if (state.status == GameStatus.finished) return const [];

    return <GameAction>[
      ..._legalMoves(state, player),
      ..._legalWalls(state, player),
    ];
  }

  /// Legal destinations, iterated in row-major order.
  static List<GameAction> _legalMoves(GameState state, PlayerId player) {
    final size = state.boardConfig.size;
    final actions = <GameAction>[];
    for (var row = 0; row < size; row++) {
      for (var column = 0; column < size; column++) {
        final action = GameAction.move(Cell(row: row, column: column));
        if (ActionValidator.validate(state, player, action) == null) {
          actions.add(action);
        }
      }
    }
    return actions;
  }

  /// Legal wall anchors for the current inventory.
  static List<GameAction> _legalWalls(GameState state, PlayerId player) {
    if (state.wallsRemaining(player) <= 0) return const [];

    final size = state.boardConfig.size;
    final maxAnchor = size - 2;
    final actions = <GameAction>[];
    for (final orientation in [WallOrientation.h, WallOrientation.v]) {
      for (var row = 0; row <= maxAnchor; row++) {
        for (var column = 0; column <= maxAnchor; column++) {
          final action = GameAction.wall(
            orientation: orientation,
            anchor: Cell(row: row, column: column),
          );
          if (_overlaps(state, action as WallAction)) continue;
          if (ActionValidator.validate(state, player, action) == null) {
            actions.add(action);
          }
        }
      }
    }
    return actions;
  }

  /// True when [action] overlaps an existing wall of the **same** orientation.
  ///
  /// Mirrors the `wallOverlaps` check in [ActionValidator] so the two stay
  /// consistent. Same-anchor walls of the opposite orientation are **not**
  /// pruned: spec v2.0.0 (R-WALL-08) makes that shape legal, so those
  /// candidates must reach the validator and be offered to the player.
  static bool _overlaps(GameState state, WallAction action) {
    final row = action.anchor.row;
    final column = action.anchor.column;
    final orientation = action.orientation;
    for (final existing in state.walls) {
      if (existing.orientation != orientation) continue;
      if (orientation == WallOrientation.h) {
        if (existing.anchorRow == row &&
            (existing.anchorColumn - column).abs() <= 1) {
          return true;
        }
      } else {
        if (existing.anchorColumn == column &&
            (existing.anchorRow - row).abs() <= 1) {
          return true;
        }
      }
    }
    return false;
  }
}
