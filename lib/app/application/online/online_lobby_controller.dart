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

  /// Waiting in the matchmaking queue for an opponent to appear.
  searching,

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
    this.matchmaking,
    MatchRepository? matches,
    this.boardConfig = const BoardConfig(),
  }) : _matchRepository = matches;

  static const AppLogger _log = AppLogger('online_lobby');

  /// Identity.
  final AuthGateway auth;

  /// Room storage.
  final RoomRepository rooms;

  /// Random matchmaking, when the build offers it.
  ///
  /// Optional so the code-based flow keeps working — and keeps working in the
  /// existing tests — in a build with no matchmaking at all. When null,
  /// [quickMatch] reports a rejection rather than pretending to search.
  final MatchmakingRepository? matchmaking;

  /// Board both players will play on when the creator creates a room.
  final BoardConfig boardConfig;

  AuthState _authState = const AuthState.signedOut();
  Room? _room;
  RoomFailure? _lastFailure;
  OnlineLobbyPhase _phase = OnlineLobbyPhase.needsSignIn;
  StreamSubscription<Room?>? _watch;
  StreamSubscription<Room?>? _matchWatch;
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

  /// Whether this build offers random matchmaking.
  bool get hasMatchmaking => matchmaking != null;

  /// The room repository, so a screen can build a match controller for a started
  /// room without re-wiring the Firebase clients.
  ///
  /// Exposed deliberately: the lobby and the match are two views of one match
  /// document, and a second set of repositories would be a second set of
  /// ownership. Phase 9's screen reads it once, here.
  RoomRepository? get roomsRepository => rooms;

  /// The match repository, when this build has one.
  ///
  /// Null in a build without match synchronisation, which is what the screen
  /// checks before offering to play.
  MatchRepository? get matchRepository => _matchRepository;

  final MatchRepository? _matchRepository;

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
      // The wording deliberately does not blame connectivity: the most common
      // cause by far is a build with no Firebase configuration, which says
      // nothing about the player's connection. The auth layer's own reason is
      // included because it is credential-free and safe to show.
      final detail = _authState.detail;
      _fail(
        RoomFailureReason.notAuthenticated,
        detail == null
            ? 'Could not sign in. Online play is unavailable.'
            : 'Could not sign in. Online play is unavailable ($detail).',
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

  /// Requests an opponent, or reports why it could not.
  ///
  /// Three outcomes, and the difference matters:
  ///
  /// * **matched immediately** — someone was already waiting; the shared room is
  ///   entered through the same path a code-joined room takes, so ready state,
  ///   match start and Phase 9 behave identically.
  /// * **queued** — nobody was waiting, so the caller waits and watches its own
  ///   `matched` document. No polling.
  /// * **rejected** — nothing was written and nothing is being watched, so the
  ///   player is told rather than left on a spinner.
  Future<void> quickMatch({BoardConfig? config}) async {
    final service = matchmaking;
    if (service == null) {
      _fail(
        RoomFailureReason.notAMember,
        'Quick Match is not available in this build.',
      );
      return;
    }
    final id = uid;
    if (id == null) {
      _fail(RoomFailureReason.notAuthenticated, 'Sign in to play online.');
      return;
    }

    final board = config ?? boardConfig;
    _setPhase(OnlineLobbyPhase.searching);
    final result = await service.findMatch(config: board);
    if (_disposed) return;

    switch (result) {
      case MatchFound(:final room):
        _lastFailure = null;
        await _enterRoom(room);
      case MatchQueued():
        _lastFailure = null;
        _setPhase(OnlineLobbyPhase.searching);
        // The waiting player is notified by a listener, not by polling.
        await _watchForMatch(board, id);
      case MatchRejected(:final failure):
        _lastFailure = RoomFailure(
          RoomFailureReason.invalidRoomDocument,
          failure.message,
        );
        _setPhase(OnlineLobbyPhase.failed);
    }
  }

  /// Leaves the matchmaking queue, returning to the entry state.
  Future<void> cancelQuickMatch() async {
    final service = matchmaking;
    final id = uid;
    if (service == null || id == null) {
      _setPhase(OnlineLobbyPhase.idle);
      return;
    }
    _setPhase(OnlineLobbyPhase.busy);
    await service.cancel(config: boardConfig);
    await _matchWatch?.cancel();
    _matchWatch = null;
    if (_disposed) return;
    _lastFailure = null;
    _setPhase(OnlineLobbyPhase.idle);
  }

  /// Watches the caller's own match notification, entering the room when it lands.
  Future<void> _watchForMatch(BoardConfig config, String uid) async {
    await _matchWatch?.cancel();
    if (_disposed) return;
    _matchWatch = matchmaking!.watchForMatch(config: config, uid: uid).listen((
      room,
    ) {
      if (_disposed) return;
      if (room == null) return; // still waiting
      _log.log('matched into ${room.code}');
      unawaited(_enterRoom(room));
    });
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
    unawaited(_matchWatch?.cancel());
    _watch = null;
    _matchWatch = null;
    super.dispose();
  }
}
