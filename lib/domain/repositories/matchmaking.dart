import '../models/board_config.dart';
import 'room.dart';

/// Why a matchmaking attempt was refused.
///
/// Mirrors `RoomFailureReason`'s discipline — a distinct value per expected
/// rejection, so the caller can say something useful — plus the transport case
/// `rules.md` §7 lists as a data-layer error.
enum MatchmakingFailureReason {
  /// No uid is resolved, so there is nobody to queue.
  notAuthenticated,

  /// A compatible partner was waiting but no claim ever committed, so the caller
  /// is *not* actually queued for anyone and should be told to retry.
  ///
  /// Deliberately distinct from simply being queued: "nobody is waiting yet" and
  /// "someone was there and we could not commit" call for different reactions.
  pairingFailed,
}

/// A structured matchmaking failure.
class MatchmakingFailure {
  /// Creates a matchmaking failure.
  const MatchmakingFailure(this.reason, [this.message]);

  /// Machine-readable reason.
  final MatchmakingFailureReason reason;

  /// Human-readable explanation, safe to show a player.
  final String? message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MatchmakingFailure &&
          reason == other.reason &&
          message == other.message;

  @override
  int get hashCode => Object.hash(reason, message);

  @override
  String toString() => 'MatchmakingFailure(${reason.name}: $message)';
}

/// The outcome of asking for a match.
sealed class MatchmakingResult {
  const MatchmakingResult._();

  /// An opponent was found and [room] is the shared room both players are in.
  const factory MatchmakingResult.matched(Room room) = MatchFound;

  /// Nobody was waiting, so the caller is now in the queue.
  const factory MatchmakingResult.queued() = MatchQueued;

  /// The attempt was refused.
  const factory MatchmakingResult.rejected(MatchmakingFailure failure) =
      MatchRejected;
}

/// An opponent was found; the shared [Room] is ready for the Phase 8 flow.
class MatchFound extends MatchmakingResult {
  const MatchFound(this.room) : super._();

  /// The room both players are now seated in.
  final Room room;
}

/// The caller is waiting for an opponent.
class MatchQueued extends MatchmakingResult {
  const MatchQueued() : super._();
}

/// The attempt was refused.
class MatchRejected extends MatchmakingResult {
  const MatchRejected(this.failure) : super._();

  /// Why it was refused.
  final MatchmakingFailure failure;

  /// The machine-readable reason.
  MatchmakingFailureReason get reason => failure.reason;
}

/// Random matchmaking, declared in the domain layer and implemented in
/// `lib/data/remote/`.
///
/// ## What it produces
///
/// A [Room] in exactly the shape Phase 8 defined, at the same
/// `matches/{code}` path, so ready state, match start and Phase 9's move
/// synchronisation are unchanged whether a room was found by code or by
/// matchmaking. The only difference is how the two players found each other.
///
/// ## Why pairing needs a transaction
///
/// Two clients can call [findMatch] at the same moment. Without atomicity they
/// can each claim the same queue entry — putting one player in two rooms — or
/// both find an empty queue and wait forever while a compatible partner is
/// present. The claim is therefore a single transaction, and the mutual
/// exclusion token is a *shared* document both participants write, so a genuine
/// simultaneous double-claim becomes a write-write conflict the loser retries.
///
/// See `FirestoreMatchmakingRepository` for the full walkthrough.
abstract interface class MatchmakingRepository {
  /// Joins the queue for [config], pairing with a waiting player if there is one.
  ///
  /// Returns [MatchFound] when paired, [MatchQueued] when now waiting, and
  /// [MatchRejected] when it could not proceed. Never throws.
  Future<MatchmakingResult> findMatch({required BoardConfig config});

  /// Stops waiting, removing the caller's queue entry for [config].
  ///
  /// Best-effort and total: a player who is not queued is already in the desired
  /// state, so a missing entry is not an error. Mirrors Phase 8's
  /// `RoomRepository.leave` discipline.
  Future<void> cancel({required BoardConfig config});

  /// Emits the room once an opponent claims the caller, and null while they are
  /// still waiting.
  ///
  /// This is how the *waiting* player learns about the match. The claimer already
  /// knows the code because it created the room, so only one side needs a
  /// notification. [uid] is passed explicitly because the uid resolves
  /// asynchronously while a listener must be built synchronously.
  Stream<Room?> watchForMatch({
    required BoardConfig config,
    required String uid,
  });
}

/// The path segment that partitions the queue by board configuration.
///
/// ## Why board config is in the path rather than a field
///
/// Firestore serves "equality filter on one field + `orderBy` on a different
/// field" only from a *composite* index, which is a manual console step (or a
/// Blaze-plan `firebase deploy`) — `architecture.md` §10 rules those out. Putting
/// the configuration in the path reduces the only query needed to a bare
/// `orderBy` + `limit` on a single subcollection, which the automatic
/// single-field index serves. Verified against Firestore's indexing
/// documentation rather than assumed.
///
/// The consequence is deliberate: **matchmaking pairs only on an exact
/// `BoardConfig` match.** No source document specifies configurable online match
/// settings — `PRD.md` §6.4 and `design.md` §19 list only "create match / join
/// match / room code / opponent status / connection state" — so exact matching is
/// the simplest thing that satisfies the requirement, and it avoids the
/// ambiguity of "compatible but not equal" boards. Recorded as Q-8.9.
String matchmakingBoardKey(BoardConfig config) =>
    's${config.size}w${config.wallsPerPlayer}';
