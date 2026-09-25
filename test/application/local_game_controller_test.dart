import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/action_failure.dart';
import 'package:wallforge/domain/models/board_config.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/game_status.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/domain/serialization/game_state_serializer.dart';

void main() {
  group('LocalGameController', () {
    test('constructor applies a custom config', () {
      final controller = LocalGameController(
        config: const BoardConfig(size: 7, wallsPerPlayer: 8),
      );
      addTearDown(controller.dispose);

      expect(
        controller.state.boardConfig,
        const BoardConfig(size: 7, wallsPerPlayer: 8),
      );
      expect(
        controller.state.pawnPosition(PlayerId.blue),
        const Cell(row: 6, column: 3),
      );
      expect(
        controller.state.pawnPosition(PlayerId.red),
        const Cell(row: 0, column: 3),
      );
      expect(controller.state.wallsRemaining(PlayerId.blue), 8);
      expect(controller.state.wallsRemaining(PlayerId.red), 8);
    });

    test('startMatch applies custom config and resets presentation state', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.tapCell(const Cell(row: 7, column: 4));
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);

      controller.startMatch(
        config: const BoardConfig(size: 5, wallsPerPlayer: 3),
      );

      expect(
        controller.state.boardConfig,
        const BoardConfig(size: 5, wallsPerPlayer: 3),
      );
      expect(controller.state.turnNumber, 0);
      expect(controller.mode, InteractionMode.move);
      expect(controller.selectedCell, isNull);
      expect(controller.pendingWall, isNull);
      expect(controller.lastFailure, isNull);
    });

    test('restart and rematch preserve the current config', () {
      final controller = LocalGameController(
        config: const BoardConfig(size: 7, wallsPerPlayer: 8),
      );
      addTearDown(controller.dispose);
      controller.tapCell(const Cell(row: 5, column: 3));

      controller.restart();
      expect(controller.state.turnNumber, 0);
      expect(controller.state.boardConfig.size, 7);
      expect(controller.state.wallsRemaining(PlayerId.blue), 8);

      controller.tapCell(const Cell(row: 5, column: 3));
      controller.rematch();
      expect(controller.state.turnNumber, 0);
      expect(controller.state.boardConfig.size, 7);
      expect(controller.state.wallsRemaining(PlayerId.red), 8);
    });

    test('setMode clears selected cell and pending wall', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.tapCell(const Cell(row: 0, column: 0));
      expect(controller.selectedCell, const Cell(row: 0, column: 0));

      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
      expect(controller.pendingWall, isNotNull);

      controller.setMode(InteractionMode.move);
      expect(controller.selectedCell, isNull);
      expect(controller.pendingWall, isNull);
    });

    test('tapCell applies a legal move and passes the turn', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      final before = controller.state;

      controller.tapCell(const Cell(row: 7, column: 4));

      expect(controller.state, isNot(before));
      expect(
        controller.state.pawnPosition(PlayerId.blue),
        const Cell(row: 7, column: 4),
      );
      expect(controller.state.turnNumber, 1);
      expect(controller.currentPlayer, PlayerId.red);
      expect(controller.lastFailure, isNull);
    });

    test('tapCell rejects an illegal move without changing state', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      final before = controller.state;

      controller.tapCell(const Cell(row: 0, column: 0));

      expect(controller.state, before);
      expect(controller.lastFailure, ActionFailure.moveNotAdjacent);
    });

    test(
      'confirmation wall flow applies, cancels, and returns to move mode',
      () {
        final controller = LocalGameController();
        addTearDown(controller.dispose);
        controller.setMode(InteractionMode.wall);
        controller.tapWallSlot(
          const Cell(row: 6, column: 5),
          WallOrientation.h,
        );

        expect(controller.pendingWall, isNotNull);
        expect(controller.pendingWallFailure, isNull);
        expect(controller.state.turnNumber, 0);

        controller.cancel();
        expect(controller.pendingWall, isNull);
        expect(controller.state.turnNumber, 0);

        controller.tapWallSlot(
          const Cell(row: 6, column: 5),
          WallOrientation.h,
        );
        controller.confirm();
        expect(controller.pendingWall, isNull);
        expect(controller.state.wallsRemaining(PlayerId.blue), 9);
        expect(controller.state.turnNumber, 1);
        expect(controller.currentPlayer, PlayerId.red);
        expect(controller.mode, InteractionMode.move);
      },
    );

    test('wall mode without confirmation applies a valid wall immediately', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.toggleConfirmWallPlacement();
      controller.setMode(InteractionMode.wall);

      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);

      expect(controller.pendingWall, isNull);
      expect(controller.state.wallsRemaining(PlayerId.blue), 9);
      expect(controller.state.turnNumber, 1);
      expect(controller.mode, InteractionMode.move);
    });

    test('wall mode without confirmation reports an invalid wall', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.toggleConfirmWallPlacement();
      controller.setMode(InteractionMode.wall);
      final before = controller.state;

      controller.tapWallSlot(const Cell(row: 8, column: 0), WallOrientation.h);

      expect(controller.state, before);
      expect(controller.lastFailure, ActionFailure.wallOutOfBounds);
      expect(controller.mode, InteractionMode.wall);
    });

    test('pending wall validity is computed from the current engine state', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.setMode(InteractionMode.wall);

      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
      expect(controller.pendingWallFailure, isNull);

      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.v);
      expect(controller.pendingWallFailure, isNull);

      controller.tapWallSlot(const Cell(row: 8, column: 0), WallOrientation.h);
      expect(controller.pendingWallFailure, ActionFailure.wallOutOfBounds);
    });

    test('pending wall reports overlap and crossing failures', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
      controller.confirm();

      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
      expect(controller.pendingWallFailure, ActionFailure.wallOverlaps);

      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.v);
      expect(controller.pendingWallFailure, ActionFailure.wallCrosses);
    });

    test('pending wall reports a path-blocking failure', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      const moves = [
        Cell(row: 8, column: 3),
        Cell(row: 0, column: 5),
        Cell(row: 8, column: 2),
        Cell(row: 0, column: 6),
        Cell(row: 8, column: 1),
        Cell(row: 0, column: 5),
        Cell(row: 8, column: 0),
        Cell(row: 0, column: 4),
      ];
      for (final move in moves) {
        controller.tapCell(move);
        expect(controller.lastFailure, isNull);
      }
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 7, column: 0), WallOrientation.h);
      controller.confirm();
      controller.setMode(InteractionMode.move);
      controller.tapCell(const Cell(row: 0, column: 3));
      expect(controller.lastFailure, isNull);

      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 7, column: 1), WallOrientation.v);
      expect(controller.pendingWallFailure, ActionFailure.wallBlocksPath);
    });

    test('invalid pending wall cannot be confirmed', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      controller.setMode(InteractionMode.wall);
      controller.tapWallSlot(const Cell(row: 8, column: 0), WallOrientation.h);
      final before = controller.state;

      controller.confirm();

      expect(controller.state, before);
      expect(controller.pendingWall, isNotNull);
      expect(controller.lastFailure, isNull);
    });

    test('dismissResult hides a finished result', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      _replayScriptedGame(controller);
      expect(controller.showingResult, isTrue);

      controller.dismissResult();

      expect(controller.showingResult, isFalse);
      expect(controller.state.status, GameStatus.finished);
    });

    test('finished state locks gameplay inputs but permits rematch', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);
      _replayScriptedGame(controller);
      expect(controller.isFinished, isTrue);
      final finished = controller.state;
      final mode = controller.mode;
      final confirmSetting = controller.confirmWallPlacement;

      controller.setMode(InteractionMode.wall);
      controller.tapCell(const Cell(row: 7, column: 4));
      controller.tapWallSlot(const Cell(row: 6, column: 5), WallOrientation.h);
      controller.confirm();
      controller.cancel();
      controller.toggleConfirmWallPlacement();

      expect(controller.state, finished);
      expect(controller.mode, mode);
      expect(controller.confirmWallPlacement, confirmSetting);

      controller.rematch();
      expect(controller.state.status, GameStatus.inProgress);
      expect(controller.state.turnNumber, 0);
    });

    test('all failure reasons have messages', () {
      const expected = <ActionFailure, String>{
        ActionFailure.matchFinished: 'The game is already over.',
        ActionFailure.wrongTurn: "It's not your turn.",
        ActionFailure.moveOutOfBoard: 'You cannot move off the board.',
        ActionFailure.moveNotAdjacent: 'You can only move to an adjacent cell.',
        ActionFailure.moveBlockedByWall: 'A wall blocks that move.',
        ActionFailure.moveOntoPawn: 'You cannot move onto the opponent.',
        ActionFailure.moveIllegalJump: 'That jump is not allowed.',
        ActionFailure.noWallsRemaining: 'You have no walls left.',
        ActionFailure.wallOutOfBounds: 'Wall placement is out of bounds.',
        ActionFailure.wallOverlaps: 'Wall overlaps an existing wall.',
        ActionFailure.wallCrosses: 'Wall crosses an existing wall.',
        ActionFailure.wallBlocksPath:
            "Wall would block a player's path to goal.",
      };

      for (final entry in expected.entries) {
        expect(LocalGameController.failureMessage(entry.key), entry.value);
      }
    });

    test('scripted game through controller matches §16 JSON', () {
      final controller = LocalGameController();
      addTearDown(controller.dispose);

      _replayScriptedGame(controller);

      expect(GameStateSerializer.toJson(controller.state), {
        'schemaVersion': 1,
        'boardConfig': {'size': 9, 'wallsPerPlayer': 10},
        'players': ['blue', 'red'],
        'currentPlayer': 'red',
        'pawnPositions': {
          'blue': {'row': 0, 'column': 5},
          'red': {'row': 6, 'column': 4},
        },
        'walls': [
          {
            'owner': 'red',
            'orientation': 'V',
            'anchor': {'row': 6, 'column': 3},
          },
          {
            'owner': 'blue',
            'orientation': 'H',
            'anchor': {'row': 6, 'column': 5},
          },
          {
            'owner': 'red',
            'orientation': 'H',
            'anchor': {'row': 1, 'column': 3},
          },
        ],
        'remainingWalls': {'blue': 9, 'red': 8},
        'turnNumber': 17,
        'status': 'finished',
        'winner': 'blue',
      });
    });

    group('300 seeded controller property games', () {
      for (var seed = 0; seed < 300; seed++) {
        test('seed $seed preserves engine state and rejects illegal input', () {
          final random = Random(seed);
          final controller = LocalGameController();
          addTearDown(controller.dispose);
          var expected = GameState.initial();

          for (var step = 0; step < 60; step++) {
            if (expected.status == GameStatus.finished) break;
            final legal = GameEngine.legalActions(expected);
            final useLegal = random.nextBool() && legal.isNotEmpty;
            final action = useLegal
                ? legal[random.nextInt(legal.length)]
                : _illegalAction(expected, random);
            final independent = GameEngine.apply(
              expected,
              expected.currentPlayer,
              action,
            );

            switch (action) {
              case MoveAction(:final destination):
                controller.setMode(InteractionMode.move);
                expect(controller.state, expected);
                controller.tapCell(destination);
              case WallAction(:final orientation, :final anchor):
                controller.setMode(InteractionMode.wall);
                expect(controller.state, expected);
                controller.tapWallSlot(anchor, orientation);
                expect(controller.state, expected);
                controller.confirm();
            }

            if (independent is SuccessResult) {
              expected = independent.state;
            }
            expect(controller.state, expected);
          }
        });
      }
    });
  });
}

GameAction _illegalAction(GameState state, Random random) {
  final size = state.boardConfig.size;
  if (random.nextBool()) {
    return GameAction.move(
      Cell(row: size + random.nextInt(3), column: random.nextInt(size + 2)),
    );
  }
  return GameAction.wall(
    orientation: random.nextBool() ? WallOrientation.h : WallOrientation.v,
    anchor: Cell(
      row: size + random.nextInt(3),
      column: size + random.nextInt(3),
    ),
  );
}

void _replayScriptedGame(LocalGameController controller) {
  const actions = <(PlayerId, GameAction)>[
    (PlayerId.blue, GameAction.move(Cell(row: 7, column: 4))),
    (PlayerId.red, GameAction.move(Cell(row: 1, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 6, column: 4))),
    (PlayerId.red, GameAction.move(Cell(row: 2, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 5, column: 4))),
    (
      PlayerId.red,
      GameAction.wall(
        orientation: WallOrientation.v,
        anchor: Cell(row: 6, column: 3),
      ),
    ),
    (
      PlayerId.blue,
      GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 6, column: 5),
      ),
    ),
    (PlayerId.red, GameAction.move(Cell(row: 3, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 4, column: 4))),
    (
      PlayerId.red,
      GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 1, column: 3),
      ),
    ),
    (PlayerId.blue, GameAction.move(Cell(row: 2, column: 4))),
    (PlayerId.red, GameAction.move(Cell(row: 4, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 2, column: 5))),
    (PlayerId.red, GameAction.move(Cell(row: 5, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 1, column: 5))),
    (PlayerId.red, GameAction.move(Cell(row: 6, column: 4))),
    (PlayerId.blue, GameAction.move(Cell(row: 0, column: 5))),
  ];

  for (final (player, action) in actions) {
    expect(controller.currentPlayer, player);
    switch (action) {
      case MoveAction(:final destination):
        controller.tapCell(destination);
      case WallAction(:final orientation, :final anchor):
        controller.setMode(InteractionMode.wall);
        controller.tapWallSlot(anchor, orientation);
        controller.confirm();
    }
  }
}
