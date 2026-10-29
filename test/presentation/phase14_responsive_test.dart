import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/local_game_controller.dart';
import 'package:wallforge/app/theme/app_breakpoints.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/board/board.dart';
import 'package:wallforge/presentation/screens/game/game_screen.dart';

/// Phase 14 (Responsive Web): the centralized breakpoints, the
/// three-tier layouts with tablet-specific assertions, the
/// landscape-phone decision, mouse hover, uiScale composition, and
/// resize discipline.
///
/// The four standard viewports plus the landscape phone size.
const _sizes = <Size>[
  Size(320, 568),
  Size(390, 844),
  Size(768, 1024),
  Size(1440, 900),
  Size(844, 390),
];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.dark, home: home);

void main() {
  group('AppBreakpoints', () {
    test('tier boundaries: 768 is the tablet floor, 1024 desktop', () {
      expect(AppBreakpoints.tierForWidth(320), AppBreakpoint.phone);
      expect(AppBreakpoints.tierForWidth(767), AppBreakpoint.phone);
      expect(AppBreakpoints.tierForWidth(768), AppBreakpoint.tablet);
      expect(AppBreakpoints.tierForWidth(1023), AppBreakpoint.tablet);
      expect(AppBreakpoints.tierForWidth(1024), AppBreakpoint.desktop);
      expect(AppBreakpoints.tierForWidth(1440), AppBreakpoint.desktop);
    });

    test('landscape phone = wider than tall and phone-short', () {
      expect(AppBreakpoints.isLandscapePhone(const Size(844, 390)), isTrue);
      expect(AppBreakpoints.isLandscapePhone(const Size(390, 844)), isFalse);
      expect(AppBreakpoints.isLandscapePhone(const Size(768, 1024)), isFalse);
      // A landscape tablet is not a landscape phone.
      expect(AppBreakpoints.isLandscapePhone(const Size(1024, 768)), isFalse);
    });

    test('no hard-coded breakpoint literal remains in lib/', () {
      // The scan the phase promised: the raw comparison literal may
      // exist only inside the centralized definition itself.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('app_breakpoints.dart')) continue;
        final text = entity.readAsStringSync();
        for (final pattern in ['>= 768', '> 768', '< 768', '<= 768']) {
          if (text.contains(pattern)) {
            offenders.add('${entity.path} contains "$pattern"');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('local game screen tiers', () {
    Future<void> pumpGame(WidgetTester tester, Size size) async {
      _setSize(tester, size);
      await tester.pumpWidget(
        _app(GameScreen(controller: LocalGameController())),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    testWidgets('phone tiers: strips, no rails', (tester) async {
      for (final size in [const Size(320, 568), const Size(390, 844)]) {
        await pumpGame(tester, size);
        expect(find.text('P1'), findsOneWidget, reason: '$size');
        expect(find.text('PLAYER 1'), findsNothing, reason: '$size');
      }
    });

    testWidgets('tablet 768x1024: hybrid — strips kept, board grows, '
        'content centered (NOT the desktop layout)', (tester) async {
      await pumpGame(tester, const Size(390, 844));
      final phoneBoard = tester.getSize(find.byType(BoardView)).width;

      await pumpGame(tester, const Size(768, 1024));
      // Tablet assertions deliberately differ from desktop's: the
      // strip arrangement is kept (no 280px rails, no PLAYER 1 rail
      // card) — before Phase 14 this viewport got the desktop rails.
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('PLAYER 1'), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 280),
        findsNothing,
      );
      final boardSize = tester.getSize(find.byType(BoardView));
      // The board is substantially larger than on a phone…
      expect(boardSize.width, greaterThan(phoneBoard + 100));
      // …but capped by the hybrid measure, and centered.
      expect(boardSize.width, lessThanOrEqualTo(680));
      final center = tester.getCenter(find.byType(BoardView));
      expect(center.dx, closeTo(768 / 2, 2));
    });

    testWidgets('desktop 1440x900: side rails return', (tester) async {
      await pumpGame(tester, const Size(1440, 900));
      expect(find.text('PLAYER 1'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 280),
        findsNWidgets(2),
      );
    });

    testWidgets('landscape phone 844x390: compact rails, no overflow', (
      tester,
    ) async {
      await pumpGame(tester, const Size(844, 390));
      // The recorded decision: landscape phones borrow the side-panel
      // arrangement with compact 200px rails.
      expect(find.text('PLAYER 1'), findsOneWidget);
      // The rail card renders at 200 minus its margins (2 x 16).
      final railCard = tester.getSize(
        find
            .ancestor(
              of: find.text('PLAYER 1'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(railCard.width, closeTo(200 - 32, 1));
      expect(tester.takeException(), isNull);
    });
  });

  group('mouse hover (design §28)', () {
    testWidgets('hovering a wall slot in WALL mode shows the ghost; '
        'leaving clears it', (tester) async {
      _setSize(tester, const Size(1024, 768));
      final controller = LocalGameController();
      await tester.pumpWidget(_app(GameScreen(controller: controller)));
      await tester.pump();
      await tester.tap(find.text('WALL'));
      await tester.pump();

      BoardPainter painter() =>
          tester
                  .widget<CustomPaint>(
                    find
                        .descendant(
                          of: find.byType(BoardView),
                          matching: find.byType(CustomPaint),
                        )
                        .first,
                  )
                  .painter!
              as BoardPainter;
      expect(painter().wallPreview, isNull);

      final boardTopLeft = tester.getTopLeft(find.byType(BoardView));
      final boardWidth = tester.getSize(find.byType(BoardView)).width;
      final geometry = BoardGeometry(
        boardSize: controller.state.boardConfig.size,
        areaSize: boardWidth,
      );
      // Hover a point inside the horizontal slot but away from the
      // grid crossing at its center, where the vertical slot's snap
      // tolerance also reaches (the tap logic shares that priority).
      final slotRect = geometry.wallRect(2, 2, WallOrientation.h);
      final slotCenter =
          boardTopLeft +
          Offset(slotRect.left + slotRect.width / 4, slotRect.center.dy);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: slotCenter);
      await tester.pump();
      await gesture.moveTo(slotCenter);
      await tester.pump();

      final preview = painter().wallPreview;
      expect(preview, isNotNull);
      expect(preview!.anchor, const Cell(row: 2, column: 2));
      expect(preview.orientation, WallOrientation.h);
      // A fresh board: this slot is legal, and the hover ghost says
      // so — via the same engine validate the staged preview uses.
      expect(preview.isValid, isTrue);

      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(painter().wallPreview, isNull);
      await gesture.removePointer();
    });
  });

  group('resize discipline (rules §16)', () {
    testWidgets('resizing through every tier never touches game state', (
      tester,
    ) async {
      final controller = LocalGameController();
      _setSize(tester, const Size(390, 844));
      await tester.pumpWidget(_app(GameScreen(controller: controller)));
      await tester.pump();
      // Make a real move first, so there is state worth protecting.
      final target = controller.legalMoveTargets.first;
      controller.tapCell(target);
      await tester.pump();
      final stateBefore = controller.state;
      final turnBefore = controller.state.turnNumber;
      final targetsBefore = controller.legalMoveTargets;

      for (final size in _sizes) {
        _setSize(tester, size);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: '$size');
        // The very same state object: no recompute, no new engine
        // state, no re-run of anything game-logical on a resize.
        expect(identical(controller.state, stateBefore), isTrue);
        expect(controller.state.turnNumber, turnBefore);
        expect(controller.legalMoveTargets, targetsBefore);
      }
    });
  });
}
