import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';
import 'package:wallforge/presentation/widgets/clock_chip.dart';

/// Phase 16.5, Part C: the clock's UI surface — the countdown
/// chip (with its non-colour low-time cue) and the lobby's
/// create-room clock picker writing the chosen control into
/// the created room.
class _StubAuth implements AuthGateway {
  const _StubAuth();
  @override
  Future<AuthState> signInAnonymously() async => const AuthState.signedIn('u1');
  @override
  Future<AuthState> current() async => const AuthState.signedIn('u1');
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => 'u1';
}

void main() {
  group('ClockChip', () {
    testWidgets('shows the time and a timer icon while time is fine', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClockChip(remaining: Duration(seconds: 42), lowTime: false),
          ),
        ),
      );
      expect(find.text('0:42'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    });

    testWidgets('low time swaps the icon, not just the colour', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClockChip(
              remaining: Duration(seconds: 4),
              lowTime: true,
              announcement: '5 seconds left',
            ),
          ),
        ),
      );
      expect(find.text('0:04'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      // The semantic label carries the low-time fact in words.
      final semantics = tester.getSemantics(find.text('0:04'));
      expect(semantics.label, contains('low time'));
      expect(semantics.label, contains('4 seconds'));
    });
  });

  group('lobby clock picker', () {
    late InMemoryFirestoreClient store;

    setUp(() => store = InMemoryFirestoreClient());
    tearDown(() => store.closeWatchers());

    Future<OnlineLobbyController> pumpLobby(WidgetTester tester) async {
      const auth = _StubAuth();
      final controller = OnlineLobbyController(
        auth: auth,
        rooms: FirestoreRoomRepository(
          client: store,
          userId: auth.currentUid,
          clock: () => DateTime.utc(2026, 10, 31, 12),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: OnlineLobbyScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('the default is Off and the room is created unclocked', (
      tester,
    ) async {
      final controller = await pumpLobby(tester);
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();
      expect(controller.room, isNotNull);
      expect(controller.room!.timeControlSeconds, 0);
    });

    testWidgets('choosing 30s creates a 30-second room', (tester) async {
      final controller = await pumpLobby(tester);
      await tester.tap(find.widgetWithText(ChoiceChip, '30s'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();
      expect(controller.room, isNotNull);
      expect(controller.room!.timeControlSeconds, 30);
    });
  });
}
