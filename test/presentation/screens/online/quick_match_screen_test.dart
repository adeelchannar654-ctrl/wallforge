import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallforge/app/application/online/online_lobby_controller.dart';
import 'package:wallforge/app/theme/app_theme.dart';
import 'package:wallforge/data/remote/firestore_matchmaking_repository.dart';
import 'package:wallforge/data/remote/firestore_room_repository.dart';
import 'package:wallforge/data/remote/in_memory_firestore_client.dart';
import 'package:wallforge/domain/wallforge_domain.dart';
import 'package:wallforge/presentation/screens/online/online_lobby_screen.dart';

class _StubAuth implements AuthGateway {
  const _StubAuth(this.uid);
  final String uid;
  @override
  Future<AuthState> signInAnonymously() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> current() async => AuthState.signedIn(uid);
  @override
  Future<AuthState> signOut() async => const AuthState.signedOut();
  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();
  @override
  Future<String?> currentUid() async => uid;
}

void main() {
  late InMemoryFirestoreClient store;

  setUp(() => store = InMemoryFirestoreClient());
  tearDown(() => store.closeWatchers());

  OnlineLobbyController lobby(String uid, {bool withMatchmaking = true}) {
    final auth = _StubAuth(uid);
    return OnlineLobbyController(
      auth: auth,
      rooms: FirestoreRoomRepository(client: store, userId: auth.currentUid),
      matchmaking: withMatchmaking
          ? FirestoreMatchmakingRepository(
              client: store,
              userId: auth.currentUid,
            )
          : null,
    );
  }

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

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('quick match is offered alongside create and join', (
    tester,
  ) async {
    final controller = lobby('uid-a');
    addTearDown(controller.dispose);
    await pump(tester, controller);

    expect(find.text('QUICK MATCH'), findsOneWidget);
    expect(find.text('FIND OPPONENT'), findsOneWidget);
    // The code-based flow is untouched.
    expect(find.text('CREATE A ROOM'), findsOneWidget);
    expect(find.text('JOIN A ROOM'), findsOneWidget);
  });

  testWidgets('quick match is hidden when the build offers no matchmaking', (
    tester,
  ) async {
    final controller = lobby('uid-a', withMatchmaking: false);
    addTearDown(controller.dispose);
    await pump(tester, controller);

    expect(find.text('QUICK MATCH'), findsNothing);
    expect(find.text('FIND OPPONENT'), findsNothing);
    expect(find.text('CREATE A ROOM'), findsOneWidget);
  });

  testWidgets('searching shows a waiting state with a cancel action', (
    tester,
  ) async {
    final controller = lobby('uid-a');
    addTearDown(controller.dispose);
    await pump(tester, controller);

    await tap(tester, find.text('FIND OPPONENT'));

    expect(find.text('LOOKING FOR AN OPPONENT'), findsOneWidget);
    expect(find.text('SEARCHING'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    // The code-based entry is still usable while searching.
    expect(find.text('CREATE A ROOM'), findsOneWidget);
  });

  testWidgets('the waiting state says it does not poll', (tester) async {
    final controller = lobby('uid-a');
    addTearDown(controller.dispose);
    await pump(tester, controller);
    await tap(tester, find.text('FIND OPPONENT'));

    expect(find.textContaining('does not poll'), findsOneWidget);
  });

  testWidgets('cancel leaves the search and returns to the entry state', (
    tester,
  ) async {
    final controller = lobby('uid-a');
    addTearDown(controller.dispose);
    await pump(tester, controller);
    await tap(tester, find.text('FIND OPPONENT'));

    await tap(tester, find.text('CANCEL'));

    expect(find.text('LOOKING FOR AN OPPONENT'), findsNothing);
    expect(find.text('FIND OPPONENT'), findsOneWidget);
    expect(store.documents.keys.where((k) => k.contains('/waiting/')), isEmpty);
  });

  testWidgets('being matched switches to the shared room', (tester) async {
    final a = lobby('uid-a');
    final b = lobby('uid-b');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pump(tester, a);

    await tap(tester, find.text('FIND OPPONENT'));
    expect(find.text('LOOKING FOR AN OPPONENT'), findsOneWidget);

    await b.signIn();
    await b.quickMatch();
    await tester.pumpAndSettle();

    // a was notified through its own matched document, with no user action.
    expect(find.text('LOOKING FOR AN OPPONENT'), findsNothing);
    expect(find.text('ROOM CODE'), findsOneWidget);
    expect(find.text(a.roomCode!), findsOneWidget);
    expect(find.text('READY UP'), findsOneWidget);
    expect(a.roomCode, b.roomCode);
  });

  testWidgets('the matched room states who you play', (tester) async {
    final a = lobby('uid-a');
    final b = lobby('uid-b');
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await pump(tester, a);
    await tap(tester, find.text('FIND OPPONENT'));

    await b.signIn();
    await b.quickMatch();
    await tester.pumpAndSettle();

    expect(find.text('(YOU)'), findsOneWidget);
    expect(find.text('BLUE'), findsOneWidget);
    expect(find.text('RED'), findsOneWidget);
  });
}
