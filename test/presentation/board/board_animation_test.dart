import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/core/feedback/feedback_backends.dart';
import 'package:wallforge/core/feedback/feedback_controller.dart';
import 'package:wallforge/core/feedback/feedback_scope.dart';
import 'package:wallforge/core/feedback/feedback_timing.dart';
import 'package:wallforge/domain/engine/game_engine.dart';
import 'package:wallforge/domain/models/cell.dart';
import 'package:wallforge/domain/models/game_action.dart';
import 'package:wallforge/domain/models/game_state.dart';
import 'package:wallforge/domain/models/game_status.dart';
import 'package:wallforge/domain/models/player_id.dart';
import 'package:wallforge/domain/models/wall_orientation.dart';
import 'package:wallforge/domain/repositories/app_settings.dart';
import 'package:wallforge/presentation/board/board.dart';

/// Applies one legal action or fails the test.
GameState apply(GameState state, GameAction action) {
  final result = GameEngine.apply(state, state.currentPlayer, action);
  expect(result, isA<SuccessResult>());
  return (result as SuccessResult).state;
}

/// The spec's scripted game, applied through the engine only.
GameState stateAfterPlies(int plies) {
  const script = <GameAction>[
    GameAction.move(Cell(row: 7, column: 4)),
    GameAction.move(Cell(row: 1, column: 4)),
    GameAction.move(Cell(row: 6, column: 4)),
    GameAction.move(Cell(row: 2, column: 4)),
    GameAction.move(Cell(row: 5, column: 4)),
    GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 6, column: 3),
    ),
    GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 6, column: 5),
    ),
    GameAction.move(Cell(row: 3, column: 4)),
    GameAction.move(Cell(row: 4, column: 4)),
    GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: 1, column: 3),
    ),
    GameAction.move(Cell(row: 2, column: 4)),
    GameAction.move(Cell(row: 4, column: 4)),
    GameAction.move(Cell(row: 2, column: 5)),
    GameAction.move(Cell(row: 5, column: 4)),
    GameAction.move(Cell(row: 1, column: 5)),
    GameAction.move(Cell(row: 6, column: 4)),
    GameAction.move(Cell(row: 0, column: 5)),
  ];
  var state = GameState.initial();
  for (var i = 0; i < plies; i++) {
    state = apply(state, script[i]);
  }
  return state;
}

class _NoopSound implements SoundBackend {
  @override
  Future<void> playEffect(String asset, double volume) async {}
  @override
  Future<void> startMusic(String asset, double volume) async {}
  @override
  Future<void> stopMusic() async {}
  @override
  Future<void> setMusicVolume(double volume) async {}
  @override
  void dispose() {}
}

class _NoopHaptics implements HapticsBackend {
  const _NoopHaptics();
  @override
  void light() {}
  @override
  void medium() {}
  @override
  void heavy() {}
  @override
  void selection() {}
}

void main() {
  Widget board(
    GameState state, {
    bool platformReduced = false,
    FeedbackController? feedback,
    void Function(Cell)? onCellTap,
  }) {
    Widget child = Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: BoardView(
            state: state,
            activeGlow: state.status == GameStatus.inProgress
                ? state.currentPlayer
                : null,
            onCellTap: onCellTap,
          ),
        ),
      ),
    );
    if (platformReduced) {
      child = MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: child,
      );
    }
    final app = MaterialApp(home: child);
    return feedback == null
        ? app
        : FeedbackScope(controller: feedback, child: app);
  }

  BoardPainter painter(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(BoardView),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as BoardPainter;

  group('board animations', () {
    testWidgets('a pawn move animates within the §24 band, then rests', (
      tester,
    ) async {
      final s0 = GameState.initial();
      final s1 = stateAfterPlies(1);
      await tester.pumpWidget(board(s0));
      await tester.pumpWidget(board(s1));
      await tester.pump();

      final animator = painter(tester).animator!;
      final frame = animator.frame();
      expect(frame.pawnMove, isNotNull);
      expect(frame.pawnMove!.player, PlayerId.blue);
      expect(frame.pawnMove!.from, const Cell(row: 8, column: 4));
      expect(frame.pawnMove!.to, const Cell(row: 7, column: 4));
      expect(animator.isAnimating, isTrue);

      // Still in flight halfway through the 350 ms band value.
      await tester.pump(const Duration(milliseconds: 175));
      expect(animator.frame().pawnMove, isNotNull);
      expect(animator.frame().pawnMove!.t, inInclusiveRange(0.3, 0.7));

      // Done (and the ticker stopped) once the duration has passed.
      await tester.pump(const Duration(milliseconds: 250));
      expect(animator.frame().pawnMove, isNull);
      expect(animator.isAnimating, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wall placement animates the new wall only', (tester) async {
      final s0 = stateAfterPlies(5);
      final s1 = stateAfterPlies(6); // Red places a vertical wall.
      await tester.pumpWidget(board(s0));
      await tester.pumpWidget(board(s1));
      await tester.pump();

      final animator = painter(tester).animator!;
      expect(animator.frame().wallIn, isNotNull);
      expect(animator.frame().wallIn!.wall.anchorRow, 6);
      expect(animator.frame().wallIn!.wall.anchorColumn, 3);
      await tester.pump(FeedbackTiming.wallPlacement);
      await tester.pump(const Duration(milliseconds: 50));
      expect(animator.frame().wallIn, isNull);
    });

    testWidgets('the turn change pulses the new active pawn glow', (
      tester,
    ) async {
      await tester.pumpWidget(board(GameState.initial()));
      await tester.pumpWidget(board(stateAfterPlies(1)));
      await tester.pump();
      final frame = painter(tester).animator!.frame();
      expect(frame.glowPulse, isNotNull);
      expect(frame.glowPulse!.player, PlayerId.red);
    });

    testWidgets('victory celebrates the winner within the §24 band', (
      tester,
    ) async {
      final before = stateAfterPlies(16);
      final finished = stateAfterPlies(17);
      expect(finished.status, GameStatus.finished);
      await tester.pumpWidget(board(before));
      await tester.pumpWidget(board(finished));
      await tester.pump();

      final animator = painter(tester).animator!;
      expect(animator.frame().victory, isNotNull);
      expect(animator.frame().victory!.winner, PlayerId.blue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(animator.frame().victory, isNotNull);
      await tester.pump(const Duration(milliseconds: 400));
      expect(animator.frame().victory, isNull);
      expect(animator.isAnimating, isFalse);
    });

    testWidgets('a multi-ply jump (resume/catch-up) animates nothing', (
      tester,
    ) async {
      await tester.pumpWidget(board(GameState.initial()));
      await tester.pumpWidget(board(stateAfterPlies(5)));
      await tester.pump();
      final frame = painter(tester).animator!.frame();
      expect(frame.pawnMove, isNull);
      expect(frame.wallIn, isNull);
    });

    testWidgets('rapid moves replace the animation and never desync', (
      tester,
    ) async {
      await tester.pumpWidget(board(GameState.initial()));
      await tester.pumpWidget(board(stateAfterPlies(1)));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpWidget(board(stateAfterPlies(2)));
      await tester.pump();

      final animator = painter(tester).animator!;
      // The in-flight effect is the *latest* move, and the painter's
      // state is the latest state: the animation follows the state,
      // never the other way round.
      expect(animator.frame().pawnMove!.player, PlayerId.red);
      expect(painter(tester).state, stateAfterPlies(2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(animator.frame().isActive, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('input still lands during an animation', (tester) async {
      Cell? tapped;
      await tester.pumpWidget(
        board(GameState.initial(), onCellTap: (c) => tapped = c),
      );
      await tester.pumpWidget(
        board(stateAfterPlies(1), onCellTap: (c) => tapped = c),
      );
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(
        find.descendant(
          of: find.byType(BoardView),
          matching: find.byType(CustomPaint),
        ),
      );
      expect(tapped, isNotNull);
    });
  });

  group('reduced motion (§2: either signal is enough)', () {
    testWidgets('the platform signal skips every animation', (tester) async {
      await tester.pumpWidget(
        board(GameState.initial(), platformReduced: true),
      );
      await tester.pumpWidget(board(stateAfterPlies(1), platformReduced: true));
      await tester.pump();
      final animator = painter(tester).animator!;
      expect(animator.frame().isActive, isFalse);
      expect(animator.isAnimating, isFalse);
    });

    testWidgets('the in-app toggle skips every animation', (tester) async {
      final feedback = FeedbackController(
        _NoopSound(),
        const _NoopHaptics(),
        const AppSettings(reducedMotion: true),
      );
      await tester.pumpWidget(board(GameState.initial(), feedback: feedback));
      await tester.pumpWidget(board(stateAfterPlies(1), feedback: feedback));
      await tester.pump();
      final animator = painter(tester).animator!;
      expect(animator.frame().isActive, isFalse);
      expect(animator.isAnimating, isFalse);
    });

    testWidgets('FeedbackScope combines the two signals independently', (
      tester,
    ) async {
      Future<bool> probe({required bool platform, required bool inApp}) async {
        bool? seen;
        final feedback = FeedbackController(
          _NoopSound(),
          const _NoopHaptics(),
          AppSettings(reducedMotion: inApp),
        );
        await tester.pumpWidget(
          FeedbackScope(
            controller: feedback,
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: platform),
                child: Builder(
                  builder: (context) {
                    seen = FeedbackScope.reducedMotionActive(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        );
        return seen!;
      }

      expect(await probe(platform: false, inApp: false), isFalse);
      expect(await probe(platform: true, inApp: false), isTrue);
      expect(await probe(platform: false, inApp: true), isTrue);
      expect(await probe(platform: true, inApp: true), isTrue);
    });
  });

  group('performance profile (rules.md §16)', () {
    testWidgets('a flurry of rapid moves stays correct and drains', (
      tester,
    ) async {
      final watch = Stopwatch()..start();
      await tester.pumpWidget(board(GameState.initial()));
      // Twelve plies arriving every 50 ms — far faster than any
      // animation: each new transition replaces the in-flight effect.
      for (var ply = 1; ply <= 12; ply++) {
        await tester.pumpWidget(board(stateAfterPlies(ply)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(milliseconds: 600));
      watch.stop();

      final animator = painter(tester).animator!;
      expect(painter(tester).state, stateAfterPlies(12));
      expect(animator.frame().isActive, isFalse);
      expect(animator.isAnimating, isFalse);
      expect(tester.takeException(), isNull);
      // The whole flurry (13 board builds + ~25 animation frames of
      // real rendering on this machine) must stay cheap; the bound is
      // deliberately generous so it catches pathology, not noise.
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    });
  });
}
