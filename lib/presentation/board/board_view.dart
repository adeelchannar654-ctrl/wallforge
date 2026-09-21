import 'package:flutter/material.dart';

import '../../domain/models/cell.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/player_id.dart';
import 'board_geometry.dart';
import 'board_painter.dart';

/// A pure renderer that displays a Wallforge game board.
///
/// Takes a [GameState] and optional overlays. Contains no rules and never
/// mutates state. Interaction callbacks are Phase 4 — expose none yet.
class BoardView extends StatelessWidget {
  const BoardView({
    super.key,
    required this.state,
    this.legalMoveTargets = const {},
    this.wallPreview,
    this.selectedCell,
    this.showCoordinates = true,
    this.activeGlow,
    this.maxSize = 640,
  });

  /// The game state to render.
  final GameState state;

  /// Cells to highlight as legal move destinations.
  final Set<Cell> legalMoveTargets;

  /// Ghost wall preview (valid/invalid).
  final WallPreview? wallPreview;

  /// Currently selected cell (for future interaction).
  final Cell? selectedCell;

  /// Whether to show coordinate labels on first/last rows.
  final bool showCoordinates;

  /// Which player's pawn gets the active-turn glow.
  final PlayerId? activeGlow;

  /// Maximum board size in pixels (desktop/tablet cap from DESIGN.md).
  final double maxSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.biggest.shortestSide;
        final boardSize = available.clamp(280.0, maxSize);

        final geometry = BoardGeometry(
          boardSize: state.boardConfig.size,
          areaSize: boardSize,
        );

        return Semantics(
          label: _buildSemanticsLabel(),
          child: SizedBox(
            width: boardSize,
            height: boardSize,
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(boardSize, boardSize),
                painter: BoardPainter(
                  state: state,
                  geometry: geometry,
                  legalMoveTargets: legalMoveTargets,
                  wallPreview: wallPreview,
                  selectedCell: selectedCell,
                  showCoordinates: showCoordinates,
                  activeGlow: activeGlow,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildSemanticsLabel() {
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
