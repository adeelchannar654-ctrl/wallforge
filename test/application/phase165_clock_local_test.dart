import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Phase 16.5, Part C: the clock inside the local controller —
/// timeout finishes, the AI is never timed, an unclocked match
/// schedules nothing, backgrounding freezes, and a resumed
/// match restarts its turn at a full clock.
void main() {
  late DateTime now;

  setUp(() => now = DateTime.utc(2026, 10, 31, 12));

  void advance(Duration d) => now = now.add(d);

  LocalGameController clocked({
    bool versusAi = false,
    int seconds = 15,
    InMemoryStatisticsRepository? stats,
    InMemoryUnfinishedMatchRepository? unfinished,
  }) {
    final controller = LocalGameController(
      versusAi: versusAi,
      timeControlSeconds: seconds,
      clock: () => now,
    );
    addTearDown(controller.dispose);
    controller.attachPersistence(
      settings: InMemorySettingsRepository(),
      statistics: stats ?? InMemoryStatisticsRepository(),
      unfinishedMatch: unfinished ?? InMemoryUnfinishedMatchRepository(),
    );
    return controller;
  }

  test('a timeout finishes the match: the other side wins, once', () async {
    final stats = InMemoryStatisticsRepository();
    final controller = clocked(stats: stats);
    controller.startMatch();
    expect(controller.clockArmed, isTrue);
    expect(controller.clockSide, PlayerId.blue);
    expect(controller.clockRemaining, const Duration(seconds: 15));
    expect(controller.clockTimerActive, isTrue);

    advance(const Duration(seconds: 16));
    controller.debugTickClock();

    expect(controller.isFinished, isTrue);
    expect(controller.winner, PlayerId.red);
    expect(controller.finishReason, FinishReason.timeout);
    // The engine never moved: a timeout is not a move.
    expect(controller.state.turnNumber, 0);
    expect(controller.state.status, GameStatus.inProgress);
    // Nothing is scheduled for a finished board.
    expect(controller.clockTimerActive, isFalse);
    expect(controller.clockRemaining, isNull);

    await pumpEventQueue();
    final recorded = await stats.load();
    expect(recorded.matchesPlayed, 1);
    expect(recorded.humanWins, 0); // Blue (the local "human") lost.
  });

  test('an unclocked match arms nothing and cannot time out', () {
    final controller = clocked(seconds: 0);
    controller.startMatch();
    expect(controller.clockArmed, isFalse);
    expect(controller.clockTimerActive, isFalse);
    expect(controller.clockRemaining, isNull);
    advance(const Duration(minutes: 5));
    controller.debugTickClock();
    expect(controller.isFinished, isFalse);
  });

  test('the clock hands over on a move and times the next side', () {
    final controller = clocked();
    controller.startMatch();
    advance(const Duration(seconds: 6));
    controller.tapCell(const Cell(row: 7, column: 4)); // Blue moves.
    expect(controller.state.turnNumber, 1);
    expect(controller.clockSide, PlayerId.red);
    expect(controller.clockRemaining, const Duration(seconds: 15));
    advance(const Duration(seconds: 15));
    controller.debugTickClock();
    expect(controller.winner, PlayerId.blue);
    expect(controller.finishReason, FinishReason.timeout);
  });

  test('vs-AI: the AI turn is never timed', () async {
    final controller = clocked(versusAi: true);
    controller.startMatch(versusAi: true);
    expect(controller.clockSide, PlayerId.blue);
    controller.tapCell(const Cell(row: 7, column: 4)); // Human moves.
    // The AI is thinking: no clock is running for it.
    expect(controller.clockArmed, isFalse);
    expect(controller.clockTimerActive, isFalse);
    advance(const Duration(minutes: 5));
    controller.debugTickClock();
    expect(controller.isFinished, isFalse);
    // The AI's move lands on its own schedule, then the human
    // is timed again from a full clock. Poll for the move rather
    // than sleeping a fixed span: under full-suite CPU load the
    // AI's think can take longer than any fixed allowance.
    final watch = Stopwatch()..start();
    while (controller.state.turnNumber != 2 &&
        watch.elapsed < const Duration(seconds: 20)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(controller.state.turnNumber, 2);
    expect(controller.clockSide, PlayerId.blue);
    expect(controller.clockRemaining, const Duration(seconds: 15));
  });

  test('backgrounding freezes the clock; resuming spends the rest', () {
    final controller = clocked();
    controller.startMatch();
    advance(const Duration(seconds: 10));
    controller.pauseClock();
    expect(controller.clockTimerActive, isFalse);
    expect(controller.clockRemaining, const Duration(seconds: 5));
    advance(const Duration(minutes: 10));
    controller.debugTickClock();
    expect(controller.isFinished, isFalse);
    controller.resumeClock();
    expect(controller.clockTimerActive, isTrue);
    advance(const Duration(seconds: 4));
    controller.debugTickClock();
    expect(controller.isFinished, isFalse);
    advance(const Duration(seconds: 1));
    controller.debugTickClock();
    expect(controller.isFinished, isTrue);
    expect(controller.finishReason, FinishReason.timeout);
  });

  test('a resumed match restarts the current turn at a full clock', () async {
    final unfinished = InMemoryUnfinishedMatchRepository();
    final first = clocked(unfinished: unfinished);
    first.startMatch();
    advance(const Duration(seconds: 9));
    first.tapCell(const Cell(row: 7, column: 4)); // Blue moves; saved.
    await pumpEventQueue();
    final saved = await unfinished.load();
    expect(saved, isNotNull);
    expect(saved!.timeControlSeconds, 15);

    final second = clocked(unfinished: unfinished);
    expect(second.resumeMatch(saved), isTrue);
    expect(second.state.turnNumber, 1);
    expect(second.clockSide, PlayerId.red);
    // The nine seconds Blue spent are gone with the old match;
    // Red's turn starts whole (D16.5-4).
    expect(second.clockRemaining, const Duration(seconds: 15));
  });

  test('announcements fire at the thresholds, not per second', () {
    final controller = clocked(seconds: 30);
    controller.startMatch();
    advance(const Duration(seconds: 19)); // 11 s left.
    controller.debugTickClock();
    expect(controller.clockAnnouncement, isNull);
    advance(const Duration(seconds: 1)); // 10 s left.
    controller.debugTickClock();
    expect(controller.clockAnnouncement, '10 seconds left');
    advance(const Duration(seconds: 4)); // 6 s left.
    controller.debugTickClock();
    expect(controller.clockAnnouncement, '10 seconds left');
    advance(const Duration(seconds: 1)); // 5 s left.
    controller.debugTickClock();
    expect(controller.clockAnnouncement, '5 seconds left');
    expect(controller.clockLowTime, isTrue);
  });
}
