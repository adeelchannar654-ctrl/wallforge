/// Structured reason a [BoardConfig] is invalid.
enum ConfigFailureReason {
  /// Board size is below the minimum (5).
  sizeTooSmall,

  /// Board size is even (must be odd).
  sizeEven,

  /// Negative wall inventory.
  negativeWalls,
}

/// A structured board-configuration validation failure.
class ConfigFailure {
  /// Creates a config failure.
  const ConfigFailure(this.reason, this.message);

  /// Machine-readable reason.
  final ConfigFailureReason reason;

  /// Human-readable explanation.
  final String message;

  @override
  String toString() => 'ConfigFailure(${reason.name}: $message)';
}

/// Board configuration.
///
/// Mirrors spec §2: size (odd >= 5) and wallsPerPlayer (>= 0).
///
/// The const constructor does **not** validate (it cannot, because `assert`
/// is disabled in release builds). Use [BoardConfig.check],
/// [BoardConfig.validated] or [GameState.initial] when the values come from
/// untrusted input.
class BoardConfig {
  /// Creates a board configuration without validation.
  ///
  /// Prefer [BoardConfig.validated] or [BoardConfig.check] for untrusted input.
  const BoardConfig({this.size = 9, this.wallsPerPlayer = 10});

  /// Creates a board configuration, throwing [ArgumentError] if invalid.
  factory BoardConfig.validated({int size = 9, int wallsPerPlayer = 10}) {
    final failure = check(size, wallsPerPlayer);
    if (failure != null) {
      throw ArgumentError(failure.message);
    }
    return BoardConfig(size: size, wallsPerPlayer: wallsPerPlayer);
  }

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

  /// Structured validation of a size/wallsPerPlayer pair.
  ///
  /// Returns `null` when the pair is valid.
  static ConfigFailure? check(int size, int wallsPerPlayer) {
    if (size < 5) {
      return const ConfigFailure(
        ConfigFailureReason.sizeTooSmall,
        'size must be >= 5',
      );
    }
    if (size.isOdd != true) {
      return const ConfigFailure(
        ConfigFailureReason.sizeEven,
        'size must be odd',
      );
    }
    if (wallsPerPlayer < 0) {
      return const ConfigFailure(
        ConfigFailureReason.negativeWalls,
        'wallsPerPlayer must be >= 0',
      );
    }
    return null;
  }

  /// Validates this config. Returns null if valid, error string otherwise.
  static String? validate(int size, int wallsPerPlayer) =>
      check(size, wallsPerPlayer)?.message;

  /// This instance's validation failure, or `null` when valid.
  ConfigFailure? get failure => check(size, wallsPerPlayer);

  /// Whether this instance is a valid board configuration.
  bool get isValid => failure == null;

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
