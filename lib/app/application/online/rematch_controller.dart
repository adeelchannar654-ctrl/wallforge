import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../../domain/models/board_config.dart';
import '../../../domain/repositories/matchmaking.dart';
import '../../../domain/repositories/repositories.dart';

/// The state of a rematch negotiation between the two players of a finished
/// online match (Phase 11, resolving Q-9.2).
enum RematchPhase {
  /// Nobody has proposed yet (or a proposal was declined/dismissed).
  idle,

  /// This player has proposed and is waiting for the opponent to accept.
  proposing,

  /// The opponent has proposed; this player can accept or decline.
  proposalAvailable,

  /// Both players consented and the new room exists.
  matched,

  /// The negotiation ended without a rematch (the proposal lapsed, or the
  /// proposer's queue entry was claimed by a third player's Quick Match).
  unavailable,
}

/// Drives the online rematch consent flow on the Result screen.
///
/// ## Why it is built on the matchmaking queue
///
/// A finished room document is locked by the Phase 10 Security Rules — no
/// transition matches it, so consent cannot be written onto it. The rules
/// deliberately make the matchmaking namespace generic, so consent is
/// signalled there instead, with the shipped primitives:
///
/// * **Propose** = [MatchmakingRepository.joinQueue] under the finished
///   match's own board-config key: the proposer becomes claimable, by one
///   specific player, without being greedily paired with a stranger.
/// * **Notice** = polling [MatchmakingRepository.waitingPlayerIds] for the
///   finished opponent's uid while the Result screen is open.
/// * **Accept** = [MatchmakingRepository.claimPlayer]: the standard claim
///   transaction — a brand-new room, fresh seats (proposer hosts as Blue,
///   acceptor takes Red), both `matched` documents in the same commit.
/// * **Decline** = simply not claiming. A proposal also lapses on its own
///   through the queue's 60-second staleness window, or when the proposer
///   cancels. Navigating Home abandons the negotiation entirely.
///
/// Both players must act — one proposes, the other accepts — and the new
/// room's ordinary ready/start handshake is a further explicit step before
/// any game begins. No player is ever moved into a new match automatically.
///
/// One sharp edge from `memory.md`: a proposal entry is indistinguishable
/// in shape from an ordinary Quick Match queue entry, so a third player's
/// Quick Match *can* claim the proposer first. [start]'s match watcher
/// detects that outcome (the matched room's other seat is not the finished
/// opponent), leaves that room, and reports [RematchPhase.unavailable]
/// rather than dragging the proposer into a stranger's game.
class RematchController extends ChangeNotifier {
  RematchController({
    required this.matchmaking,
    required this.rooms,
    required this.myUid,
    required this.opponentUid,
    required this.config,
    required this.finishedCode,
    required this.finishedCreatedAtMs,
    this.pollInterval = const Duration(seconds: 3),
  });

  static const AppLogger _log = AppLogger('rematch');

  final MatchmakingRepository matchmaking;

  /// Used only to leave a room this player was wrongly claimed into.
  final RoomRepository rooms;

  final String myUid;
  final String opponentUid;
  final BoardConfig config;

  /// The room code of the match that just ended, and when it was created.
  ///
  /// Matched documents are never deleted, so a `matched` document can still
  /// name the finished match itself (when it came from Quick Match) or an
  /// older pairing. A genuine rematch room is a different code created
  /// after the finished match was; anything else the match watcher reports
  /// is history and is ignored.
  final String finishedCode;
  final int finishedCreatedAtMs;

  /// How often the queue is checked for the opponent's proposal while the
  /// Result screen is open. Injectable for tests.
  final Duration pollInterval;

  RematchPhase _phase = RematchPhase.idle;
  Room? _matchedRoom;
  String? _message;
  bool _started = false;
  bool _disposed = false;
  bool _dismissedProposal = false;
  Timer? _pollTimer;
  StreamSubscription<Room?>? _matchWatch;

  RematchPhase get phase => _phase;
  Room? get matchedRoom => _matchedRoom;
  String? get message => _message;

  /// Begins watching for the opponent's proposal and for a claim landing on
  /// this player. Call once, when the Result screen appears.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _matchWatch = matchmaking
        .watchForMatch(config: config, uid: myUid)
        .listen(_onMatchedRoom);
    unawaited(_poll());
    _pollTimer = Timer.periodic(pollInterval, (_) => unawaited(_poll()));
  }

  void _onMatchedRoom(Room? room) {
    if (_disposed || room == null || _phase == RematchPhase.matched) return;
    // History, not news: the finished match itself, or a pairing that
    // predates it. The repository already filters finished rooms out of
    // this stream; these guards cover the remaining stale shapes (a live
    // but abandoned waiting room from an earlier session).
    if (room.code == finishedCode || room.createdAtMs <= finishedCreatedAtMs) {
      return;
    }
    final seats = <String?>[room.blue.playerId, room.red.playerId];
    if (seats.contains(opponentUid) && seats.contains(myUid)) {
      _matchedRoom = room;
      _setPhase(RematchPhase.matched);
      _pollTimer?.cancel();
      return;
    }
    // Claimed by a third player's Quick Match while proposing: not the
    // rematch. Leave that room and say so plainly.
    if (_phase == RematchPhase.proposing) {
      unawaited(rooms.leave(room.code));
      _message =
          'Your proposal was picked up by another player\'s Quick Match, '
          'so the rematch did not happen.';
      _setPhase(RematchPhase.unavailable);
      _pollTimer?.cancel();
    }
  }

  Future<void> _poll() async {
    if (_disposed || _phase == RematchPhase.matched) return;
    final waiting = await matchmaking.waitingPlayerIds(config: config);
    if (_disposed || _phase == RematchPhase.matched) return;
    final opponentWaiting = waiting.contains(opponentUid);
    if (opponentWaiting &&
        _phase != RematchPhase.proposing &&
        !_dismissedProposal) {
      _setPhase(RematchPhase.proposalAvailable);
    } else if (!opponentWaiting && _phase == RematchPhase.proposalAvailable) {
      // The proposal was withdrawn or lapsed (60s staleness).
      _setPhase(RematchPhase.idle);
    }
  }

  /// Proposes a rematch: enters the queue claimable by the opponent.
  ///
  /// When the opponent is *already* waiting (both players proposed), the
  /// intent on both sides is unambiguous, so proposing accepts their
  /// proposal instead — the claim still requires this explicit tap.
  Future<void> propose() async {
    if (_disposed) return;
    if (_phase == RematchPhase.proposalAvailable) {
      await accept();
      return;
    }
    _dismissedProposal = false;
    _message = null;
    _setPhase(RematchPhase.proposing);
    await matchmaking.joinQueue(config: config);
    if (_disposed) return;
    // The opponent may have proposed in the meantime.
    unawaited(_poll());
  }

  /// Accepts the opponent's proposal by claiming their queue entry into a
  /// new room (this player takes Red; the proposer hosts as Blue).
  Future<void> accept() async {
    if (_disposed) return;
    final result = await matchmaking.claimPlayer(
      config: config,
      candidateUid: opponentUid,
    );
    if (_disposed) return;
    switch (result) {
      case MatchFound(:final room):
        if (room.code == finishedCode ||
            room.createdAtMs <= finishedCreatedAtMs) {
          // The repository handed back a pairing that predates the finished
          // match — history, not the rematch.
          _message = 'That pairing has expired. Propose a fresh rematch.';
          _setPhase(RematchPhase.idle);
          return;
        }
        _matchedRoom = room;
        _setPhase(RematchPhase.matched);
        _pollTimer?.cancel();
      case MatchQueued():
        // claimPlayer never queues; treat as a failed pairing defensively.
        _message = 'Could not complete the pairing. Please try again.';
        _setPhase(RematchPhase.idle);
      case MatchRejected(:final failure):
        _log.log('rematch claim rejected: ${failure.reason.name}');
        _message = failure.message ?? 'The rematch could not be started.';
        _setPhase(RematchPhase.idle);
    }
  }

  /// Declines the opponent's proposal. Nothing is written: not claiming is
  /// the decline, and the proposal lapses on its own. The dismissal is
  /// remembered so the same proposal does not keep re-appearing on this
  /// screen.
  void decline() {
    _dismissedProposal = true;
    if (_phase == RematchPhase.proposalAvailable) {
      _setPhase(RematchPhase.idle);
    }
  }

  /// Withdraws this player's own proposal.
  Future<void> cancelProposal() async {
    await matchmaking.cancel(config: config);
    if (_disposed) return;
    if (_phase == RematchPhase.proposing) _setPhase(RematchPhase.idle);
  }

  void _setPhase(RematchPhase phase) {
    if (_disposed) return;
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    unawaited(_matchWatch?.cancel());
    super.dispose();
  }
}
