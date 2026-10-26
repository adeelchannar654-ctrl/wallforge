import 'dart:collection';

import '../../domain/engine/blocked_edges.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/player_id.dart';

/// The shortest route for [player] from their pawn to their goal row, as the
/// list of cells to step onto (the pawn's own cell excluded, the first
/// goal-row cell included).
///
/// This is the movement-assistance feature behind the `design.md` §23
/// "Movement assistance" setting. It deliberately runs the same graph the
/// engine's `Pathfinder` uses — `BlockedEdges.fromWalls` plus orthogonal
/// adjacency, pawns ignored — so the drawn route is exactly the route whose
/// length `Pathfinder.shortestRouteLength` reports, never a different notion
/// of "shortest". The engine itself is unchanged: this is a read-only BFS
/// with parent tracking, in the application layer, over public domain
/// primitives.
///
/// Returns an empty list when the pawn already stands on its goal row (a
/// finished game) or, defensively, when no route exists — a legal Wallforge
/// position always has one (R-PATH-01), so that case cannot arise in play.
List<Cell> shortestRoute(GameState state, PlayerId player) {
  final size = state.boardConfig.size;
  final goalRow = player == PlayerId.blue ? 0 : size - 1;
  final from = state.pawnPosition(player);
  if (from.row == goalRow) return const <Cell>[];

  final board = BlockedEdges.fromWalls(state.walls, size);
  final parents = <Cell, Cell?>{from: null};
  final queue = ListQueue<Cell>()..add(from);

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    for (final neighbor in board.neighborsOf(current)) {
      if (parents.containsKey(neighbor)) continue;
      if (board.isBlocked(current, neighbor)) continue;
      parents[neighbor] = current;
      if (neighbor.row == goalRow) {
        final route = <Cell>[];
        Cell? step = neighbor;
        while (step != null && step != from) {
          route.add(step);
          step = parents[step];
        }
        return route.reversed.toList(growable: false);
      }
      queue.add(neighbor);
    }
  }
  return const <Cell>[];
}
