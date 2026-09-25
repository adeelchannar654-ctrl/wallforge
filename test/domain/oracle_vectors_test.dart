import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  late Map<String, dynamic> oracle;

  setUpAll(() {
    final file = File('test/fixtures/engine_vectors.json');
    oracle = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  test('all oracle games replay correctly', () {
    final games = oracle['games'] as List;
    for (var gi = 0; gi < games.length; gi++) {
      final game = games[gi] as Map<String, dynamic>;
      final config = game['config'] as Map<String, dynamic>;
      final seed = game['seed'] as int;
      final actions = (game['actions'] as List).cast<String>();
      final checkpoints = game['checkpoints'] as List;
      final boardSize = config['size'] as int;
      final wpp = config['wallsPerPlayer'] as int;

      var state = GameState.initial(
        BoardConfig(size: boardSize, wallsPerPlayer: wpp),
      );

      var actionIdx = 0;
      for (final cp in checkpoints) {
        final cpMap = cp as Map<String, dynamic>;
        final expectedPly = cpMap['ply'] as int;
        final expectedState = cpMap['state'] as Map<String, dynamic>;
        final expectedLegal = (cpMap['legal'] as List).cast<String>();
        final expectedCandidates = cpMap['candidates'] as String;

        while (state.turnNumber < expectedPly) {
          final actionStr = actions[actionIdx];
          final action = GameAction.parse(actionStr);
          expect(
            action,
            isNotNull,
            reason: 'Game $gi (seed=$seed): Failed to parse action: $actionStr',
          );

          final result = GameEngine.apply(state, state.currentPlayer, action!);
          expect(
            result,
            isA<SuccessResult>(),
            reason:
                'Game $gi (seed=$seed): Action $actionStr failed '
                'at ply ${state.turnNumber}',
          );
          state = (result as SuccessResult).state;
          actionIdx++;
        }

        // 1. Compare serialized state
        final actualJson = GameStateSerializer.toJson(state);
        expect(
          _normalizeJson(actualJson),
          _normalizeJson(expectedState),
          reason: 'Game $gi (seed=$seed): State mismatch at ply $expectedPly',
        );

        // 2. Compare legal actions
        final actualLegal = MoveGenerator.generate(state, state.currentPlayer);
        final actualLegalStrs = actualLegal.map((a) => a.toNotation()).toList();
        expect(
          actualLegalStrs,
          expectedLegal,
          reason:
              'Game $gi (seed=$seed): Legal actions mismatch at ply $expectedPly',
        );

        // 3. Compare candidate validation codes
        final candidateActions = _allCandidates(boardSize);
        final actualCodes = StringBuffer();
        for (final cand in candidateActions) {
          final failure = ActionValidator.validate(
            state,
            state.currentPlayer,
            cand,
          );
          final code = failure == null ? '.' : _failureToCode(failure.name);
          actualCodes.write(code);
        }
        expect(
          actualCodes.toString(),
          expectedCandidates,
          reason:
              'Game $gi (seed=$seed): Candidate codes mismatch at ply $expectedPly',
        );
      }

      expect(
        state.turnNumber,
        (checkpoints.last as Map)['ply'],
        reason: 'Game $gi (seed=$seed): Final ply mismatch',
      );
    }
  });
}

List<GameAction> _allCandidates(int n) {
  final cands = <GameAction>[];

  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      cands.add(GameAction.move(Cell(row: r, column: c)));
    }
  }
  for (final (r, c) in [(-1, 0), (0, -1), (n, 0), (0, n), (-1, -1), (n, n)]) {
    cands.add(GameAction.move(Cell(row: r, column: c)));
  }
  for (final orient in [WallOrientation.h, WallOrientation.v]) {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        cands.add(
          GameAction.wall(
            orientation: orient,
            anchor: Cell(row: r, column: c),
          ),
        );
      }
    }
  }
  cands.add(
    const GameAction.wall(
      orientation: WallOrientation.h,
      anchor: Cell(row: -1, column: 0),
    ),
  );
  cands.add(
    const GameAction.wall(
      orientation: WallOrientation.v,
      anchor: Cell(row: 0, column: -1),
    ),
  );

  return cands;
}

String _failureToCode(String name) {
  const codes = {
    'matchFinished': 'a',
    'wrongTurn': 'b',
    'moveOutOfBoard': 'c',
    'moveNotAdjacent': 'd',
    'moveBlockedByWall': 'e',
    'moveOntoPawn': 'f',
    'moveIllegalJump': 'g',
    'noWallsRemaining': 'h',
    'wallOutOfBounds': 'i',
    'wallOverlaps': 'j',
    'wallCrosses': 'k',
    'wallBlocksPath': 'l',
  };
  return codes[name] ?? '?';
}

Map<String, dynamic> _normalizeJson(dynamic v) {
  if (v is Map) {
    final sorted = <String, dynamic>{};
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    for (final key in keys) {
      sorted[key] = _normalizeJson(v[key]);
    }
    return sorted;
  }
  if (v is List) {
    return {'_list': v.map(_normalizeJson).toList()};
  }
  return {'_val': v};
}
