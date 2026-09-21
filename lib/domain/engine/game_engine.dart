import '../models/action_failure.dart';
import '../models/cell.dart';
import '../models/game_action.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/player_id.dart';
import '../models/wall.dart';
import 'action_validator.dart';
import 'move_generator.dart';

/// Core game engine: applies actions and transitions state.
///
/// Mirrors spec §6 (state transitions) and §3.3 (turn structure).
class GameEngine {
  /// Validates and applies [action] for [player] in [state].
  ///
  /// Returns an [ActionResult] with either the new state or the failure.
  static ActionResult apply(
    GameState state,
    PlayerId player,
    GameAction action,
  ) {
    final failure = ActionValidator.validate(state, player, action);
    if (failure != null) {
      return ActionResult.failure(failure);
    }

    // GameAction is sealed, so this switch is exhaustive and has no
    // unreachable fallback branch.
    final GameState applied = switch (action) {
      MoveAction(:final destination) => _applyMove(state, destination),
      WallAction() => _applyWall(state, player, action),
    };

    // Check win condition
    return ActionResult.success(_checkWin(applied));
  }

  /// All legal actions for the player whose turn it is, in canonical order.
  ///
  /// Returns an empty list when the match is finished. This is the public
  /// "what can I do now?" API; [MoveGenerator] remains the generator detail.
  static List<GameAction> legalActions(GameState state) =>
      MoveGenerator.generate(state, state.currentPlayer);

  static GameState _applyMove(GameState state, Cell destination) {
    final player = state.currentPlayer;
    final newPositions = Map<PlayerId, Cell>.from(state.pawnPositions);
    newPositions[player] = destination;

    return state.copyWith(
      pawnPositions: newPositions,
      turnNumber: state.turnNumber + 1,
    );
  }

  static GameState _applyWall(
    GameState state,
    PlayerId player,
    WallAction action,
  ) {
    final newWall = Wall(
      anchorRow: action.anchor.row,
      anchorColumn: action.anchor.column,
      orientation: action.orientation,
      owner: player,
    );
    final newWalls = [...state.walls, newWall];
    final newRemaining = Map<PlayerId, int>.from(state.remainingWalls);
    newRemaining[player] = newRemaining[player]! - 1;

    return state.copyWith(
      walls: newWalls,
      remainingWalls: newRemaining,
      turnNumber: state.turnNumber + 1,
    );
  }

  /// Checks win conditions and returns updated state.
  ///
  /// R-WIN-01: A player wins immediately upon reaching their goal row.
  /// R-WIN-02: Reaching any cell on the goal row is sufficient.
  /// R-WIN-05: Only reaching your OWN goal row wins.
  static GameState _checkWin(GameState state) {
    final bluePos = state.pawnPosition(PlayerId.blue);
    final redPos = state.pawnPosition(PlayerId.red);

    // Blue wins by reaching row 0
    if (bluePos.row == state.boardConfig.blueGoalRow) {
      return state.copyWith(status: GameStatus.finished, winner: PlayerId.blue);
    }

    // Red wins by reaching row size-1
    if (redPos.row == state.boardConfig.redGoalRow) {
      return state.copyWith(status: GameStatus.finished, winner: PlayerId.red);
    }

    return state;
  }

  /// Convenience: apply a list of actions in sequence.
  ///
  /// Returns the final state and a list of failures (one per failed action).
  /// Stops on the first failure.
  static ({GameState state, List<ActionFailure> failures}) applyActions(
    GameState initial,
    List<(PlayerId, GameAction)> actions,
  ) {
    var state = initial;
    final failures = <ActionFailure>[];
    for (final (player, action) in actions) {
      final result = apply(state, player, action);
      if (result is SuccessResult) {
        state = result.state;
      } else if (result is FailureResult) {
        failures.add(result.failure);
        break;
      }
    }
    return (state: state, failures: failures);
  }
}

/// Result of applying an action.
sealed class ActionResult {
  const ActionResult._();

  factory ActionResult.success(GameState state) = SuccessResult;
  factory ActionResult.failure(ActionFailure failure) = FailureResult;
}

/// Successful action result.
class SuccessResult extends ActionResult {
  const SuccessResult(this.state) : super._();

  /// The new game state.
  final GameState state;
}

/// Failed action result.
class FailureResult extends ActionResult {
  const FailureResult(this.failure) : super._();

  /// The reason the action was rejected.
  final ActionFailure failure;
}
