import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../domain/wallforge_domain.dart';
import '../game_interaction.dart';

/// The five connection states `design.md` §19 requires.
///
/// `reconnecting` and `disconnected` are what Phase 8.1's Q-8.4 said could not
/// honestly be detected from a plain document stream, and what Phase 9 fixed by
/// widening the port with snapshot metadata: a snapshot served from cache is the
/// signal that the board on screen may be stale.
enum OnlineConnectionState {
  /// Opening the listener, or performing the first read.
  connecting,

  /// Connected, but the match has not started or the opponent has not joined.
  waiting,

  /// Connected and receiving live snapshots.
  connected,

  /// The last snapshot came from the device cache, so the network is down or
  /// the server is unreachable.
  reconnecting,

  /// The listener failed outright.
  disconnected,
}

/// Whether the controller trusts the state it is showing.
///
/// Separate from [OnlineConnectionState] on purpose: a client can be perfectly
/// connected and still be out of step, which is a data problem, not a network
/// one.
enum OnlineSyncState {
  /// The shown state is the verified shared state.
  inSync,

  /// A snapshot failed verification and recovery is under way.
  desynced,

  /// The snapshot failed verification *and* the move log could not repair it.
  /// The app must not guess; this is a stop state, not a retry loop.
  syncError,
}

/// The verdict on an incoming shared document.
enum _Verdict {
  /// Identical to what is already shown — the echo of this client's own move.
  echo,

  /// Trustworthy and newer; adopt it.
  apply,

  /// Must not be shown. Verification failed.
  desync,
}

/// Drives one client's view of a shared online match.
///
/// ## What it does and does not do
///
/// It accepts local input *only while it is this player's turn*, hands the
/// resulting action to [MatchRepository], and displays only state that has been
/// **verified**. It contains no game rules at all: every legality question goes
/// to [GameEngine], and every write goes through the repository's transaction.
///
/// ## Why verification is not optional
///
/// `PRD.md` §9: "The client must not assume that local state is authoritative
/// for another player." A snapshot is data from the network, so it is checked
/// before it is shown: it may never move the version or turn backwards, the
/// denormalised turn number must agree with the state it sits next to, a
/// single-turn advance must be reachable by one legal action, and a declared
/// winner is never believed — the engine's own [GameState.winner] is.
///
/// ## Phase 9 / Phase 10 boundary
///
/// This controller covers *this* client: preserving its state, showing
/// "Reconnecting", and converging without double-applying. What the **opponent**
/// sees, turn clocks, forfeit and abandonment are Phase 10, as is Security Rules
/// (`architecture.md` §12). The limits of the client-side checks below are stated
/// in the record rather than presented as a security boundary.
class OnlineGameController extends ChangeNotifier with GameInteraction {
  OnlineGameController({
    required this.rooms,
    required this.matches,
    required this.uid,
    required this.code,
    GameState? initialState,
  }) : _state = initialState ?? GameState.initial(),
       _room = Room.fromJson(<String, dynamic>{}) ?? _emptyRoom;

  static const AppLogger _log = AppLogger('online_game');

  /// Room storage, for the seat mapping and lifecycle.
  final RoomRepository rooms;

  /// Match synchronisation.
  final MatchRepository matches;

  /// This client's uid.
  final String uid;

  /// The match code.
  final String code;

  GameState _state;
  Room _room;
  StreamSubscription<SharedMatchDocument>? _subscription;
  OnlineConnectionState _connection = OnlineConnectionState.connecting;
  OnlineSyncState _sync = OnlineSyncState.inSync;
  MatchSyncFailure? _lastSyncFailure;
  String? _statusMessage;
  bool _submitting = false;
  bool _disposed = false;
  bool _recovering = false;

  /// An action held because it could not be sent — the offline case.
  ({int turn, GameAction action})? _pending;

  /// Placeholder room used before the first real document arrives.
  static const Room _emptyRoom = Room(
    code: '',
    status: RoomStatus.waiting,
    boardConfig: BoardConfig(),
    hostId: '',
    blue: RoomSeat.empty,
    red: RoomSeat.empty,
    createdAtMs: 0,
    updatedAtMs: 0,
  );

  // --- Read-only state --------------------------------------------------------

  @override
  GameState get interactionState => _state;

  /// The verified state being displayed.
  GameState get state => _state;

  /// The match document as last read.
  Room get room => _room;

  /// Current turn owner.
  PlayerId get currentPlayer => _state.currentPlayer;

  /// Whether the match is over.
  bool get isFinished => _state.status == GameStatus.finished;

  /// The winner, from the engine. Never from the document.
  PlayerId? get winner => _state.winner;

  /// This client's colour, or null before the room is known.
  PlayerId? get mySide => _room.sideFor(uid);

  /// The opponent's colour, or null.
  PlayerId? get opponentSide => mySide?.opponent;

  /// The opponent's uid, or null.
  String? get opponentId => _room.opponentOf(uid);

  /// Whether it is this client to act.
  bool get isMyTurn =>
      mySide != null && _state.currentPlayer == mySide && !isFinished;

  /// Whether this client plays Blue.
  bool get isBlue => mySide == PlayerId.blue;

  @override
  bool get isInteractionBlocked =>
      // Not this client's turn, a submit in flight, not verified, or offline.
      !isMyTurn ||
      _submitting ||
      _sync != OnlineSyncState.inSync ||
      _connection == OnlineConnectionState.reconnecting ||
      _connection == OnlineConnectionState.disconnected;

  /// Why input is refused, for the UI to explain rather than just grey out.
  String? get inputBlockedReason {
    if (isFinished) return 'This match is over.';
    if (_sync == OnlineSyncState.syncError) {
      return 'The shared match could not be read safely.';
    }
    if (_sync == OnlineSyncState.desynced) return 'Re-syncing the board.';
    if (_connection == OnlineConnectionState.reconnecting) {
      return 'Reconnecting. Your move is held until you are back online.';
    }
    if (_connection == OnlineConnectionState.disconnected) {
      return 'Disconnected from your opponent.';
    }
    if (_submitting) return 'Sending your move.';
    if (mySide != null && !isMyTurn) return "It is your opponent's turn.";
    return null;
  }

  /// The connection state, for `design.md` §19's chip.
  OnlineConnectionState get connection => _connection;

  /// Whether the shown state is trusted.
  OnlineSyncState get sync => _sync;

  /// The last submission failure, or null.
  MatchSyncFailure? get lastSyncFailure => _lastSyncFailure;

  /// A short status line, e.g. the recovery outcome.
  String? get statusMessage => _statusMessage;

  /// Whether a submit is in flight.
  bool get isSubmitting => _submitting;

  /// The action held while offline, if any.
  GameAction? get pendingAction => _pending?.action;

  /// Whether the connection chip should be shown at all.
  bool get hasMatch => _room.blue.playerId != null;

  // --- Lifecycle --------------------------------------------------------------

  /// Subscribes to the shared match and applies the first verified snapshot.
  Future<void> connect() async {
    _setConnection(OnlineConnectionState.connecting);
    await _subscription?.cancel();
    if (_disposed) return;
    _subscription = matches
        .watchMatch(code: code)
        .listen(
          _onDocument,
          onError: (Object error) {
            if (_disposed) return;
            _log.error('match listener failed: ${error.runtimeType}');
            _setConnection(OnlineConnectionState.disconnected);
          },
        );
  }

  /// Re-reads once, outside the listener. Used after a recovery attempt.
  Future<void> resync() async {
    _setConnection(OnlineConnectionState.connecting);
    final document = await matches.loadMatch(code: code);
    if (_disposed) return;
    if (document == null) {
      _setConnection(OnlineConnectionState.disconnected);
      return;
    }
    _onDocument(document);
  }

  // --- Submitting -------------------------------------------------------------

  /// The online sink: sends the action rather than applying it locally.
  ///
  /// The local controller applies through the engine; here the *server* decides,
  /// and the local state only changes when a verified snapshot comes back. That
  /// asymmetry is the point: a client cannot talk itself into a move.
  @override
  ActionFailure? attemptAction(GameAction action) {
    if (isInteractionBlocked) return null;
    unawaited(submit(action));
    return null;
  }

  /// Submits [action] for the current turn.
  ///
  /// Resolves to the engine refusal on rejection, so the shared interaction layer
  /// can show it the same way it shows a local illegal move.
  Future<ActionFailure?> submit(GameAction action) async {
    final turn = _state.turnNumber;
    _setSubmitting(true);
    final result = await matches.submitAction(
      code: code,
      expectedTurnNumber: turn,
      action: action,
    );
    if (_disposed) return null;
    _setSubmitting(false);

    switch (result) {
      case MoveApplied():
        _lastSyncFailure = null;
        _pending = null;
        return null;
      case MoveAlreadyApplied():
        // A lost acknowledgement: the move landed. Re-read rather than assume.
        _log.log('move $turn already applied; re-reading');
        await resync();
        return null;
      case MoveRejected(:final failure):
        _lastSyncFailure = failure;
        switch (failure.reason) {
          case MatchSyncFailureReason.networkUnavailable:
            // Hold it. Firestore does not queue a transaction, so resubmission
            // is this client's job (`rules.md` §9).
            _pending = (turn: turn, action: action);
            _setConnection(OnlineConnectionState.reconnecting);
          case MatchSyncFailureReason.staleTurn:
          case MatchSyncFailureReason.notYourTurn:
            // Our view is behind or we lost a race: re-read, do not guess.
            await resync();
          case MatchSyncFailureReason.invalidAction:
            // The engine refused it, so the local ghost was wrong. Nothing to
            // resubmit; the board is already correct.
            break;
          default:
            break;
        }
        return failure.actionFailure;
    }
  }

  // --- Incoming documents -----------------------------------------------------

  /// Handles one shared document: cache metadata, then verification.
  void _onDocument(SharedMatchDocument document) {
    if (_disposed) return;

    // Connectivity is a property of *this* document, not of the room. A live
    // (non-cached) snapshot is itself proof the server is reachable, and a
    // cached one is proof it is not. Deriving it from `_room` instead left the
    // chip stuck on WAITING whenever the room document happened to arrive
    // after the match document, because nothing re-evaluated it.
    _setConnection(
      document.fromCache
          ? OnlineConnectionState.reconnecting
          : OnlineConnectionState.connected,
    );

    if (document.fromCache) {
      // The cached copy is shown as-is: `rules.md` §9 says preserve the current
      // local state. It is not re-verified, because it cannot have moved.
      return;
    }

    final room = Room.fromJson(document.fields);
    if (room == null) {
      _failSync('The shared match could not be read.');
      return;
    }
    if (room.status != RoomStatus.started &&
        _room.status != RoomStatus.started) {
      // Still in the lobby: adopt the room, keep the board untouched.
      _room = room;
      notifyListeners();
      return;
    }

    final incoming = document.rawState;
    if (incoming == null && room.boardState == null) {
      // No snapshot at all and none expected: the match has not begun.
      _room = room;
      notifyListeners();
      return;
    }

    final verdict = _verify(room, document);
    if (verdict == _Verdict.echo) {
      _room = room;
      // An echo can still be the answer to a held action: if the move we were
      // holding landed while we were away, the very document that looks
      // unchanged from our stale local view is the proof. Resolving here is what
      // turns a lost acknowledgement into a success instead of a stuck spinner.
      _resolvePendingAfterSync();
      notifyListeners();
      return;
    }
    if (verdict == _Verdict.desync) {
      _failSync('The shared board did not match what was expected.');
      return;
    }

    // --- adopt ---
    _room = room;
    _state = room.boardState!;
    _lastSyncFailure = null;
    _statusMessage = null;
    if (_sync != OnlineSyncState.inSync) {
      _log.log('recovered from ${_sync.name} at turn ${_state.turnNumber}');
    }
    _sync = OnlineSyncState.inSync;
    _resolvePendingAfterSync();
    notifyListeners();
  }

  /// Decides whether an incoming document may be shown.
  ///
  /// Returns [_Verdict.desync] for anything the checks below cannot vouch for.
  /// Being conservative is the point: an unverified board is worse than a stale
  /// one, because the player would act on a fiction.
  _Verdict _verify(Room incoming, SharedMatchDocument document) {
    final state = incoming.boardState;
    if (state == null) return _Verdict.desync;

    // A declared winner is never believed. If the document and the state
    // disagree, that is corruption, not news.
    final declared = document.declaredWinnerId;
    if (declared != null) {
      final derived = state.status == GameStatus.finished
          ? incoming.seatFor(state.winner!).playerId
          : null;
      if (derived != declared) return _Verdict.desync;
    }

    // Time never runs backwards.
    if (state.turnNumber < _state.turnNumber) return _Verdict.desync;
    if (incoming.version < _room.version) return _Verdict.desync;

    // The denormalised field and the snapshot must agree.
    if (incoming.turnNumber != state.turnNumber) return _Verdict.desync;

    if (state.turnNumber == _state.turnNumber) {
      // Same ply: either the echo of our own move, or a divergence.
      return state == _state ? _Verdict.echo : _Verdict.desync;
    }

    if (state.turnNumber == _state.turnNumber + 1) {
      // Exactly one ply ahead: it must be reachable by one legal action from
      // what we hold. This is the check that catches a forged or corrupted
      // single-step transition.
      if (!_isReachableByOneAction(state)) return _Verdict.desync;
    } else if (state.turnNumber > _state.turnNumber + 1) {
      // Further ahead is a catch-up after being away, and the snapshot is the
      // authority for it (`architecture.md` §11). A real catch-up has written the
      // document more than once, so the version must have grown; a large turn
      // jump with an unchanged version is a forgery, not a catch-up.
      if (incoming.version <= _room.version) return _Verdict.desync;
    }

    return _Verdict.apply;
  }

  /// Whether [candidate] is reachable from the held state by exactly one action.
  ///
  /// Uses the engine's own legal-action set, so the reachability test cannot
  /// disagree with the rules.
  bool _isReachableByOneAction(GameState candidate) {
    final from = _state;
    for (final action in GameEngine.legalActions(from)) {
      final result = GameEngine.apply(from, from.currentPlayer, action);
      if (result is SuccessResult && result.state == candidate) return true;
    }
    return false;
  }

  // --- Failure, recovery, reconnection ----------------------------------------

  void _failSync(String message) {
    if (_sync == OnlineSyncState.syncError) return;
    _sync = OnlineSyncState.desynced;
    _statusMessage = message;
    _log.error('desync: $message');
    notifyListeners();
    unawaited(_recover());
  }

  /// Rebuilds the state from the move log, which `architecture.md` §11 calls the
  /// audit and recovery source.
  ///
  /// Replay is one read per move and happens **only** here, never in steady
  /// state. If the log cannot produce a state, the controller stops in
  /// [OnlineSyncState.syncError] rather than guessing.
  Future<void> _recover() async {
    if (_recovering || _disposed) return;
    _recovering = true;
    try {
      final moves = await matches.readMoves(code: code);
      if (_disposed) return;
      if (moves.isEmpty) {
        _sync = OnlineSyncState.syncError;
        _statusMessage = 'The shared move history could not be read.';
        notifyListeners();
        return;
      }

      var replayed = GameState.initial(_room.boardConfig);
      for (final move in moves) {
        final action = move.action;
        if (action == null) {
          _sync = OnlineSyncState.syncError;
          _statusMessage = 'The shared move history is incomplete.';
          notifyListeners();
          return;
        }
        final result = GameEngine.apply(
          replayed,
          replayed.currentPlayer,
          action,
        );
        if (result is! SuccessResult) {
          // A recorded move the engine refuses: the log itself is inconsistent,
          // so it cannot be used to repair anything.
          _sync = OnlineSyncState.syncError;
          _statusMessage = 'The shared move history is inconsistent.';
          notifyListeners();
          return;
        }
        replayed = result.state;
      }

      if (replayed.turnNumber != moves.last.turnNumber + 1) {
        _sync = OnlineSyncState.syncError;
        _statusMessage = 'The shared move history has a gap.';
        notifyListeners();
        return;
      }

      _state = replayed;
      _sync = OnlineSyncState.inSync;
      _statusMessage = 'Board rebuilt from the move history.';
      _log.log('recovered by replay to turn ${replayed.turnNumber}');
      notifyListeners();
    } finally {
      _recovering = false;
    }
  }

  /// Called after a successful adopt: deals with a held action.
  ///
  /// The three outcomes `rules.md` §9 implies, decided here rather than in the
  /// repository because they are all about *this* client's intent:
  ///
  /// * the move is already recorded — the acknowledgement was lost; drop it.
  /// * it is still this client's turn and the state has not moved on — resubmit
  ///   the identical action, which is idempotent.
  /// * the state moved on — the action is no longer valid; drop it and say so.
  void _resolvePendingAfterSync() {
    final pending = _pending;
    if (pending == null) return;
    if (pending.turn < _state.turnNumber) {
      // Already applied while we were away.
      _pending = null;
      return;
    }
    if (pending.turn > _state.turnNumber) {
      // We fell behind; the held move is no longer the next action.
      _pending = null;
      _statusMessage = 'Your opponent moved while you were away.';
      return;
    }
    // Same ply, our turn: resubmit the identical action. Idempotent by move id.
    unawaited(submit(pending.action));
  }

  void _setConnection(OnlineConnectionState state) {
    if (_disposed || _connection == state) return;
    _connection = state;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    if (_disposed || _submitting == value) return;
    _submitting = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
