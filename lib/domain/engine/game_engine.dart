import '../models/action_failure.dart';
import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall.dart';
import '../models/wall_orientation.dart';
import 'action_validator.dart';
import 'pathfinder.dart';

/// Core game engine: applies actions and transitions state.
///
/// Mirrors spec §6 (state transitions) and §14 (apply actions).
class GameEngine {
  /// Validates and applies [action] to [state].
  ///
  /// Returns the new state on success, or the structured failure.
  static ({GameState state, ActionFailure? failure}) applyAction(
    GameState state,
    GameAction action,
  ) {
    final failure = ActionValidator.validate(state, action);
    if (failure != null) {
      return (state: state, failure: failure);
    }

    final GameState newState;
    if (action is MoveAction) {
      newState = _applyMove(state, action.target);
    } else if (action is JumpAction) {
      newState = _applyJump(state, action.target);
    } else if (action is PlaceWallAction) {
      newState = _applyPlaceWall(state, action.origin, action.orientation);
    } else {
      newState = state;
    }

    return (state: newState, failure: null);
  }

  static GameState _applyMove(GameState state, Cell target) {
    final updated = state.activePlayer == PlayerId.blue
        ? state.copyWith(bluePawn: target)
        : state.copyWith(redPawn: target);
    final switched = updated.copyWith(
      activePlayer: state.activePlayer.opponent,
      moveCount: state.moveCount + 1,
    );
    return _checkWin(switched);
  }

  static GameState _applyJump(GameState state, Cell target) {
    final updated = state.activePlayer == PlayerId.blue
        ? state.copyWith(bluePawn: target)
        : state.copyWith(redPawn: target);
    final switched = updated.copyWith(
      activePlayer: state.activePlayer.opponent,
      moveCount: state.moveCount + 1,
    );
    return _checkWin(switched);
  }

  static GameState _applyPlaceWall(
    GameState state,
    Cell origin,
    WallOrientation orientation,
  ) {
    final newWall = Wall(origin: origin, orientation: orientation);
    final newWalls = [...state.walls, newWall];
    final newBlueRemaining = state.activePlayer == PlayerId.blue
        ? state.blueWallsRemaining - 1
        : state.blueWallsRemaining;
    final newRedRemaining = state.activePlayer == PlayerId.red
        ? state.redWallsRemaining - 1
        : state.redWallsRemaining;

    return state.copyWith(
      walls: newWalls,
      blueWallsRemaining: newBlueRemaining,
      redWallsRemaining: newRedRemaining,
      activePlayer: state.activePlayer.opponent,
      moveCount: state.moveCount + 1,
    );
  }

  /// Checks win conditions and returns updated state.
  ///
  /// Direct wins: Blue wins by reaching row H-1; Red wins by reaching row 0.
  /// Wall-blocking wins: if opponent can't reach their goal row.
  static GameState _checkWin(GameState state) {
    // Direct wins
    if (state.bluePawn.row == state.config.rows - 1) {
      return state.copyWith(status: GameStatus.blueWins);
    }
    if (state.redPawn.row == 0) {
      return state.copyWith(status: GameStatus.redWins);
    }

    // Wall-blocking wins
    if (!Pathfinder.canReachGoal(
      from: state.bluePawn,
      goalRow: state.config.rows - 1,
      walls: state.walls,
      cols: state.config.cols,
      rows: state.config.rows,
    )) {
      return state.copyWith(status: GameStatus.redWins);
    }

    if (!Pathfinder.canReachGoal(
      from: state.redPawn,
      goalRow: 0,
      walls: state.walls,
      cols: state.config.cols,
      rows: state.config.rows,
    )) {
      return state.copyWith(status: GameStatus.blueWins);
    }

    return state;
  }
}
