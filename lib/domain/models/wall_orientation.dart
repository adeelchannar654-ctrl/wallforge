/// Orientation of a wall piece on the board.
///
/// Mirrors spec §3.6 R-WALL-01.
enum WallOrientation {
  /// Horizontal wall: lies on grid line below row r, spanning columns c and c+1.
  h,

  /// Vertical wall: lies on grid line to the right of column c, spanning rows r and r+1.
  v;
}
