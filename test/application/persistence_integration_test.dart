import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Simulates an app close/reopen around a live match by building a brand new
/// controller over the same repositories, which is what persistence exists for.
({
  LocalGameController controller,
  InMemorySettingsRepository settings,
  InMemoryStatisticsRepository statistics,
  InMemoryUnfinishedMatchRepository unfinished,
})
openApp({
  InMemorySettingsRepository? settings,
  InMemoryStatisticsRepository? statistics,
  InMemoryUnfinishedMatchRepository? unfinished,
}) {
  final s = settings ?? InMemorySettingsRepository();
  final st = statistics ?? InMemoryStatisticsRepository();
  final u = unfinished ?? InMemoryUnfinishedMatchRepository();
  final controller = LocalGameController();
  controller.attachPersistence(settings: s, statistics: st, unfinishedMatch: u);
  return (controller: controller, settings: s, statistics: st, unfinished: u);
}

/// Drives a 5x5 local match to a finish, alternating legal turns.
///
/// Blue starts at (4,2) and Red at (0,2). Blue walking to row 0 wins; Red
/// walking to row 4 wins. Both paths are plain adjacent steps on an empty
/// board, so this is a legal game rather than a hand-built state.
void playToBlueWin(LocalGameController controller) {
  const bluePath = <Cell>[
    Cell(row: 3, column: 2),
    Cell(row: 2, column: 2),
    Cell(row: 1, column: 2),
    Cell(row: 0, column: 2),
  ];
  const redPath = <Cell>[
    Cell(row: 0, column: 3),
    Cell(row: 1, column: 3),
    Cell(row: 0, column: 3),
  ];
  for (var i = 0; i < bluePath.length; i++) {
    controller.tapCell(bluePath[i]);
    if (controller.state.status == GameStatus.finished) return;
    if (i < redPath.length) {
      controller.tapCell(redPath[i]);
      if (controller.state.status == GameStatus.finished) return;
    }
  }
}

/// Drives a 5x5 local match where **Red** reaches its goal row, so the recorded
/// result is a loss for the human (Blue).
///
/// Blue starts at (4,2) and Red at (0,2), so Blue must step out of column 2 for
/// Red to walk down it. Every move below is a legal orthogonal step, which
/// matters: an illegal tap does not pass the turn, so one bad entry would make
/// the *next* tap move the wrong pawn.
void playToRedWin(LocalGameController controller) {
  const moves = <Cell>[
    // Blue clears column 2 ...
    Cell(row: 4, column: 3),
    // ... while Red starts down column 2.
    Cell(row: 1, column: 2),
    Cell(row: 4, column: 4),
    Cell(row: 2, column: 2),
    Cell(row: 3, column: 4),
    Cell(row: 3, column: 2),
    Cell(row: 2, column: 4),
    Cell(row: 4, column: 2), // Red reaches its goal row and wins
  ];
  for (final cell in moves) {
    controller.tapCell(cell);
    if (controller.state.status == GameStatus.finished) return;
  }
}

void main() {
  group('settings survive a restart', () {
    testWidgets('confirmWallPlacement is restored', (tester) async {
      final first = openApp();
      first.controller.toggleConfirmWallPlacement();
      expect(first.controller.confirmWallPlacement, isFalse);
      first.controller.dispose();

      // Reopen over the same storage.
      final second = openApp(
        settings: first.settings,
        statistics: first.statistics,
        unfinished: first.unfinished,
      );
      await second.controller.loadPersisted();

      expect(second.controller.confirmWallPlacement, isFalse);
      second.controller.dispose();
    });

    testWidgets('the AI difficulty is restored', (tester) async {
      final first = openApp();
      first.controller.startMatch(
        versusAi: true,
        aiDifficulty: AiDifficulty.expert,
      );
      first.controller.dispose();

      final second = openApp(
        settings: first.settings,
        statistics: first.statistics,
        unfinished: first.unfinished,
      );
      await second.controller.loadPersisted();

      expect(second.controller.aiDifficulty, AiDifficulty.expert);
      second.controller.dispose();
    });
  });

  group('an unfinished match survives a restart', () {
    testWidgets('a partial match is saved and resumed, and play continues', (
      tester,
    ) async {
      final first = openApp();
      final controller = first.controller;
      controller.startMatch(config: const BoardConfig(size: 7));

      // Play a few legal moves. Blue starts at (6,3) on a 7x7 and Red at (0,3),
      // so the turns have to alternate: an illegal tap does not pass the turn.
      controller.tapCell(const Cell(row: 5, column: 3)); // Blue
      controller.tapCell(const Cell(row: 0, column: 4)); // Red
      final turnBeforeClose = controller.state.turnNumber;
      final blueBefore = controller.state.pawnPosition(PlayerId.blue);
      final redBefore = controller.state.pawnPosition(PlayerId.red);
      expect(turnBeforeClose, 2);
      expect(
        controller.state.status,
        GameStatus.inProgress,
        reason: 'match not finished',
      );
      expect(await first.unfinished.load(), isNotNull);
      controller.dispose();

      // ---- Simulated app close and reopen ----
      final second = openApp(
        settings: first.settings,
        statistics: first.statistics,
        unfinished: first.unfinished,
      );
      final resumed = second.controller;
      await resumed.refreshResumableMatch();

      expect(resumed.resumableMatch, isNotNull);
      expect(resumed.resumableMatch!.boardSize, 7);
      expect(resumed.resumableMatch!.versusAi, isFalse);

      final adopted = resumed.resumeMatch(resumed.resumableMatch!);
      expect(adopted, isTrue);

      // The resumed match is the same match, not a new one.
      expect(resumed.state.turnNumber, turnBeforeClose);
      expect(resumed.state.pawnPosition(PlayerId.blue), blueBefore);
      expect(resumed.state.pawnPosition(PlayerId.red), redBefore);
      expect(resumed.state.status, GameStatus.inProgress);

      // And it continues legally. Two plies have been played, so by R-TURN-05 it
      // is Blue's turn again (even turnNumber) and Blue can still move.
      expect(resumed.currentPlayer, PlayerId.blue);
      expect(resumed.legalMoveTargets, isNotEmpty);
      final target = resumed.legalMoveTargets.first;
      final turnBefore = resumed.state.turnNumber;
      resumed.tapCell(target);
      expect(
        resumed.state.turnNumber,
        turnBefore + 1,
        reason: 'play must continue from the resumed position',
      );
      resumed.dispose();
    });

    testWidgets('a resumed AI match keeps its opponent and difficulty', (
      tester,
    ) async {
      final first = openApp();
      first.controller.startMatch(
        versusAi: true,
        aiDifficulty: AiDifficulty.hard,
      );
      first.controller.tapCell(const Cell(row: 8, column: 3));
      // Let the AI reply.
      await tester.pump(kAiThinkDelay);
      await tester.pump();
      expect(first.controller.state.turnNumber, 2);
      first.controller.dispose();

      final second = openApp(
        settings: first.settings,
        statistics: first.statistics,
        unfinished: first.unfinished,
      );
      await second.controller.refreshResumableMatch();
      final match = second.controller.resumableMatch!;
      expect(match.versusAi, isTrue);
      expect(match.aiDifficulty, 'hard');

      second.controller.resumeMatch(match);
      expect(second.controller.versusAi, isTrue);
      expect(second.controller.aiDifficulty, AiDifficulty.hard);
      second.controller.dispose();
    });

    testWidgets('a finished match is not resumable', (tester) async {
      final first = openApp();
      first.controller.startMatch(config: const BoardConfig(size: 5));
      playToBlueWin(first.controller);
      expect(first.controller.state.status, GameStatus.finished);
      expect(first.controller.state.winner, PlayerId.blue);
      // A finished match clears the resumable save.
      expect(await first.unfinished.load(), isNull);
      first.controller.dispose();
    });
  });

  group('statistics are recorded on completion', () {
    testWidgets('a win for the human is recorded against the right bucket', (
      tester,
    ) async {
      final app = openApp();
      final controller = app.controller;
      controller.startMatch(config: const BoardConfig(size: 5));
      playToBlueWin(controller);
      expect(controller.state.winner, PlayerId.blue);
      await tester.pump();

      final stats = await app.statistics.load();
      expect(stats.matchesPlayed, 1);
      expect(stats.humanWins, 1);
      expect(stats.humanLosses, 0);
      expect(stats.byBoardSize['5']?.wins, 1);
      expect(
        stats.byDifficulty['local']?.played,
        1,
        reason: 'a pass-and-play match is recorded under "local"',
      );
      controller.dispose();
    });

    testWidgets('a loss for the human is recorded as a loss', (tester) async {
      final app = openApp();
      final controller = app.controller;
      controller.startMatch(config: const BoardConfig(size: 5));
      playToRedWin(controller);
      expect(controller.state.winner, PlayerId.red);
      await tester.pump();

      final stats = await app.statistics.load();
      expect(stats.matchesPlayed, 1);
      expect(stats.humanWins, 0, reason: 'Red won, so the human did not');
      expect(stats.humanLosses, 1);
      expect(stats.winRate, 0);
      controller.dispose();
    });

    testWidgets('no statistics are recorded mid-match', (tester) async {
      final app = openApp();
      app.controller.startMatch(config: const BoardConfig(size: 7));
      app.controller.tapCell(const Cell(row: 6, column: 3));
      await tester.pump();
      expect(await app.statistics.load(), MatchStatistics.empty);
      app.controller.dispose();
    });
  });

  group('opt-in persistence', () {
    testWidgets('a controller with no repositories does no persistence', (
      tester,
    ) async {
      final controller = LocalGameController();
      // These must all be safe no-ops rather than throwing.
      await controller.loadPersisted();
      await controller.persistSettings();
      await controller.recordFinishedMatch();
      await controller.refreshResumableMatch();
      expect(controller.hasPersistence, isFalse);
      expect(controller.resumableMatch, isNull);
      controller.startMatch();
      controller.tapCell(const Cell(row: 8, column: 3));
      expect(controller.state.turnNumber, 1);
      controller.dispose();
    });
  });
}
