// The public constructor parameter names are the API while the
// fields stay private, so initializing formals cannot be used.
// ignore_for_file: prefer_initializing_formals
import '../../domain/models/player_id.dart';

/// A per-move countdown (Phase 16.5): one turn at a time, driven
/// entirely by an injected clock so every behaviour — expiry,
/// pause, resume — is deterministic under test.
///
/// The clock is a rule of the match layer, not of the engine:
/// it never touches `GameState`. Its owner (a game controller)
/// starts a turn, ticks it from a 1 Hz timer that exists only
/// while a turn is in flight, and is told through [onTimeout]
/// when the turn's time is gone.
///
/// Pause semantics (D16.5-4): pausing freezes the remaining
/// time; resuming re-arms from exactly that remainder. Nothing
/// about the wall clock leaks across a pause.
class MatchClock {
  MatchClock({
    required DateTime Function() now,
    required void Function(PlayerId side) onTimeout,
  }) : _now = now,
       _onTimeout = onTimeout;

  final DateTime Function() _now;
  final void Function(PlayerId side) _onTimeout;

  PlayerId? _side;
  DateTime? _deadline;
  Duration _frozenRemaining = Duration.zero;
  bool _paused = false;
  bool _fired = false;

  /// The side whose turn is being timed, or null when idle.
  PlayerId? get side => _side;

  /// Whether a turn is currently being timed (paused included).
  bool get isArmed => _side != null;

  /// Whether the countdown is frozen by a pause.
  bool get isPaused => _paused;

  /// Time left for the current turn, clamped at zero; null when
  /// no turn is being timed.
  Duration? get remaining {
    if (_side == null) return null;
    if (_paused) return _frozenRemaining;
    final deadline = _deadline;
    if (deadline == null) return null;
    final left = deadline.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Starts timing [side]'s turn with the full [limit].
  void startTurn(PlayerId side, Duration limit) {
    _side = side;
    _fired = false;
    _paused = false;
    _deadline = _now().add(limit);
  }

  /// Stops timing entirely (match over, clock off, AI's turn).
  void stop() {
    _side = null;
    _deadline = null;
    _paused = false;
    _fired = false;
  }

  /// Freezes the countdown (the app was backgrounded).
  void pause() {
    if (_side == null || _paused) return;
    _frozenRemaining = remaining ?? Duration.zero;
    _paused = true;
  }

  /// Resumes from the frozen remainder.
  void resume() {
    if (!_paused) return;
    _deadline = _now().add(_frozenRemaining);
    _paused = false;
  }

  /// Advances the clock: fires [onTimeout] exactly once when the
  /// deadline has been reached. Called by the owner's 1 Hz
  /// timer; a paused or idle clock does nothing.
  void tick() {
    if (_paused || _fired) return;
    final deadline = _deadline;
    final side = _side;
    if (deadline == null || side == null) return;
    if (!_now().isBefore(deadline)) {
      _fired = true;
      _onTimeout(side);
    }
  }
}
