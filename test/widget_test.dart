// Phase 0 smoke test.
//
// This verifies the real application shell initialises and renders the
// Wallforge foundation (branding + tagline) — not a placeholder counter.
//
// Conventions for later phases (see `architecture.md` §20):
//   - put domain tests under `test/domain/`
//   - put application tests under `test/application/`
//   - put data tests under `test/data/`
//   - engine tests must be deterministic and framework-independent.

import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/app.dart';

void main() {
  group('Wallforge application shell', () {
    testWidgets('launches and shows Wallforge branding', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WallforgeApp());
      await tester.pumpAndSettle();

      // Branding is rendered in uppercase as the display title.
      expect(find.text('WALLFORGE'), findsOneWidget);
    });

    testWidgets('shows the project tagline from design.md', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WallforgeApp());
      await tester.pumpAndSettle();

      expect(find.text('Forge your path. Block your rival.'), findsOneWidget);
    });
  });
}
