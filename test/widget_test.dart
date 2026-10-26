import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/presentation/board/board.dart';
import 'package:wallforge/presentation/screens/home/home_screen.dart';
import 'package:wallforge/presentation/screens/splash/splash_screen.dart';

void main() {
  group('Wallforge application shell', () {
    testWidgets('launches to the splash, then lands on Home', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(const WallforgeApp());
      await tester.pump();

      // The entry route is the Phase 11 splash (design ledger §13s).
      expect(find.byType(SplashScreen), findsOneWidget);

      // The splash replaces itself with Home after its branding beat.
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      // Home carries the small board visual design.md §17 asks for.
      expect(find.byType(BoardView), findsOneWidget);
    });
  });
}
