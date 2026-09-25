import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/engine/blocked_edges.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/presentation/board/board_geometry.dart';

/// Step 0.1: Wall-geometry ↔ engine cross-check.
///
/// For every anchor on sizes 5, 7, 9, 11:
/// 1. Create a Wall at that anchor/orientation.
/// 2. Build BlockedEdges from that single wall.
/// 3. Verify the two expected edges are blocked.
/// 4. Verify the wall rect from BoardGeometry spans exactly the two segments
///    that BlockedEdges recorded for that wall.
void main() {
  for (final size in [5, 7, 9, 11]) {
    group('wall-geometry cross-check size=$size', () {
      final g = BoardGeometry(boardSize: size, areaSize: 450);

      test('every H anchor: wall rect covers exactly 2 H segments', () {
        final maxAnchor = size - 2;
        for (var r = 0; r <= maxAnchor; r++) {
          for (var c = 0; c <= maxAnchor; c++) {
            final wall = Wall(
              anchorRow: r,
              anchorColumn: c,
              orientation: WallOrientation.h,
              owner: PlayerId.blue,
            );
            final blocked = BlockedEdges.fromWalls([wall], size);

            // The two edges blocked by H(r,c) per spec §3.6 R-WALL-04:
            // (r,c)↔(r+1,c) and (r,c+1)↔(r+1,c+1)
            final e1a = Cell(row: r, column: c);
            final e1b = Cell(row: r + 1, column: c);
            final e2a = Cell(row: r, column: c + 1);
            final e2b = Cell(row: r + 1, column: c + 1);

            expect(
              blocked.isBlocked(e1a, e1b),
              isTrue,
              reason:
                  'H($r,$c) should block (${e1a.row},${e1a.column})→(${e1b.row},${e1b.column})',
            );
            expect(
              blocked.isBlocked(e2a, e2b),
              isTrue,
              reason:
                  'H($r,$c) should block (${e2a.row},${e2a.column})→(${e2b.row},${e2b.column})',
            );

            // Also verify the reverse directions (BlockedEdges._add stores both).
            expect(
              blocked.isBlocked(e1b, e1a),
              isTrue,
              reason:
                  'H($r,$c) reverse block (${e1b.row},${e1b.column})→(${e1a.row},${e1a.column})',
            );
            expect(
              blocked.isBlocked(e2b, e2a),
              isTrue,
              reason:
                  'H($r,$c) reverse block (${e2b.row},${e2b.column})→(${e2a.row},${e2a.column})',
            );

            // Wall rect geometry: H wall rect width = cellSize * 2,
            // height = grooveWidth * 1.5
            final rect = g.wallRect(r, c, WallOrientation.h);
            expect(rect.width, closeTo(g.cellSize * 2, 0.001));
            expect(rect.height, closeTo(g.grooveWidth * 1.5, 0.001));

            // The wall rect left edge aligns with the left column.
            expect(rect.left, closeTo(g.padding + c * g.cellSize, 0.001));

            // Verify no other edges are blocked (single wall = 2 undirected edges).
            var edgeCount = 0;
            for (var rr = 0; rr < size; rr++) {
              for (var cc = 0; cc < size; cc++) {
                for (final (dr, dc) in [(0, 1), (1, 0)]) {
                  final nr = rr + dr;
                  final nc = cc + dc;
                  if (nr < size && nc < size) {
                    if (blocked.isBlocked(
                      Cell(row: rr, column: cc),
                      Cell(row: nr, column: nc),
                    )) {
                      edgeCount++;
                    }
                  }
                }
              }
            }
            expect(
              edgeCount,
              2,
              reason:
                  'H($r,$c) should produce exactly 2 blocked undirected edges',
            );
          }
        }
      });

      test('every V anchor: wall rect covers exactly 2 V segments', () {
        final maxAnchor = size - 2;
        for (var r = 0; r <= maxAnchor; r++) {
          for (var c = 0; c <= maxAnchor; c++) {
            final wall = Wall(
              anchorRow: r,
              anchorColumn: c,
              orientation: WallOrientation.v,
              owner: PlayerId.blue,
            );
            final blocked = BlockedEdges.fromWalls([wall], size);

            // The two edges blocked by V(r,c):
            // (r,c)↔(r,c+1) and (r+1,c)↔(r+1,c+1)
            final e1a = Cell(row: r, column: c);
            final e1b = Cell(row: r, column: c + 1);
            final e2a = Cell(row: r + 1, column: c);
            final e2b = Cell(row: r + 1, column: c + 1);

            expect(
              blocked.isBlocked(e1a, e1b),
              isTrue,
              reason:
                  'V($r,$c) should block (${e1a.row},${e1a.column})→(${e1b.row},${e1b.column})',
            );
            expect(
              blocked.isBlocked(e2a, e2b),
              isTrue,
              reason:
                  'V($r,$c) should block (${e2a.row},${e2a.column})→(${e2b.row},${e2b.column})',
            );

            // Reverse directions.
            expect(
              blocked.isBlocked(e1b, e1a),
              isTrue,
              reason:
                  'V($r,$c) reverse block (${e1b.row},${e1b.column})→(${e1a.row},${e1a.column})',
            );
            expect(
              blocked.isBlocked(e2b, e2a),
              isTrue,
              reason:
                  'V($r,$c) reverse block (${e2b.row},${e2b.column})→(${e2a.row},${e2a.column})',
            );

            // Wall rect geometry: V wall rect height = cellSize * 2,
            // width = grooveWidth * 1.5
            final rect = g.wallRect(r, c, WallOrientation.v);
            expect(rect.height, closeTo(g.cellSize * 2, 0.001));
            expect(rect.width, closeTo(g.grooveWidth * 1.5, 0.001));

            // The wall rect top edge aligns with the top row.
            expect(rect.top, closeTo(g.padding + r * g.cellSize, 0.001));

            // Verify no other edges are blocked (single wall = 2 undirected edges).
            var edgeCount = 0;
            for (var rr = 0; rr < size; rr++) {
              for (var cc = 0; cc < size; cc++) {
                for (final (dr, dc) in [(0, 1), (1, 0)]) {
                  final nr = rr + dr;
                  final nc = cc + dc;
                  if (nr < size && nc < size) {
                    if (blocked.isBlocked(
                      Cell(row: rr, column: cc),
                      Cell(row: nr, column: nc),
                    )) {
                      edgeCount++;
                    }
                  }
                }
              }
            }
            expect(
              edgeCount,
              2,
              reason:
                  'V($r,$c) should produce exactly 2 blocked undirected edges',
            );
          }
        }
      });
    });
  }

  group('engine-played states: wall count matches BlockedEdges', () {
    test('apply walls through engine, verify blocked edge count', () {
      for (final size in [5, 7, 9, 11]) {
        var state = GameState.initial(BoardConfig(size: size));
        final rng = Random(42);
        var wallsPlaced = 0;

        for (var turn = 0; turn < 40; turn++) {
          final actions = GameEngine.legalActions(state);
          if (actions.isEmpty) break;

          final wallActions = actions.whereType<WallAction>().toList();
          if (wallActions.isEmpty) break;

          final pick = wallActions[rng.nextInt(wallActions.length)];
          final result = GameEngine.apply(state, state.currentPlayer, pick);
          if (result is SuccessResult) {
            state = result.state;
            wallsPlaced++;
          }
        }

        final blocked = BlockedEdges.fromWalls(state.walls, size);
        var edgeCount = 0;
        for (var r = 0; r < size; r++) {
          for (var c = 0; c < size; c++) {
            for (final (dr, dc) in [(0, 1), (1, 0)]) {
              final nr = r + dr;
              final nc = c + dc;
              if (nr < size && nc < size) {
                if (blocked.isBlocked(
                  Cell(row: r, column: c),
                  Cell(row: nr, column: nc),
                )) {
                  edgeCount++;
                }
              }
            }
          }
        }

        // Each wall blocks exactly 2 undirected edges.
        expect(
          edgeCount,
          state.walls.length * 2,
          reason:
              'size=$size: blocked undirected edge count must be 2x wall count',
        );
        expect(
          state.walls.length,
          wallsPlaced,
          reason: 'size=$size: placed walls must match state.walls count',
        );
      }
    });
  });

  group('engine-played states: pathfinder consistency with BlockedEdges', () {
    test('neighborsOf returns correct orthogonal on-board cells', () {
      for (final size in [5, 7, 9, 11]) {
        final blocked = BlockedEdges.fromWalls([], size);

        // Center cell: 4 neighbors.
        final center = Cell(row: size ~/ 2, column: size ~/ 2);
        final centerNeighbors = blocked.neighborsOf(center);
        expect(centerNeighbors.length, 4);

        // Corner cell: 2 neighbors.
        const corner = Cell(row: 0, column: 0);
        final cornerNeighbors = blocked.neighborsOf(corner);
        expect(cornerNeighbors.length, 2);

        // Edge cell (not corner): 3 neighbors.
        final edge = Cell(row: 0, column: size ~/ 2);
        final edgeNeighbors = blocked.neighborsOf(edge);
        expect(edgeNeighbors.length, 3);
      }
    });
  });
}
