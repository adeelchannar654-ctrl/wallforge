import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Spec v2.0.0 rule change: same-anchor, opposite-orientation walls (a "+"
/// crossing) are LEGAL. Same-orientation overlap remains illegal.
///
/// The blocked-edge assertions deliberately go through the engine's own
/// [BlockedEdges] rather than re-deriving the geometry here, so the test tracks
/// real engine behaviour instead of a second copy of it.
void main() {
  group('v2.0.0: crossing walls are legal', () {
    for (final size in [5, 7, 9, 11]) {
      test('size=$size: H+V at the same anchor blocks all four edges', () {
        const r = 2;
        const c = 2;
        final walls = [
          const Wall(
            owner: PlayerId.blue,
            orientation: WallOrientation.h,
            anchorRow: 2,
            anchorColumn: 2,
          ),
          const Wall(
            owner: PlayerId.red,
            orientation: WallOrientation.v,
            anchorRow: 2,
            anchorColumn: 2,
          ),
        ];

        final board = BlockedEdges.fromWalls(walls, size);

        // H(2,2) blocks (2,2)-(3,2) and (2,3)-(3,3)
        expect(
          board.isBlocked(
            const Cell(row: r, column: c),
            const Cell(row: r + 1, column: c),
          ),
          isTrue,
          reason: 'H second segment of the lower-left edge',
        );
        expect(
          board.isBlocked(
            const Cell(row: r, column: c + 1),
            const Cell(row: r + 1, column: c + 1),
          ),
          isTrue,
          reason: 'H second segment of the lower-right edge',
        );
        // V(2,2) blocks (2,2)-(2,3) and (3,2)-(3,3)
        expect(
          board.isBlocked(
            const Cell(row: r, column: c),
            const Cell(row: r, column: c + 1),
          ),
          isTrue,
          reason: 'V segment of the upper edge',
        );
        expect(
          board.isBlocked(
            const Cell(row: r + 1, column: c),
            const Cell(row: r + 1, column: c + 1),
          ),
          isTrue,
          reason: 'V segment of the lower edge',
        );

        // The four cells around the shared anchor are mutually unreachable
        // across every orthogonal edge inside the 2x2 block.
        const corner = [
          Cell(row: r, column: c),
          Cell(row: r, column: c + 1),
          Cell(row: r + 1, column: c),
          Cell(row: r + 1, column: c + 1),
        ];
        final insideEdges = <(Cell, Cell)>[
          (corner[0], corner[1]),
          (corner[2], corner[3]),
          (corner[0], corner[2]),
          (corner[1], corner[3]),
        ];
        for (final (a, b) in insideEdges) {
          expect(
            board.isBlocked(a, b),
            isTrue,
            reason: 'every edge inside the 2x2 corner must be blocked: $a-$b',
          );
          expect(
            board.isBlocked(b, a),
            isTrue,
            reason: 'blocking is symmetric: $b-$a',
          );
        }

        // The pair blocks exactly the four edges of that 2x2 block, and
        // nothing outside it.
        expect(
          board.neighborsOf(const Cell(row: r, column: c)),
          hasLength(4),
          reason: 'the anchor cell keeps all four on-board neighbours listed',
        );
        expect(
          board.isBlocked(
            const Cell(row: r, column: c),
            const Cell(row: r - 1, column: c),
          ),
          isFalse,
          reason: 'no edge outside the 2x2 corner may be blocked',
        );
      });

      test('size=$size: the crossing placement validates and coexists', () {
        final state = GameState.initial(BoardConfig(size: size)).copyWith(
          walls: [
            const Wall(
              owner: PlayerId.blue,
              orientation: WallOrientation.h,
              anchorRow: 2,
              anchorColumn: 2,
            ),
          ],
        );

        const action = GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 2, column: 2),
        );

        expect(
          ActionValidator.validate(state, PlayerId.blue, action),
          isNull,
          reason: 'R-WALL-08 (v2.0.0): same-anchor crossing must be legal',
        );

        final result = GameEngine.apply(state, PlayerId.blue, action);
        expect(result, isA<SuccessResult>());
        final after = (result as SuccessResult).state;
        expect(after.walls, hasLength(2));
        expect(
          after.walls.map((w) => w.orientation),
          containsAll(<WallOrientation>[WallOrientation.h, WallOrientation.v]),
        );
        expect(after.remainingWalls[PlayerId.blue], 9);
        expect(after.turnNumber, 1);
        expect(after.currentPlayer, PlayerId.red);
      });

      test('size=$size: same-orientation duplicates are still illegal', () {
        final state = GameState.initial(BoardConfig(size: size)).copyWith(
          walls: const [
            Wall(
              owner: PlayerId.blue,
              orientation: WallOrientation.h,
              anchorRow: 2,
              anchorColumn: 2,
            ),
            Wall(
              owner: PlayerId.red,
              orientation: WallOrientation.v,
              anchorRow: 2,
              anchorColumn: 2,
            ),
          ],
        );

        // H duplicate of the H wall -> wallOverlaps
        expect(
          ActionValidator.validate(
            state,
            PlayerId.blue,
            const GameAction.wall(
              orientation: WallOrientation.h,
              anchor: Cell(row: 2, column: 2),
            ),
          ),
          ActionFailure.wallOverlaps,
        );
        // H offset by one from the H wall -> wallOverlaps
        expect(
          ActionValidator.validate(
            state,
            PlayerId.blue,
            const GameAction.wall(
              orientation: WallOrientation.h,
              anchor: Cell(row: 2, column: 3),
            ),
          ),
          ActionFailure.wallOverlaps,
        );
        // V duplicate of the V wall -> wallOverlaps
        expect(
          ActionValidator.validate(
            state,
            PlayerId.blue,
            const GameAction.wall(
              orientation: WallOrientation.v,
              anchor: Cell(row: 2, column: 2),
            ),
          ),
          ActionFailure.wallOverlaps,
          reason: 'Red already owns V(2,2); a second V there still overlaps',
        );
        // V offset by one from the V wall -> wallOverlaps
        expect(
          ActionValidator.validate(
            state,
            PlayerId.blue,
            const GameAction.wall(
              orientation: WallOrientation.v,
              anchor: Cell(row: 3, column: 2),
            ),
          ),
          ActionFailure.wallOverlaps,
        );
      });

      test(
        'size=$size: path preservation still applies next to a crossing',
        () {
          // Blue is sealed into the bottom-left pocket {(n-1,0),(n-1,1)} by
          // H(n-2,0). A crossing V(n-2,1) is legal by shape but must still be
          // rejected by R-PATH-01.
          final last = size - 1;
          final state = GameState.initial(BoardConfig(size: size)).copyWith(
            pawnPositions: {
              PlayerId.blue: Cell(row: last, column: 0),
              PlayerId.red: Cell(row: 0, column: size ~/ 2),
            },
            walls: [
              Wall(
                owner: PlayerId.blue,
                orientation: WallOrientation.h,
                anchorRow: last - 1,
                anchorColumn: 0,
              ),
            ],
          );

          expect(
            ActionValidator.validate(
              state,
              PlayerId.blue,
              GameAction.wall(
                orientation: WallOrientation.v,
                anchor: Cell(row: last - 1, column: 1),
              ),
            ),
            ActionFailure.wallBlocksPath,
            reason: 'v2.0.0 relaxes shape only; R-PATH-01 is untouched',
          );
        },
      );
    }

    test('a crossing pair is offered by the legal-action generator', () {
      final state = GameState.initial().copyWith(
        walls: const [
          Wall(
            owner: PlayerId.blue,
            orientation: WallOrientation.h,
            anchorRow: 3,
            anchorColumn: 3,
          ),
        ],
        remainingWalls: const {PlayerId.blue: 9, PlayerId.red: 10},
      );

      final legal = MoveGenerator.generate(state, PlayerId.blue);
      final notation = legal.map((a) => a.toNotation()).toList();

      expect(
        notation,
        contains('W V 3,3'),
        reason: 'the crossing candidate must reach the player, not be pruned',
      );
      expect(
        notation,
        isNot(contains('W H 3,3')),
        reason: 'the same-orientation duplicate must still be pruned',
      );
      expect(
        notation,
        isNot(contains('W H 3,4')),
        reason: 'the offset-by-one overlap must still be pruned',
      );
    });

    test('both owners may hold one wall each at the same anchor', () {
      var state = GameState.initial();

      const h = GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 3, column: 3),
      );
      const v = GameAction.wall(
        orientation: WallOrientation.v,
        anchor: Cell(row: 3, column: 3),
      );

      // Blue places H(3,3), Red places V(3,3) at the same anchor.
      var result = GameEngine.apply(state, state.currentPlayer, h);
      expect(result, isA<SuccessResult>());
      state = (result as SuccessResult).state;
      result = GameEngine.apply(state, state.currentPlayer, v);
      expect(result, isA<SuccessResult>());
      state = (result as SuccessResult).state;

      expect(state.walls, hasLength(2));
      expect(state.remainingWalls[PlayerId.blue], 9);
      expect(state.remainingWalls[PlayerId.red], 9);

      // A third wall at that anchor overlaps one of the two, whichever
      // orientation it uses, so the "+" holds at most two walls.
      expect(
        ActionValidator.validate(state, state.currentPlayer, h),
        ActionFailure.wallOverlaps,
      );
      expect(
        ActionValidator.validate(state, state.currentPlayer, v),
        ActionFailure.wallOverlaps,
      );
    });
  });

  group('v2.0.0: wallCrosses is retired', () {
    test('no legal or illegal input produces it', () {
      // Exhaustive over every wall candidate on the default board, in a state
      // that already contains a crossing pair.
      final state = GameState.initial().copyWith(
        walls: const [
          Wall(
            owner: PlayerId.blue,
            orientation: WallOrientation.h,
            anchorRow: 3,
            anchorColumn: 3,
          ),
          Wall(
            owner: PlayerId.red,
            orientation: WallOrientation.v,
            anchorRow: 3,
            anchorColumn: 3,
          ),
        ],
        remainingWalls: const {PlayerId.blue: 9, PlayerId.red: 9},
      );

      for (final orientation in WallOrientation.values) {
        for (var row = 0; row < 9; row++) {
          for (var column = 0; column < 9; column++) {
            final failure = ActionValidator.validate(
              state,
              PlayerId.blue,
              GameAction.wall(
                orientation: orientation,
                anchor: Cell(row: row, column: column),
              ),
            );
            expect(
              failure,
              isNot(ActionFailure.wallCrosses),
              reason: 'v2.0.0 retired this reason; $orientation($row,$column)',
            );
          }
        }
      }
    });
  });
}
