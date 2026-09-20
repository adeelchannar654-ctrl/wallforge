/// Current status of a match.
///
/// Mirrors spec §4.8.
enum GameStatus {
  /// Match not yet started (awaiting both players).
  waitingForPlayers,

  /// Both players connected, Blue to move.
  active,

  /// Blue won.
  blueWins,

  /// Red won.
  redWins,

  /// Game over, no winner possible.
  draw,
}
