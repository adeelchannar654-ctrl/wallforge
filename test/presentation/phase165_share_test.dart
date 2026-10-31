import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/replay.dart';
import 'package:wallforge/app/application/share_result_text.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/widgets/result_card.dart';

/// Phase 16.5, Part G: the shareable result — text contents,
/// replay honesty, the rendered card's bytes and size, and
/// the platform fallback flow (native: text copied + card
/// preview; no board when the move list is partial).
MatchRecord record({
  FinishReason reason = FinishReason.goal,
  PlayerId? winnerSide = PlayerId.blue,
  List<String> moves = const ['M 7,4', 'M 1,4', 'M 6,4'],
  bool movesComplete = true,
}) => MatchRecord(
  id: 'SECRET-ROOM-CODE',
  mode: MatchMode.online,
  boardSize: 9,
  wallsPerPlayer: 10,
  mySide: PlayerId.blue,
  winnerSide: winnerSide,
  finishReason: reason,
  opponentLabel: 'Online player',
  plies: moves.length,
  durationMs: 12 * 60 * 1000,
  endedAtMs: DateTime(2026, 10, 31, 18, 30).millisecondsSinceEpoch,
  timeControlSeconds: 30,
  moves: moves,
  movesComplete: movesComplete,
  rematchOf: null,
);

void main() {
  group('buildShareText', () {
    test('carries the facts and no identifier', () {
      final text = buildShareText(record());
      expect(text, startsWith('Blue wins — Wallforge'));
      expect(text, contains('Online'));
      expect(text, contains('Online player'));
      expect(text, contains('9×9'));
      expect(text, contains('3 plies'));
      expect(text, contains('12 min'));
      expect(text, contains('Oct 31, 2026'));
      // The record id (a room code) must never leak into a share.
      expect(text, isNot(contains('SECRET-ROOM-CODE')));
    });

    test('timeout and abandonment wordings', () {
      expect(
        buildShareText(record(reason: FinishReason.timeout)),
        startsWith('Blue wins on time'),
      );
      expect(
        buildShareText(record(reason: FinishReason.resign)),
        startsWith('Blue wins by resignation'),
      );
      expect(
        buildShareText(record(reason: FinishReason.abandon, winnerSide: null)),
        startsWith('Match abandoned'),
      );
    });
  });

  group('replayFinalState', () {
    test('a complete list replays to the true final board', () {
      final state = replayFinalState(record());
      expect(state, isNotNull);
      expect(state!.turnNumber, 3);
      expect(state.pawnPosition(PlayerId.blue), const Cell(row: 6, column: 4));
      expect(state.pawnPosition(PlayerId.red), const Cell(row: 1, column: 4));
    });

    test('a partial or corrupt list yields no board', () {
      expect(replayFinalState(record(movesComplete: false)), isNull);
      expect(replayFinalState(record(moves: ['M 7,4', 'X 9,9'])), isNull);
      // An illegal jump (two cells in one move) is refused.
      expect(replayFinalState(record(moves: ['M 5,4'])), isNull);
    });
  });

  group('the card and the share flow', () {
    String? clipboardText;

    setUp(() {
      clipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              clipboardText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('capture produces a PNG at the expected size', (tester) async {
      Uint8List? png;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  png = await captureResultCardPng(
                    context,
                    ResultCard(
                      record: record(),
                      finalState: replayFinalState(record())!,
                    ),
                  );
                },
                child: const Text('CAPTURE'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('CAPTURE'));
      await tester.pump();
      // The overlay paints across fake-zone frames while the
      // PNG readback lands on the engine's real event loop:
      // give the real loop a grace period, then settle so the
      // capture's continuations flush and the assignment lands.
      // One retry, so a loaded machine does not flake the test.
      for (var attempt = 0; attempt < 2 && png == null; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 750)),
        );
        await tester.pumpAndSettle();
      }
      expect(png, isNotNull);
      // PNG magic bytes.
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      // Decoding is engine async work: it belongs in runAsync,
      // like the readback itself.
      final dims = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(png!);
        final frame = await codec.getNextFrame();
        return (frame.image.width, frame.image.height);
      });
      // 600×780 logical at pixelRatio 2.
      expect(dims, (1200, 1560));
    });

    testWidgets('native flow: text copied, card previewed', (tester) async {
      Future<void>? pending;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  pending = shareMatchResult(
                    context,
                    record: record(),
                    finalState: replayFinalState(record()),
                  );
                },
                child: const Text('SHARE'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SHARE'));
      await tester.pump();
      expect(pending, isNotNull);
      // Let the capture half finish on the real event loop;
      // the dialog it opens is then pumped into view. One
      // retry, so a loaded machine does not flake the test.
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
        if (find.text('Your result card').evaluate().isNotEmpty) break;
      }
      expect(clipboardText, buildShareText(record()));
      expect(find.text('Your result card'), findsOneWidget);
      expect(find.textContaining('system share sheet'), findsOneWidget);
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();
      expect(find.text('Your result card'), findsNothing);
    });

    testWidgets('a partial list shares text only, and says why', (
      tester,
    ) async {
      final partial = record(movesComplete: false);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => shareMatchResult(
                  context,
                  record: partial,
                  finalState: replayFinalState(partial),
                ),
                child: const Text('SHARE'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('SHARE'));
      await tester.pumpAndSettle();
      expect(clipboardText, buildShareText(partial));
      expect(find.text('Your result card'), findsNothing);
      expect(find.textContaining('move list is incomplete'), findsOneWidget);
    });
  });
}
