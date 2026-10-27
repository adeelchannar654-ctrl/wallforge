import 'package:flutter/material.dart';

import '../../core/feedback/feedback_scope.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player_id.dart';
import '../../domain/models/wall_orientation.dart';
import 'board_animation.dart';
import 'board_geometry.dart';
import 'board_painter.dart';

/// A pure renderer that displays a Wallforge game board.
///
/// Takes a [GameState] and optional overlays. Contains no rules and never
/// mutates state. Interaction is delegated to optional callbacks.
///
/// Phase 12: the view is stateful so it can own a [BoardAnimator]. State
/// *transitions* between builds trigger the one-shot animations
/// `design.md` §7–§9 specify (pawn translation with landing bounce, wall
/// scale/opacity in, active-glow pulse on turn change, goal-strip pulse
/// on proximity and victory, selection-ring fade). The animation is
/// purely visual: [state] is always the source of truth, a transition
/// that skips a ply (resume, rematch, catch-up) animates nothing, and
/// under reduced motion every effect resolves instantly.
class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.state,
    this.legalMoveTargets = const {},
    this.pathCells = const [],
    this.wallPreview,
    this.selectedCell,
    this.showCoordinates = true,
    this.activeGlow,
    this.maxSize = 640,
    this.onCellTap,
    this.onWallSlotTap,
  });

  /// The game state to render.
  final GameState state;

  /// Cells to highlight as legal move destinations.
  final Set<Cell> legalMoveTargets;

  /// Movement-assistance route cells for the player to move (Phase 11),
  /// drawn as a dotted trail. Empty unless the setting is on and Move is
  /// selected.
  final List<Cell> pathCells;

  /// Ghost wall preview (valid/invalid).
  final WallPreview? wallPreview;

  /// Currently selected cell.
  final Cell? selectedCell;

  /// Whether to show coordinate labels on first/last rows.
  final bool showCoordinates;

  /// Which player's pawn gets the active-turn glow.
  final PlayerId? activeGlow;

  /// Maximum board size in pixels (desktop/tablet cap from DESIGN.md).
  final double maxSize;

  /// Called when a cell is tapped.
  final ValueChanged<Cell>? onCellTap;

  /// Called when a wall slot is tapped.
  final void Function(Cell anchor, WallOrientation orientation)? onWallSlotTap;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView>
    with SingleTickerProviderStateMixin {
  late final BoardAnimator _animator = BoardAnimator(this);

  @override
  void dispose() {
    _animator.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The selection ring fades in whenever a new cell is selected,
    // independent of any state change (selection is interaction state).
    if (widget.selectedCell != null &&
        widget.selectedCell != oldWidget.selectedCell) {
      if (_reducedMotion) {
        _animator.clear();
      } else {
        _animator.playSelection(widget.selectedCell!);
      }
    }

    final old = oldWidget.state;
    final next = widget.state;
    if (old == next) return;

    if (_reducedMotion) {
      _animator.clear();
      return;
    }

    // Only a single-ply transition is an action the player can follow;
    // anything larger is a jump (resume, rematch, online catch-up) and
    // animating it would misrepresent what happened.
    final singlePly = next.turnNumber == old.turnNumber + 1;

    if (singlePly) {
      for (final player in PlayerId.values) {
        final from = old.pawnPosition(player);
        final to = next.pawnPosition(player);
        if (from != to) {
          _animator.playPawnMove(player, from, to);
          // §7 proximity: the pawn newly reached the row next to its
          // goal — pulse that goal strip once.
          if (_isGoalAdjacent(to, player, next.boardConfig.size) &&
              !_isGoalAdjacent(from, player, next.boardConfig.size)) {
            _animator.playGoalPulse(top: player == PlayerId.blue);
          }
        }
      }
      final added = next.walls
          .where((wall) => !old.walls.contains(wall))
          .toList();
      if (added.length == 1) {
        _animator.playWallIn(added.single);
      }
    }

    // The active glow pulses once when the turn passes (§8, via §24's
    // state-change rule — never a perpetual animation).
    if (widget.activeGlow != null &&
        widget.activeGlow != oldWidget.activeGlow &&
        next.status == GameStatus.inProgress) {
      _animator.playGlowPulse(widget.activeGlow!);
    }

    // Victory (§7/§8): the celebration plays on the transition into the
    // finished state, whatever ply delta carried it there.
    if (old.status != GameStatus.finished &&
        next.status == GameStatus.finished &&
        next.winner != null) {
      _animator.playVictory(next.winner!);
    }
  }

  bool get _reducedMotion => FeedbackScope.reducedMotionActive(context);

  /// Whether [cell] is on the row directly before [player]'s goal row —
  /// the recorded definition of goal proximity (`memory.md` §13t): one
  /// step from the goal edge, computable without any pathfinding
  /// (`rules.md` §16).
  static bool _isGoalAdjacent(Cell cell, PlayerId player, int size) =>
      player == PlayerId.blue ? cell.row == 1 : cell.row == size - 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.biggest.shortestSide;
        // The 280 floor keeps a playable board tappable, but a caller that
        // caps the board below it (Home's small visual, Phase 11) means the
        // cap, not the floor — clamp() would throw for lower > upper.
        final floor = widget.maxSize >= 280.0 ? 280.0 : 0.0;
        final boardSize = available.clamp(floor, widget.maxSize);

        final geometry = BoardGeometry(
          boardSize: widget.state.boardConfig.size,
          areaSize: boardSize,
        );

        final hasCallbacks =
            widget.onCellTap != null || widget.onWallSlotTap != null;

        Widget board = Semantics(
          label: _buildSemanticsLabel(),
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(boardSize, boardSize),
                painter: BoardPainter(
                  state: widget.state,
                  geometry: geometry,
                  legalMoveTargets: widget.legalMoveTargets,
                  pathCells: widget.pathCells,
                  wallPreview: widget.wallPreview,
                  selectedCell: widget.selectedCell,
                  showCoordinates: widget.showCoordinates,
                  activeGlow: widget.activeGlow,
                  animator: _animator,
                ),
              ),
            ),
          ),
        );

        if (hasCallbacks) {
          board = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleTap(details.localPosition, geometry),
            child: board,
          );
        }

        return board;
      },
    );
  }

  void _handleTap(Offset position, BoardGeometry geometry) {
    // Wall slots win inside the snap tolerance; taps beyond it fall through to
    // the cell underneath, so the two targets never both fire for one tap.
    final wallAnchor = geometry.wallAnchorAt(position);
    if (wallAnchor != null && widget.onWallSlotTap != null) {
      widget.onWallSlotTap!(
        Cell(row: wallAnchor.row, column: wallAnchor.col),
        wallAnchor.orientation,
      );
      return;
    }

    // Check cell tap.
    final cell = geometry.cellAt(position);
    if (cell != null && widget.onCellTap != null) {
      widget.onCellTap!(cell);
    }
  }

  String _buildSemanticsLabel() {
    final state = widget.state;
    final blue = state.pawnPosition(PlayerId.blue);
    final red = state.pawnPosition(PlayerId.red);
    final blueWalls = state.wallsRemaining(PlayerId.blue);
    final redWalls = state.wallsRemaining(PlayerId.red);
    final size = state.boardConfig.size;
    final blueFile = String.fromCharCode(0x61 + blue.column);
    final blueRank = size - blue.row;
    final redFile = String.fromCharCode(0x61 + red.column);
    final redRank = size - red.row;
    return 'Blue pawn at $blueFile$blueRank, $blueWalls walls left. '
        'Red pawn at $redFile$redRank, $redWalls walls left.';
  }
}
