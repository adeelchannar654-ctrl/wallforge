import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/app.dart';
import 'package:wallforge/presentation/board/board.dart';

void main() {
  group('Wallforge application shell', () {
    testWidgets('launches and shows board preview screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const WallforgeApp());
      await tester.pumpAndSettle();

      // BoardPreviewScreen shows the board view.
      expect(find.byType(BoardView), findsOneWidget);
    });
  });
}
