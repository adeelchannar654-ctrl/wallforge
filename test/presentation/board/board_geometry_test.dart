import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/board/board_geometry.dart';

void main() {
  group('BoardGeometry', () {
    for (final size in [5, 7, 9, 11]) {
      group('boardSize=$size', () {
        final g = BoardGeometry(boardSize: size, areaSize: 450);

        test('cellSize = areaSize / boardSize', () {
          expect(g.cellSize, closeTo(450 / size, 0.001));
        });

        test('cellRect returns correct rect for each cell', () {
          for (var row = 0; row < size; row++) {
            for (var col = 0; col < size; col++) {
              final rect = g.cellRect(row, col);
              expect(rect.width, closeTo(g.cellSize, 0.001));
              expect(rect.height, closeTo(g.cellSize, 0.001));
              expect(rect.left, closeTo(col * g.cellSize, 0.001));
              expect(rect.top, closeTo(row * g.cellSize, 0.001));
            }
          }
        });

        test('cellCenter returns centre of cell', () {
          for (var row = 0; row < size; row++) {
            for (var col = 0; col < size; col++) {
              final center = g.cellCenter(row, col);
              final rect = g.cellRect(row, col);
              expect(center.dx, closeTo(rect.center.dx, 0.001));
              expect(center.dy, closeTo(rect.center.dy, 0.001));
            }
          }
        });

        test('cellCenterFromModel matches cellCenter', () {
          for (var row = 0; row < size; row++) {
            for (var col = 0; col < size; col++) {
              final cell = Cell(row: row, column: col);
              final fromModel = g.cellCenterFromModel(cell);
              final direct = g.cellCenter(row, col);
              expect(fromModel.dx, closeTo(direct.dx, 0.001));
              expect(fromModel.dy, closeTo(direct.dy, 0.001));
            }
          }
        });

        test('cellRectCentered is smaller than cellRect', () {
          final rect = g.cellRect(0, 0);
          final centered = g.cellRectCentered(0, 0);
          expect(centered.width, lessThan(rect.width));
          expect(centered.height, lessThan(rect.height));
        });

        test('cellLabel: a1 = bottom-left, correct file letter', () {
          final bottomLeft = g.cellLabel(size - 1, 0);
          expect(bottomLeft, 'a1');

          final topRight = g.cellLabel(0, size - 1);
          final lastFile = String.fromCharCode(0x61 + size - 1);
          expect(topRight, '${lastFile}$size');
        });

        test('cellLabel: file increments with column', () {
          for (var col = 0; col < size; col++) {
            final label = g.cellLabel(size - 1, col);
            final expectedFile = String.fromCharCode(0x61 + col);
            expect(label, '${expectedFile}1');
          }
        });

        test('cellLabel: rank decrements with row', () {
          for (var row = 0; row < size; row++) {
            final label = g.cellLabel(row, 0);
            final expectedRank = size - row;
            expect(label, 'a$expectedRank');
          }
        });

        test('wallRect for H orientation spans 2 cells horizontally', () {
          final rect = g.wallRect(0, 0, WallOrientation.h);
          expect(rect.width, closeTo(g.cellSize * 2, 0.001));
          expect(rect.height, closeTo(g.grooveWidth * 1.5, 0.001));
          expect(rect.left, closeTo(0, 0.001));
          expect(rect.top, closeTo(g.cellSize - g.grooveWidth, 0.001));
        });

        test('wallRect for V orientation spans 2 cells vertically', () {
          final rect = g.wallRect(0, 0, WallOrientation.v);
          expect(rect.height, closeTo(g.cellSize * 2, 0.001));
          expect(rect.width, closeTo(g.grooveWidth * 1.5, 0.001));
          expect(rect.left, closeTo(g.cellSize - g.grooveWidth, 0.001));
          expect(rect.top, closeTo(0, 0.001));
        });

        test('wallRectFromModel matches wallRect', () {
          final wall = Wall(
            owner: PlayerId.blue,
            orientation: WallOrientation.h,
            anchorRow: 0,
            anchorColumn: 0,
          );
          final fromModel = g.wallRectFromModel(wall);
          final direct = g.wallRect(0, 0, WallOrientation.h);
          expect(fromModel, direct);
        });

        test('cellAt returns correct cell for valid position', () {
          final center = g.cellCenter(2, 3.clamp(0, size - 1));
          final cell = g.cellAt(center);
          expect(cell, isNotNull);
          expect(cell!.row, 2);
          expect(cell.column, 3.clamp(0, size - 1));
        });

        test('cellAt returns null outside board', () {
          final outside = g.cellAt(const Offset(-10, -10));
          expect(outside, isNull);
          final outside2 = g.cellAt(Offset(500, 500));
          expect(outside2, isNull);
        });

        test('wallAnchorAt returns null at cell centres', () {
          final center = g.cellCenter(
            3.clamp(0, size - 1),
            3.clamp(0, size - 1),
          );
          final anchor = g.wallAnchorAt(center);
          expect(anchor, isNull);
        });

        test('wallAnchorAt returns H wall anchor in horizontal groove', () {
          final grooveY = g.cellSize - g.grooveWidth;
          final pos = Offset(g.cellSize * 0.5, grooveY);
          final anchor = g.wallAnchorAt(pos);
          expect(anchor, isNotNull);
          expect(anchor!.orientation, WallOrientation.h);
        });

        test('wallAnchorAt returns V wall anchor in vertical groove', () {
          final grooveX = g.cellSize - g.grooveWidth;
          final pos = Offset(grooveX, g.cellSize * 0.5);
          final anchor = g.wallAnchorAt(pos);
          expect(anchor, isNotNull);
          expect(anchor!.orientation, WallOrientation.v);
        });

        test('topGoalStrip is above board', () {
          expect(g.topGoalStrip.bottom, closeTo(g.padding, 0.001));
          expect(g.topGoalStrip.top, lessThan(g.padding));
        });

        test('bottomGoalStrip is below board', () {
          expect(
            g.bottomGoalStrip.top,
            closeTo(g.padding + g.boardArea, 0.001),
          );
          expect(
            g.bottomGoalStrip.bottom,
            greaterThan(g.padding + g.boardArea),
          );
        });
      });
    }

    group('edge cases', () {
      test('boardSize=5 with padding', () {
        final g = BoardGeometry(boardSize: 5, areaSize: 300, padding: 20);
        expect(g.boardArea, 260);
        expect(g.cellSize, 52);
        final rect = g.cellRect(0, 0);
        expect(rect.left, 20);
        expect(rect.top, 20);
      });

      test('boardSize=7 areaSize=500', () {
        final g = BoardGeometry(boardSize: 7, areaSize: 500);
        expect(g.cellSize, closeTo(500 / 7, 0.001));
      });
    });
  });
}
