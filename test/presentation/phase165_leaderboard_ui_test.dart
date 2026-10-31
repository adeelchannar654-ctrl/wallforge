import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/leaderboard_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';
import 'package:wallforge/presentation/screens/leaderboard/leaderboard_screen.dart';

/// Phase 16.5, Part H: the leaderboard screen's states —
/// ready rows with the YOU treatment (tag + outline, not
/// colour alone), the pinned 50+ row, last week's podium,
/// the honesty footer, and the empty / unavailable states.
class _FakeRepo implements LeaderboardRepository {
  _FakeRepo(this.top, this.mine, {this.fail = false, this.lastWeek = const []});

  final List<LeaderboardEntry> top;
  final LeaderboardEntry? mine;
  final bool fail;
  final List<LeaderboardEntry> lastWeek;

  @override
  Future<List<LeaderboardEntry>> fetchTop(
    int weekStart, {
    int limit = kLeaderboardTopLimit,
  }) async {
    if (fail) throw StateError('down');
    // The controller asks for last week with limit 3.
    if (limit == 3) return lastWeek;
    return top.take(limit).toList();
  }

  @override
  Future<LeaderboardEntry?> fetchEntry(int weekStart, String uid) async {
    if (fail) throw StateError('down');
    return mine;
  }

  @override
  Future<LeaderboardSubmitOutcome> recordResult({
    required String matchId,
    required String opponentUid,
    required bool won,
    required int plies,
    required int matchEndedAtMs,
    required String displayName,
  }) async => LeaderboardSubmitOutcome.counted;

  @override
  Future<bool> renameCurrentEntry({required String displayName}) async => true;
}

LeaderboardEntry entry(
  String uid,
  int points, {
  int wins = 0,
  int losses = 0,
}) => LeaderboardEntry(
  uid: uid,
  displayName: generateDisplayName(uid, 0),
  points: points,
  wins: wins,
  losses: losses,
  countedMatches: const {},
  opponentCounts: const {},
);

void main() {
  setUp(LeaderboardController.clearCache);

  Future<void> pumpBoard(
    WidgetTester tester,
    LeaderboardController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LeaderboardScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  LeaderboardController controller(_FakeRepo repo) => LeaderboardController(
    repository: repo,
    names: InMemoryLeaderboardNameRepository(),
    myUid: 'uid-me',
    clock: () => DateTime.utc(2026, 10, 28, 12),
  );

  testWidgets('ready: rows, YOU tag, reset line, honesty footer', (
    tester,
  ) async {
    final mine = entry('uid-me', 6, wins: 2);
    final c = controller(
      _FakeRepo(
        [entry('uid-a', 9, wins: 3), mine],
        mine,
        lastWeek: [entry('uid-z', 12, wins: 4)],
      ),
    );
    await pumpBoard(tester, c);
    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.textContaining('Resets in 4 d 12 h'), findsOneWidget);
    expect(
      find.text('${generateDisplayName('uid-me', 0)} · YOU'),
      findsOneWidget,
    );
    expect(find.text('9 pts'), findsOneWidget);
    expect(find.text('6 pts'), findsOneWidget);
    expect(find.text('LAST WEEK'), findsOneWidget);
    expect(find.text('12 pts'), findsOneWidget);
    expect(find.textContaining('colluding can still inflate'), findsOneWidget);
    expect(
      find.textContaining('You play as ${generateDisplayName('uid-me', 0)}'),
      findsOneWidget,
    );
  });

  testWidgets('an entry outside the top is pinned as 50+', (tester) async {
    final mine = entry('uid-me', 1);
    final c = controller(
      _FakeRepo([for (var i = 0; i < 50; i++) entry('uid-$i', 100 - i)], mine),
    );
    await pumpBoard(tester, c);
    // The pinned row sits below fifty board rows: scroll it
    // into the built range first.
    await tester.scrollUntilVisible(find.text('50+'), 400);
    await tester.pumpAndSettle();
    expect(find.text('50+'), findsOneWidget);
    expect(
      find.text('${generateDisplayName('uid-me', 0)} · YOU'),
      findsOneWidget,
    );
  });

  testWidgets('empty state explains what counts', (tester) async {
    final c = controller(_FakeRepo(const [], null));
    await pumpBoard(tester, c);
    expect(find.textContaining('No counted matches yet'), findsOneWidget);
  });

  testWidgets('unavailable state offers a retry', (tester) async {
    final c = controller(_FakeRepo(const [], null, fail: true));
    await pumpBoard(tester, c);
    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
  });

  testWidgets('the board tolerates a narrow screen at 1.5 scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mine = entry('uid-me', 6, wins: 2);
    final c = controller(_FakeRepo([mine], mine));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: LeaderboardScreen(controller: c),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
