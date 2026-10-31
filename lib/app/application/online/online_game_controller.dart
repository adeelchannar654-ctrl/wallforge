import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../domain/wallforge_domain.dart';
import '../achievements/achievements_service.dart';
import '../action_inference.dart';
import '../game_interaction.dart';
import 'leaderboard_submitter.dart';

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

/// What the *opponent's* presence looks like from this client (Phase 10).
///
/// Separate from [OnlineConnectionState] on purpose: that enum is about this
/// client's own network path (Phase 9). This one is about the other player —
/// derived from the shared document standing still while it is their turn,
/// which is the only presence signal a serverless design has. The document
/// advancing is proof of life; it not advancing past
/// [opponentInactivityThreshold] is treated as the opponent having gone.
enum OpponentPresence {
  /// No judgement applies: the match has not started, is over, or it is
  /// this client's turn (the player who might be gone is us).
  notApplicable,

  /// It is the opponent's turn and the document advanced recently.
  active,

  /// It is the opponent's turn and the document has not advanced for the
  /// whole inactivity threshold: the opponent appears to have disconnected.
  stalled,
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
/// Phase 9 covered *this* client: preserving its state, showing
/// "Reconnecting", and converging without double-applying. Phase 10 adds the
/// other half: what this client concludes about the **opponent** —
/// [OpponentPresence] and the abandonment claim — with Security Rules
/// (`firestore.rules`) as the server-side boundary. The limits of the
/// client-side checks below are stated in `security_model.md` rather than
/// presented as a security boundary.
class OnlineGameController extends ChangeNotifier with GameInteraction {
  OnlineGameController({
    required this.rooms,
    required this.matches,
    required this.uid,
    required this.code,
    GameState? initialState,
    DateTime Function()? clock,
    this.opponentTimeout = opponentInactivityThreshold,
    this.movementAssistance = false,
    MatchHistoryRepository? history,
    AchievementsService? achievements,
    this.leaderboardSubmitter,
  }) : _state = initialState ?? GameState.initial(),
       _clock = clock ?? DateTime.now,
       _historyRepository = history,
       _achievementsService = achievements,
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

  /// How long the opponent may stay silent before [opponentPresence] calls
  /// them stalled. Injectable so tests do not wait in real time; defaults to
  /// the shared [opponentInactivityThreshold] the claim and the Security
  /// Rules also use.
  final Duration opponentTimeout;

  /// Whether the local player has movement assistance on (`design.md` §23,
  /// Phase 11): the board draws their shortest route while Move is selected
  /// on their turn. Resolved from the persisted settings by the lobby when
  /// it builds this controller; the game itself has no settings store.
  final bool movementAssistance;

  // --- Phase 16.5, Part E: history capture -----------------------------------

  /// The per-device history store, or null when unwired (tests
  /// that do not care about history). Recording an online
  /// finish costs no Firestore operations: the record is built
  /// from the final snapshot already in memory and the gate
  /// lives in the local store.
  final MatchHistoryRepository? _historyRepository;

  /// The achievements service (Phase 16.5, Part F), evaluated
  /// after a finish is recorded.
  final AchievementsService? _achievementsService;

  /// The leaderboard submitter (Phase 16.5, Part H), fired
  /// once when the match ends. Null when the feature flag is
  /// off or the screen did not wire it.
  final LeaderboardSubmitter? leaderboardSubmitter;

  /// Set by the game screen: called with the achievements a
  /// recorded finish just unlocked, for the unlock toast.
  /// Never called with an empty list.
  void Function(List<AchievementDefinition>)? onAchievementsUnlocked;

  /// The record built for this match when it finished
  /// (Phase 16.5, Part G: the share flow's input), or null
  /// before the finish is recorded.
  MatchRecord? get lastFinishedRecord => _lastFinishedRecord;
  MatchRecord? _lastFinishedRecord;

  /// The moves this client witnessed, in spec notation.
  final List<String> _recordedMoves = <String>[];

  /// Whether [_recordedMoves] is complete: false the moment a
  /// snapshot jump shows a ply this client never saw.
  bool _movesComplete = true;

  /// Whether the terminal record has been handed to the store
  /// (its gate would refuse a second copy anyway; this just
  /// avoids rebuilding it on every snapshot).
  bool _historyRecorded = false;

  /// The `updatedAt` of the first started snapshot, for the
  /// record's duration.
  int? _startedObservedAtMs;

  final DateTime Function() _clock;

  GameState _state;
  Room _room;
  StreamSubscription<SharedMatchDocument>? _subscription;
  OnlineConnectionState _connection = OnlineConnectionState.connecting;
  OnlineSyncState _sync = OnlineSyncState.inSync;
  MatchSyncFailure? _lastSyncFailure;
  String? _statusMessage;
  bool _submitting = false;
  bool _disposed = false;

  /// Whether any snapshot has been adopted yet (Phase 12 cue gating: the
  /// first adopt is this client *joining* a state, not an event in the
  /// match, so it fires no cues).
  bool _adopted = false;
  bool _recovering = false;
  bool _claiming = false;
  AbandonmentFailure? _claimFailure;
  bool _resigning = false;
  ResignFailure? _resignFailure;

  // --- Phase 16.5: game clock ------------------------------------------------

  /// Estimated offset between this device's clock and the
  /// server's, in milliseconds (server − local), learned from
  /// the `serverUpdatedAt` stamp on each live snapshot. The
  /// stamp was written one network trip ago, so the estimate
  /// carries up to a round-trip of error — immaterial at
  /// one-second display granularity, and never used to judge a
  /// claim (the repository pre-checks and the rules decide
  /// against `request.time`).
  int _serverOffsetMs = 0;

  /// The 1 Hz clock ticker; exists only while a clocked match
  /// is live (see `_syncClockTimer`).
  Timer? _clockTimer;
  bool _claimingTimeout = false;
  TimeoutClaimFailure? _timeoutFailure;

  /// The turn a timeout claim was last attempted for, so the
  /// auto-claim fires once per turn, not once per tick.
  int _timeoutClaimedTurn = -1;
  int _lastClockSecond = -1;
  int _lastClockTurn = -1;
  String? _clockAnnouncement;
  int _lastAnnouncedThreshold = 0;
  OpponentPresence _lastPresence = OpponentPresence.notApplicable;
  Timer? _presenceTimer;

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

  /// Whether the match is over: the engine finished it, or the
  /// room document did (resign/timeout — Phase 16.5 finishes that
  /// leave the board snapshot `inProgress` on purpose).
  bool get isFinished =>
      _state.status == GameStatus.finished ||
      _room.status == RoomStatus.finished;

  /// Whether the match ended by an abandonment claim (Phase 10) rather than
  /// by play. Terminal, like [isFinished], but with no winner.
  bool get isAbandoned => _room.status == RoomStatus.abandoned;

  /// Whether this client is the one who claimed the match as abandoned.
  bool get claimedByMe => _room.abandonedById == uid;

  /// The opponent's presence, judged from the shared document.
  ///
  /// The signal is deliberately the same one the claim itself is judged by —
  /// the stored `updatedAt` standing still while it is the opponent's turn —
  /// so the banner never promises a claim the repository would refuse. The
  /// timestamp is written by the *opponent's* client, so a badly skewed
  /// opponent clock can stretch or shrink the wait; `security_model.md`
  /// records that limit rather than hiding it.
  OpponentPresence get opponentPresence {
    // Phase 16.5: a clocked match replaces the inactivity
    // heuristic with the turn deadline — there is no abandonment
    // claim to offer, whatever the presence looks like.
    if (_room.timeControlSeconds > 0) return OpponentPresence.notApplicable;
    if (_room.status != RoomStatus.started || isFinished) {
      return OpponentPresence.notApplicable;
    }
    final current = _room.currentPlayerId;
    if (current == null || current == uid || opponentId == null) {
      return OpponentPresence.notApplicable;
    }
    final idleMs = _clock().millisecondsSinceEpoch - _room.updatedAtMs;
    return idleMs >= opponentTimeout.inMilliseconds
        ? OpponentPresence.stalled
        : OpponentPresence.active;
  }

  /// Whether the abandonment claim is available right now.
  bool get canClaimAbandonment =>
      opponentPresence == OpponentPresence.stalled && !_claiming;

  /// Whether a claim is in flight.
  bool get isClaiming => _claiming;

  /// The last refused claim, or null.
  AbandonmentFailure? get claimFailure => _claimFailure;

  /// The winner, from the engine. Never from the document.
  ///
  /// The one exception is an application-layer finish (Phase
  /// 16.5): a resign or timeout leaves the engine state
  /// unfinished by design, so the winner can only come from the
  /// document — where the Security Rules guarantee it is the
  /// member who did not resign / was not to move, which is why
  /// believing it in exactly this case is sound.
  PlayerId? get winner =>
      _state.winner ??
      ((_room.status == RoomStatus.finished &&
              (_room.finishReason == FinishReason.resign ||
                  _room.finishReason == FinishReason.timeout) &&
              _room.winnerId != null)
          ? _room.sideFor(_room.winnerId!)
          : null);

  /// Why the match ended, when it has (Phase 16.5).
  FinishReason? get finishReason =>
      _room.finishReason ??
      (_state.status == GameStatus.finished ? FinishReason.goal : null) ??
      (isAbandoned ? FinishReason.abandon : null);

  /// Whether this client resigned the match.
  bool get resignedByMe =>
      _room.finishReason == FinishReason.resign &&
      winner != null &&
      winner != mySide;

  // --- Phase 16.5: clock surface ----------------------------------------------

  /// The match's per-move control in seconds (0 = off).
  int get timeControlSeconds => _room.timeControlSeconds;

  /// This device's best estimate of the server's current time.
  int get estimatedServerNowMs =>
      _clock().millisecondsSinceEpoch + _serverOffsetMs;

  /// Time left on the current turn's clock, or null when no
  /// clock is running (off, not started, or over). Computed from
  /// the stored server deadline against the skew-corrected
  /// local estimate — never from a locally counted duration, so
  /// a reconnect lands on the same value as a steady client.
  Duration? get clockRemaining {
    if (_room.timeControlSeconds <= 0 ||
        _room.status != RoomStatus.started ||
        isFinished ||
        isAbandoned) {
      return null;
    }
    final deadline = _room.turnDeadlineMs;
    if (deadline == null) return null;
    final ms = deadline - estimatedServerNowMs;
    return ms <= 0 ? Duration.zero : Duration(milliseconds: ms);
  }

  /// The side whose clock is running, or null.
  PlayerId? get clockSide =>
      clockRemaining == null ? null : _state.currentPlayer;

  /// Whether the running clock is in its last five seconds.
  bool get clockLowTime {
    final remaining = clockRemaining;
    return remaining != null && remaining.inSeconds <= 5;
  }

  /// The latest threshold announcement ("10 seconds left"),
  /// set only at the thresholds (see the local controller).
  String? get clockAnnouncement => _clockAnnouncement;

  /// Whether the timeout claim is available right now: clocked,
  /// live, the opponent to move, and the deadline plus grace
  /// has passed on the estimated server clock.
  bool get canClaimTimeout =>
      _room.timeControlSeconds > 0 &&
      _room.status == RoomStatus.started &&
      !isFinished &&
      !isAbandoned &&
      !isMyTurn &&
      _room.currentPlayerId != null &&
      _room.turnDeadlineMs != null &&
      estimatedServerNowMs > _room.turnDeadlineMs! + kTimeoutGraceMs;

  /// Whether a timeout claim is in flight.
  bool get isClaimingTimeout => _claimingTimeout;

  /// The last refused timeout claim, or null.
  TimeoutClaimFailure? get timeoutFailure => _timeoutFailure;

  /// Claims the match on time: the opponent's clock ran out.
  ///
  /// Also fired automatically by the clock ticker the moment
  /// the claim becomes available — the waiting player should
  /// not have to win a tapping race against a fact the shared
  /// document already proves.
  Future<void> claimTimeout() async {
    if (_claimingTimeout || !canClaimTimeout) return;
    _claimingTimeout = true;
    _timeoutFailure = null;
    notifyListeners();
    final result = await matches.claimTimeout(code: code);
    if (_disposed) return;
    _claimingTimeout = false;
    switch (result) {
      case TimeoutClaimed():
        await resync();
      case TimeoutClaimRejected(:final failure):
        _timeoutFailure = failure;
        _log.log('timeout claim refused: ${failure.reason.name}');
    }
    notifyListeners();
  }

  void _noteServerTime(Room room) {
    final stamp = room.serverUpdatedAtMs;
    if (stamp == null) return;
    _serverOffsetMs = stamp - _clock().millisecondsSinceEpoch;
  }

  /// Keeps the 1 Hz clock ticker in existence exactly while a
  /// clocked match is live — an unclocked, waiting or finished
  /// match schedules nothing (Phase 15 invariant).
  void _syncClockTimer() {
    final shouldRun =
        _room.timeControlSeconds > 0 &&
        _room.status == RoomStatus.started &&
        !isFinished &&
        !isAbandoned &&
        !_disposed;
    if (shouldRun && _clockTimer == null) {
      _clockTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _onClockTick(),
      );
    } else if (!shouldRun && _clockTimer != null) {
      _clockTimer!.cancel();
      _clockTimer = null;
    }
  }

  void _onClockTick() {
    if (_disposed) return;
    if (_room.turnNumber != _lastClockTurn) {
      _lastClockTurn = _room.turnNumber;
      _lastAnnouncedThreshold = 0;
      _clockAnnouncement = null;
      _lastClockSecond = -1;
    }
    if (canClaimTimeout && _timeoutClaimedTurn != _room.turnNumber) {
      _timeoutClaimedTurn = _room.turnNumber;
      unawaited(claimTimeout());
    }
    final remaining = clockRemaining;
    if (remaining != null) {
      final seconds = remaining.inSeconds;
      if (seconds <= 10 && _lastAnnouncedThreshold == 0) {
        _lastAnnouncedThreshold = 10;
        _clockAnnouncement = '10 seconds left';
      } else if (seconds <= 5 && _lastAnnouncedThreshold == 10) {
        _lastAnnouncedThreshold = 5;
        _clockAnnouncement = '5 seconds left';
      }
      if (seconds <= 5 && seconds > 0 && isMyTurn) feedback?.onClockTick();
      if (seconds != _lastClockSecond) {
        _lastClockSecond = seconds;
        notifyListeners();
      }
    }
    _syncClockTimer();
  }

  /// Whether the clock ticker currently exists (lifecycle tests).
  bool get clockTimerActive => _clockTimer != null;

  /// Drives one clock tick directly (tests).
  @visibleForTesting
  void debugTickClock() => _onClockTick();

  // --- Phase 16.5, Part E: history recording ---------------------------------

  /// Captures the ply between two consecutive snapshots for
  /// the history record's move list. A transition that is not
  /// exactly one ply marks the list partial — the record must
  /// never present a list with silent gaps as complete.
  void _capturePly(GameState before, GameState after) {
    if (after.turnNumber == before.turnNumber) return;
    final action = inferAction(before, after);
    if (action == null) {
      _movesComplete = false;
      return;
    }
    _recordedMoves.add(action.toNotation());
  }

  /// Hands the finished match to the history store, once.
  ///
  /// Runs on the snapshot paths (adopt and echo alike: a
  /// resign or timeout finish changes no board state, so it
  /// arrives as an echo). The store's own gate would refuse a
  /// duplicate anyway — this flag just avoids rebuilding the
  /// record on every later snapshot.
  void _maybeRecordHistory() {
    if (_historyRecorded || !(isFinished || isAbandoned)) return;
    _historyRecorded = true;
    unawaited(_recordHistory());
    // Phase 16.5, Part H: the same terminal snapshot feeds
    // the weekly leaderboard (best-effort, flag-gated by the
    // wiring — the submitter is simply absent when off).
    final submitter = leaderboardSubmitter;
    if (submitter != null) unawaited(submitter.submit(_room));
  }

  Future<void> _recordHistory() async {
    final history = _historyRepository;
    if (history == null) return;
    final room = _room;
    final startedAt = _startedObservedAtMs ?? room.createdAtMs;
    final record = MatchRecord(
      id: room.code,
      mode: MatchMode.online,
      boardSize: room.boardConfig.size,
      wallsPerPlayer: room.boardConfig.wallsPerPlayer,
      mySide: mySide,
      winnerSide: winner,
      finishReason:
          room.finishReason ??
          (isAbandoned ? FinishReason.abandon : FinishReason.goal),
      opponentLabel: 'Online player',
      plies: _state.turnNumber,
      durationMs: room.updatedAtMs > startedAt
          ? room.updatedAtMs - startedAt
          : 0,
      endedAtMs: room.updatedAtMs,
      timeControlSeconds: room.timeControlSeconds,
      moves: List<String>.of(_recordedMoves),
      movesComplete: _movesComplete,
      rematchOf: room.rematchOf,
    );
    _lastFinishedRecord = record;
    final added = await history.recordIfNew(record);
    // Phase 16.5, Part F: achievements evaluate over the
    // record just written.
    final achievements = _achievementsService;
    if (added && achievements != null) {
      final fresh = await achievements.onMatchRecorded();
      if (fresh.isNotEmpty && !_disposed) {
        onAchievementsUnlocked?.call(fresh);
      }
    }
  }

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
      // Not this client's turn, a submit in flight, not verified, offline —
      // or the match was claimed as abandoned under us.
      !isMyTurn ||
      _submitting ||
      isAbandoned ||
      _sync != OnlineSyncState.inSync ||
      _connection == OnlineConnectionState.reconnecting ||
      _connection == OnlineConnectionState.disconnected;

  /// Why input is refused, for the UI to explain rather than just grey out.
  String? get inputBlockedReason {
    if (isAbandoned) return 'This match was abandoned.';
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
    // Presence is a function of time passing, not only of documents
    // arriving: a stalled opponent produces no snapshot to react to. The
    // timer only re-evaluates the derived presence and notifies when it
    // flips; the five-second cadence is display polish, not a game rule,
    // and it writes nothing (`rules.md` §5: no periodic writes).
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_disposed) return;
      final presence = opponentPresence;
      if (presence != _lastPresence) {
        _lastPresence = presence;
        notifyListeners();
      }
    });
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

  /// Phase 12: this controller's submit verdict is asynchronous, so the
  /// shared interaction layer must not fire cues on attempt — they fire
  /// when the verified snapshot adopts an action (see
  /// [_fireAdoptedCues]), and the invalid cue fires on an `invalidAction`
  /// rejection in [submit].
  @override
  bool get cuesOnAttempt => false;

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
        // Phase 12: only an engine refusal is the "invalid action" cue —
        // network and turn races are connection facts, not user errors.
        if (failure.reason == MatchSyncFailureReason.invalidAction) {
          feedback?.onInvalidAction();
        }
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
    // Phase 16.5: every live snapshot refines the server-clock
    // estimate the countdown runs on.
    _noteServerTime(room);
    if (room.boardState == null &&
        _room.status != RoomStatus.started &&
        _room.status != RoomStatus.finished &&
        _room.status != RoomStatus.abandoned) {
      // Still in the lobby: adopt the room, keep the board untouched. The
      // gate is the absence of a snapshot rather than the status alone, so
      // a first document that already ended the match (finished, or claimed
      // as abandoned while this client was away) still flows through
      // verification below and lands as the terminal state it is.
      _room = room;
      _lastPresence = opponentPresence;
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
      // An echo still proves this client holds a verified state, so the
      // first one ends the "just joined" window for Phase 12 cues.
      _adopted = true;
      _lastPresence = opponentPresence;
      // An echo can still be the answer to a held action: if the move we were
      // holding landed while we were away, the very document that looks
      // unchanged from our stale local view is the proof. Resolving here is what
      // turns a lost acknowledgement into a success instead of a stuck spinner.
      _resolvePendingAfterSync();
      _syncClockTimer();
      _maybeRecordHistory();
      notifyListeners();
      return;
    }
    if (verdict == _Verdict.desync) {
      _failSync('The shared board did not match what was expected.');
      return;
    }

    // --- adopt ---
    final previousState = _state;
    _capturePly(previousState, room.boardState!);
    if (room.status == RoomStatus.started) {
      _startedObservedAtMs ??= room.updatedAtMs;
    }
    _room = room;
    _state = room.boardState!;
    _fireAdoptedCues(previousState, _state);
    _adopted = true;
    _lastPresence = opponentPresence;
    _lastSyncFailure = null;
    _statusMessage = null;
    if (_sync != OnlineSyncState.inSync) {
      _log.log('recovered from ${_sync.name} at turn ${_state.turnNumber}');
    }
    _sync = OnlineSyncState.inSync;
    _resolvePendingAfterSync();
    _syncClockTimer();
    _maybeRecordHistory();
    notifyListeners();
  }

  /// Phase 12 cues for an adopted snapshot — fired exactly once per
  /// event, from the verified state transition itself:
  ///
  /// * exactly one ply advanced, and the mover was this client → the
  ///   move/wall cue (this is the confirmation of our own submit; the
  ///   echo verdict guarantees it cannot fire twice for one action);
  /// * exactly one ply, mover was the opponent → the turn-change cue
  ///   (the turn returned to us; one event, one sound);
  /// * the match transitioned into finished → the victory cue (in
  ///   addition to our own winning action's cue; instead of the
  ///   turn-change cue for the opponent's winning action);
  /// * a jump of more than one ply is a catch-up: no action can be
  ///   attributed, so only a finish is cued.
  void _fireAdoptedCues(GameState previous, GameState next) {
    if (!_adopted) return;
    final feedback = this.feedback;
    if (feedback == null) return;
    final finishedNow =
        next.status == GameStatus.finished &&
        previous.status != GameStatus.finished;
    if (next.turnNumber != previous.turnNumber + 1) {
      if (finishedNow) feedback.onVictory();
      return;
    }
    final mover = previous.currentPlayer;
    if (mover == mySide) {
      final movedPawn =
          previous.pawnPosition(mover) != next.pawnPosition(mover);
      if (movedPawn) {
        feedback.onMove();
      } else {
        feedback.onWallPlaced();
      }
    } else if (!finishedNow) {
      feedback.onTurnChanged();
    }
    if (finishedNow) feedback.onVictory();
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
    //
    // Phase 16.5 exception, deliberately narrow: a resign/timeout
    // finish leaves the engine state unfinished *by design* and
    // declares its winner only in the document. That shape is
    // accepted only when the room itself is finished with one of
    // those two reasons and the declared winner is seated — the
    // Security Rules guarantee the winner is the member who did
    // not resign / was not to move.
    final declared = document.declaredWinnerId;
    if (declared != null) {
      final derived = state.status == GameStatus.finished
          ? incoming.seatFor(state.winner!).playerId
          : null;
      final appLayerFinish =
          incoming.status == RoomStatus.finished &&
          state.status != GameStatus.finished &&
          (incoming.finishReason == FinishReason.resign ||
              incoming.finishReason == FinishReason.timeout) &&
          incoming.sideFor(declared) != null;
      if (!appLayerFinish && derived != declared) return _Verdict.desync;
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

  /// Claims the match as abandoned: the opponent has been silent past the
  /// threshold on their own turn.
  ///
  /// The repository's transaction is the authority — this method only
  /// refuses early when the presence signal says the claim cannot apply, so
  /// a button shown by mistake cannot produce a spurious write attempt.
  /// The outcome arrives through the listener like every other match fact;
  /// a refused claim (the race case: the opponent moved first) is kept as
  /// [claimFailure] for the UI to state plainly.
  Future<void> claimAbandonment() async {
    if (_claiming || opponentPresence != OpponentPresence.stalled) return;
    _claiming = true;
    _claimFailure = null;
    notifyListeners();
    final result = await matches.claimAbandonment(code: code);
    if (_disposed) return;
    _claiming = false;
    switch (result) {
      case AbandonmentClaimed():
        // The listener will deliver the abandoned document; re-read once so
        // the terminal state shows even if the snapshot is slow.
        await resync();
      case AbandonmentRejected(:final failure):
        _claimFailure = failure;
        _log.log('abandonment claim refused: ${failure.reason.name}');
    }
    notifyListeners();
  }

  /// Resigns the match (Phase 16.5): the opponent wins.
  ///
  /// The outcome arrives through the listener like every other
  /// match fact; a refused resignation is kept as [resignFailure]
  /// for the UI to state plainly.
  Future<void> resign() async {
    if (_resigning || isFinished || isAbandoned) return;
    _resigning = true;
    _resignFailure = null;
    notifyListeners();
    final result = await matches.resign(code: code);
    if (_disposed) return;
    _resigning = false;
    switch (result) {
      case ResignSuccess():
        await resync();
      case ResignRejected(:final failure):
        _resignFailure = failure;
        _log.log('resign refused: ${failure.reason.name}');
    }
    notifyListeners();
  }

  /// Whether a resignation is in flight.
  bool get isResigning => _resigning;

  /// The last refused resignation, or null.
  ResignFailure? get resignFailure => _resignFailure;

  @override
  void dispose() {
    _disposed = true;
    _clockTimer?.cancel();
    _clockTimer = null;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
