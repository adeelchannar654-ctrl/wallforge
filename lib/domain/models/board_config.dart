/// Immutable board geometry constants.
///
/// Mirrors spec §4.1: rows=10, cols=10, totalWalls=10, maxWallsPerPlayer=5.
class BoardConfig {
  /// Standard 10x10 board.
  const BoardConfig({
    this.rows = 10,
    this.cols = 10,
    this.totalWalls = 10,
    this.maxWallsPerPlayer = 5,
  });

  /// Number of rows.
  final int rows;

  /// Number of columns.
  final int cols;

  /// Total wall count in a standard match.
  final int totalWalls;

  /// Max walls each player may hold initially (spec §4.1).
  final int maxWallsPerPlayer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardConfig &&
          runtimeType == other.runtimeType &&
          rows == other.rows &&
          cols == other.cols &&
          totalWalls == other.totalWalls &&
          maxWallsPerPlayer == other.maxWallsPerPlayer;

  @override
  int get hashCode => Object.hash(rows, cols, totalWalls, maxWallsPerPlayer);

  @override
  String toString() =>
      'BoardConfig(rows=$rows, cols=$cols, totalWalls=$totalWalls, '
      'maxWallsPerPlayer=$maxWallsPerPlayer)';
}
