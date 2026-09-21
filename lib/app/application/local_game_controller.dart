import 'package:flutter/foundation.dart';

import '../../domain/engine/game_engine.dart';
import '../../domain/models/action_failure.dart';
import '../../domain/models/board_config.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/game_action.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player_id.dart';
import '../../domain/models/wall_orientation.dart';

/// Interaction mode for the board.
enum InteractionMode {
  /// Tap a highlighted cell to move.
  move,

  /// Tap a wall slot to place a wall.
  wall,
}

/// Phase 4 application layer: local pass-and-play game controller.
///
/// Manages a single match between two human players sharing a screen.
/// Strictly ChangeNotifier-based per §2.3; no Flutter widget imports.
class LocalGameController extends ChangeNotifier {
  /// Creates a controller with an optional initial board config.
  LocalGameController({BoardConfig config = const BoardConfig()}) {
    _state = GameState.initial(config);
  }

  GameState _state = GameState.initial();
  InteractionMode _mode = InteractionMode.move;
  bool _confirmWallPlacement = true;
  Cell? _selectedCell;
  ({Cell anchor, WallOrientation orientation})? _pendingWall;
  ActionFailure? _lastFailure;
  bool _showingResult = false;

  // --- Read-only getters ----------------------------------------------------

  GameState get state => _state;
  InteractionMode get mode => _mode;
  bool get confirmWallPlacement => _confirmWallPlacement;
  Cell? get selectedCell => _selectedCell;
  ({Cell anchor, WallOrientation orientation})? get pendingWall => _pendingWall;
  ActionFailure? get lastFailure => _lastFailure;
  bool get showingResult => _showingResult;

  PlayerId? get winner => _state.winner;
  bool get isFinished => _state.status == GameStatus.finished;
  PlayerId get currentPlayer => _state.currentPlayer;

  Set<Cell> get legalMoveTargets {
    if (_mode != InteractionMode.move) return {};
    if (_state.status == GameStatus.finished) return {};
    return GameEngine.legalActions(_state)
        .whereType<MoveAction>()
        .map((a) => a.destination)
        .toSet();
  }

  // --- Actions called by presentation ---------------------------------------

  /// Start a new match.
  void startMatch({BoardConfig config = const BoardConfig()}) {
    _state = GameState.initial(config);
    _mode = InteractionMode.move;
    _selectedCell = null;
    _pendingWall = null;
    _lastFailure = null;
    _showingResult = false;
    notifyListeners();
  }

  /// Restart the current match with same config.
  void restart() {
    startMatch(config: _state.boardConfig);
  }

  /// Start a rematch (same config, swap who goes first if desired).
  void rematch() {
    startMatch(config: _state.boardConfig);
  }

  /// Toggle between move and wall interaction modes.
  void setMode(InteractionMode mode) {
    if (_state.status == GameStatus.finished) return;
    _mode = mode;
    _selectedCell = null;
    _pendingWall = null;
    _lastFailure = null;
    notifyListeners();
  }

  /// Toggle the confirm-wall-placement setting.
  void toggleConfirmWallPlacement() {
    _confirmWallPlacement = !_confirmWallPlacement;
    notifyListeners();
  }

  /// Tap a cell on the board.
  ///
  /// In move mode: if the cell is a legal move target, apply the move.
  /// In wall mode: ignored (use tapWallSlot for wall placement).
  void tapCell(Cell cell) {
    if (_state.status == GameStatus.finished) return;
    _lastFailure = null;

    if (_mode == InteractionMode.move) {
      _selectedCell = cell;
      final action = GameAction.move(cell);
      final result = GameEngine.apply(_state, _state.currentPlayer, action);
      if (result is SuccessResult) {
        _state = result.state;
        _selectedCell = null;
        if (_state.status == GameStatus.finished) {
          _showingResult = true;
        }
        _mode = InteractionMode.move;
      } else if (result is FailureResult) {
        _lastFailure = result.failure;
      }
      notifyListeners();
    }
  }

  /// Tap a wall slot on the board.
  ///
  /// If confirm mode is off, places the wall immediately.
  /// If confirm mode is on, sets the pending wall for confirmation.
  void tapWallSlot(Cell anchor, WallOrientation orientation) {
    if (_state.status == GameStatus.finished) return;
    _lastFailure = null;

    if (_mode != InteractionMode.wall) return;

    if (_confirmWallPlacement) {
      _pendingWall = (anchor: anchor, orientation: orientation);
      notifyListeners();
    } else {
      _applyWall(anchor, orientation);
    }
  }

  /// Confirm the pending wall placement.
  void confirm() {
    if (_pendingWall != null) {
      _applyWall(_pendingWall!.anchor, _pendingWall!.orientation);
    }
  }

  /// Cancel the pending wall placement.
  void cancel() {
    _pendingWall = null;
    _lastFailure = null;
    notifyListeners();
  }

  /// Dismiss the result dialog.
  void dismissResult() {
    _showingResult = false;
    notifyListeners();
  }

  // --- Internal helpers -----------------------------------------------------

  void _applyWall(Cell anchor, WallOrientation orientation) {
    final action = GameAction.wall(orientation: orientation, anchor: anchor);
    final result = GameEngine.apply(_state, _state.currentPlayer, action);
    if (result is SuccessResult) {
      _state = result.state;
      _pendingWall = null;
      _lastFailure = null;
      if (_state.status == GameStatus.finished) {
        _showingResult = true;
      }
      _mode = InteractionMode.move;
    } else if (result is FailureResult) {
      _lastFailure = result.failure;
    }
    notifyListeners();
  }

  /// Returns a human-readable message for the given [failure].
  static String failureMessage(ActionFailure failure) => switch (failure) {
    ActionFailure.matchFinished => 'The game is already over.',
    ActionFailure.wrongTurn => "It's not your turn.",
    ActionFailure.moveOutOfBoard => 'You cannot move off the board.',
    ActionFailure.moveNotAdjacent => 'You can only move to an adjacent cell.',
    ActionFailure.moveBlockedByWall => 'A wall blocks that move.',
    ActionFailure.moveOntoPawn => 'You cannot move onto the opponent.',
    ActionFailure.moveIllegalJump => 'That jump is not allowed.',
    ActionFailure.noWallsRemaining => 'You have no walls left.',
    ActionFailure.wallOutOfBounds => 'Wall placement is out of bounds.',
    ActionFailure.wallOverlaps => 'Wall overlaps an existing wall.',
    ActionFailure.wallCrosses => 'Wall crosses an existing wall.',
    ActionFailure.wallBlocksPath =>
      'Wall would block a player\'s path to goal.',
  };
}
