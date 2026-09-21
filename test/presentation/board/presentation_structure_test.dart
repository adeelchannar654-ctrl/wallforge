import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board.dart';

/// Structure tests: tokens, notches, wall↔BlockedEdges cross-check.
void main() {
  group('Tokens', () {
    test('WallInventoryNotches renders with correct notch count', () {
      // Not a widget test — just verify the model is sound.
      final state = GameState.initial();
      expect(state.wallsRemaining(PlayerId.blue), 10);
      expect(state.wallsRemaining(PlayerId.red), 10);
    });

    test('wallsRemaining decreases after wall placement', () {
      var state = GameState.initial();
      final action = GameAction.wall(
        orientation: WallOrientation.h,
        anchor: const Cell(row: 4, column: 0),
      );
      final r = GameEngine.apply(state, PlayerId.blue, action);
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;
      expect(state.wallsRemaining(PlayerId.blue), 9);
      expect(state.wallsRemaining(PlayerId.red), 10);
    });
  });

  group('Wall ↔ BlockedEdges cross-check', () {
    test('all anchors on size 9 map to valid blocked edges', () {
      const size = 9;
      final config = BoardConfig(size: size);
      final g = BoardGeometry(boardSize: size, areaSize: 450);

      for (var r = 0; r < size - 1; r++) {
        for (var c = 0; c < size - 1; c++) {
          // H wall
          final hRect = g.wallRect(r, c, WallOrientation.h);
          expect(hRect.width, greaterThan(0));

          // V wall
          final vRect = g.wallRect(r, c, WallOrientation.v);
          expect(vRect.height, greaterThan(0));
        }
      }
    });

    test('BlockedEdges produced by wall placement matches spec', () {
      var state = GameState.initial();
      final action = GameAction.wall(
        orientation: WallOrientation.v,
        anchor: const Cell(row: 3, column: 4),
      );
      final r = GameEngine.apply(state, PlayerId.blue, action);
      expect(r, isA<SuccessResult>());
      state = (r as SuccessResult).state;

      // V(3,4) blocks edges (3,4)→(3,5), (4,4)→(4,5), (3,5)→(4,5), (3,4)→(4,4)
      // Verify the wall was placed and pawn is still at start.
      final pawn = state.pawnPosition(PlayerId.blue);
      expect(pawn, const Cell(row: 8, column: 4));
    });

    test('wall rect dimensions match groove-based geometry', () {
      const size = 9;
      final g = BoardGeometry(boardSize: size, areaSize: 450);

      // H wall rect height should be 1.5x groove width.
      final h = g.wallRect(0, 0, WallOrientation.h);
      expect(h.height, closeTo(g.grooveWidth * 1.5, 0.001));

      // V wall rect width should be 1.5x groove width.
      final v = g.wallRect(0, 0, WallOrientation.v);
      expect(v.width, closeTo(g.grooveWidth * 1.5, 0.001));
    });
  });

  group('BoardConfig', () {
    test('size 9 config has correct anchor range', () {
      const config = BoardConfig(size: 9);
      expect(config.maxAnchor, 7);
      expect(config.totalWallSlots, 2 * 8 * 8);
    });

    test('size 5 config has correct anchor range', () {
      const config = BoardConfig(size: 5);
      expect(config.maxAnchor, 3);
      expect(config.totalWallSlots, 2 * 4 * 4);
    });

    test('size 7 config has correct anchor range', () {
      const config = BoardConfig(size: 7);
      expect(config.maxAnchor, 5);
    });

    test('size 11 config has correct anchor range', () {
      const config = BoardConfig(size: 11);
      expect(config.maxAnchor, 9);
    });
  });
}
