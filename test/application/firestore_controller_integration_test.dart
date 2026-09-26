import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/ai/ai_difficulty.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/data/local/in_memory_repositories.dart';
import 'package:wallforge/data/remote/firestore_settings_repository.dart';
import 'package:wallforge/data/remote/firestore_statistics_repository.dart';
import 'package:wallforge/data/remote/firestore_unfinished_match_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';

/// Proves the Phase 6 interface boundary actually holds.
///
/// The scenarios below are deliberately the *same* ones
/// `persistence_integration_test.dart` runs against the `shared_preferences`
/// repositories, with the only difference being that the three repositories are
/// now Firestore-backed. Not one line of application code changes between the
/// two files — which is the entire point of the boundary, and the reason Phase 7
/// needed no application changes.
void main() {
  const uid = 'device-owner-1';
  Future<String?> owner() async => uid;

  /// A controller wired to Firestore-backed repositories over a shared in-memory
  /// document store, which stands in for a project in tests.
  ({LocalGameController controller, InMemoryFirestoreClient client}) openApp({
    InMemoryFirestoreClient? client,
  }) {
    final store = client ?? InMemoryFirestoreClient();
    final controller = LocalGameController();
    controller.attachPersistence(
      settings: FirestoreSettingsRepository(client: store, userId: owner),
      statistics: FirestoreStatisticsRepository(client: store, userId: owner),
      unfinishedMatch: FirestoreUnfinishedMatchRepository(
        client: store,
        userId: owner,
      ),
    );
    return (controller: controller, client: store);
  }

  void playToBlueWin(LocalGameController controller) {
    const moves = <Cell>[
      Cell(row: 3, column: 2),
      Cell(row: 0, column: 3),
      Cell(row: 2, column: 2),
      Cell(row: 1, column: 3),
      Cell(row: 1, column: 2),
      Cell(row: 0, column: 3),
      Cell(row: 0, column: 2),
    ];
    for (final cell in moves) {
      controller.tapCell(cell);
      if (controller.state.status == GameStatus.finished) return;
    }
  }

  test('the controller reports persistence as attached', () {
    final app = openApp();
    expect(app.controller.hasPersistence, isTrue);
    app.controller.dispose();
  });

  test('settings survive a restart backed by Firestore', () async {
    final first = openApp();
    first.controller.toggleConfirmWallPlacement();
    expect(first.controller.confirmWallPlacement, isFalse);
    first.controller.dispose();

    // Same document store, brand new controller: the Phase 6 scenario, unchanged.
    final second = openApp(client: first.client);
    await second.controller.loadPersisted();
    expect(second.controller.confirmWallPlacement, isFalse);
    second.controller.dispose();
  });

  test('an unfinished match is saved, restored and continued', () async {
    final first = openApp();
    final controller = first.controller;
    controller.startMatch(config: const BoardConfig(size: 7));

    controller.tapCell(const Cell(row: 5, column: 3)); // Blue
    controller.tapCell(const Cell(row: 0, column: 4)); // Red
    final turnBeforeClose = controller.state.turnNumber;
    final blueBefore = controller.state.pawnPosition(PlayerId.blue);
    expect(turnBeforeClose, 2);
    expect(controller.state.status, GameStatus.inProgress);
    controller.dispose();

    // The document really is in the store, under the documented path. A
    // microtask drain is required because resolving the owner id is async, so
    // the unawaited write lands a tick later than the local implementation.
    await Future<void>.delayed(Duration.zero);
    expect(
      first.client.documents.containsKey('users/$uid/unfinishedMatch'),
      isTrue,
    );

    final second = openApp(client: first.client);
    await second.controller.refreshResumableMatch();
    final saved = second.controller.resumableMatch;
    expect(saved, isNotNull);
    expect(saved!.versusAi, isFalse);
    expect(second.controller.resumeMatch(saved), isTrue);

    expect(second.controller.state.turnNumber, turnBeforeClose);
    expect(second.controller.state.pawnPosition(PlayerId.blue), blueBefore);
    expect(second.controller.currentPlayer, PlayerId.blue);
    expect(second.controller.legalMoveTargets, isNotEmpty);

    final turnBefore = second.controller.state.turnNumber;
    second.controller.tapCell(second.controller.legalMoveTargets.first);
    expect(second.controller.state.turnNumber, turnBefore + 1);
    second.controller.dispose();
  });

  test('a resumed AI match keeps its opponent and difficulty', () async {
    final first = openApp();
    first.controller.startMatch(
      versusAi: true,
      aiDifficulty: AiDifficulty.hard,
    );
    first.controller.tapCell(const Cell(row: 8, column: 3));
    await Future<void>.delayed(
      kAiThinkDelay + const Duration(milliseconds: 50),
    );
    expect(first.controller.state.turnNumber, 2);
    first.controller.dispose();

    final second = openApp(client: first.client);
    await second.controller.refreshResumableMatch();
    final match = second.controller.resumableMatch!;
    expect(match.versusAi, isTrue);
    expect(match.aiDifficulty, 'hard');
    second.controller.resumeMatch(match);
    expect(second.controller.versusAi, isTrue);
    expect(second.controller.aiDifficulty, AiDifficulty.hard);
    second.controller.dispose();
  });

  test('a finished match is recorded in Firestore and not resumable', () async {
    final app = openApp();
    final controller = app.controller;
    controller.startMatch(config: const BoardConfig(size: 5));
    playToBlueWin(controller);
    expect(controller.state.winner, PlayerId.blue);

    await Future<void>.delayed(Duration.zero);

    final statsDoc = app.client.documents['users/$uid/statistics'];
    expect(statsDoc, isNotNull);
    expect(statsDoc!['matchesPlayed'], 1);
    expect(statsDoc['humanWins'], 1);
    expect(
      app.client.documents.containsKey('users/$uid/unfinishedMatch'),
      isFalse,
      reason: 'a finished match must not stay resumable',
    );
    controller.dispose();
  });

  test('a transport failure never breaks the controller', () async {
    final app = openApp();
    final controller = app.controller;
    controller.startMatch(config: const BoardConfig(size: 5));
    // Let startMatch's own unawaited writes settle, so the injected fault is
    // consumed by the taps under test rather than by start-up work.
    await Future<void>.delayed(Duration.zero);

    // Every storage operation from here on fails. Turns still alternate, so the
    // moves below alternate Blue and Red.
    app.client.failNextOperation = true;
    controller.tapCell(const Cell(row: 3, column: 2));
    await Future<void>.delayed(Duration.zero);
    app.client.failNextOperation = true;
    controller.tapCell(const Cell(row: 0, column: 3));
    await Future<void>.delayed(Duration.zero);

    // Play is unaffected: the failures cost persistence, not the match. Had the
    // repositories not guarded their client calls, this test would fail with an
    // uncaught StateError instead of reaching these assertions.
    expect(controller.state.turnNumber, 2);
    expect(controller.state.pawnPosition(PlayerId.blue).row, 3);
    expect(controller.state.pawnPosition(PlayerId.red).column, 3);
    expect(
      app.client.documents.containsKey('users/$uid/unfinishedMatch'),
      isFalse,
      reason:
          'the resumable save could not be written while storage was failing',
    );
    controller.dispose();
  });

  test('a dispose during an in-flight load is ignored', () async {
    // Phase 7 made the storage read genuinely network-bound, so a route can now
    // be popped while `loadPersisted` is still awaiting. That must not notify a
    // disposed ChangeNotifier, which Flutter asserts against.
    final completer = Completer<AppSettings>();
    final controller = LocalGameController();
    controller.attachPersistence(
      settings: _SlowSettingsRepository(completer),
      statistics: InMemoryStatisticsRepository(),
      unfinishedMatch: InMemoryUnfinishedMatchRepository(),
    );
    final pending = controller.loadPersisted();
    controller.dispose();
    completer.complete(AppSettings.defaults);
    await expectLater(pending, completes);
  });

  test('swapping the local repositories for Firestore ones needs no '
      'application change', () {
    // The same controller, two different repository sets. If this needed an
    // application edit, the Phase 6 boundary would not be doing its job.
    final local = LocalGameController();
    final remote = LocalGameController();
    expect(local.runtimeType, remote.runtimeType);

    local.attachPersistence(
      settings: InMemorySettingsRepository(),
      statistics: InMemoryStatisticsRepository(),
      unfinishedMatch: InMemoryUnfinishedMatchRepository(),
    );
    remote.attachPersistence(
      settings: FirestoreSettingsRepository(
        client: InMemoryFirestoreClient(),
        userId: owner,
      ),
      statistics: FirestoreStatisticsRepository(
        client: InMemoryFirestoreClient(),
        userId: owner,
      ),
      unfinishedMatch: FirestoreUnfinishedMatchRepository(
        client: InMemoryFirestoreClient(),
        userId: owner,
      ),
    );
    expect(local.hasPersistence, isTrue);
    expect(remote.hasPersistence, isTrue);
    local.dispose();
    remote.dispose();
  });
}

/// A settings repository whose read is controlled by the test, so the
/// dispose-during-load window can be hit deterministically.
class _SlowSettingsRepository implements SettingsRepository {
  _SlowSettingsRepository(this._completer);

  final Completer<AppSettings> _completer;

  @override
  Future<AppSettings> load() => _completer.future;

  @override
  Future<void> save(AppSettings settings) async {}
}
