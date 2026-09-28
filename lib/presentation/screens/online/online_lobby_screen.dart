import 'package:flutter/material.dart';

import '../../../app/application/online/online_game_controller.dart';
import '../../../app/application/online/online_lobby_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/wallforge_domain.dart';
import 'online_game_screen.dart';

/// Online lobby: choose create or join, then the shared room.
///
/// ## Design source
///
/// `design.md` §19 specifies this screen's contents: create match, join match,
/// room code, opponent status, connection state. It names no visual treatment
/// for a lobby, so — following the pattern Phase 5 set for the AI selector and
/// Phase 4 for placement feedback — this reuses the existing tokens and component
/// shapes rather than inventing a new visual language. Tracked as Q-8.5.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({
    super.key,
    required this.controller,
    this.ownsController = false,
  });

  /// The lobby to render.
  final OnlineLobbyController controller;

  /// Whether this widget disposes [controller] when the route is popped.
  ///
  /// The route sets this because it built the controller; a test that injects a
  /// controller and asserts on it afterwards leaves ownership to itself. Without
  /// the flag the controller's room subscription would outlive the screen.
  final bool ownsController;

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  final TextEditingController _codeField = TextEditingController();
  String? _joinError;

  @override
  void initState() {
    super.initState();
    // Signing in is automatic, because anonymous auth exists precisely to remove
    // friction (`rules.md` §6 "low-friction"). Without this the lobby would sit
    // in `needsSignIn` with no way out: `createRoom` and `joinRoom` both refuse
    // without a uid, so the screen would be unusable.
    //
    // A failure is not fatal — the controller reports it and the screen shows the
    // message, so an offline or unconfigured build still explains itself.
    if (widget.controller.phase == OnlineLobbyPhase.needsSignIn &&
        widget.controller.uid == null) {
      widget.controller.signIn();
    }
  }

  @override
  void dispose() {
    _codeField.dispose();
    if (widget.ownsController) widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.onSurface,
            title: const Text('ONLINE PLAY', style: AppTypography.labelCaps),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildStatusLine(controller),
                  const SizedBox(height: AppSpacing.lg),
                  if (!controller.isInRoom)
                    ..._buildEntry(controller)
                  else
                    ..._buildRoom(controller),
                  if (controller.phase == OnlineLobbyPhase.searching &&
                      !controller.isInRoom) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildSearching(context, controller),
                  ],
                  if (controller.failureMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildError(controller.failureMessage!),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _cancel(context, controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Status ----------------------------------------------------------------

  /// `design.md` §19's connection states, using only the ones this phase can
  /// actually observe. See `OnlineLobbyPhase` for what is deliberately missing.
  ///
  /// These are the only status words on the screen, so a player is never left
  /// wondering whether "WAITING" describes them or the empty seat.
  Widget _buildStatusLine(OnlineLobbyController controller) {
    final (label, color) = switch (controller.phase) {
      OnlineLobbyPhase.needsSignIn => (
        'NOT SIGNED IN',
        AppColors.textSecondary,
      ),
      OnlineLobbyPhase.busy => ('CONNECTING', AppColors.textSecondary),
      OnlineLobbyPhase.idle => (
        controller.uid == null ? 'READY' : 'CONNECTED',
        AppColors.primaryContainer,
      ),
      OnlineLobbyPhase.waiting => ('WAITING', AppColors.textSecondary),
      OnlineLobbyPhase.ready => ('CONNECTED', AppColors.primaryContainer),
      OnlineLobbyPhase.searching => ('SEARCHING', AppColors.textSecondary),
      OnlineLobbyPhase.started => ('CONNECTED', AppColors.tertiaryContainer),
      OnlineLobbyPhase.failed => ('DISCONNECTED', AppColors.error),
    };
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: AppTypography.labelCaps.copyWith(color: color)),
      ],
    );
  }

  // --- Entry: create or join --------------------------------------------------

  List<Widget> _buildEntry(OnlineLobbyController controller) {
    final board = controller.boardConfig;
    return <Widget>[
      if (controller.hasMatchmaking)
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('QUICK MATCH', style: AppTypography.labelCaps),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Get paired with someone else automatically. No room code '
                'needed — a ${board.size}x${board.size} board.',
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _primaryButton(
                label: 'FIND OPPONENT',
                onPressed: controller.isBusy ? null : controller.quickMatch,
              ),
            ],
          ),
        ),
      if (controller.hasMatchmaking) const SizedBox(height: AppSpacing.md),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('CREATE A ROOM', style: AppTypography.labelCaps),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You play Blue and share a ${board.size}x${board.size} board. '
              'Give the code to your opponent.',
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _primaryButton(
              label: controller.isBusy ? 'WORKING' : 'CREATE ROOM',
              onPressed: controller.isBusy ? null : controller.createRoom,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('JOIN A ROOM', style: AppTypography.labelCaps),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Enter the ${RoomCode.length}-character code your opponent '
              'created.',
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _codeField,
              textCapitalization: TextCapitalization.characters,
              maxLength: RoomCode.length,
              style: AppTypography.numericStat.copyWith(
                color: AppColors.onSurface,
                letterSpacing: 4,
              ),
              decoration: InputDecoration(
                hintText: 'ABC123',
                hintStyle: AppTypography.numericStat.copyWith(
                  color: AppColors.outline,
                  letterSpacing: 4,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
              ),
              onChanged: (_) => setState(() => _joinError = null),
            ),
            if (_joinError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  _joinError!,
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            _primaryButton(
              label: 'JOIN ROOM',
              onPressed: controller.isBusy ? null : _join,
            ),
          ],
        ),
      ),
    ];
  }

  /// Opens the online match for a started room.
  ///
  /// The match controller is built here so the lobby keeps ownership of its uid
  /// and repositories, and so a failed connection cannot leave a half-built
  /// screen on the stack.
  Future<void> _enterMatch(
    BuildContext context,
    OnlineLobbyController controller,
    Room room,
  ) async {
    final match = OnlineGameController(
      rooms: controller.roomsRepository!,
      matches: controller.matchRepository!,
      uid: controller.uid!,
      code: room.code,
    );
    await match.connect();
    if (!context.mounted) {
      match.dispose();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OnlineGameScreen(controller: match, ownsController: true),
      ),
    );
  }

  /// The matchmaking waiting state, with a cancel action.
  Widget _buildSearching(
    BuildContext context,
    OnlineLobbyController controller,
  ) => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('LOOKING FOR AN OPPONENT', style: AppTypography.labelCaps),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Waiting for someone else to pick Quick Match on a '
          '${controller.boardConfig.size}x${controller.boardConfig.size} '
          'board. This does not poll — you are notified the moment you are '
          'paired.',
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _primaryButton(
          label: 'CANCEL',
          onPressed: () => controller.cancelQuickMatch(),
        ),
      ],
    ),
  );

  Future<void> _join() async {
    final code = _codeField.text;
    // Checked here as well as in the controller so the field can show the
    // problem next to the field the player is looking at.
    if (!RoomCode.isValid(code)) {
      setState(
        () => _joinError = 'Room codes are ${RoomCode.length} characters.',
      );
      return;
    }
    await widget.controller.joinRoom(code);
  }

  // --- Room ------------------------------------------------------------------

  List<Widget> _buildRoom(OnlineLobbyController controller) {
    final room = controller.room!;
    return <Widget>[
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('ROOM CODE', style: AppTypography.labelCaps),
            const SizedBox(height: AppSpacing.xs),
            // Large and spaced, because this is the one value a player copies.
            Text(
              room.code,
              textAlign: TextAlign.center,
              style: AppTypography.displayMd.copyWith(
                color: AppColors.primaryContainer,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${room.boardConfig.size}x${room.boardConfig.size} board',
              textAlign: TextAlign.center,
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('PLAYERS', style: AppTypography.labelCaps),
            const SizedBox(height: AppSpacing.sm),
            _playerRow(
              'BLUE',
              AppColors.bluePlayer,
              isYou: controller.mySide == PlayerId.blue,
              isReady: room.blue.isReady,
              isEmpty: room.blue.isEmpty,
            ),
            const SizedBox(height: AppSpacing.sm),
            _playerRow(
              'RED',
              AppColors.redPlayer,
              isYou: controller.mySide == PlayerId.red,
              isReady: room.red.isReady,
              isEmpty: room.red.isEmpty,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      // Ready-up is always available to a seated player, including after the
      // opponent arrives — an earlier version hid it once the room filled, which
      // made it impossible to ready up at all.
      if (!controller.hasStarted) ...<Widget>[
        _primaryButton(
          label: controller.amReady ? 'UNREADY' : 'READY UP',
          onPressed: controller.toggleReady,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Only the host may start, so only the host is offered the action; a
        // guest sees a neutral line instead of a button that would be refused.
        if (controller.amHost)
          _primaryButton(
            label: controller.canStart ? 'START MATCH' : 'WAITING FOR READY',
            onPressed: controller.canStart ? controller.startMatch : null,
          )
        else
          _hint(controller.bothReady ? 'Waiting for the host to start.' : null),
      ],
      if (controller.hasStarted) ...[
        const SizedBox(height: AppSpacing.md),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('MATCH STARTED', style: AppTypography.labelCaps),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You play ${controller.mySide?.name.toUpperCase()}. '
                'Turns are synchronised between devices.',
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _primaryButton(
                label: 'PLAY',
                onPressed: () => _enterMatch(context, controller, room),
              ),
            ],
          ),
        ),
      ],
    ];
  }

  Widget _playerRow(
    String label,
    Color color, {
    required bool isYou,
    required bool isReady,
    required bool isEmpty,
  }) {
    // An empty seat reads as a dash rather than "WAITING", which is reserved for
    // the connection state above.
    final status = isEmpty
        ? '—'
        : isReady
        ? 'READY'
        : 'NOT READY';
    return Row(
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isEmpty ? AppColors.outlineVariant : color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.labelCaps),
        const SizedBox(width: AppSpacing.xs),
        if (isYou)
          Text(
            '(YOU)',
            style: AppTypography.labelCaps.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        const Spacer(),
        Text(
          status,
          style: AppTypography.labelCaps.copyWith(
            color: isEmpty
                ? AppColors.textSecondary
                : isReady
                ? AppColors.tertiaryContainer
                : AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // --- Shared ----------------------------------------------------------------

  Widget _cancel(BuildContext context, OnlineLobbyController controller) =>
      OutlinedButton(
        onPressed: () {
          if (controller.isInRoom) {
            controller.leaveRoom();
          } else {
            Navigator.of(context).maybePop();
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
        child: Text(
          controller.isInRoom ? 'LEAVE ROOM' : 'BACK',
          style: AppTypography.labelCaps,
        ),
      );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadii.md),
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: child,
  );

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.onPrimaryContainer,
      disabledBackgroundColor: AppColors.surfaceContainerHighest,
      disabledForegroundColor: AppColors.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    ),
    child: Text(
      label,
      style: AppTypography.labelCaps.copyWith(
        color: onPressed == null
            ? AppColors.onSurfaceVariant
            : AppColors.onPrimaryContainer,
      ),
    ),
  );

  Widget _hint(String? message) => message == null
      ? const SizedBox.shrink()
      : Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        );

  Widget _buildError(String message) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.errorContainer.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(AppRadii.sm),
      border: Border.all(color: AppColors.error),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.error_outline, color: AppColors.error, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: AppTypography.bodyBase.copyWith(color: AppColors.error),
          ),
        ),
      ],
    ),
  );
}
