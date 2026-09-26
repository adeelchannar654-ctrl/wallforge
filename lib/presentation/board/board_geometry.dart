import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/cell.dart';
import '../../domain/models/wall.dart';
import '../../domain/models/wall_orientation.dart';

/// Pure, unit-tested geometry for a Wallforge board.
///
/// Converts logical game coordinates to pixel positions and back.
/// No Flutter dependency except [Size] and [Rect] for layout.
class BoardGeometry {
  const BoardGeometry({
    required this.boardSize,
    required this.areaSize,
    this.padding = 0,
  }) : assert(boardSize >= 5);

  /// NxN grid dimension (must be odd, >= 5).
  final int boardSize;

  /// Total pixel area available for the board (width or height, since 1:1).
  final double areaSize;

  /// Outer padding inside the board container.
  final double padding;

  /// Minimum interactive target clearance required by the Stitch design system.
  ///
  /// Source: `stitch_wallforge_ui_design_system/stitch_wallforge_ui_design_system/
  /// tactical_neon_arena/DESIGN.md` §Layout & Spacing — "Interactive grid points,
  /// wall slots, and control pills require an absolute minimum hit-target
  /// clearance of 44x44px."
  static const double minimumInteractiveTarget = 44;

  /// Guard band that keeps a cell-centre tap outside wall-snap range.
  static const double _cellCentreGuard = 0.5;

  // --- Derived metrics -------------------------------------------------------

  /// Effective board area after padding.
  double get boardArea => areaSize - padding * 2;

  /// Size of one cell (square).
  double get cellSize => boardArea / boardSize;

  /// Gap between cells (the groove). Matches the visual 1.5/9 ratio ≈ 1.67%.
  /// In code.html L89: `gap-1.5` on a 9-col grid inside `p-1.5`.
  double get grooveWidth => cellSize * 0.04;

  /// Perpendicular snap radius used by [wallAnchorAt].
  ///
  /// Half of [minimumInteractiveTarget] (22 px), capped just under half a cell so
  /// that a tap at a cell centre can never be captured as a wall anchor. On
  /// boards dense enough that half a cell is smaller than 22 px the cap wins, so
  /// the reachable target is `2 * wallHitTolerance` px on that board.
  double get wallHitTolerance => math.min(
    minimumInteractiveTarget / 2,
    math.max(0, cellSize / 2 - _cellCentreGuard),
  );

  /// The movement-grid rect that wall and cell anchors are derived from.
  Rect get boardRect => Rect.fromLTWH(padding, padding, boardArea, boardArea);

  /// Cell rect (without groove offset).
  Rect cellRect(int row, int column) {
    final x = padding + column * cellSize;
    final y = padding + row * cellSize;
    return Rect.fromLTWH(x, y, cellSize, cellSize);
  }

  /// Cell rect centred on the cell (accounts for groove).
  Rect cellRectCentered(int row, int column) {
    final halfGroove = grooveWidth / 2;
    final inset = halfGroove + 1;
    final r = cellRect(row, column);
    return r.deflate(inset);
  }

  /// Centre point of a cell in pixel coordinates.
  Offset cellCenter(int row, int column) {
    final r = cellRect(row, column);
    return r.center;
  }

  /// Centre point of a cell from a [Cell] model.
  Offset cellCenterFromModel(Cell cell) => cellCenter(cell.row, cell.column);

  // --- Wall geometry ---------------------------------------------------------

  /// Rect for a horizontal wall anchored at (anchorRow, anchorColumn).
  ///
  /// H(r,c) blocks edges (r,c)-(r+1,c) and (r,c+1)-(r+1,c+1).
  /// The wall is drawn between rows r and r+1, spanning columns c to c+1.
  Rect wallRect(int anchorRow, int anchorColumn, WallOrientation orientation) {
    if (orientation == WallOrientation.h) {
      final x = padding + anchorColumn * cellSize;
      final y = padding + (anchorRow + 1) * cellSize - grooveWidth;
      final w = cellSize * 2;
      return Rect.fromLTWH(x, y, w, grooveWidth * 1.5);
    } else {
      final x = padding + (anchorColumn + 1) * cellSize - grooveWidth;
      final y = padding + anchorRow * cellSize;
      final h = cellSize * 2;
      return Rect.fromLTWH(x, y, grooveWidth * 1.5, h);
    }
  }

  /// Rect for a [Wall] model.
  Rect wallRectFromModel(Wall wall) =>
      wallRect(wall.anchorRow, wall.anchorColumn, wall.orientation);

  // --- Hit testing -----------------------------------------------------------

  /// Cell at pixel position [position], or null if outside the board.
  Cell? cellAt(Offset position) {
    final col = ((position.dx - padding) / cellSize).floor();
    final row = ((position.dy - padding) / cellSize).floor();
    if (row < 0 || row >= boardSize || col < 0 || col >= boardSize) return null;
    return Cell(row: row, column: col);
  }

  /// Wall anchor nearest to pixel [position], or null.
  ///
  /// The nearest horizontal and the nearest vertical grid line are measured and
  /// the closer one decides the orientation; exact ties resolve to horizontal,
  /// matching `game_spec.md` §3.10 R-ORDER-03 (H before V) and the previous
  /// scan order. The snapped index on that axis is the nearest line, the other
  /// index is the cell that contains the tap, so each anchor stays centred on
  /// its own two-cell bar. When the winning line is farther away than
  /// [wallHitTolerance] the result is null, so a tap in the middle of a cell is
  /// never reported as a wall slot.
  ({int row, int col, WallOrientation orientation})? wallAnchorAt(
    Offset position,
  ) {
    if (!boardRect.contains(position)) return null;

    final horizontal = _nearestAnchorLine(position.dy);
    final vertical = _nearestAnchorLine(position.dx);
    final tolerance = wallHitTolerance;

    if (horizontal.distance <= vertical.distance &&
        horizontal.distance <= tolerance) {
      return (
        row: horizontal.index,
        col: _anchorCellIndex(position.dx),
        orientation: WallOrientation.h,
      );
    }
    if (vertical.distance <= tolerance) {
      return (
        row: _anchorCellIndex(position.dy),
        col: vertical.index,
        orientation: WallOrientation.v,
      );
    }
    return null;
  }

  /// Index of the cell that contains [coordinate], clipped to the valid anchor
  /// range `0..boardSize - 2`.
  int _anchorCellIndex(double coordinate) {
    final cell = ((coordinate - padding) / cellSize).floor();
    if (cell < 0) return 0;
    if (cell > boardSize - 2) return boardSize - 2;
    return cell;
  }

  /// Nearest interior grid line to [coordinate] on one axis.
  ///
  /// Returns the anchor index (`line index - 1`) and the absolute distance.
  /// A coordinate exactly between two lines resolves to the higher line index.
  ({int index, double distance}) _nearestAnchorLine(double coordinate) {
    final cell = (coordinate - padding) / cellSize;
    final clamped = cell.clamp(1.0, (boardSize - 1).toDouble());
    final line = clamped.round();
    return (
      index: line - 1,
      distance: (coordinate - (padding + line * cellSize)).abs(),
    );
  }

  // --- Coordinate labels -----------------------------------------------------

  /// Chess-style label for a cell: file letter + rank number.
  ///
  /// `a1` = bottom-left = cell(size-1, 0).
  /// `i9` = top-right = cell(0, 8) for 9×9.
  String cellLabel(int row, int column) {
    final file = String.fromCharCode(0x61 + column); // 'a' + column
    final rank = boardSize - row;
    return '$file$rank';
  }

  // --- Goal strip rects ------------------------------------------------------

  /// Rect for the top goal strip (Blue's goal, row 0).
  Rect get topGoalStrip => Rect.fromLTWH(
    padding,
    padding - grooveWidth * 3,
    boardArea,
    grooveWidth * 3,
  );

  /// Rect for the bottom goal strip (Red's goal, row size-1).
  Rect get bottomGoalStrip =>
      Rect.fromLTWH(padding, padding + boardArea, boardArea, grooveWidth * 3);
}
