import 'board_config.dart';
import 'cell.dart';
import 'game_status.dart';
import 'player_id.dart';
import 'wall.dart';

/// Immutable snapshot of a Wallforge match.
///
/// Mirrors spec §6: complete game state.
/// currentPlayer is derived from turnNumber parity (R-STATE-05).
///
/// Every collection is stored behind an unmodifiable view, so a state can
/// never be mutated in place; all transitions go through [copyWith].
class GameState {
  /// Creates a game state, defensively copying all collections.
  ///
  /// Use [GameState.initial] for the standard start.
  GameState({
    required this.boardConfig,
    required Map<PlayerId, Cell> pawnPositions,
    required List<Wall> walls,
    required Map<PlayerId, int> remainingWalls,
    required this.turnNumber,
    required this.status,
    this.winner,
  }) : pawnPositions = Map<PlayerId, Cell>.unmodifiable(pawnPositions),
       walls = List<Wall>.unmodifiable(walls),
       remainingWalls = Map<PlayerId, int>.unmodifiable(remainingWalls);

  /// Standard initial state per spec §6.1.
  factory GameState.initial([BoardConfig config = const BoardConfig()]) {
    return GameState(
      boardConfig: config,
      pawnPositions: {
        PlayerId.blue: Cell(
          row: config.blueStart.$1,
          column: config.blueStart.$2,
        ),
        PlayerId.red: Cell(row: config.redStart.$1, column: config.redStart.$2),
      },
      walls: const [],
      remainingWalls: {
        PlayerId.blue: config.wallsPerPlayer,
        PlayerId.red: config.wallsPerPlayer,
      },
      turnNumber: 0,
      status: GameStatus.inProgress,
    );
  }

  /// Board configuration.
  final BoardConfig boardConfig;

  /// Current cell for each player pawn (unmodifiable).
  final Map<PlayerId, Cell> pawnPositions;

  /// All placed walls (unmodifiable).
  final List<Wall> walls;

  /// Walls left in each player inventory (unmodifiable).
  final Map<PlayerId, int> remainingWalls;

  /// Count of completed actions (starts at 0).
  final int turnNumber;

  /// Game status: inProgress or finished.
  final GameStatus status;

  /// Winner if status is finished; null otherwise.
  final PlayerId? winner;

  /// Current player derived from turnNumber parity (R-STATE-05).
  ///
  /// Blue when turnNumber is even, Red when turnNumber is odd.
  PlayerId get currentPlayer =>
      turnNumber.isEven ? PlayerId.blue : PlayerId.red;

  /// Position of [player]'s pawn.
  Cell pawnPosition(PlayerId player) => pawnPositions[player]!;

  /// Walls remaining for [player].
  int wallsRemaining(PlayerId player) => remainingWalls[player]!;

  /// Returns a copy with the given fields replaced.
  GameState copyWith({
    BoardConfig? boardConfig,
    Map<PlayerId, Cell>? pawnPositions,
    List<Wall>? walls,
    Map<PlayerId, int>? remainingWalls,
    int? turnNumber,
    GameStatus? status,
    PlayerId? winner,
  }) {
    return GameState(
      boardConfig: boardConfig ?? this.boardConfig,
      pawnPositions: pawnPositions ?? this.pawnPositions,
      walls: walls ?? this.walls,
      remainingWalls: remainingWalls ?? this.remainingWalls,
      turnNumber: turnNumber ?? this.turnNumber,
      status: status ?? this.status,
      winner: winner ?? this.winner,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          boardConfig == other.boardConfig &&
          _mapEquals(pawnPositions, other.pawnPositions) &&
          _listEquals(walls, other.walls) &&
          _mapEquals(remainingWalls, other.remainingWalls) &&
          turnNumber == other.turnNumber &&
          status == other.status &&
          winner == other.winner;

  @override
  int get hashCode => Object.hash(
    boardConfig,
    Object.hashAll(pawnPositions.entries),
    Object.hashAll(walls),
    Object.hashAll(remainingWalls.entries),
    turnNumber,
    status,
    winner,
  );

  @override
  String toString() =>
      'GameState(pawns: ${pawnPositions[PlayerId.blue]}-${pawnPositions[PlayerId.red]}, '
      'turn=$turnNumber, player=$currentPlayer, walls=${walls.length}, '
      'status=$status, winner=$winner)';

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
