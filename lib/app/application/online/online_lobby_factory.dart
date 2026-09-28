import '../../../data/remote/cloud_firestore_client.dart';
import '../../../data/remote/firebase_auth_gateway.dart';
import '../../../data/remote/firestore_match_repository.dart';
import '../../../data/remote/firestore_matchmaking_repository.dart';
import '../../../data/remote/firestore_room_repository.dart';
import '../../../domain/wallforge_domain.dart';
import 'online_lobby_controller.dart';

/// Builds an [OnlineLobbyController] wired to the real Firebase services.
///
/// Mirrors `PersistenceFactory`'s role from Phase 7, and inherits its rule: a
/// build with no Firebase configuration must still run, so nothing here
/// assumes Firebase initialised. `FirebaseAuthGateway` and `CloudFirestoreClient`
/// both resolve their platform objects lazily and degrade to a reported status
/// rather than throwing, so constructing a lobby is always safe.
class OnlineLobbyFactory {
  const OnlineLobbyFactory._();

  /// A lobby backed by Firebase Authentication and Cloud Firestore.
  ///
  /// [boardConfig] is the board a created room — or a Quick Match queue — uses.
  static OnlineLobbyController firebase({BoardConfig? boardConfig}) {
    final auth = FirebaseAuthGateway();
    // One shared client, so the queue and the rooms it creates go through the
    // same connection and the same in-memory double in tests.
    final client = CloudFirestoreClient();
    return OnlineLobbyController(
      auth: auth,
      // The room repository's owner resolver is the auth gateway's uid — the
      // Phase 6/7 `UserIdResolver` seam, now fed a real authenticated identity.
      // It resolves to null when nobody is signed in, and every repository call
      // then refuses rather than writing under a placeholder id.
      rooms: FirestoreRoomRepository(client: client, userId: auth.currentUid),
      matchmaking: FirestoreMatchmakingRepository(
        client: client,
        userId: auth.currentUid,
      ),
      // Phase 9: the same client and the same uid resolver, so a matched room
      // and the match document inside it are reached through one connection and
      // one identity.
      matches: FirestoreMatchRepository(
        client: client,
        userId: auth.currentUid,
      ),
      boardConfig: boardConfig ?? const BoardConfig(),
    );
  }

  /// A lobby over injected doubles, for tests and for previews.
  static OnlineLobbyController withServices({
    required AuthGateway auth,
    required RoomRepository rooms,
    MatchmakingRepository? matchmaking,
    MatchRepository? matches,
    BoardConfig boardConfig = const BoardConfig(),
  }) => OnlineLobbyController(
    auth: auth,
    rooms: rooms,
    matchmaking: matchmaking,
    matches: matches,
    boardConfig: boardConfig,
  );
}
