import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../domain/wallforge_domain.dart';

/// What the online lobby is currently doing, from `design.md` §19's connection
/// states.
///
/// Two of §19's five states are deliberately absent. `reconnecting` needs
/// Firestore snapshot metadata (a snapshot served from cache rather than the
/// server), which is meaningful once Phase 9 streams moves but would be a guess
/// here; and `disconnected` covers the whole "the room document is not there any
/// more" case. Recorded as Q-8.4 rather than faked.
enum OnlineLobbyPhase {
  /// No identity yet, or the last attempt failed.
  needsSignIn,

  /// Signing in or performing a room operation.
  busy,

  /// Signed in, no room — the player chooses create or join.
  idle,

  /// In a room, waiting for the opponent to join.
  waiting,

  /// In a room with both players present.
  ready,

  /// The match has started. Phase 9 attaches move sync from here.
  started,

  /// Something failed; [OnlineLobbyController.lastFailure] says what.
  failed,
}

/// Drives the online lobby: sign in, create or join a room, ready up, start.
///
/// ## Why a controller and not widget logic
///
/// `rules.md` §3.4 forbids business logic in widgets, and the lifecycle is all
/// sequencing: a screen should render [phase] and call these methods. It is a
/// [ChangeNotifier] like `LocalGameController`, so it stays usable as a plain
/// synchronous object in tests.
///
/// ## Honest scope
///
/// Reaching [OnlineLobbyPhase.started] means both players are in one shared
/// record with an agreed board and seat assignment. **Moves are not
/// synchronised in this phase** — that is Phase 9 — and the UI says so rather
/// than letting a player believe otherwise.
class OnlineLobbyController extends ChangeNotifier {
  OnlineLobbyController({
    required this.auth,
    required this.rooms,
    this.boardConfig = const BoardConfig(),
  });

  static const AppLogger _log = AppLogger('online_lobby');

  /// Identity.
  final AuthGateway auth;

  /// Room storage.
  final RoomRepository rooms;

  /// Board both players will play on when the creator creates a room.
  final BoardConfig boardConfig;

  AuthState _authState = const AuthState.signedOut();
  Room? _room;
  RoomFailure? _lastFailure;
  OnlineLobbyPhase _phase = OnlineLobbyPhase.needsSignIn;
  StreamSubscription<Room?>? _watch;
  bool _disposed = false;

  // --- Observable state -------------------------------------------------------

  /// The room the caller is in, or null.
  Room? get room => _room;

  /// The last rejection, or null.
  ///
  /// Expected rejections are values, not exceptions, per `rules.md` §7.
  RoomFailure? get lastFailure => _lastFailure;

  /// A message safe to show the player, or null.
  String? get failureMessage => _lastFailure?.message;

  /// What the lobby is doing.
  OnlineLobbyPhase get phase => _phase;

  /// Whether a room operation is in flight.
  bool get isBusy => _phase == OnlineLobbyPhase.busy;

  /// Whether the caller is currently in a room.
  bool get isInRoom => _room != null;

  /// The signed-in user's id, or null.
  String? get uid => _authState.uid;

  /// Which side the caller plays, or null when not in a room.
  PlayerId? get mySide {
    final id = uid;
    final current = _room;
    if (id == null || current == null) return null;
    return current.sideFor(id);
  }

  /// The opponent's uid, or null when alone.
  String? get opponentId {
    final id = uid;
    final current = _room;
    if (id == null || current == null) return null;
    return current.opponentOf(id);
  }

  /// Whether the caller has readied up.
  bool get amReady {
    final id = uid;
    final current = _room;
    if (id == null || current == null) return false;
    return current.isReadyFor(id);
  }

  /// Whether the opponent has readied up.
  bool get isOpponentReady {
    final opponent = opponentId;
    final current = _room;
    if (opponent == null || current == null) return false;
    return current.isReadyFor(opponent);
  }

  /// Whether both players are present and readied up.
  bool get bothReady => _room?.bothReady ?? false;

  /// Whether the caller created the room, and so may start it.
  bool get amHost => _room?.isHost(uid ?? '') ?? false;

  /// Whether the host may start right now.
  bool get canStart => amHost && (_room?.canStart ?? false);

  /// Whether the match has started.
  bool get hasStarted => _room?.status == RoomStatus.started;

  /// The room code to show, or null.
  String? get roomCode => _room?.code;

  // --- Operations -------------------------------------------------------------

  /// Signs in anonymously and refreshes the state.
  ///
  /// A failure leaves the app usable: [phase] becomes [OnlineLobbyPhase.failed]
  /// and the player can retry, which matters because the same build must work
  /// offline and with no Firebase configuration at all.
  Future<void> signIn() async {
    _setPhase(OnlineLobbyPhase.busy);
    _authState = await auth.signInAnonymously();
    if (_disposed) return;
    if (!_authState.isSignedIn) {
      _fail(
        RoomFailureReason.notAuthenticated,
        'Could not sign in. Online play needs a connection.',
      );
      return;
    }
    _log.log('signed in for online play');
    _setPhase(OnlineLobbyPhase.idle);
  }

  /// Creates a room and starts watching it.
  Future<void> createRoom({BoardConfig? config}) async {
    final created = await _run(
      () => rooms.create(config: config ?? boardConfig),
    );
    if (created == null) return;
    await _enterRoom(created);
  }

  /// Joins the room with [code].
  ///
  /// A malformed code is rejected locally with
  /// [RoomFailureReason.invalidRoomCode] before any network call, so a typo does
  /// not cost a read.
  Future<void> joinRoom(String code) async {
    if (!RoomCode.isValid(code)) {
      _fail(
        RoomFailureReason.invalidRoomCode,
        'Room codes are ${RoomCode.length} characters.',
      );
      return;
    }
    final joined = await _run(() => rooms.join(code));
    if (joined == null) return;
    await _enterRoom(joined);
  }

  /// Toggles the caller's ready state.
  Future<void> toggleReady() async {
    final current = _room;
    if (current == null) return;
    final result = await _run(
      () => rooms.setReady(code: current.code, ready: !amReady),
    );
    if (result != null) _room = result;
  }

  /// Starts the match. Host-only; the repository enforces that.
  Future<void> startMatch() async {
    final current = _room;
    if (current == null) return;
    final result = await _run(() => rooms.start(current.code));
    if (result != null) {
      _room = result;
      _setPhase(OnlineLobbyPhase.started);
    }
  }

  /// Leaves or cancels the room and returns to the idle state.
  Future<void> leaveRoom() async {
    final current = _room;
    if (current == null) return;
    _setPhase(OnlineLobbyPhase.busy);
    final result = await rooms.leave(current.code);
    if (_disposed) return;
    // `roomNotFound` here means the room was already gone, which is the state
    // the player asked for, so it is not surfaced as an error.
    if (result is RoomRejected &&
        result.reason != RoomFailureReason.roomNotFound) {
      _lastFailure = result.failure;
      _setPhase(OnlineLobbyPhase.failed);
      return;
    }
    _log.log('left room');
    _room = null;
    _lastFailure = null;
    _setPhase(OnlineLobbyPhase.idle);
  }

  // --- Internals --------------------------------------------------------------

  /// Runs a repository call, folding a rejection into [lastFailure].
  ///
  /// Returns the room on success, or null when the call was rejected, so callers
  /// cannot accidentally continue on a failure.
  Future<Room?> _run(Future<RoomResult> Function() action) async {
    _setPhase(OnlineLobbyPhase.busy);
    final result = await action();
    if (_disposed) return null;
    if (result is RoomRejected) {
      _lastFailure = result.failure;
      _setPhase(OnlineLobbyPhase.failed);
      return null;
    }
    _lastFailure = null;
    return (result as RoomSuccess).room;
  }

  Future<void> _enterRoom(Room room) async {
    _room = room;
    _lastFailure = null;
    _derivePhase();
    await _watchRoom(room.code);
  }

  /// Subscribes to the room so the creator sees the opponent arrive.
  ///
  /// A single listener on a single document, per the free-tier reasoning in
  /// `FirestoreRoomRepository`.
  Future<void> _watchRoom(String code) async {
    await _watch?.cancel();
    if (_disposed) return;
    _watch = rooms
        .watch(code)
        .listen(
          (room) {
            if (_disposed) return;
            if (room == null) {
              // The document is gone: either the host cancelled or it was deleted.
              _room = null;
              _log.log('room closed remotely');
              _setPhase(OnlineLobbyPhase.idle);
              return;
            }
            _room = room;
            _derivePhase();
          },
          onError: (Object error) {
            if (_disposed) return;
            _log.error('room watch failed: ${error.runtimeType}');
            _fail(
              RoomFailureReason.networkUnavailable,
              'Lost the connection to the room.',
            );
          },
        );
  }

  /// Recomputes [phase] from the room alone, so the UI never disagrees with the
  /// stored state.
  void _derivePhase() {
    final current = _room;
    if (current == null) {
      _setPhase(OnlineLobbyPhase.idle);
      return;
    }
    if (current.status == RoomStatus.started) {
      _setPhase(OnlineLobbyPhase.started);
      return;
    }
    _setPhase(
      current.isFull ? OnlineLobbyPhase.ready : OnlineLobbyPhase.waiting,
    );
  }

  void _fail(RoomFailureReason reason, String message) {
    _lastFailure = RoomFailure(reason, message);
    _setPhase(OnlineLobbyPhase.failed);
  }

  void _setPhase(OnlineLobbyPhase phase) {
    if (_disposed) return;
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_watch?.cancel());
    _watch = null;
    super.dispose();
  }
}
