/// Board configuration.
///
/// Mirrors spec §2: size (odd ≥ 5) and wallsPerPlayer (≥ 0).
class BoardConfig {
  /// Creates a board configuration.
  const BoardConfig({this.size = 9, this.wallsPerPlayer = 10})
      : assert(size >= 5, 'size must be >= 5'),
        assert(wallsPerPlayer >= 0, 'wallsPerPlayer must be >= 0');

  /// Board dimension (NxN grid). MUST be odd and >= 5.
  final int size;

  /// Number of walls each player starts with.
  final int wallsPerPlayer;

  /// Blue start cell: (size-1, size~/2).
  (int, int) get blueStart => (size - 1, size ~/ 2);

  /// Red start cell: (0, size~/2).
  (int, int) get redStart => (0, size ~/ 2);

  /// Blue goal row: 0.
  int get blueGoalRow => 0;

  /// Red goal row: size-1.
  int get redGoalRow => size - 1;

  /// Anchor range: 0..size-2 on both axes.
  int get maxAnchor => size - 2;

  /// Total wall slots: 2 * (size-1)^2.
  int get totalWallSlots => 2 * (size - 1) * (size - 1);

  /// Validates this config. Returns null if valid, error string otherwise.
  static String? validate(int size, int wallsPerPlayer) {
    if (size < 5) return 'size must be >= 5';
    if (size.isOdd != true) return 'size must be odd';
    if (wallsPerPlayer < 0) return 'wallsPerPlayer must be >= 0';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardConfig &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          wallsPerPlayer == other.wallsPerPlayer;

  @override
  int get hashCode => Object.hash(size, wallsPerPlayer);

  @override
  String toString() =>
      'BoardConfig(size: $size, wallsPerPlayer: $wallsPerPlayer)';
}
