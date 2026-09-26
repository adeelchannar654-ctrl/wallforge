import 'dart:math' as math;

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
          expect(topRight, '$lastFile$size');
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
          const wall = Wall(
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
          final outside2 = g.cellAt(const Offset(500, 500));
          expect(outside2, isNull);
        });

        test(
          'wallHitTolerance is half the 44px target, capped below a half cell',
          () {
            final expected = math.min(22.0, g.cellSize / 2 - 0.5);
            expect(g.wallHitTolerance, closeTo(expected, 0.0001));
            expect(g.wallHitTolerance, lessThanOrEqualTo(22.0));
            expect(g.wallHitTolerance, greaterThan(0));
            expect(g.cellSize / 2, greaterThan(g.wallHitTolerance));
          },
        );

        test('wallAnchorAt returns null at every cell centre', () {
          for (var row = 0; row < size; row++) {
            for (var column = 0; column < size; column++) {
              expect(
                g.wallAnchorAt(g.cellCenter(row, column)),
                isNull,
                reason: 'cell ($row,$column) centre must not resolve to a wall',
              );
            }
          }
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

        test('wallAnchorAt returns null outside the board rect', () {
          expect(g.wallAnchorAt(const Offset(-4, 40)), isNull);
          expect(g.wallAnchorAt(Offset(g.areaSize + 4, 40)), isNull);
          expect(g.wallAnchorAt(const Offset(40, -4)), isNull);
          expect(g.wallAnchorAt(Offset(40, g.areaSize + 4)), isNull);
        });

        test('every valid anchor resolves at its exact grid line', () {
          for (var r = 0; r < size - 1; r++) {
            for (var c = 0; c < size - 1; c++) {
              final horizontal = g.wallAnchorAt(
                Offset(g.cellCenter(0, c).dx, g.padding + (r + 1) * g.cellSize),
              );
              expect(horizontal, (
                row: r,
                col: c,
                orientation: WallOrientation.h,
              ));

              final vertical = g.wallAnchorAt(
                Offset(g.padding + (c + 1) * g.cellSize, g.cellCenter(r, 0).dy),
              );
              expect(vertical, (
                row: r,
                col: c,
                orientation: WallOrientation.v,
              ));
            }
          }
        });

        test(
          'a tap off the groove but inside tolerance keeps the same anchor',
          () {
            final r = size ~/ 2;
            final c = size ~/ 2;
            final lineY = g.padding + (r + 1) * g.cellSize;
            final x = g.cellCenter(0, c).dx;

            for (final factor in [0.25, 0.5, 0.9]) {
              for (final sign in [-1.0, 1.0]) {
                final pos = Offset(
                  x,
                  lineY + sign * g.wallHitTolerance * factor,
                );
                expect(
                  g.wallAnchorAt(pos),
                  (row: r, col: c, orientation: WallOrientation.h),
                  reason: 'offset ${sign * factor} of tolerance must not drift',
                );
              }
            }
          },
        );

        test(
          'tolerance boundary is inclusive and the cell-centre band is null',
          () {
            final r = size ~/ 2;
            final c = size ~/ 2;
            final lineY = g.padding + (r + 1) * g.cellSize;
            final x = g.cellCenter(0, c).dx;
            final expected = (row: r, col: c, orientation: WallOrientation.h);

            expect(
              g.wallAnchorAt(Offset(x, lineY + g.wallHitTolerance)),
              expected,
            );
            expect(
              g.wallAnchorAt(Offset(x, lineY - g.wallHitTolerance)),
              expected,
            );

            final deadBand = g.cellSize - 2 * g.wallHitTolerance;
            expect(deadBand, greaterThan(0));
            expect(
              g.wallAnchorAt(
                Offset(x, lineY + g.wallHitTolerance + deadBand / 4),
              ),
              isNull,
            );
          },
        );

        test(
          'a near-miss near the tolerance edge does not drift to the neighbour',
          () {
            const r = 2;
            const c = 2;
            final lineY = g.padding + (r + 1) * g.cellSize;
            final x = g.cellCenter(0, c).dx;
            final nearMiss = Offset(x, lineY + g.wallHitTolerance * 0.95);

            expect(g.wallAnchorAt(nearMiss), (
              row: r,
              col: c,
              orientation: WallOrientation.h,
            ));
            expect(
              g.wallAnchorAt(nearMiss)?.row,
              isNot(r + 1),
              reason: 'the neighbouring groove must not steal the tap',
            );
          },
        );

        test(
          'the nearer of two equidistant grooves wins deterministically',
          () {
            final line = g.padding + 2 * g.cellSize;
            const offset = 3.0;

            expect(g.wallAnchorAt(Offset(line - offset, line - offset)), (
              row: 1,
              col: 1,
              orientation: WallOrientation.h,
            ), reason: 'an exact tie resolves to horizontal');
            expect(g.wallAnchorAt(Offset(line - 1, line - 5)), (
              row: 1,
              col: 1,
              orientation: WallOrientation.v,
            ), reason: 'the closer vertical line wins');
            expect(g.wallAnchorAt(Offset(line - 5, line - 1)), (
              row: 1,
              col: 1,
              orientation: WallOrientation.h,
            ), reason: 'the closer horizontal line wins');
          },
        );

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
        const g = BoardGeometry(boardSize: 5, areaSize: 300, padding: 20);
        expect(g.boardArea, 260);
        expect(g.cellSize, 52);
        final rect = g.cellRect(0, 0);
        expect(rect.left, 20);
        expect(rect.top, 20);
      });

      test('boardSize=7 areaSize=500', () {
        const g = BoardGeometry(boardSize: 7, areaSize: 500);
        expect(g.cellSize, closeTo(500 / 7, 0.001));
      });
    });
  });
}
