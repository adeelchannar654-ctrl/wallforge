import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/game_interaction.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/core/feedback/feedback_backends.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/core/feedback/feedback_timing.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/domain/repositories/unfinished_match.dart';

class FakeSoundBackend implements SoundBackend {
  final List<String> effects = [];
  int musicStarts = 0;

  @override
  Future<void> playEffect(String asset, double volume) async {
    effects.add(asset);
  }

  @override
  Future<void> startMusic(String asset, double volume) async {
    musicStarts++;
  }

  @override
  Future<void> stopMusic() async {}

  @override
  Future<void> setMusicVolume(double volume) async {}

  @override
  void dispose() {}
}

class FakeHapticsBackend implements HapticsBackend {
  final List<String> calls = [];

  @override
  void light() => calls.add('light');

  @override
  void medium() => calls.add('medium');

  @override
  void heavy() => calls.add('heavy');

  @override
  void selection() => calls.add('selection');
}

void main() {
  late FakeSoundBackend sound;
  late FakeHapticsBackend haptics;

  LocalGameController wired({bool versusAi = false}) {
    sound = FakeSoundBackend();
    haptics = FakeHapticsBackend();
    final controller = LocalGameController(versusAi: versusAi);
    controller.feedback = FeedbackController(sound, haptics);
    return controller;
  }

  group('LocalGameController cues', () {
    test('a legal pawn move fires the move cue exactly once', () {
      final c = wired();
      c.tapCell(const Cell(row: 7, column: 4));
      expect(sound.effects, [FeedbackAssets.move]);
      expect(haptics.calls, ['light']);
    });

    test('an illegal move fires the invalid cue and no move cue', () {
      final c = wired();
      c.tapCell(const Cell(row: 0, column: 0));
      expect(sound.effects, [FeedbackAssets.invalidAction]);
      expect(haptics.calls, ['heavy']);
    });

    test('staging a wall fires nothing; confirming it fires the wall cue', () {
      final c = wired();
      c.setMode(InteractionMode.wall);
      c.tapWallSlot(const Cell(row: 7, column: 3), WallOrientation.h);
      expect(sound.effects, isEmpty, reason: 'nothing is placed yet');
      c.confirm();
      expect(sound.effects, [FeedbackAssets.wallPlaced]);
    });

    test('with confirmation off, the wall cue fires on the tap', () {
      final c = wired();
      c.toggleConfirmWallPlacement();
      c.setMode(InteractionMode.wall);
      c.tapWallSlot(const Cell(row: 7, column: 3), WallOrientation.h);
      expect(sound.effects, [FeedbackAssets.wallPlaced]);
    });

    test('an illegal wall fires the invalid cue', () {
      final c = wired();
      c.toggleConfirmWallPlacement();
      c.setMode(InteractionMode.wall);
      // A wall anchored off the board's wall grid is refused by the engine.
      c.tapWallSlot(const Cell(row: 8, column: 8), WallOrientation.h);
      expect(sound.effects, [FeedbackAssets.invalidAction]);
    });

    test('the winning move fires move then victory, each once', () {
      // Play the spec's scripted game up to the last ply, adopt that
      // state, and make the winning move through the real tap path.
      const script = <(PlayerId, GameAction)>[
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
      ];
      var state = GameState.initial();
      for (final (side, action) in script) {
        state = (GameEngine.apply(state, side, action) as SuccessResult).state;
      }
      final c = wired();
      final adopted = c.resumeMatch(
        UnfinishedMatch(
          gameState: state,
          boardSize: 9,
          versusAi: false,
          aiDifficulty: 'local',
          savedAtTurn: state.turnNumber,
        ),
      );
      expect(adopted, isTrue);
      c.tapCell(const Cell(row: 0, column: 5));
      expect(sound.effects, [FeedbackAssets.move, FeedbackAssets.victory]);
    });

    test(
      'the AI returning the turn fires the turn cue, not a second move',
      () async {
        final c = wired(versusAi: true);
        c.tapCell(const Cell(row: 7, column: 4));
        expect(sound.effects, [FeedbackAssets.move]);
        // The AI "thinks" for kAiThinkDelay (300 ms) before playing.
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(sound.effects, [FeedbackAssets.move, FeedbackAssets.turnChange]);
        c.dispose();
      },
    );
  });
}
