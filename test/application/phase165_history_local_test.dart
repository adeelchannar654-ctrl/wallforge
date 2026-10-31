import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part E: local matches land in history exactly
/// once, with their move lists, alongside — never instead of —
/// the legacy statistics.
void main() {
  late InMemoryMatchHistoryRepository history;
  late InMemoryStatisticsRepository stats;
  late InMemoryUnfinishedMatchRepository unfinished;

  LocalGameController controller({DateTime Function()? clock, int? seconds}) {
    final c = LocalGameController(clock: clock, timeControlSeconds: seconds);
    addTearDown(c.dispose);
    c.attachPersistence(
      settings: InMemorySettingsRepository(),
      statistics: stats,
      unfinishedMatch: unfinished,
      history: history,
    );
    return c;
  }

  setUp(() {
    history = InMemoryMatchHistoryRepository();
    stats = InMemoryStatisticsRepository();
    unfinished = InMemoryUnfinishedMatchRepository();
  });

  test('a pass-and-play resign records once, with its moves', () async {
    final c = controller();
    c.startMatch();
    c.tapCell(const Cell(row: 7, column: 4)); // Blue: M 7,4
    c.tapCell(const Cell(row: 1, column: 4)); // Red: M 1,4
    c.resign(PlayerId.red);
    await pumpEventQueue();

    final records = await history.load();
    expect(records, hasLength(1));
    final r = records.single;
    expect(r.id, c.matchId);
    expect(r.mode, MatchMode.local);
    expect(r.mySide, isNull);
    expect(r.winnerSide, PlayerId.blue);
    expect(r.finishReason, FinishReason.resign);
    expect(r.opponentLabel, 'Local player');
    expect(r.plies, 2);
    expect(r.moves, ['M 7,4', 'M 1,4']);
    expect(r.movesComplete, isTrue);
    expect(r.rematchOf, isNull);
    // Statistics folded exactly once, through the same gate.
    expect((await stats.load()).matchesPlayed, 1);
  });

  test('a goal finish records with reason goal and the winning move', () async {
    final c = controller();
    c.startMatch(config: const BoardConfig(size: 5));
    // Blue walks straight up the middle; Red shuffles sideways.
    c.tapCell(const Cell(row: 3, column: 2));
    c.tapCell(const Cell(row: 0, column: 3));
    c.tapCell(const Cell(row: 2, column: 2));
    c.tapCell(const Cell(row: 0, column: 2));
    c.tapCell(const Cell(row: 1, column: 2));
    c.tapCell(const Cell(row: 0, column: 3));
    c.tapCell(const Cell(row: 0, column: 2)); // Blue reaches the goal.
    expect(c.isFinished, isTrue);
    await pumpEventQueue();

    final r = (await history.load()).single;
    expect(r.finishReason, FinishReason.goal);
    expect(r.winnerSide, PlayerId.blue);
    expect(r.plies, 7);
    expect(r.moves, hasLength(7));
    expect(r.moves.last, 'M 0,2');
  });

  test('recording is idempotent across a repeated finish call', () async {
    final c = controller();
    c.startMatch(versusAi: true);
    c.resign(PlayerId.blue);
    await pumpEventQueue();
    await c.recordFinishedMatch(); // a second observation
    await pumpEventQueue();
    expect(await history.load(), hasLength(1));
    expect((await stats.load()).matchesPlayed, 1);
    final r = (await history.load()).single;
    expect(r.mode, MatchMode.versusAi);
    expect(r.mySide, PlayerId.blue);
    expect(r.isLoss, isTrue);
    expect(r.opponentLabel, 'AI · Easy');
  });

  test('a clock timeout records with reason timeout', () async {
    var now = DateTime.utc(2026, 10, 31, 12);
    final c = controller(clock: () => now, seconds: 15);
    c.startMatch();
    now = now.add(const Duration(seconds: 16));
    c.debugTickClock();
    expect(c.finishReason, FinishReason.timeout);
    await pumpEventQueue();
    final r = (await history.load()).single;
    expect(r.finishReason, FinishReason.timeout);
    expect(r.timeControlSeconds, 15);
    expect(r.winnerSide, PlayerId.red);
  });

  test('a rematch record links to the match it follows', () async {
    final c = controller();
    c.startMatch(versusAi: true);
    final firstId = c.matchId;
    c.resign(PlayerId.blue);
    await pumpEventQueue();
    c.rematch();
    expect(c.matchId, isNot(firstId));
    c.resign(PlayerId.blue); // the AI's side in the swapped game
    await pumpEventQueue();
    final records = await history.load();
    expect(records, hasLength(2));
    expect(records.first.rematchOf, firstId);
    expect(records.first.mySide, PlayerId.red); // swapped
    expect(records.first.isWin, isTrue); // the AI conceded
    expect(records.last.rematchOf, isNull);
  });

  test('a resumed match records whole: identity, moves, one entry', () async {
    final first = controller();
    first.startMatch();
    first.tapCell(const Cell(row: 7, column: 4));
    await pumpEventQueue();
    final saved = await unfinished.load();
    expect(saved, isNotNull);

    final second = controller();
    expect(second.resumeMatch(saved!), isTrue);
    expect(second.matchId, first.matchId);
    second.tapCell(const Cell(row: 1, column: 4));
    second.resign(PlayerId.blue);
    await pumpEventQueue();

    final records = await history.load();
    expect(records, hasLength(1));
    expect(records.single.moves, ['M 7,4', 'M 1,4']);
    expect(records.single.plies, 2);
  });
}
