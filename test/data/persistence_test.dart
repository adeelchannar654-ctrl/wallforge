import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/local/shared_preferences_settings_repository.dart';
import 'package:wallforge/data/local/shared_preferences_statistics_repository.dart';
import 'package:wallforge/data/local/shared_preferences_unfinished_match_repository.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettings round trip', () {
    test('survives JSON encode/decode unchanged', () {
      const settings = AppSettings(
        confirmWallPlacement: false,
        aiDifficulty: 'expert',
        tutorialCompleted: true,
      );
      final decoded = AppSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, settings);
    });

    test('defaults match the app initial values', () {
      expect(AppSettings.defaults.confirmWallPlacement, isTrue);
      expect(AppSettings.defaults.aiDifficulty, 'easy');
      expect(AppSettings.defaults.tutorialCompleted, isFalse);
    });

    test('every offered difficulty name is accepted', () {
      for (final name in AppSettings.knownAiDifficulties) {
        final decoded = AppSettings.fromJson(<String, dynamic>{
          'aiDifficulty': name,
        });
        expect(decoded.aiDifficulty, name);
      }
    });
  });

  group('MatchStatistics round trip', () {
    test('survives JSON encode/decode unchanged', () {
      var stats = MatchStatistics.empty;
      stats = stats.recordResult(
        boardSize: 9,
        difficulty: 'easy',
        humanWon: true,
      );
      stats = stats.recordResult(
        boardSize: 9,
        difficulty: 'expert',
        humanWon: false,
      );
      stats = stats.recordResult(
        boardSize: 7,
        difficulty: 'local',
        humanWon: true,
      );

      final decoded = MatchStatistics.fromJson(
        jsonDecode(jsonEncode(stats.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, stats);
    });

    test('records wins and losses against the right player', () {
      var stats = MatchStatistics.empty;
      stats = stats.recordResult(
        boardSize: 9,
        difficulty: 'hard',
        humanWon: true,
      );
      stats = stats.recordResult(
        boardSize: 9,
        difficulty: 'hard',
        humanWon: false,
      );

      expect(stats.matchesPlayed, 2);
      expect(stats.humanWins, 1);
      expect(stats.humanLosses, 1);
      expect(stats.winRate, 0.5);
      expect(stats.byBoardSize['9']?.played, 2);
      expect(stats.byBoardSize['9']?.wins, 1);
      expect(stats.byDifficulty['hard']?.losses, 1);
    });

    test('win rate is null before any match', () {
      expect(MatchStatistics.empty.winRate, isNull);
    });
  });

  group('UnfinishedMatch round trip', () {
    test('survives JSON encode/decode unchanged', () {
      final state = GameState.initial(const BoardConfig(size: 7)).copyWith(
        turnNumber: 4,
        pawnPositions: const {
          PlayerId.blue: Cell(row: 6, column: 3),
          PlayerId.red: Cell(row: 0, column: 3),
        },
        walls: const [
          Wall(
            owner: PlayerId.blue,
            orientation: WallOrientation.h,
            anchorRow: 3,
            anchorColumn: 3,
          ),
        ],
        remainingWalls: const {PlayerId.blue: 9, PlayerId.red: 10},
      );
      final match = UnfinishedMatch(
        gameState: state,
        boardSize: 7,
        versusAi: true,
        aiDifficulty: 'hard',
        savedAtTurn: 4,
      );

      final decoded = UnfinishedMatch.fromJson(
        jsonDecode(jsonEncode(match.toJson())) as Map<String, dynamic>,
      );

      expect(decoded, isNotNull);
      expect(decoded!.boardSize, 7);
      expect(decoded.versusAi, isTrue);
      expect(decoded.aiDifficulty, 'hard');
      expect(decoded.savedAtTurn, 4);
      expect(decoded.gameState, state, reason: 'state must be identical');
    });
  });

  group('corruption and missing data never throw', () {
    test('AppSettings falls back per field', () {
      final settings = AppSettings.fromJson(<String, dynamic>{
        'confirmWallPlacement': 'not-a-bool',
        'aiDifficulty': 42,
        'tutorialCompleted': <String>[],
      });
      expect(settings, AppSettings.defaults);
    });

    test('AppSettings substitutes a default for an unknown difficulty', () {
      final settings = AppSettings.fromJson(<String, dynamic>{
        'aiDifficulty': 'impossible',
      });
      expect(settings.aiDifficulty, 'easy');
    });

    test('AppSettings handles null and non-map input', () {
      expect(AppSettings.fromJson(null), AppSettings.defaults);
    });

    test('MatchStatistics falls back per field', () {
      final stats = MatchStatistics.fromJson(<String, dynamic>{
        'matchesPlayed': -5,
        'humanWins': 'many',
        'byBoardSize': 'not-a-map',
        'byDifficulty': 7,
      });
      expect(stats, MatchStatistics.empty);
    });

    test('MatchStatistics drops malformed buckets but keeps good ones', () {
      final stats = MatchStatistics.fromJson(<String, dynamic>{
        'matchesPlayed': 2,
        'byBoardSize': <String, dynamic>{
          '9': <String, dynamic>{'played': 2, 'wins': 1, 'losses': 1},
          'bad': 'not-a-map',
        },
      });
      expect(stats.matchesPlayed, 2);
      expect(stats.byBoardSize['9']?.wins, 1);
      expect(stats.byBoardSize.containsKey('bad'), isFalse);
    });

    test('UnfinishedMatch returns null for unusable input', () {
      expect(UnfinishedMatch.fromJson(null), isNull);
      expect(
        UnfinishedMatch.fromJson(<String, dynamic>{'boardSize': 3}),
        isNull,
        reason: 'board size below the minimum is rejected',
      );
      expect(
        UnfinishedMatch.fromJson(<String, dynamic>{
          'boardSize': 9,
          'gameState': 'not-a-map',
        }),
        isNull,
      );
      expect(
        UnfinishedMatch.fromJson(<String, dynamic>{
          'boardSize': 9,
          'gameState': <String, dynamic>{'schemaVersion': 999},
        }),
        isNull,
        reason: 'an unknown schema version is rejected by the engine decoder',
      );
    });

    test('UnfinishedMatch rejects a state that violates an invariant', () {
      // Both pawns on the same cell violates R-STATE-01.
      final bogus = GameState.initial().copyWith(
        pawnPositions: const {
          PlayerId.blue: Cell(row: 4, column: 4),
          PlayerId.red: Cell(row: 4, column: 4),
        },
      );
      final match = UnfinishedMatch(
        gameState: bogus,
        boardSize: 9,
        versusAi: false,
        aiDifficulty: 'local',
      );
      expect(UnfinishedMatch.fromJson(match.toJson()), isNull);
    });
  });

  group('value semantics', () {
    test('AppSettings copyWith replaces only the given fields', () {
      const original = AppSettings(
        confirmWallPlacement: false,
        aiDifficulty: 'hard',
        tutorialCompleted: true,
      );
      expect(original.copyWith(), original);
      expect(original.copyWith(aiDifficulty: 'easy').aiDifficulty, 'easy');
      expect(
        original.copyWith(aiDifficulty: 'easy').confirmWallPlacement,
        false,
      );
      expect(
        original.copyWith(confirmWallPlacement: true).tutorialCompleted,
        isTrue,
      );
    });

    test('AppSettings equality and hashCode agree', () {
      const a = AppSettings(aiDifficulty: 'medium');
      const b = AppSettings(aiDifficulty: 'medium');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const AppSettings(aiDifficulty: 'hard')));
      expect(a.toString(), contains('medium'));
    });

    test('MatchStatistics copyWith and equality behave', () {
      final stats = MatchStatistics.empty.recordResult(
        boardSize: 9,
        difficulty: 'easy',
        humanWon: true,
      );
      expect(stats.copyWith(), stats);
      expect(stats.copyWith(matchesPlayed: 99).matchesPlayed, 99);
      expect(stats, isNot(stats.copyWith(matchesPlayed: 99)));
      expect(stats.hashCode, stats.copyWith().hashCode);
      expect(stats.toString(), contains('played: 1'));

      // Different bucket maps must not compare equal.
      final other = stats.recordResult(
        boardSize: 5,
        difficulty: 'local',
        humanWon: true,
      );
      expect(stats, isNot(other));
    });

    test('Bucket copyWith, equality and toString behave', () {
      const bucket = Bucket(played: 3, wins: 2, losses: 1);
      expect(bucket.copyWith(), bucket);
      expect(bucket.copyWith(wins: 3).wins, 3);
      expect(bucket, isNot(const Bucket(played: 3, wins: 1, losses: 2)));
      expect(
        bucket.hashCode,
        const Bucket(played: 3, wins: 2, losses: 1).hashCode,
      );
      expect(bucket.toString(), contains('played: 3'));
      // Malformed bucket JSON falls back to zeros.
      expect(Bucket.fromJson(<String, dynamic>{'played': 'x'}).played, 0);
    });

    test('MatchStatistics.fromJson coerces a double count', () {
      final stats = MatchStatistics.fromJson(<String, dynamic>{
        'matchesPlayed': 4.7,
      });
      expect(stats.matchesPlayed, 4);
    });

    test('UnfinishedMatch toString reports its context', () {
      final match = UnfinishedMatch(
        gameState: GameState.initial(),
        boardSize: 11,
        versusAi: true,
        aiDifficulty: 'expert',
        savedAtTurn: 8,
      );
      expect(match.toString(), contains('11'));
      expect(match.toString(), contains('expert'));
      expect(match.toString(), contains('8'));
    });
  });

  group('shared_preferences implementations', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('settings persist and reload', () async {
      const repo = SharedPreferencesSettingsRepository();
      const settings = AppSettings(
        confirmWallPlacement: false,
        aiDifficulty: 'medium',
      );

      expect(await repo.load(), AppSettings.defaults, reason: 'nothing stored');

      await repo.save(settings);
      expect(await repo.load(), settings);
    });

    test('settings survive a simulated app restart', () async {
      const repo = SharedPreferencesSettingsRepository();
      const settings = AppSettings(
        confirmWallPlacement: false,
        aiDifficulty: 'expert',
      );
      await repo.save(settings);

      // A "restart" is a brand new repository over the same backing store.
      const afterRestart = SharedPreferencesSettingsRepository();
      expect(await afterRestart.load(), settings);
    });

    test('a corrupt stored value degrades to defaults', () async {
      const repo = SharedPreferencesSettingsRepository();
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallforge.settings.v1': 'this is not json',
      });
      expect(await repo.load(), AppSettings.defaults);
    });

    test('statistics accumulate across repository instances', () async {
      const repo = SharedPreferencesStatisticsRepository();
      expect(await repo.load(), MatchStatistics.empty);

      await repo.recordResult(boardSize: 9, difficulty: 'easy', humanWon: true);
      await repo.recordResult(
        boardSize: 9,
        difficulty: 'easy',
        humanWon: false,
      );

      final reloaded = await const SharedPreferencesStatisticsRepository()
          .load();
      expect(reloaded.matchesPlayed, 2);
      expect(reloaded.humanWins, 1);
      expect(reloaded.humanLosses, 1);
      expect(reloaded.byDifficulty['easy']?.played, 2);
    });

    test('a corrupt statistics value degrades to empty', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallforge.statistics.v1': '{not valid',
      });
      expect(
        await const SharedPreferencesStatisticsRepository().load(),
        MatchStatistics.empty,
      );
    });

    test('statistics clear removes the stored value', () async {
      const repo = SharedPreferencesStatisticsRepository();
      await repo.recordResult(boardSize: 9, difficulty: 'easy', humanWon: true);
      await repo.clear();
      expect(await repo.load(), MatchStatistics.empty);
    });

    test('unfinished match persists, reloads and clears', () async {
      const repo = SharedPreferencesUnfinishedMatchRepository();
      expect(await repo.load(), isNull);

      final state = GameState.initial().copyWith(turnNumber: 6);
      final match = UnfinishedMatch(
        gameState: state,
        boardSize: 9,
        versusAi: true,
        aiDifficulty: 'hard',
        savedAtTurn: 6,
      );
      await repo.save(match);

      final reloaded = await const SharedPreferencesUnfinishedMatchRepository()
          .load();
      expect(reloaded, isNotNull);
      expect(reloaded!.gameState, state);
      expect(reloaded.versusAi, isTrue);

      await repo.clear();
      expect(await repo.load(), isNull);
    });

    test('a corrupt unfinished match loads as null', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'wallforge.unfinished_match.v1': 'nonsense',
      });
      expect(
        await const SharedPreferencesUnfinishedMatchRepository().load(),
        isNull,
      );
    });
  });

  group('in-memory implementations honour the same contract', () {
    test(
      'settings, statistics and unfinished match behave identically',
      () async {
        final settings = InMemorySettingsRepository();
        const wanted = AppSettings(confirmWallPlacement: false);
        await settings.save(wanted);
        expect(await settings.load(), wanted);
        expect(settings.saveCount, 1);

        final stats = InMemoryStatisticsRepository();
        final updated = await stats.recordResult(
          boardSize: 9,
          difficulty: 'local',
          humanWon: true,
        );
        expect(updated.matchesPlayed, 1);
        expect(await stats.load(), updated);
        await stats.clear();
        expect(await stats.load(), MatchStatistics.empty);

        final unfinished = InMemoryUnfinishedMatchRepository();
        final match = UnfinishedMatch(
          gameState: GameState.initial(),
          boardSize: 9,
          versusAi: false,
          aiDifficulty: 'local',
        );
        await unfinished.save(match);
        expect(await unfinished.load(), match);
        await unfinished.clear();
        expect(await unfinished.load(), isNull);
      },
    );
  });
}
