import 'package:flutter/foundation.dart';

import '../../domain/engine/game_engine.dart';
import '../../domain/models/action_failure.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/game_action.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/wall_orientation.dart';

/// Interaction mode for the board.
///
/// Extracted from `local_game_controller.dart` in Phase 9 so the online
/// controller shares the *same* type rather than declaring a second one: a
/// board that toggles to a differently-named wall mode per client would be an
/// invitation to drift.
enum InteractionMode {
  /// Tap a highlighted cell to move.
  move,

  /// Tap a wall slot to place a wall.
  wall,
}

/// The board-interaction layer shared by the local and online controllers.
///
/// ## Why this exists
///
/// `LocalGameController` mixed two unrelated concerns: *board interaction*
/// (which mode is active, which cell is selected, which wall is pending
/// confirmation, which failure to show) and *what happens to the action*
/// (apply it locally, or send it to a server). Phase 9 needs the first without
/// the second, and copying it would mean two implementations of the same
/// selection and confirm-gate logic that could drift apart.
///
/// So the interaction state and its transitions live here, and each controller
/// supplies only an [attemptAction] sink. Nothing about game rules is in this
/// file: every legality question still goes through [GameEngine], which is the
/// only place `rules.md` permits such logic.
///
/// The gate is [isInputEnabled], which a controller can override to refuse input
/// for reasons of its own — the online controller refuses while it is not this
/// player's turn, or while reconnecting.
mixin GameInteraction on ChangeNotifier {
  InteractionMode _mode = InteractionMode.move;
  Cell? _selectedCell;
  ({Cell anchor, WallOrientation orientation})? _pendingWall;
  ActionFailure? _lastFailure;

  /// The live board state. Supplied by the host controller.
  GameState get interactionState;

  /// Whether the player may currently act.
  ///
  /// True by default, so `LocalGameController`'s behaviour is unchanged.
  bool get isInputEnabled =>
      interactionState.status == GameStatus.inProgress && !isInteractionBlocked;

  /// An extra reason to refuse input, beyond the match being in progress.
  ///
  /// False by default. The online controller sets it while it is not this
  /// player's turn, submitting, reconnecting, or desynchronised.
  bool get isInteractionBlocked => false;

  /// Sends [action] to wherever it goes.
  ///
  /// Returns the engine's failure, or null when the action was accepted. The
  /// local controller applies it to its own state and returns null; the online
  /// controller submits it to the server and may return a failure the server
  /// reported.
  ActionFailure? attemptAction(GameAction action);

  /// Called after an accepted move, so a controller can run its own follow-up
  /// (persistence, result display, scheduling the AI).
  void onActionApplied() {}

  // --- Interaction state -----------------------------------------------------

  /// The active mode.
  InteractionMode get mode => _mode;

  /// The cell the player last tapped in move mode, or null.
  Cell? get selectedCell => _selectedCell;

  /// The wall awaiting confirmation, or null.
  ({Cell anchor, WallOrientation orientation})? get pendingWall => _pendingWall;

  /// The most recent interaction failure, or null.
  ActionFailure? get lastFailure => _lastFailure;

  /// Whether the pending wall is legal in the current state.
  ///
  /// Read by the board to grey out an invalid ghost. Delegates to the engine, so
  /// the preview and the eventual application can never disagree.
  ActionFailure? get pendingWallFailure {
    final pending = _pendingWall;
    if (pending == null) return null;
    return GameEngine.validate(
      interactionState,
      interactionState.currentPlayer,
      GameAction.wall(orientation: pending.orientation, anchor: pending.anchor),
    );
  }

  /// Whether wall placement is confirmed before it is applied.
  bool get confirmWallPlacement => _confirmWallPlacement;
  bool _confirmWallPlacement = true;

  /// The legal move destinations, empty unless it is this player's move.
  Set<Cell> get legalMoveTargets {
    if (_mode != InteractionMode.move) return {};
    if (!isInputEnabled) return {};
    return GameEngine.legalActions(interactionState)
        .whereType<MoveAction>()
        .map((a) => a.destination)
        .toSet();
  }

  /// Resets the transient interaction state, e.g. when a new match starts.
  void resetInteraction() {
    _mode = InteractionMode.move;
    _selectedCell = null;
    _pendingWall = null;
    _lastFailure = null;
  }

  // --- Interactions ----------------------------------------------------------

  /// Switches mode without notifying, for a caller that is about to notify.
  ///
  /// Split out from [setMode] so the AI path — which switches mode, applies, and
  /// then notifies once — does not emit an extra intermediate frame.
  void interactionSetMode(InteractionMode mode) {
    if (interactionState.status == GameStatus.finished) return;
    _mode = mode;
    _selectedCell = null;
    _pendingWall = null;
    _lastFailure = null;
  }

  /// Switch between move and wall mode.
  void setMode(InteractionMode mode) {
    if (interactionState.status == GameStatus.finished) return;
    interactionSetMode(mode);
    notifyListeners();
  }

  /// Toggle whether a wall is confirmed before it is placed.
  void toggleConfirmWallPlacement() {
    if (interactionState.status == GameStatus.finished) return;
    _confirmWallPlacement = !_confirmWallPlacement;
    notifyListeners();
    onConfirmWallPlacementToggled();
  }

  /// Sets the confirm gate from a stored setting, without persisting it back.
  ///
  /// Loading a saved value must not immediately write it, or every app start
  /// would cost a write for no reason (`rules.md` §5: write only meaningful
  /// changes).
  void setConfirmWallPlacementSilently(bool value) {
    if (_confirmWallPlacement == value) return;
    _confirmWallPlacement = value;
    notifyListeners();
  }

  /// Hook for a controller that persists the confirm setting.
  void onConfirmWallPlacementToggled() {}

  /// Tap a cell on the board.
  ///
  /// In move mode this offers a pawn move to [cell] to [attemptAction]; the
  /// engine decides whether it is legal. In wall mode it is ignored, because
  /// walls are placed with [tapWallSlot].
  void tapCell(Cell cell) {
    if (!isInputEnabled) return;
    _lastFailure = null;
    if (_mode != InteractionMode.move) return;

    _selectedCell = cell;
    final failure = attemptAction(GameAction.move(cell));
    if (failure == null) {
      _selectedCell = null;
      _mode = InteractionMode.move;
      onActionApplied();
    } else {
      _lastFailure = failure;
    }
    notifyListeners();
  }

  /// Tap a wall slot on the board.
  ///
  /// With confirmation on, this only stages the wall; with it off, the wall is
  /// offered to [attemptAction] immediately.
  void tapWallSlot(Cell anchor, WallOrientation orientation) {
    if (!isInputEnabled) return;
    _lastFailure = null;
    if (_mode != InteractionMode.wall) return;

    if (_confirmWallPlacement) {
      _pendingWall = (anchor: anchor, orientation: orientation);
      notifyListeners();
    } else {
      _applyWall(anchor, orientation);
    }
  }

  /// Confirm the staged wall.
  void confirm() {
    if (_pendingWall == null || pendingWallFailure != null) return;
    final pending = _pendingWall!;
    _pendingWall = null;
    _applyWall(pending.anchor, pending.orientation);
  }

  /// Discard the staged wall.
  void cancel() {
    if (interactionState.status == GameStatus.finished) return;
    _pendingWall = null;
    _lastFailure = null;
    notifyListeners();
  }

  void _applyWall(Cell anchor, WallOrientation orientation) {
    final failure = attemptAction(
      GameAction.wall(orientation: orientation, anchor: anchor),
    );
    _lastFailure = failure;
    if (failure == null) {
      _pendingWall = null;
      // Returns to move mode after a wall lands, which is what the Phase 4
      // local controller did and what the board's ghost preview assumes.
      interactionSetMode(InteractionMode.move);
      onActionApplied();
    }
    notifyListeners();
  }
}
