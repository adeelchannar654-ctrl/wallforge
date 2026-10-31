import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/engine/game_engine.dart';
import '../../domain/models/action_failure.dart';
import '../../domain/models/board_config.dart';
import '../../domain/models/cell.dart';
import '../../domain/models/finish_reason.dart';
import '../../domain/models/game_action.dart';
import 'match_clock.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/game_status.dart';
import '../../domain/models/player_id.dart';
import '../../domain/repositories/repositories.dart';
import 'ai/ai_difficulty.dart';
import 'game_interaction.dart';
import 'ai/ai_opponent.dart';

/// How long the AI "thinks" before moving.
///
/// `design.md` §20 does not specify AI timing, so this is a recorded own
/// decision: an instant reply reads as a glitch, and a long pause reads as a
/// hang. A short, fixed delay is predictable and costs nothing.
const Duration kAiThinkDelay = Duration(milliseconds: 300);

/// The player the AI controls in a versus-AI match started
/// fresh. A rematch swaps the sides (Phase 16.5), so the
/// controller tracks the live assignment in a field seeded
/// from this constant.
const PlayerId kAiPlayer = PlayerId.red;

/// Phase 4 application layer: local pass-and-play game controller.
///
/// Manages a single match between two human players sharing a screen.
/// Strictly ChangeNotifier-based per §2.3; no Flutter widget imports.
class LocalGameController extends ChangeNotifier with GameInteraction {
  /// Creates a controller with an optional initial board config.
  ///
  /// Pass `versusAi: true` to play the offline AI opponent at [aiDifficulty].
  ///
  /// Persistence is **opt-in** via [attachPersistence]. With no repositories
  /// attached the controller performs no persistence at all, which keeps its
  /// behaviour identical to Phase 4/5 and keeps the existing synchronous tests
  /// honest. The router attaches the `shared_preferences` implementations at
  /// startup; tests attach the in-memory ones.
  LocalGameController({
    BoardConfig config = const BoardConfig(),
    bool versusAi = false,
    AiDifficulty aiDifficulty = AiDifficulty.easy,
    int? timeControlSeconds,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now {
    _state = GameState.initial(config);
    _versusAi = versusAi;
    _aiDifficulty = aiDifficulty;
    // Phase 16.5: an explicit control wins; otherwise the
    // persisted Settings default is adopted when it loads.
    _timeControlSeconds = timeControlSeconds ?? 0;
    _clockExplicit = timeControlSeconds != null;
    _matchClock = MatchClock(now: _now, onTimeout: _onClockTimeout);
    _recordAiPosition();
    // Blue always moves first (R-PLAYER-07), so the AI's first turn is
    // scheduled from the human's first action rather than here.
  }

  SettingsRepository? _settingsRepository;
  StatisticsRepository? _statisticsRepository;
  UnfinishedMatchRepository? _unfinishedMatchRepository;

  /// Attaches local storage.
  ///
  /// Called by the router with the `shared_preferences` implementations, and by
  /// tests with the in-memory ones. The controller only ever talks to the
  /// domain repository interfaces, so Phase 7 can supply a Firebase
  /// implementation here without any change above this layer.
  void attachPersistence({
    required SettingsRepository settings,
    required StatisticsRepository statistics,
    required UnfinishedMatchRepository unfinishedMatch,
  }) {
    _settingsRepository = settings;
    _statisticsRepository = statistics;
    _unfinishedMatchRepository = unfinishedMatch;
  }

  /// The settings this controller is running with.
  AppSettings _settings = AppSettings.defaults;

  /// The live settings, after [loadPersisted] has run.
  AppSettings get settings => _settings;

  /// Whether any persistence is wired up at all.
  bool get hasPersistence => _settingsRepository != null;

  GameState _state = GameState.initial();
  bool _showingResult = false;

  /// Phase 16.5: an application-layer finish that the engine did
  /// not produce (resign, clock timeout). The engine state stays
  /// `inProgress`; the outcome lives here, at the match layer.
  PlayerId? _outcomeWinner;
  FinishReason? _appFinishReason;

  // --- Phase 16.5: per-move clock ------------------------------------------

  /// The injected wall clock (tests substitute a manual one).
  final DateTime Function() _now;

  /// The match clock state machine.
  late final MatchClock _matchClock;

  /// The resolved per-move control for this match, in seconds
  /// (0 = off): the explicit value when one was given, else the
  /// persisted Settings default once it has loaded.
  int _timeControlSeconds = 0;
  bool _clockExplicit = false;

  /// The 1 Hz display/timeout ticker. Exists only while a
  /// clocked human turn is in flight (Phase 15's invariant: an
  /// idle or unclocked board schedules nothing).
  Timer? _clockTimer;

  /// The current live-region announcement ("10 seconds left"),
  /// set only when a threshold is crossed — never per second.
  String? _clockAnnouncement;

  /// The last threshold announced for this turn (10, then 5).
  int _lastAnnouncedThreshold = 0;

  /// Phase 5: optional offline AI opponent.
  bool _versusAi = false;
  AiDifficulty _aiDifficulty = AiDifficulty.easy;

  /// The side the AI currently plays (Phase 16.5): [kAiPlayer]
  /// in a fresh match, swapped by a rematch.
  PlayerId _aiPlayer = kAiPlayer;
  Timer? _aiTimer;

  /// The AI pawn's cell on its own previous turn, so it can avoid stepping
  /// straight back into it.
  Cell? _aiPreviousCell;

  /// Position keys already occupied this game, with the ply at which each was
  /// last seen. Lets the AI notice it is replaying a position.
  final Map<String, int> _aiVisitOrder = {};

  // --- Read-only getters ----------------------------------------------------

  GameState get state => _state;
  bool get showingResult => _showingResult;

  /// The state the shared interaction layer validates against.
  @override
  GameState get interactionState => _state;

  /// Whether this match is against the offline AI rather than pass-and-play.
  bool get versusAi => _versusAi;

  /// The difficulty the AI plays at.
  AiDifficulty get aiDifficulty => _aiDifficulty;

  /// True when it is the AI's turn to act, so the board is not waiting on a
  /// human.
  bool get isAiTurn =>
      _versusAi &&
      _state.status == GameStatus.inProgress &&
      _state.currentPlayer == _aiPlayer;

  /// The side the human plays in a vs-AI match (Blue in a fresh
  /// match, Red in a rematch — Phase 16.5's side swap).
  PlayerId get humanSide => _humanPlayer;

  /// The side the AI plays in a vs-AI match.
  PlayerId get aiSide => _aiPlayer;

  /// The winner: the engine's, for a goal finish, or the
  /// application-layer outcome for a resign/timeout finish.
  PlayerId? get winner => _state.winner ?? _outcomeWinner;

  /// Why the match ended, when it has: `goal` for an engine
  /// finish, the application reason for a resign/timeout.
  FinishReason? get finishReason =>
      _appFinishReason ??
      (_state.status == GameStatus.finished ? FinishReason.goal : null);

  bool get isFinished =>
      _state.status == GameStatus.finished || _outcomeWinner != null;
  PlayerId get currentPlayer => _state.currentPlayer;

  // --- Phase 16.5: clock surface --------------------------------------------

  /// The per-move control this match runs under, in seconds
  /// (0 = off).
  int get timeControlSeconds => _timeControlSeconds;

  /// Whether a clocked human turn is currently being timed.
  bool get clockArmed => _matchClock.isArmed && !isFinished;

  /// Time left for the side being timed, or null when the clock
  /// is not running (off, AI's turn, or the match is over).
  Duration? get clockRemaining => clockArmed ? _matchClock.remaining : null;

  /// The side whose clock is running.
  PlayerId? get clockSide => clockArmed ? _matchClock.side : null;

  /// Whether the running clock is in its last five seconds —
  /// the low-time state the UI marks with an icon and text, not
  /// colour alone.
  bool get clockLowTime {
    final remaining = clockRemaining;
    return remaining != null && remaining.inSeconds <= 5;
  }

  /// The latest threshold announcement for assistive technology
  /// ("10 seconds left" / "5 seconds left"), or null. Changes
  /// only at the thresholds, so a live region reading it never
  /// chatters every second.
  String? get clockAnnouncement => _clockAnnouncement;

  /// Whether the 1 Hz ticker currently exists. Exposed for the
  /// lifecycle tests that prove an unclocked or finished board
  /// schedules nothing.
  bool get clockTimerActive => _clockTimer != null;

  /// Starts timing the current turn if this match is clocked.
  ///
  /// Called by the game screen when it presents the match: a
  /// controller also exists on Home (for statistics and the
  /// resume card), and a clock must never run — or time out —
  /// where nobody is playing.
  void activateClock() {
    _clockActivated = true;
    _armClockForCurrentTurn();
  }

  /// Whether the game screen has presented this match (see
  /// [activateClock]): the persisted-default adoption re-arms
  /// only for a presented match whose first turn has not moved.
  bool _clockActivated = false;

  /// Freezes the countdown while the app is backgrounded
  /// (D16.5-4).
  void pauseClock() {
    _matchClock.pause();
    _syncClockTimer();
  }

  /// Resumes the countdown from the frozen remainder.
  void resumeClock() {
    _matchClock.resume();
    _syncClockTimer();
    notifyListeners();
  }

  void _onClockTimeout(PlayerId side) {
    if (isFinished) return;
    _finishByApplication(side.opponent, FinishReason.timeout);
  }

  /// (Re)arms the clock for whoever is to move, or stops it:
  /// off, finished, and AI turns are never timed.
  void _armClockForCurrentTurn() {
    if (_disposed) return;
    if (isFinished || _timeControlSeconds <= 0) {
      _stopClock();
      return;
    }
    if (_versusAi && _state.currentPlayer == _aiPlayer) {
      _stopClock();
      return;
    }
    _matchClock.startTurn(
      _state.currentPlayer,
      Duration(seconds: _timeControlSeconds),
    );
    _lastAnnouncedThreshold = 0;
    _clockAnnouncement = null;
    _syncClockTimer();
  }

  void _stopClock() {
    _matchClock.stop();
    _syncClockTimer();
  }

  /// Keeps the 1 Hz ticker in existence exactly while a clocked
  /// human turn is in flight and unpaused.
  void _syncClockTimer() {
    final shouldRun =
        _matchClock.isArmed && !_matchClock.isPaused && !_disposed;
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
    _matchClock.tick();
    final remaining = _matchClock.remaining;
    if (remaining != null && _matchClock.isArmed && !isFinished) {
      final seconds = remaining.inSeconds;
      if (seconds <= 10 && _lastAnnouncedThreshold == 0) {
        _lastAnnouncedThreshold = 10;
        _clockAnnouncement = '10 seconds left';
      } else if (seconds <= 5 && _lastAnnouncedThreshold == 10) {
        _lastAnnouncedThreshold = 5;
        _clockAnnouncement = '5 seconds left';
      }
      if (seconds <= 5 && seconds > 0) feedback?.onClockTick();
    }
    notifyListeners();
  }

  /// Drives one clock tick directly (tests use a manual clock
  /// and call this instead of waiting for the 1 Hz timer).
  @visibleForTesting
  void debugTickClock() => _onClockTick();

  // --- Actions called by presentation ---------------------------------------

  /// Start a new match.
  void startMatch({
    BoardConfig config = const BoardConfig(),
    bool versusAi = false,
    AiDifficulty aiDifficulty = AiDifficulty.easy,
    int? timeControlSeconds,
    PlayerId? humanSide,
  }) {
    _state = GameState.initial(config);
    resetInteraction();
    _showingResult = false;
    _outcomeWinner = null;
    _appFinishReason = null;
    if (timeControlSeconds != null) {
      _timeControlSeconds = timeControlSeconds;
      _clockExplicit = true;
    }
    _versusAi = versusAi;
    _aiDifficulty = aiDifficulty;
    // Phase 16.5: the human's side in a vs-AI match — Blue for
    // a fresh match (the default the difficulty screen states),
    // Red for a rematch, where the sides swap. Pass-and-play
    // has no fixed human side; the field rests at the default.
    _aiPlayer = versusAi ? (humanSide ?? PlayerId.blue).opponent : kAiPlayer;
    _aiPreviousCell = null;
    _aiVisitOrder.clear();
    _cancelAiTurn();
    _recordAiPosition();
    // Starting a new match abandons any previously resumable one, and the
    // difficulty just chosen is a setting worth keeping across restarts.
    _resumableMatch = null;
    unawaited(_clearUnfinished());
    unawaited(persistSettings());
    _armClockForCurrentTurn();
    notifyListeners();
    _scheduleAiTurn();
  }

  /// Restart the current match with same config and the same opponent.
  ///
  /// A restart keeps the sides as they are; only a rematch
  /// exchanges them.
  void restart() {
    startMatch(
      config: _state.boardConfig,
      versusAi: _versusAi,
      aiDifficulty: _aiDifficulty,
      timeControlSeconds: _timeControlSeconds,
      humanSide: _versusAi ? _humanPlayer : null,
    );
  }

  /// Start a rematch: same board, same opponent, same clock —
  /// and the sides swap (Phase 16.5).
  ///
  /// Whoever moved first in the finished match moves second in
  /// this one: in vs-AI the human takes the other colour and
  /// the AI opens as Blue; online, the seats exchange in the
  /// new room. Blue still moves first (R-PLAYER-07) — it is
  /// the *players* who change colours, never the rule. In
  /// pass-and-play the two players exchange colours physically
  /// on the shared screen; there is no per-player identity in
  /// the app to swap, so the swap is the players' own act and
  /// the match simply restarts with the same settings.
  void rematch() {
    startMatch(
      config: _state.boardConfig,
      versusAi: _versusAi,
      aiDifficulty: _aiDifficulty,
      timeControlSeconds: _timeControlSeconds,
      humanSide: _versusAi ? _humanPlayer.opponent : null,
    );
  }

  /// Resigns the match for [side] (Phase 16.5): the opponent
  /// wins, recorded with `FinishReason.resign`.
  ///
  /// Application-layer finish: the engine state is left exactly
  /// as it stands (it only ever finishes on a goal), and the
  /// outcome is carried by [_outcomeWinner]. Any pending AI turn
  /// is cancelled, the resumable save is dropped, and the finish
  /// is recorded through the same path a goal finish uses — so
  /// statistics (and, later, history) see exactly one finish.
  void resign(PlayerId side) {
    if (isFinished || _state.status != GameStatus.inProgress) return;
    _finishByApplication(side.opponent, FinishReason.resign);
  }

  /// Ends the match at the application layer with [winner] and
  /// [reason] (resign now; the game clock's timeout in Part C).
  void _finishByApplication(PlayerId winner, FinishReason reason) {
    _outcomeWinner = winner;
    _appFinishReason = reason;
    _showingResult = true;
    _stopClock();
    _cancelAiTurn();
    unawaited(recordFinishedMatch());
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _clockTimer?.cancel();
    _clockTimer = null;
    _cancelAiTurn();
    super.dispose();
  }

  /// Set in [dispose] so async persistence work that lands afterwards becomes a
  /// no-op instead of notifying a disposed [ChangeNotifier].
  ///
  /// This is not hypothetical: [loadPersisted] and the save methods are
  /// deliberately unawaited, so a route popped while a slow read is still in
  /// flight would otherwise hit Flutter's "used after dispose" assertion. With
  /// `shared_preferences` the window is tiny, but the Firestore repositories added
  /// in Phase 7 make the read genuinely asynchronous and network-bound, which
  /// turns the window from theoretical to routine.
  bool _disposed = false;

  /// Applies [action] locally, or returns the engine's refusal.
  ///
  /// The local sink. Nothing is sent anywhere: the engine decides and the new
  /// state replaces the old one. This is exactly the Phase 4/5 behaviour.
  @override
  ActionFailure? attemptAction(GameAction action) {
    // An application-layer finish (resign/timeout) ends the match
    // even though the engine state still reads inProgress.
    if (_outcomeWinner != null) return ActionFailure.matchFinished;
    final result = GameEngine.apply(_state, _state.currentPlayer, action);
    if (result is SuccessResult) {
      _state = result.state;
      return null;
    }
    return (result as FailureResult).failure;
  }

  @override
  void onActionApplied() {
    if (_state.status == GameStatus.finished) {
      _showingResult = true;
      _stopClock();
      // Phase 12: the match ending is its own event, distinct from the
      // winning action's cue, and fires exactly once — this is the only
      // place a local match transitions into the finished state.
      feedback?.onVictory();
      unawaited(recordFinishedMatch());
    } else {
      _saveUnfinished();
      // Phase 16.5: the turn — and its clock — passes to the
      // next player (or stops, when the AI is to move).
      _armClockForCurrentTurn();
    }
    _recordAiPosition();
    _scheduleAiTurn();
  }

  @override
  void onConfirmWallPlacementToggled() => unawaited(persistSettings());

  /// Dismiss the result dialog.
  void dismissResult() {
    _showingResult = false;
    notifyListeners();
  }

  // --- Phase 6 local persistence --------------------------------------------

  /// Loads persisted settings and the resumable match.
  ///
  /// Call once at startup. Safe to call with no repositories wired up, and safe
  /// to call when the stored data is corrupt — the repositories fall back to
  /// defaults and [resumableMatch] simply stays null.
  Future<void> loadPersisted() async {
    final settingsRepo = _settingsRepository;
    if (settingsRepo != null) {
      final loaded = await settingsRepo.load();
      if (_disposed) return;
      _settings = loaded;
      setConfirmWallPlacementSilently(loaded.confirmWallPlacement);
      _aiDifficulty = _difficultyFromName(loaded.aiDifficulty);
      // Phase 16.5: adopt the persisted default clock when this
      // match was not given an explicit control. If the game
      // screen has already presented the match (the load raced
      // the first frame), re-arm so the first turn is timed too.
      if (!_clockExplicit) {
        _timeControlSeconds = loaded.defaultTimeControlSeconds;
        if (_clockActivated && _state.turnNumber == 0 && !isFinished) {
          _armClockForCurrentTurn();
        }
      }
      // Phase 12: keep the feedback layer's snapshot at the persisted
      // values, so cues are gated correctly from the first move.
      feedback?.applySettings(loaded);
    }
    if (_disposed) return;
    notifyListeners();
  }

  /// The resumable match, or null when there is none.
  ///
  /// Read by the entry screen to decide whether to offer "resume".
  UnfinishedMatch? get resumableMatch => _resumableMatch;
  UnfinishedMatch? _resumableMatch;

  /// Loads the stored unfinished match without applying it.
  ///
  /// Separate from [loadPersisted] so the entry screen can ask "is there
  /// something to resume?" without the controller adopting the state behind the
  /// player's back.
  Future<void> refreshResumableMatch() async {
    final repo = _unfinishedMatchRepository;
    if (repo == null) return;
    final loaded = await repo.load();
    if (_disposed) return;
    _resumableMatch = loaded;
    notifyListeners();
  }

  /// Restores a previously saved match and continues playing it.
  ///
  /// The state comes from the engine's own serializer, so the resumed match is
  /// validated exactly like any other state. Returns false when [match] cannot
  /// be adopted.
  bool resumeMatch(UnfinishedMatch match) {
    if (match.gameState.status == GameStatus.finished) return false;
    _cancelAiTurn();
    _state = match.gameState;
    _versusAi = match.versusAi;
    _aiDifficulty = _difficultyFromName(match.aiDifficulty);
    // Phase 16.5: a rematch in progress resumes with its sides
    // as they were — the save carries the human's side.
    _aiPlayer = match.versusAi ? match.humanSide.opponent : kAiPlayer;
    // Phase 16.5: the resumed match keeps its time control, and
    // the current turn restarts at a full clock (D16.5-4) — the
    // save deliberately stores no deadline.
    _timeControlSeconds = match.timeControlSeconds;
    _clockExplicit = true;
    _outcomeWinner = null;
    _appFinishReason = null;
    resetInteraction();
    _showingResult = false;
    _aiPreviousCell = null;
    _aiVisitOrder.clear();
    _recordAiPosition();
    _resumableMatch = null;
    _armClockForCurrentTurn();
    notifyListeners();
    _scheduleAiTurn();
    return true;
  }

  /// Records a finished match into the local statistics and drops the resumable
  /// match, since a finished match is no longer resumable.
  Future<void> recordFinishedMatch() async {
    final winner = this.winner;
    if (winner == null) return;
    unawaited(_clearUnfinished());
    final stats = _statisticsRepository;
    if (stats == null) return;
    await stats.recordResult(
      boardSize: _state.boardConfig.size,
      difficulty: _difficultyNameFor(_versusAi, _aiDifficulty),
      humanWon: winner == _humanPlayer,
    );
  }

  /// The stored settings, so the entry screen can preselect a difficulty.
  Future<AppSettings> loadSettings() async =>
      _settingsRepository?.load() ?? AppSettings.defaults;

  /// Persists the current settings (used when the player changes a setting).
  Future<void> persistSettings() async {
    final repo = _settingsRepository;
    if (repo == null) return;
    _settings = _settings.copyWith(
      confirmWallPlacement: confirmWallPlacement,
      aiDifficulty: _difficultyNameFor(_versusAi, _aiDifficulty),
    );
    await repo.save(_settings);
  }

  /// The player a human controls; the AI always takes the other side.
  PlayerId get _humanPlayer => _aiPlayer.opponent;

  /// Saves the in-progress match so it can be resumed after a restart.
  void _saveUnfinished() {
    final repo = _unfinishedMatchRepository;
    if (repo == null) return;
    if (_state.status != GameStatus.inProgress) return;
    unawaited(
      repo.save(
        UnfinishedMatch(
          gameState: _state,
          boardSize: _state.boardConfig.size,
          versusAi: _versusAi,
          aiDifficulty: _difficultyNameFor(_versusAi, _aiDifficulty),
          savedAtTurn: _state.turnNumber,
          timeControlSeconds: _timeControlSeconds,
          humanSide: _humanPlayer,
        ),
      ),
    );
  }

  Future<void> _clearUnfinished() async {
    final repo = _unfinishedMatchRepository;
    if (repo == null) return;
    _resumableMatch = null;
    await repo.clear();
  }

  /// Maps a persisted difficulty name onto the application enum, falling back to
  /// [AiDifficulty.easy] for an unknown or missing value.
  static AiDifficulty _difficultyFromName(String name) {
    for (final difficulty in AiDifficulty.values) {
      if (difficulty.name == name) return difficulty;
    }
    return AiDifficulty.values.first;
  }

  /// The persisted name for the current opponent. Pass-and-play matches are
  /// recorded under `"local"`, which is not an [AiDifficulty] name.
  static String _difficultyNameFor(bool versusAi, AiDifficulty difficulty) =>
      versusAi ? difficulty.name : 'local';

  // --- Internal helpers -----------------------------------------------------

  /// Remembers the AI pawn's current cell and position for loop avoidance.
  void _recordAiPosition() {
    if (!_versusAi) return;
    _aiPreviousCell ??= _state.pawnPosition(_aiPlayer);
    _aiVisitOrder[AiOpponent.positionKey(_state)] = _state.turnNumber;
  }

  void _cancelAiTurn() {
    _aiTimer?.cancel();
    _aiTimer = null;
    // Phase 16: every cancellation also invalidates any search
    // already in flight, via the generation token below.
    _aiGeneration++;
  }

  /// Cancellation token for AI searches (Phase 16). _runAiTurn
  /// captures the current value when it starts; _cancelAiTurn —
  /// called on schedule, restart, new match and dispose — increments
  /// it, so a search that finishes after any of those events finds
  /// its generation stale and drops its result. The turn-number
  /// check alone could not tell two different matches that happen to
  /// share a turn number apart; the generation can.
  int _aiGeneration = 0;

  /// Queues the AI's move when it is the AI's turn.
  ///
  /// The timer sets WHEN the search starts (so the UI shows whose turn
  /// it is first); it cannot make the search itself non-blocking —
  /// Phase 15 (Q-5.3 corrected): a synchronous Expert search blocked
  /// the UI thread for ~1.3 s on 9×9 and ~3.2 s on 11×11 regardless of
  /// the timer. The search therefore runs through
  /// [AiOpponent.chooseActionAsync], which yields to the event loop
  /// between root candidates, and the result is applied only if the
  /// match is still exactly where the search started.
  void _scheduleAiTurn() {
    _cancelAiTurn();
    if (!isAiTurn) return;
    _aiTimer = Timer(kAiThinkDelay, () {
      _aiTimer = null;
      if (!isAiTurn) return;
      unawaited(_runAiTurn());
    });
  }

  /// Runs the AI search for the current position and applies its
  /// choice, unless the match moved on while the search was yielding
  /// (restart, dispose, or the turn otherwise changed) — a stale
  /// result must never land.
  Future<void> _runAiTurn() async {
    final turnAtStart = _state.turnNumber;
    final generationAtStart = _aiGeneration;
    final action = await AiOpponent.chooseActionAsync(
      _state,
      _aiDifficulty,
      _aiPlayer,
      previousCell: _aiPreviousCell,
      visitOrder: _aiVisitOrder,
    );
    if (_disposed ||
        _aiGeneration != generationAtStart ||
        !isAiTurn ||
        _state.turnNumber != turnAtStart) {
      return;
    }
    if (action == null) return;
    _playAiAction(action);
  }

  /// Applies the AI's chosen action through the shared interaction layer,
  /// exactly as a human action is. The AI never bypasses validation.
  void _playAiAction(GameAction action) {
    _aiPreviousCell = _state.pawnPosition(_aiPlayer);
    setModeSilently(InteractionMode.move);
    final failure = attemptAction(action);
    if (failure == null) {
      onActionApplied();
      // Phase 12: the AI's action returns the turn to the human — the
      // turn-change cue fires here rather than a second move cue for an
      // action the viewer did not take (one event, one sound; the
      // victory cue above already covered a finishing AI move).
      if (_state.status != GameStatus.finished) feedback?.onTurnChanged();
    }
    notifyListeners();
  }

  /// Returns mode without the notify that [setMode] performs, so the AI path
  /// can switch mode and apply in one update.
  void setModeSilently(InteractionMode mode) => interactionSetMode(mode);

  /// Returns a human-readable message for the given [failure].
  static String failureMessage(ActionFailure failure) => switch (failure) {
    ActionFailure.matchFinished => 'The game is already over.',
    ActionFailure.wrongTurn => "It's not your turn.",
    ActionFailure.moveOutOfBoard => 'You cannot move off the board.',
    ActionFailure.moveNotAdjacent => 'You can only move to an adjacent cell.',
    ActionFailure.moveBlockedByWall => 'A wall blocks that move.',
    ActionFailure.moveOntoPawn => 'You cannot move onto the opponent.',
    ActionFailure.moveIllegalJump => 'That jump is not allowed.',
    ActionFailure.noWallsRemaining => 'You have no walls left.',
    ActionFailure.wallOutOfBounds => 'Wall placement is out of bounds.',
    ActionFailure.wallOverlaps => 'Wall overlaps an existing wall.',
    // Retired in spec v2.0.0 (unreachable: crossing walls are legal). Kept so
    // this switch stays exhaustive over the declared taxonomy.
    ActionFailure.wallCrosses => 'Wall crosses an existing wall.',
    ActionFailure.wallBlocksPath =>
      'Wall would block a player\'s path to goal.',
  };
}
