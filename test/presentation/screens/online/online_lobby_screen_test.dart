import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';

/// Always-succeeds anonymous identity, so the widget tests exercise the lobby UI
/// rather than the auth failure path (covered in the controller tests).
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

/// Fails sign-in, to prove the screen shows a message instead of hanging.
class _FailingAuth implements AuthGateway {
  const _FailingAuth();
  @override
  Future<AuthState> signInAnonymously() async =>
      const AuthState.unavailable('FirebaseAuthException(anonymous-disabled)');
  @override
  Future<AuthState> current() async => const AuthState.signedOut();
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => null;
}

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  OnlineLobbyController lobby({AuthGateway auth = const _StubAuth()}) =>
      OnlineLobbyController(
        auth: auth,
        rooms: FirestoreRoomRepository(
          client: store,
          userId: auth.currentUid,
          clock: () => DateTime.utc(2026, 9, 27, 12),
        ),
      );

  /// Mounts the screen and lets the automatic anonymous sign-in settle, so the
  /// first interaction happens in the idle state rather than mid-handshake.
  Future<void> pump(
    WidgetTester tester,
    OnlineLobbyController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: OnlineLobbyScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('entry state', () {
    testWidgets('offers create and join, and nothing about a room yet', (
      tester,
    ) async {
      final controller = lobby();
      addTearDown(controller.dispose);
      await pump(tester, controller);

      expect(find.text('CREATE A ROOM'), findsOneWidget);
      expect(find.text('JOIN A ROOM'), findsOneWidget);
      expect(find.text('ROOM CODE'), findsNothing);
      expect(find.text('LEAVE ROOM'), findsNothing);
      expect(find.text('BACK'), findsOneWidget);
    });

    testWidgets('shows the sign-in failure rather than hanging', (
      tester,
    ) async {
      final controller = lobby(auth: const _FailingAuth());
      addTearDown(controller.dispose);
      await pump(tester, controller);
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();

      expect(find.text('DISCONNECTED'), findsOneWidget);
      expect(find.textContaining('Sign in to play online'), findsOneWidget);
    });
  });

  group('creating', () {
    testWidgets('shows the generated code and both seats', (tester) async {
      final controller = lobby();
      addTearDown(controller.dispose);
      await pump(tester, controller);
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();

      final code = controller.roomCode!;
      expect(find.text('ROOM CODE'), findsOneWidget);
      expect(find.text(code), findsOneWidget);
      expect(find.text('9x9 board'), findsOneWidget);
      expect(find.text('BLUE'), findsOneWidget);
      expect(find.text('RED'), findsOneWidget);
      expect(find.text('(YOU)'), findsOneWidget);
      // The creator is told they are Blue, and the room is not startable yet.
      expect(find.text('WAITING'), findsOneWidget);
      expect(find.text('WAITING FOR READY'), findsOneWidget);
      expect(find.text('READY UP'), findsOneWidget);
      expect(find.text('LEAVE ROOM'), findsOneWidget);
    });

    testWidgets('leaving returns to the entry state', (tester) async {
      final controller = lobby();
      addTearDown(controller.dispose);
      await pump(tester, controller);
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LEAVE ROOM'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE A ROOM'), findsOneWidget);
      expect(find.text('ROOM CODE'), findsNothing);
    });
  });

  group('joining', () {
    testWidgets('rejects a malformed code next to the field', (tester) async {
      final controller = lobby();
      addTearDown(controller.dispose);
      await pump(tester, controller);

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('JOIN ROOM'));
      await tester.pumpAndSettle();

      expect(find.textContaining('6 characters'), findsWidgets);
      expect(find.text('ROOM CODE'), findsNothing);
    });

    testWidgets('reports an unknown code with the repository message', (
      tester,
    ) async {
      final controller = lobby();
      addTearDown(controller.dispose);
      await pump(tester, controller);

      await tester.enterText(find.byType(TextField), 'AB39HK');
      await tester.tap(find.text('JOIN ROOM'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No room with that code'), findsOneWidget);
      expect(find.text('ROOM CODE'), findsNothing);
    });
  });

  group('lobby with two players', () {
    /// Drives a second controller into the same room, as a second device would.
    Future<void> secondPlayerJoins(WidgetTester tester, String code) async {
      final other = OnlineLobbyController(
        auth: const _StubAuth2(),
        rooms: FirestoreRoomRepository(
          client: store,
          userId: () async => 'u2',
          clock: () => DateTime.utc(2026, 9, 27, 12),
        ),
      );
      addTearDown(other.dispose);
      await other.signIn();
      await other.joinRoom(code);
      await tester.pumpAndSettle();
    }

    testWidgets('ready state is reflected per player', (tester) async {
      final controller = lobby();
      addTearDown(controller.dispose);
      await pump(tester, controller);
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();
      await secondPlayerJoins(tester, controller.roomCode!);

      expect(find.text('CONNECTED'), findsOneWidget);
      await tester.tap(find.text('READY UP'));
      await tester.pumpAndSettle();

      // Our own ready flag flips, and the button offers to withdraw it.
      expect(find.text('UNREADY'), findsOneWidget);
      expect(find.text('WAITING FOR READY'), findsOneWidget);
    });

    testWidgets('starting reveals the honest no-synchronisation notice', (
      tester,
    ) async {
      final controller = lobby();
      addTearDown(controller.dispose);
      await pump(tester, controller);
      await tester.tap(find.text('CREATE ROOM'));
      await tester.pumpAndSettle();
      final code = controller.roomCode!;
      await secondPlayerJoins(tester, code);

      await tester.tap(find.text('READY UP'));
      await tester.pumpAndSettle();

      final other = OnlineLobbyController(
        auth: const _StubAuth2(),
        rooms: FirestoreRoomRepository(
          client: store,
          userId: () async => 'u2',
          clock: () => DateTime.utc(2026, 9, 27, 12),
        ),
      );
      addTearDown(other.dispose);
      await other.signIn();
      await other.joinRoom(code);
      await other.toggleReady();
      await tester.pumpAndSettle();

      await tester.tap(find.text('START MATCH'));
      await tester.pumpAndSettle();

      expect(find.text('MATCH STARTED'), findsOneWidget);
      expect(find.text('PLAY'), findsOneWidget);
      // The screen must not imply moves are synchronised.
      expect(
        find.textContaining('synchronised between devices'),
        findsOneWidget,
      );
      expect(find.textContaining('You play BLUE'), findsOneWidget);
    });
  });

  group('ownership', () {
    testWidgets('a screen that owns its controller disposes it', (
      tester,
    ) async {
      final controller = lobby();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: OnlineLobbyScreen(controller: controller, ownsController: true),
        ),
      );
      await tester.pumpAndSettle();
      // Replacing the tree tears the route down; the controller must go with it.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pumpAndSettle();
      // A disposed ChangeNotifier throws if touched afterwards, so the absence
      // of an error here is the assertion.
      expect(tester.takeException(), isNull);
    });
  });
}

/// The second simulated device's identity.
class _StubAuth2 implements AuthGateway {
  const _StubAuth2();
  @override
  Future<AuthState> signInAnonymously() async => const AuthState.signedIn('u2');
  @override
  Future<AuthState> current() async => const AuthState.signedIn('u2');
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => 'u2';
}
