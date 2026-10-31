import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/account/account_controller.dart';
import 'package:wallforge/app/application/account/identity_guard.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/local/shared_preferences_leaderboard_name_repository.dart';
import 'package:wallforge/presentation/screens/account/account_screen.dart';

import '../support/fake_account_auth_gateway.dart';

/// Phase 16.6, Part H: the responsive / accessibility matrix
/// for the new account screens — six viewports at UI scale 1
/// and 1.5, plus high-contrast and reduced-motion variants.
/// Every render must complete without an exception (overflow,
/// layout or otherwise) — the Phase 13 tolerance bound applied
/// to the phase's own screens, in both identity states (the
/// guest layout carries the sign-in form; the account layout
/// carries the verify, session and delete cards).
void main() {
  const viewports = <Size>[
    Size(320, 568),
    Size(390, 844),
    Size(768, 1024),
    Size(1024, 768),
    Size(1440, 900),
    Size(844, 390),
  ];

  Future<AccountController> controllerFor({required bool account}) async {
    final controller = AccountController(
      gateway: FakeAccountAuthGateway(),
      guard: IdentityGuard(),
    );
    await controller.start();
    if (account) {
      // An unverified email account shows the fullest layout:
      // status, verify card, session card and delete card.
      await controller.createEmailAccount(
        email: 'player@x.io',
        password: 'password-9',
      );
    }
    return controller;
  }

  Future<void> pumpAccount(
    WidgetTester tester,
    AccountController controller, {
    required Size size,
    required double scale,
    bool highContrast = false,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              highContrast: highContrast,
              disableAnimations: reducedMotion,
            ),
            child: AccountScreen(
              controller: controller,
              nameRepository: InMemoryLeaderboardNameRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason:
          'account screen must render cleanly at $size x$scale '
          '(hc=$highContrast rm=$reducedMotion)',
    );
  }

  for (final account in [false, true]) {
    final state = account ? 'account' : 'guest';
    for (final size in viewports) {
      for (final scale in [1.0, 1.5]) {
        testWidgets('$state at ${size.width}x${size.height} x$scale', (
          tester,
        ) async {
          final controller = await controllerFor(account: account);
          addTearDown(controller.dispose);
          await pumpAccount(tester, controller, size: size, scale: scale);
        });
      }
    }
    testWidgets('$state high-contrast + reduced motion, phone x1.5', (
      tester,
    ) async {
      final controller = await controllerFor(account: account);
      addTearDown(controller.dispose);
      await pumpAccount(
        tester,
        controller,
        size: const Size(390, 844),
        scale: 1.5,
        highContrast: true,
        reducedMotion: true,
      );
    });
  }
}
