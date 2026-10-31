import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/achievements/achievements_screen.dart';
import 'package:wallforge/presentation/widgets/achievement_toast.dart';

/// Phase 16.5, Part F: the achievements screen (locked and
/// unlocked states, progress in words) and the unlock toast.
void main() {
  testWidgets('unlocked shows its date; locked shows text progress', (
    tester,
  ) async {
    final history = InMemoryMatchHistoryRepository([
      const MatchRecord(
        id: 'a',
        mode: MatchMode.versusAi,
        boardSize: 9,
        wallsPerPlayer: 10,
        mySide: PlayerId.blue,
        winnerSide: PlayerId.blue,
        finishReason: FinishReason.goal,
        opponentLabel: 'AI · Easy',
        plies: 20,
        durationMs: 60000,
        endedAtMs: 1000,
        timeControlSeconds: 0,
        moves: ['M 7,4'],
        movesComplete: true,
        rematchOf: null,
      ),
      const MatchRecord(
        id: 'b',
        mode: MatchMode.versusAi,
        boardSize: 9,
        wallsPerPlayer: 10,
        mySide: PlayerId.blue,
        winnerSide: PlayerId.blue,
        finishReason: FinishReason.goal,
        opponentLabel: 'AI · Easy',
        plies: 22,
        durationMs: 60000,
        endedAtMs: 2000,
        timeControlSeconds: 0,
        moves: ['M 7,4'],
        movesComplete: true,
        rematchOf: null,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: AchievementsScreen(
          historyRepository: history,
          statisticsRepository: InMemoryStatisticsRepository(),
          achievementsRepository: InMemoryAchievementsRepository({
            'first-win': DateTime(2026, 10, 31, 18, 30).millisecondsSinceEpoch,
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First Win'), findsOneWidget);
    expect(find.textContaining('Unlocked · '), findsOneWidget);
    expect(find.text('On a Roll'), findsOneWidget);
    // Two wins toward the 3-win streak, stated as a count.
    expect(find.text('Progress: 2 of 3'), findsOneWidget);
    expect(
      find.textContaining('earned and kept on this device only'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the toast announces and offers the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAchievementUnlocks(context, [
                achievementById('first-win')!,
              ]),
              child: const Text('GO'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();
    expect(find.text('Achievement unlocked: First Win'), findsOneWidget);
    expect(find.text('VIEW'), findsOneWidget);
  });
}
