import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/leaderboard_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/domain/repositories/leaderboard.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/achievements/achievements_screen.dart';
import 'package:wallforge/presentation/screens/history/history_detail_screen.dart';
import 'package:wallforge/presentation/screens/history/history_screen.dart';
import 'package:wallforge/presentation/screens/leaderboard/leaderboard_screen.dart';

/// Phase 16.5, Part I: the responsive / accessibility matrix
/// for the phase's new screens — five viewports plus the
/// landscape phone, at the default scale and at UI scale 1.5
/// (the Phase 13 tolerance bound). Every render must complete
/// without an exception (overflow, layout or otherwise).
class _FakeRepo implements LeaderboardRepository {
  @override
  Future<List<LeaderboardEntry>> fetchTop(
    int weekStart, {
    int limit = kLeaderboardTopLimit,
  }) async => [
    LeaderboardEntry(
      uid: 'uid-me',
      displayName: generateDisplayName('uid-me', 0),
      points: 12,
      wins: 4,
      losses: 1,
      countedMatches: const {},
      opponentCounts: const {},
    ),
    LeaderboardEntry(
      uid: 'uid-other',
      displayName: generateDisplayName('uid-other', 0),
      points: 9,
      wins: 3,
      losses: 2,
      countedMatches: const {},
      opponentCounts: const {},
    ),
  ];

  @override
  Future<LeaderboardEntry?> fetchEntry(int weekStart, String uid) async =>
      (await fetchTop(weekStart)).first;

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

MatchRecord _record() => const MatchRecord(
  id: 'm1',
  mode: MatchMode.online,
  boardSize: 9,
  wallsPerPlayer: 10,
  mySide: PlayerId.blue,
  winnerSide: PlayerId.red,
  finishReason: FinishReason.timeout,
  opponentLabel: 'Online player',
  plies: 34,
  durationMs: 754000,
  endedAtMs: 1761950000000,
  timeControlSeconds: 30,
  moves: ['M 7,4', 'M 1,4', 'W H 4,4'],
  movesComplete: true,
  rematchOf: 'EARLIER1',
);

void main() {
  const viewports = <Size>[
    Size(320, 568),
    Size(390, 844),
    Size(768, 1024),
    Size(1024, 768),
    Size(1440, 900),
    Size(844, 390),
  ];

  final screens = <String, Widget Function()>{
    'history': () => HistoryScreen(
      historyRepository: InMemoryMatchHistoryRepository([_record()]),
    ),
    'history detail': () => HistoryDetailScreen(
      record: _record(),
      historyRepository: InMemoryMatchHistoryRepository(),
    ),
    'achievements': () => AchievementsScreen(
      historyRepository: InMemoryMatchHistoryRepository([_record()]),
      statisticsRepository: InMemoryStatisticsRepository(),
      achievementsRepository: InMemoryAchievementsRepository({
        'first-win': 1761950000000,
      }),
    ),
    'leaderboard': () => LeaderboardScreen(
      controller: LeaderboardController(
        repository: _FakeRepo(),
        names: InMemoryLeaderboardNameRepository(),
        myUid: 'uid-me',
        clock: () => DateTime.utc(2026, 10, 28, 12),
      ),
    ),
  };

  for (final entry in screens.entries) {
    for (final size in viewports) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('${entry.key} at ${size.width}x${size.height} x$scale', (
          tester,
        ) async {
          LeaderboardController.clearCache();
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.dark,
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: entry.value(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} must render cleanly at $size x$scale',
          );
        });
      }
    }
  }
}
