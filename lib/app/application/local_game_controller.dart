import 'dart:async';

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
import 'ai/ai_difficulty.dart';
import 'ai/ai_opponent.dart';

/// Interaction mode for the board.
enum InteractionMode {
  /// Tap a highlighted cell to move.
  move,

  /// Tap a wall slot to place a wall.
  wall,
}

/// How long the AI "thinks" before moving.
///
/// `design.md` §20 does not specify AI timing, so this is a recorded own
/// decision: an instant reply reads as a glitch, and a long pause reads as a
/// hang. A short, fixed delay is predictable and costs nothing.
const Duration kAiThinkDelay = Duration(milliseconds: 300);

/// The player the AI controls in a versus-AI match.
const PlayerId kAiPlayer = PlayerId.red;

/// Phase 4 application layer: local pass-and-play game controller.
///
/// Manages a single match between two human players sharing a screen.
/// Strictly ChangeNotifier-based per §2.3; no Flutter widget imports.
class LocalGameController extends ChangeNotifier {
  /// Creates a controller with an optional initial board config.
  ///
  /// Pass `versusAi: true` to play the offline AI opponent at [aiDifficulty].
  LocalGameController({
    BoardConfig config = const BoardConfig(),
    bool versusAi = false,
    AiDifficulty aiDifficulty = AiDifficulty.easy,
  }) {
    _state = GameState.initial(config);
    _versusAi = versusAi;
    _aiDifficulty = aiDifficulty;
    _recordAiPosition();
    // Blue always moves first (R-PLAYER-07), so the AI's first turn is
    // scheduled from the human's first action rather than here.
  }

  GameState _state = GameState.initial();
  InteractionMode _mode = InteractionMode.move;
  bool _confirmWallPlacement = true;
  Cell? _selectedCell;
  ({Cell anchor, WallOrientation orientation})? _pendingWall;
  ActionFailure? _lastFailure;
  bool _showingResult = false;

  /// Phase 5: optional offline AI opponent.
  bool _versusAi = false;
  AiDifficulty _aiDifficulty = AiDifficulty.easy;
  Timer? _aiTimer;

  /// The AI pawn's cell on its own previous turn, so it can avoid stepping
  /// straight back into it.
  Cell? _aiPreviousCell;

  /// Position keys already occupied this game, with the ply at which each was
  /// last seen. Lets the AI notice it is replaying a position.
  final Map<String, int> _aiVisitOrder = {};

  // --- Read-only getters ----------------------------------------------------

  GameState get state => _state;
  InteractionMode get mode => _mode;
  bool get confirmWallPlacement => _confirmWallPlacement;
  Cell? get selectedCell => _selectedCell;
  ({Cell anchor, WallOrientation orientation})? get pendingWall => _pendingWall;
  ActionFailure? get pendingWallFailure {
    final pending = _pendingWall;
    if (pending == null) return null;
    return GameEngine.validate(
      _state,
      _state.currentPlayer,
      GameAction.wall(orientation: pending.orientation, anchor: pending.anchor),
    );
  }

  ActionFailure? get lastFailure => _lastFailure;
  bool get showingResult => _showingResult;

  /// Whether this match is against the offline AI rather than pass-and-play.
  bool get versusAi => _versusAi;

  /// The difficulty the AI plays at.
  AiDifficulty get aiDifficulty => _aiDifficulty;

  /// True when it is the AI's turn to act, so the board is not waiting on a
  /// human.
  bool get isAiTurn =>
      _versusAi &&
      _state.status == GameStatus.inProgress &&
      _state.currentPlayer == kAiPlayer;

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
  void startMatch({
    BoardConfig config = const BoardConfig(),
    bool versusAi = false,
    AiDifficulty aiDifficulty = AiDifficulty.easy,
  }) {
    _state = GameState.initial(config);
    _mode = InteractionMode.move;
    _selectedCell = null;
    _pendingWall = null;
    _lastFailure = null;
    _showingResult = false;
    _versusAi = versusAi;
    _aiDifficulty = aiDifficulty;
    _aiPreviousCell = null;
    _aiVisitOrder.clear();
    _cancelAiTurn();
    _recordAiPosition();
    notifyListeners();
    _scheduleAiTurn();
  }

  /// Restart the current match with same config and the same opponent.
  void restart() {
    startMatch(
      config: _state.boardConfig,
      versusAi: _versusAi,
      aiDifficulty: _aiDifficulty,
    );
  }

  /// Start a rematch (same config, swap who goes first if desired).
  void rematch() {
    startMatch(
      config: _state.boardConfig,
      versusAi: _versusAi,
      aiDifficulty: _aiDifficulty,
    );
  }

  @override
  void dispose() {
    _cancelAiTurn();
    super.dispose();
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
    if (_state.status == GameStatus.finished) return;
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
      _recordAiPosition();
      notifyListeners();
      _scheduleAiTurn();
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
    if (_pendingWall == null || pendingWallFailure != null) return;
    _applyWall(_pendingWall!.anchor, _pendingWall!.orientation);
  }

  /// Cancel the pending wall placement.
  void cancel() {
    if (_state.status == GameStatus.finished) return;
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

  /// Remembers the AI pawn's current cell and position for loop avoidance.
  void _recordAiPosition() {
    if (!_versusAi) return;
    _aiPreviousCell ??= _state.pawnPosition(kAiPlayer);
    _aiVisitOrder[AiOpponent.positionKey(_state)] = _state.turnNumber;
  }

  void _cancelAiTurn() {
    _aiTimer?.cancel();
    _aiTimer = null;
  }

  /// Queues the AI's move when it is the AI's turn.
  ///
  /// The search runs on a timer rather than inline so a slow Expert search
  /// cannot block a frame, and so the UI shows whose turn it is first.
  void _scheduleAiTurn() {
    _cancelAiTurn();
    if (!isAiTurn) return;
    _aiTimer = Timer(kAiThinkDelay, () {
      _aiTimer = null;
      if (!isAiTurn) return;
      final action = AiOpponent.chooseAction(
        _state,
        _aiDifficulty,
        kAiPlayer,
        previousCell: _aiPreviousCell,
        visitOrder: _aiVisitOrder,
      );
      if (action == null) return;
      _playAiAction(action);
    });
  }

  /// Applies the AI's chosen action through the engine, exactly as a human
  /// action is applied. The AI never bypasses validation.
  void _playAiAction(GameAction action) {
    final player = _state.currentPlayer;
    final result = GameEngine.apply(_state, player, action);
    if (result is! SuccessResult) {
      // Unreachable: the action came from the validated legal-action set.
      _lastFailure = (result as FailureResult).failure;
      notifyListeners();
      return;
    }
    _aiPreviousCell = _state.pawnPosition(kAiPlayer);
    _state = result.state;
    _pendingWall = null;
    _lastFailure = null;
    if (_state.status == GameStatus.finished) {
      _showingResult = true;
    }
    _mode = InteractionMode.move;
    _recordAiPosition();
    notifyListeners();
    _scheduleAiTurn();
  }

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
    _recordAiPosition();
    notifyListeners();
    _scheduleAiTurn();
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
    // Retired in spec v2.0.0 (unreachable: crossing walls are legal). Kept so
    // this switch stays exhaustive over the declared taxonomy.
    ActionFailure.wallCrosses => 'Wall crosses an existing wall.',
    ActionFailure.wallBlocksPath =>
      'Wall would block a player\'s path to goal.',
  };
}
