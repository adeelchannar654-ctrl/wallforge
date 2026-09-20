/// Current status of a match.
///
/// Mirrors spec §6.1: inProgress or finished.
enum GameStatus {
  /// Game is in progress.
  inProgress,

  /// Game is finished (a player won).
  finished,
}
