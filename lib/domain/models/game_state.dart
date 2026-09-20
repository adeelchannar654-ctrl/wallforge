import 'board_config.dart';
import 'cell.dart';
import 'game_status.dart';
import 'player_id.dart';
import 'wall.dart';

/// Immutable snapshot of a Wallforge match.
///
/// Mirrors spec §4: complete game state.
class GameState {
  /// Creates a game state.
  const GameState({
    required this.config,
    required this.bluePawn,
    required this.redPawn,
    required this.walls,
    required this.blueWallsRemaining,
    required this.redWallsRemaining,
    required this.activePlayer,
    required this.status,
    required this.moveCount,
  });

  /// Standard initial state per spec §6.1.
  factory GameState.initial({BoardConfig config = const BoardConfig()}) {
    return GameState(
      config: config,
      bluePawn: Cell(col: config.cols ~/ 2, row: 0),
      redPawn: Cell(col: config.cols ~/ 2, row: config.rows - 1),
      walls: const [],
      blueWallsRemaining: config.maxWallsPerPlayer,
      redWallsRemaining: config.maxWallsPerPlayer,
      activePlayer: PlayerId.blue,
      status: GameStatus.active,
      moveCount: 0,
    );
  }

  /// Board geometry.
  final BoardConfig config;

  /// Blue pawn position.
  final Cell bluePawn;

  /// Red pawn position.
  final Cell redPawn;

  /// All walls currently on the board.
  final List<Wall> walls;

  /// Walls remaining for Blue.
  final int blueWallsRemaining;

  /// Walls remaining for Red.
  final int redWallsRemaining;

  /// Whose turn it is.
  final PlayerId activePlayer;

  /// Match status.
  final GameStatus status;

  /// Number of moves made so far.
  final int moveCount;

  /// Position of [player]'s pawn.
  Cell pawnPosition(PlayerId player) =>
      player == PlayerId.blue ? bluePawn : redPawn;

  /// Walls remaining for [player].
  int wallsRemaining(PlayerId player) =>
      player == PlayerId.blue ? blueWallsRemaining : redWallsRemaining;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameState &&
          runtimeType == other.runtimeType &&
          config == other.config &&
          bluePawn == other.bluePawn &&
          redPawn == other.redPawn &&
          _listEquals(walls, other.walls) &&
          blueWallsRemaining == other.blueWallsRemaining &&
          redWallsRemaining == other.redWallsRemaining &&
          activePlayer == other.activePlayer &&
          status == other.status &&
          moveCount == other.moveCount;

  @override
  int get hashCode => Object.hash(
    config,
    bluePawn,
    redPawn,
    Object.hashAll(walls),
    blueWallsRemaining,
    redWallsRemaining,
    activePlayer,
    status,
    moveCount,
  );

  @override
  String toString() =>
      'GameState(blue=$bluePawn, red=$redPawn, active=$activePlayer, '
      'walls=${walls.length}, move=$moveCount, status=$status)';

  /// Returns a copy with the given fields replaced.
  GameState copyWith({
    BoardConfig? config,
    Cell? bluePawn,
    Cell? redPawn,
    List<Wall>? walls,
    int? blueWallsRemaining,
    int? redWallsRemaining,
    PlayerId? activePlayer,
    GameStatus? status,
    int? moveCount,
  }) {
    return GameState(
      config: config ?? this.config,
      bluePawn: bluePawn ?? this.bluePawn,
      redPawn: redPawn ?? this.redPawn,
      walls: walls ?? this.walls,
      blueWallsRemaining: blueWallsRemaining ?? this.blueWallsRemaining,
      redWallsRemaining: redWallsRemaining ?? this.redWallsRemaining,
      activePlayer: activePlayer ?? this.activePlayer,
      status: status ?? this.status,
      moveCount: moveCount ?? this.moveCount,
    );
  }

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
