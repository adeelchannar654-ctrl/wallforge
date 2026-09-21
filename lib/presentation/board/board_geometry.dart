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

  // --- Derived metrics -------------------------------------------------------

  /// Effective board area after padding.
  double get boardArea => areaSize - padding * 2;

  /// Size of one cell (square).
  double get cellSize => boardArea / boardSize;

  /// Gap between cells (the groove). Matches the visual 1.5/9 ratio ≈ 1.67%.
  /// In code.html L89: `gap-1.5` on a 9-col grid inside `p-1.5`.
  double get grooveWidth => cellSize * 0.04;

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

  /// Wall anchor at pixel position [position], or null.
  ///
  /// For a horizontal wall, the anchor row is the row whose bottom groove
  /// contains the position. For a vertical wall, the anchor column is the
  /// column whose right groove contains the position.
  ({int row, int col, WallOrientation orientation})? wallAnchorAt(
    Offset position,
  ) {
    // Check horizontal (groove between rows).
    for (var r = 0; r < boardSize - 1; r++) {
      final grooveY = padding + (r + 1) * cellSize - grooveWidth;
      final grooveRect = Rect.fromLTWH(
        padding,
        grooveY,
        boardArea,
        grooveWidth * 1.5,
      );
      if (grooveRect.contains(position)) {
        final col = ((position.dx - padding) / cellSize).floor();
        if (col >= 0 && col < boardSize - 1) {
          return (row: r, col: col, orientation: WallOrientation.h);
        }
      }
    }
    // Check vertical (groove between columns).
    for (var c = 0; c < boardSize - 1; c++) {
      final grooveX = padding + (c + 1) * cellSize - grooveWidth;
      final grooveRect = Rect.fromLTWH(
        grooveX,
        padding,
        grooveWidth * 1.5,
        boardArea,
      );
      if (grooveRect.contains(position)) {
        final row = ((position.dy - padding) / cellSize).floor();
        if (row >= 0 && row < boardSize - 1) {
          return (row: row, col: c, orientation: WallOrientation.v);
        }
      }
    }
    return null;
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
