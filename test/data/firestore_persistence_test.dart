import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/data/remote/firestore_client.dart';
import 'package:wallforge/data/remote/firestore_settings_repository.dart';
import 'package:wallforge/data/remote/firestore_statistics_repository.dart';
import 'package:wallforge/data/remote/firestore_unfinished_match_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Conformance tests for the Firestore-backed Phase 6 repository interfaces.
///
/// **Coverage honesty.** The Firestore emulator is *not* usable in this
/// environment: the local emulator cache contains only the UI emulator, and the
/// Firebase CLI has no logged-in project, so there is no `firebase.json` target
/// to boot a Firestore emulator against. These tests therefore run against
/// [InMemoryFirestoreClient], which implements the same [FirestoreClient]
/// contract that [CloudFirestoreClient] implements over a real
/// `FirebaseFirestore`. That proves the repositories' logic, document layout and
/// error handling; it does **not** prove live Firestore connectivity, which
/// needs a configured project and is listed as an Open Question in
/// `memory.md` §13o.
void main() {
  const uid = 'device-owner-1';
  Future<String?> owner() async => uid;

  group('document layout is exactly three documents per user', () {
    test('paths are scoped under users/{uid}', () async {
      final client = InMemoryFirestoreClient();
      final settings = FirestoreSettingsRepository(
        client: client,
        userId: owner,
      );
      final stats = FirestoreStatisticsRepository(
        client: client,
        userId: owner,
      );
      final match = FirestoreUnfinishedMatchRepository(
        client: client,
        userId: owner,
      );

      await settings.save(const AppSettings(aiDifficulty: 'hard'));
      await stats.recordResult(
        boardSize: 9,
        difficulty: 'hard',
        humanWon: true,
      );
      await match.save(
        UnfinishedMatch(
          gameState: GameState.initial(),
          boardSize: 9,
          versusAi: true,
          aiDifficulty: 'hard',
        ),
      );

      expect(
        client.documents.keys.toList()..sort(),
        <String>[
          'users/$uid/settings',
          'users/$uid/statistics',
          'users/$uid/unfinishedMatch',
        ],
        reason:
            'three flat documents per user keeps the free-tier cost minimal',
      );
    });

    test('two different users never see each other documents', () async {
      final client = InMemoryFirestoreClient();
      Future<String?> otherOwner() async => 'device-owner-2';

      final a = FirestoreSettingsRepository(client: client, userId: owner);
      final b = FirestoreSettingsRepository(client: client, userId: otherOwner);

      // Deliberately the two opposite values, so the assertions below can only
      // pass if each owner really read back their own document.
      await a.save(const AppSettings(confirmWallPlacement: false));
      await b.save(const AppSettings());

      expect((await a.load()).confirmWallPlacement, isFalse);
      expect((await b.load()).confirmWallPlacement, isTrue);
    });
  });

  group('settings conformance', () {
    test('round-trips through the client', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreSettingsRepository(client: client, userId: owner);
      const settings = AppSettings(
        confirmWallPlacement: false,
        aiDifficulty: 'expert',
        tutorialCompleted: true,
      );

      expect(await repo.load(), AppSettings.defaults, reason: 'nothing stored');
      await repo.save(settings);
      expect(await repo.load(), settings);
    });

    test('survives a simulated restart over the same client', () async {
      final client = InMemoryFirestoreClient();
      const settings = AppSettings(aiDifficulty: 'medium');
      await FirestoreSettingsRepository(
        client: client,
        userId: owner,
      ).save(settings);

      final afterRestart = FirestoreSettingsRepository(
        client: client,
        userId: owner,
      );
      expect(await afterRestart.load(), settings);
    });

    test('a corrupt stored value degrades to defaults', () async {
      final client = InMemoryFirestoreClient(
        seed: <String, Map<String, dynamic>>{
          'users/$uid/settings': <String, dynamic>{
            'confirmWallPlacement': 'not-a-bool',
            'aiDifficulty': 'impossible',
          },
        },
      );
      final repo = FirestoreSettingsRepository(client: client, userId: owner);
      expect(await repo.load(), AppSettings.defaults);
    });

    test('a transport failure does not throw', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreSettingsRepository(client: client, userId: owner);

      client.failNextOperation = true;
      expect(await repo.load(), AppSettings.defaults);
      client.failNextOperation = true;
      await repo.save(const AppSettings());
      // Save swallowed the failure; the document simply is not there.
      expect(client.documents, isEmpty);
    });

    test('reads as valid JSON, so the document is portable', () async {
      final client = InMemoryFirestoreClient();
      await FirestoreSettingsRepository(
        client: client,
        userId: owner,
      ).save(const AppSettings(aiDifficulty: 'hard'));

      final encoded = jsonEncode(client.documents['users/$uid/settings']);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['aiDifficulty'], 'hard');
      expect(decoded['schemaVersion'], 1);
    });

    test('a null owner id is a no-op, not a crash', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreSettingsRepository(
        client: client,
        userId: () async => null,
      );
      expect(await repo.load(), AppSettings.defaults);
      await repo.save(const AppSettings());
      expect(client.documents, isEmpty);
    });
  });

  group('statistics conformance', () {
    test(
      'records wins and losses, split by board size and difficulty',
      () async {
        final client = InMemoryFirestoreClient();
        final repo = FirestoreStatisticsRepository(
          client: client,
          userId: owner,
        );

        expect(await repo.load(), MatchStatistics.empty);
        await repo.recordResult(
          boardSize: 9,
          difficulty: 'easy',
          humanWon: true,
        );
        await repo.recordResult(
          boardSize: 9,
          difficulty: 'expert',
          humanWon: false,
        );
        await repo.recordResult(
          boardSize: 7,
          difficulty: 'local',
          humanWon: true,
        );

        final stats = await FirestoreStatisticsRepository(
          client: client,
          userId: owner,
        ).load();

        expect(stats.matchesPlayed, 3);
        expect(stats.humanWins, 2);
        expect(stats.humanLosses, 1);
        expect(stats.byBoardSize['9']?.played, 2);
        expect(stats.byDifficulty['expert']?.losses, 1);
        expect(stats.byDifficulty['local']?.wins, 1);
      },
    );

    test('statistics survive a simulated restart', () async {
      final client = InMemoryFirestoreClient();
      await FirestoreStatisticsRepository(
        client: client,
        userId: owner,
      ).recordResult(boardSize: 5, difficulty: 'hard', humanWon: true);

      final reloaded = await FirestoreStatisticsRepository(
        client: client,
        userId: owner,
      ).load();
      expect(reloaded.matchesPlayed, 1);
      expect(reloaded.humanWins, 1);
    });

    test('one match result is one write, not a document per match', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreStatisticsRepository(client: client, userId: owner);
      for (var i = 0; i < 5; i++) {
        await repo.recordResult(
          boardSize: 9,
          difficulty: 'easy',
          humanWon: i.isEven,
        );
      }
      expect(
        client.documents.length,
        1,
        reason: 'storage must not grow with the number of matches played',
      );
      expect((await repo.load()).matchesPlayed, 5);
    });

    test('clear removes the document', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreStatisticsRepository(client: client, userId: owner);
      await repo.recordResult(boardSize: 9, difficulty: 'easy', humanWon: true);
      await repo.clear();
      expect(await repo.load(), MatchStatistics.empty);
    });

    test('a transport failure does not throw', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreStatisticsRepository(client: client, userId: owner);
      client.failNextOperation = true;
      expect(await repo.load(), MatchStatistics.empty);
      client.failNextOperation = true;
      final result = await repo.recordResult(
        boardSize: 9,
        difficulty: 'easy',
        humanWon: true,
      );
      expect(
        result.matchesPlayed,
        1,
        reason: 'the in-memory tally still applies',
      );
    });
  });

  group('unfinished match conformance', () {
    UnfinishedMatch sample() {
      final state = GameState.initial(const BoardConfig(size: 7)).copyWith(
        turnNumber: 4,
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
      return UnfinishedMatch(
        gameState: state,
        boardSize: 7,
        versusAi: true,
        aiDifficulty: 'hard',
        savedAtTurn: 4,
      );
    }

    test('round-trips the state through the client', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreUnfinishedMatchRepository(
        client: client,
        userId: owner,
      );
      expect(await repo.load(), isNull);

      final match = sample();
      await repo.save(match);
      final loaded = await FirestoreUnfinishedMatchRepository(
        client: client,
        userId: owner,
      ).load();

      expect(loaded, isNotNull);
      expect(loaded!.boardSize, 7);
      expect(loaded.versusAi, isTrue);
      expect(loaded.aiDifficulty, 'hard');
      expect(loaded.savedAtTurn, 4);
      expect(loaded.gameState, match.gameState);
    });

    test('a saved state violating an invariant loads as null', () async {
      final client = InMemoryFirestoreClient(
        seed: <String, Map<String, dynamic>>{
          'users/$uid/unfinishedMatch': <String, dynamic>{
            'boardSize': 9,
            'versusAi': false,
            'aiDifficulty': 'local',
            'savedAtTurn': 2,
            'gameState': GameStateSerializer.toJson(
              GameState.initial().copyWith(
                // Both pawns on one cell violates R-STATE-01.
                pawnPositions: const {
                  PlayerId.blue: Cell(row: 4, column: 4),
                  PlayerId.red: Cell(row: 4, column: 4),
                },
              ),
            ),
          },
        },
      );
      final repo = FirestoreUnfinishedMatchRepository(
        client: client,
        userId: owner,
      );
      expect(await repo.load(), isNull);
    });

    test('an unknown schema version loads as null', () async {
      final client = InMemoryFirestoreClient(
        seed: <String, Map<String, dynamic>>{
          'users/$uid/unfinishedMatch': <String, dynamic>{
            'boardSize': 9,
            'gameState': <String, dynamic>{'schemaVersion': 999},
          },
        },
      );
      expect(
        await FirestoreUnfinishedMatchRepository(
          client: client,
          userId: owner,
        ).load(),
        isNull,
      );
    });

    test('clear removes the document', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreUnfinishedMatchRepository(
        client: client,
        userId: owner,
      );
      await repo.save(sample());
      await repo.clear();
      expect(await repo.load(), isNull);
    });

    test('a transport failure does not throw', () async {
      final client = InMemoryFirestoreClient();
      final repo = FirestoreUnfinishedMatchRepository(
        client: client,
        userId: owner,
      );
      client.failNextOperation = true;
      expect(await repo.load(), isNull);
      client.failNextOperation = true;
      await repo.save(sample());
      expect(client.documents, isEmpty);
    });
  });
}
