import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/feedback/feedback_timing.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/player_id.dart';
import '../../domain/models/wall.dart';

/// One frame of board animation, in model terms (Phase 12).
///
/// The painter interprets this against the board geometry; every field
/// is null when its effect is not playing, so an idle frame renders
/// exactly the pre-Phase-12 board.
class BoardAnimFrame {
  const BoardAnimFrame({
    this.pawnMove,
    this.wallIn,
    this.glowPulse,
    this.goalPulse,
    this.victory,
    this.selection,
  });

  /// A pawn translating between cells: raw progress 0..1 over
  /// [FeedbackTiming.pawnMovement]. The landing bounce is derived from
  /// the final portion of the progress by the painter.
  final ({PlayerId player, Cell from, Cell to, double t})? pawnMove;

  /// A wall scaling/fading into place over
  /// [FeedbackTiming.wallPlacement].
  final ({Wall wall, double t})? wallIn;

  /// The active pawn's glow swelling once over
  /// [FeedbackTiming.turnGlowPulse] (`design.md` §8's pulse, applied at
  /// the state change per §24 rather than perpetually).
  final ({PlayerId player, double t})? glowPulse;

  /// A goal strip swelling once over
  /// [FeedbackTiming.goalProximityPulse] (§7: goal animation on
  /// proximity). [top] is Blue's strip (row 0), otherwise Red's.
  final ({bool top, double t})? goalPulse;

  /// The victory celebration over [FeedbackTiming.victory]: the winning
  /// pawn's bounce and its goal strip's swell (§7/§8).
  final ({PlayerId winner, double t})? victory;

  /// The selection ring fading in over [FeedbackTiming.microFeedback]
  /// (§8's stronger ring for the selected cell).
  final ({Cell cell, double t})? selection;

  /// Whether any effect is mid-flight.
  bool get isActive =>
      pawnMove != null ||
      wallIn != null ||
      glowPulse != null ||
      goalPulse != null ||
      victory != null ||
      selection != null;
}

enum _Kind { pawnMove, wallIn, glowPulse, goalPulse, victory, selection }

class _Effect {
  _Effect(this.kind, this.start, this.duration, this.data);

  final _Kind kind;
  final Duration start;
  final Duration duration;

  /// Kind-specific payload: pawnMove → (PlayerId, Cell, Cell);
  /// wallIn → Wall; glowPulse → PlayerId; goalPulse → bool (top);
  /// victory → PlayerId; selection → Cell.
  final Object data;

  double progressAt(Duration now) {
    if (duration == Duration.zero) return 1;
    final t = (now - start).inMicroseconds / duration.inMicroseconds;
    return t.clamp(0.0, 1.0);
  }

  bool isDoneAt(Duration now) => now - start >= duration;
}

/// Drives the board's one-shot animations (Phase 12).
///
/// A single ticker runs only while at least one effect is in flight, so
/// an idle board costs no frames (`rules.md` §16). Effects react to
/// state transitions the widget already observed — the animator never
/// causes engine work, never runs pathfinding, and never feeds back
/// into game state: `GameState` is always the source of truth, and if a
/// new transition arrives mid-animation the old effect is simply
/// replaced, so rapid play can never desync the picture from the state.
class BoardAnimator extends ChangeNotifier {
  BoardAnimator(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  final List<_Effect> _effects = [];

  /// The animation clock, in ticker time: [_base] accumulates the
  /// elapsed of every finished ticker run, [_tickElapsed] is the
  /// current run's. Ticker time (not wall time) is what a frame clock
  /// should be — it pauses with the frame loop and is deterministic
  /// under test.
  Duration _base = Duration.zero;
  Duration _tickElapsed = Duration.zero;

  Duration get _now => _base + _tickElapsed;

  /// Whether any effect is in flight (the ticker is running).
  bool get isAnimating => _ticker.isActive;

  void _onTick(Duration elapsed) {
    _tickElapsed = elapsed;
    _effects.removeWhere((e) => e.isDoneAt(_now));
    if (_effects.isEmpty) {
      _ticker.stop();
      _base += elapsed;
      _tickElapsed = Duration.zero;
    }
    notifyListeners();
  }

  void _play(_Kind kind, Duration duration, Object data) {
    if (duration == Duration.zero) return;
    _effects.removeWhere((e) => e.kind == kind);
    _effects.add(_Effect(kind, _now, duration, data));
    if (!_ticker.isActive) _ticker.start();
    notifyListeners();
  }

  /// A pawn moved from one cell to another.
  void playPawnMove(PlayerId player, Cell from, Cell to) =>
      _play(_Kind.pawnMove, FeedbackTiming.pawnMovement, (player, from, to));

  /// A wall was placed.
  void playWallIn(Wall wall) =>
      _play(_Kind.wallIn, FeedbackTiming.wallPlacement, wall);

  /// The turn changed: pulse the new active pawn's glow once.
  void playGlowPulse(PlayerId player) =>
      _play(_Kind.glowPulse, FeedbackTiming.turnGlowPulse, player);

  /// A pawn reached the row next to its goal: pulse that goal strip.
  void playGoalPulse({required bool top}) =>
      _play(_Kind.goalPulse, FeedbackTiming.goalProximityPulse, top);

  /// The match was won: celebrate the winning pawn and its goal strip.
  void playVictory(PlayerId winner) =>
      _play(_Kind.victory, FeedbackTiming.victory, winner);

  /// A cell was selected: fade its ring in.
  void playSelection(Cell cell) =>
      _play(_Kind.selection, FeedbackTiming.microFeedback, cell);

  /// Drops every effect (reduced motion: the end state applies at once).
  void clear() {
    if (_effects.isEmpty) return;
    _effects.clear();
    if (_ticker.isActive) {
      _ticker.stop();
      _base += _tickElapsed;
      _tickElapsed = Duration.zero;
    }
    notifyListeners();
  }

  /// The current frame, computed from the effects in flight.
  BoardAnimFrame frame() {
    if (_effects.isEmpty) return const BoardAnimFrame();
    final now = _now;
    ({PlayerId player, Cell from, Cell to, double t})? pawnMove;
    ({Wall wall, double t})? wallIn;
    ({PlayerId player, double t})? glowPulse;
    ({bool top, double t})? goalPulse;
    ({PlayerId winner, double t})? victory;
    ({Cell cell, double t})? selection;
    for (final e in _effects) {
      final t = e.progressAt(now);
      switch (e.kind) {
        case _Kind.pawnMove:
          final d = e.data as (PlayerId, Cell, Cell);
          pawnMove = (player: d.$1, from: d.$2, to: d.$3, t: t);
        case _Kind.wallIn:
          wallIn = (wall: e.data as Wall, t: t);
        case _Kind.glowPulse:
          glowPulse = (player: e.data as PlayerId, t: t);
        case _Kind.goalPulse:
          goalPulse = (top: e.data as bool, t: t);
        case _Kind.victory:
          victory = (winner: e.data as PlayerId, t: t);
        case _Kind.selection:
          selection = (cell: e.data as Cell, t: t);
      }
    }
    return BoardAnimFrame(
      pawnMove: pawnMove,
      wallIn: wallIn,
      glowPulse: glowPulse,
      goalPulse: goalPulse,
      victory: victory,
      selection: selection,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
