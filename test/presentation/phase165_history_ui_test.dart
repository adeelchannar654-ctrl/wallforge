import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/router/app_router.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/history/history_detail_screen.dart';
import 'package:wallforge/presentation/screens/history/history_screen.dart';

/// Phase 16.5, Part E: the history screens — list, filters,
/// detail, delete, clear-all, and the empty states.
MatchRecord sample(
  String id, {
  required MatchMode mode,
  required PlayerId? mySide,
  required PlayerId? winnerSide,
  FinishReason reason = FinishReason.goal,
  List<String> moves = const ['M 7,4', 'M 1,4'],
}) => MatchRecord(
  id: id,
  mode: mode,
  boardSize: 9,
  wallsPerPlayer: 10,
  mySide: mySide,
  winnerSide: winnerSide,
  finishReason: reason,
  opponentLabel: mode == MatchMode.versusAi
      ? 'AI · Hard'
      : mode == MatchMode.online
      ? 'Online player'
      : 'Local player',
  plies: moves.length,
  durationMs: 125000,
  endedAtMs: DateTime(2026, 10, 31, 18, 30).millisecondsSinceEpoch,
  timeControlSeconds: 0,
  moves: moves,
  movesComplete: true,
  rematchOf: null,
);

void main() {
  late InMemoryMatchHistoryRepository history;

  setUp(() {
    history = InMemoryMatchHistoryRepository([
      sample(
        'a',
        mode: MatchMode.versusAi,
        mySide: PlayerId.blue,
        winnerSide: PlayerId.blue,
      ),
      sample(
        'b',
        mode: MatchMode.online,
        mySide: PlayerId.red,
        winnerSide: PlayerId.blue,
        reason: FinishReason.resign,
      ),
      sample(
        'c',
        mode: MatchMode.local,
        mySide: null,
        winnerSide: PlayerId.red,
      ),
    ]);
  });

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        navigatorObservers: [AppRouter.routeObserver],
        home: HistoryScreen(historyRepository: history),
        onGenerateRoute: (settings) {
          if (settings.name == '/history/detail') {
            return MaterialPageRoute<void>(
              builder: (_) => HistoryDetailScreen(
                record: settings.arguments! as MatchRecord,
                historyRepository: history,
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every record with a words-first headline', (tester) async {
    await pumpHistory(tester);
    expect(find.text('Won · Vs AI'), findsOneWidget);
    expect(find.text('Lost · Online'), findsOneWidget);
    expect(find.text('Red won · Local'), findsOneWidget);
    expect(find.textContaining('Stored on this device only'), findsOneWidget);
  });

  testWidgets('mode and result filters narrow the list', (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Online'));
    await tester.pumpAndSettle();
    expect(find.text('Lost · Online'), findsOneWidget);
    expect(find.text('Won · Vs AI'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All modes'));
    await tester.pumpAndSettle();
    final wonChip = find.widgetWithText(ChoiceChip, 'Won');
    await tester.ensureVisible(wonChip);
    await tester.pumpAndSettle();
    await tester.tap(wonChip);
    await tester.pumpAndSettle();
    expect(find.text('Won · Vs AI'), findsOneWidget);
    expect(find.text('Lost · Online'), findsNothing);
    // Pass-and-play belongs to no single player: it is neither
    // a win nor a loss, so the result filter leaves it out.
    expect(find.text('Red won · Local'), findsNothing);
  });

  testWidgets('detail shows the facts and the moves; delete removes', (
    tester,
  ) async {
    await pumpHistory(tester);
    await tester.tap(find.text('Won · Vs AI'));
    await tester.pumpAndSettle();
    expect(find.text('Match details'), findsOneWidget);
    expect(find.text('AI · Hard'), findsOneWidget);
    expect(find.textContaining('1. M 7,4'), findsOneWidget);
    expect(find.textContaining('2. M 1,4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    expect(find.text('Won · Vs AI'), findsNothing);
    expect(await history.load(), hasLength(2));
  });

  testWidgets('clear all asks first, then empties', (tester) async {
    await pumpHistory(tester);
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Clear match history?'), findsOneWidget);
    await tester.tap(find.text('CLEAR ALL'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches recorded yet'), findsOneWidget);
    expect(await history.load(), isEmpty);
  });

  testWidgets('an empty history explains itself', (tester) async {
    history = InMemoryMatchHistoryRepository();
    await pumpHistory(tester);
    expect(find.textContaining('No matches recorded yet'), findsOneWidget);
  });

  testWidgets('the list tolerates a narrow screen at 1.5 UI scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: HistoryScreen(historyRepository: history),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Won · Vs AI'), findsOneWidget);
  });
}
