/// Named animation durations for the whole app (Phase 12).
///
/// Every value sits inside one of the conceptual bands `design.md` §24
/// declares; §24 leaves the exact tuning to implementation, and this class
/// is where that tuning lives — one set of constants, never magic numbers
/// scattered through widgets.
abstract final class FeedbackTiming {
  /// Micro feedback (band 100–180 ms): button-press response, the
  /// selection ring fading in.
  static const Duration microFeedback = Duration(milliseconds: 140);

  /// UI transition (band 180–300 ms): screen-to-screen transitions, the
  /// turn banner switching.
  static const Duration uiTransition = Duration(milliseconds: 240);

  /// Pawn movement (band 250–450 ms): a pawn translating between cells,
  /// including its landing bounce in the final portion.
  static const Duration pawnMovement = Duration(milliseconds: 350);

  /// Wall placement (band 180–300 ms): a placed wall scaling/fading into
  /// its final position.
  static const Duration wallPlacement = Duration(milliseconds: 240);

  /// Victory (band 500–1000 ms): the goal celebration.
  static const Duration victory = Duration(milliseconds: 750);

  /// The active pawn's glow swelling once when the turn changes (the
  /// "slight glow/pulse" of `design.md` §8, applied as a state-change
  /// pulse per §24's purposeful rule, not a perpetual animation).
  /// Priced in the UI-transition band.
  static const Duration turnGlowPulse = Duration(milliseconds: 300);

  /// The goal strip swelling once when a pawn reaches the row next to
  /// its goal (`design.md` §7: goal animation on proximity). Priced at
  /// the victory band's floor because it is goal communication.
  static const Duration goalProximityPulse = Duration(milliseconds: 500);

  /// What reduced motion resolves every visual animation to: the end
  /// state, applied instantly. Recorded decision (`memory.md` §13t):
  /// "reduced" means *skip*, consistently, mirroring how Flutter itself
  /// treats `MediaQuery.disableAnimations`.
  static const Duration reduced = Duration.zero;
}

/// The bundled audio assets (Phase 12), synthesized for this project by
/// `tool/audio/generate_audio.py` and released under CC0 — see
/// `assets/audio/LICENCE.txt`. Paths are relative to `assets/`, as the
/// audio backend's asset source expects.
abstract final class FeedbackAssets {
  static const String move = 'audio/move.wav';
  static const String wallPlaced = 'audio/wall.wav';
  static const String invalidAction = 'audio/invalid.wav';
  static const String turnChange = 'audio/turn.wav';
  static const String victory = 'audio/victory.wav';
  static const String buttonPress = 'audio/button.wav';
  static const String music = 'audio/music.mp3';
}
