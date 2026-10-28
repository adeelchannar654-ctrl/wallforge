import 'package:flutter/material.dart';

import '../../../app/application/game_interaction.dart';
import '../../../app/application/local_game_controller.dart';
import '../../../core/feedback/feedback_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_settings_repository.dart';
import '../../../domain/models/board_config.dart';
import '../../../domain/models/cell.dart';
import '../../../domain/models/game_state.dart';
import '../../../domain/models/game_status.dart';
import '../../../domain/models/player_id.dart';
import '../../../domain/models/wall.dart';
import '../../../domain/models/wall_orientation.dart';
import '../../../domain/repositories/repositories.dart';
import '../../board/board.dart';
import '../../widgets/app_chrome.dart';

/// The guided tutorial (`design.md` §22 + `PRD.md` §6.7).
///
/// §22's requirements are: use the real board, teach one concept at a time,
/// and let the player skip and revisit. Its sequence is labelled an
/// *example* (Goal → Move → Wall → Block → Race); `PRD.md` §6.7 lists the
/// concepts (Goal, Movement, Wall placement, Limited wall inventory,
/// Winning). The five steps below follow both: the limited-inventory
/// concept is taught inside the Wall step, and Winning closes the Race
/// step. All step copy is this phase's own (no source text exists —
/// recorded in `memory.md` §13s).
///
/// Every step's board is a real [GameState] driven by the real engine
/// through a [LocalGameController] — the Move and Wall steps advance only
/// when the learner actually performs the action, exactly as §22's "use
/// the real board" demands. Nothing is simulated.
///
/// Finishing or skipping records `AppSettings.tutorialCompleted` (the
/// Phase 6 reserved flag): its meaning is "the first-run offer has been
/// resolved" — Home stops promoting the tutorial, and it stays replayable
/// from Home and Settings either way.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    this.settingsRepository = const SharedPreferencesSettingsRepository(),
  });

  final SettingsRepository settingsRepository;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

/// One tutorial step: its copy and the position it teaches from.
class _Step {
  const _Step({
    required this.title,
    required this.body,
    required this.state,
    this.interaction,
  });

  final String title;
  final String body;
  final GameState state;

  /// What the learner must do to complete the step, or null for a
  /// read-and-continue step.
  final _Interaction? interaction;
}

enum _Interaction { move, wall }

class _TutorialScreenState extends State<TutorialScreen> {
  static const BoardConfig _config = BoardConfig(size: 5);

  late final List<_Step> _steps = _buildSteps();
  int _index = 0;
  LocalGameController? _controller;
  bool _stepComplete = false;

  _Step get _step => _steps[_index];

  @override
  void initState() {
    super.initState();
    _enterStep(0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<_Step> _buildSteps() {
    GameState at({
      required Cell blue,
      required Cell red,
      List<Wall> walls = const [],
      int turnNumber = 0,
    }) {
      return GameState(
        boardConfig: _config,
        pawnPositions: {PlayerId.blue: blue, PlayerId.red: red},
        walls: walls,
        remainingWalls: {
          PlayerId.blue: _config.wallsPerPlayer,
          PlayerId.red: _config.wallsPerPlayer,
        },
        turnNumber: turnNumber,
        status: GameStatus.inProgress,
      );
    }

    return [
      _Step(
        title: 'Reach the far row',
        body:
            'You are Blue. Your pawn starts at the bottom of the board. '
            'Get it onto the green row at the top before Red reaches the '
            'bottom row.',
        state: GameState.initial(_config),
      ),
      _Step(
        title: 'Move your pawn',
        body:
            'On your turn you can move your pawn one square up, down, left '
            'or right. Tap a highlighted square next to your pawn.',
        state: at(
          blue: const Cell(row: 3, column: 2),
          red: const Cell(row: 0, column: 0),
        ),
        interaction: _Interaction.move,
      ),
      _Step(
        title: 'Place a wall',
        body:
            'Instead of moving, you can place a wall to slow Red down. '
            'Tap a slot between squares to stage a wall, then confirm it. '
            'You have ${_config.wallsPerPlayer} walls — once placed, a '
            'wall stays for the whole game.',
        state: at(
          blue: const Cell(row: 4, column: 2),
          red: const Cell(row: 0, column: 2),
        ),
        interaction: _Interaction.wall,
      ),
      _Step(
        title: 'Walls can block — never seal',
        body:
            'A wall can cut off the direct route, like the one in front of '
            'Red here. But a wall may never close off every path: there '
            'must always be a way through, for both players.',
        state: at(
          blue: const Cell(row: 4, column: 2),
          red: const Cell(row: 1, column: 2),
          walls: const [
            Wall(
              anchorRow: 1,
              anchorColumn: 1,
              orientation: WallOrientation.h,
              owner: PlayerId.blue,
            ),
          ],
        ),
      ),
      _Step(
        title: 'First to the far row wins',
        body:
            'Wallforge is a race. Move when the path is clear, spend walls '
            'when they buy you time, and remember yours are limited. '
            'First pawn to the far row wins the game.',
        state: at(
          blue: const Cell(row: 1, column: 2),
          red: const Cell(row: 3, column: 2),
          turnNumber: 8,
        ),
      ),
    ];
  }

  void _enterStep(int index) {
    _controller?.dispose();
    _controller = null;
    _index = index;
    _stepComplete = _step.interaction == null;
    final state = _step.state;
    final controller = LocalGameController(config: _config);
    // Phase 12: the tutorial plays on the real board through the real
    // controller, so its moves carry the same feedback as a match's.
    // (The shared instance, not the scope: this runs from initState,
    // where inherited-widget lookups are not yet allowed.)
    controller.feedback = FeedbackService.shared;
    // Adopt the prepared position through the same validated path a
    // resumed match takes.
    controller.resumeMatch(
      UnfinishedMatch(
        gameState: state,
        boardSize: _config.size,
        versusAi: false,
        aiDifficulty: 'local',
        savedAtTurn: state.turnNumber,
      ),
    );
    if (_step.interaction == _Interaction.wall) {
      controller.setMode(InteractionMode.wall);
    }
    controller.addListener(_onControllerChanged);
    _controller = controller;
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;
    var complete = _stepComplete;
    switch (_step.interaction) {
      case _Interaction.move:
        complete =
            controller.state.pawnPosition(PlayerId.blue) !=
            _step.state.pawnPosition(PlayerId.blue);
      case _Interaction.wall:
        complete = controller.state.walls.isNotEmpty;
      case null:
        complete = true;
    }
    setState(() => _stepComplete = complete);
  }

  /// Completing and skipping land in the same place: the flag records that
  /// the first-run offer has been resolved (see the class doc).
  Future<void> _finish() async {
    final settings = await widget.settingsRepository.load();
    await widget.settingsRepository.save(
      settings.copyWith(tutorialCompleted: true),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _next() {
    if (_index >= _steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _enterStep(_index + 1));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isLast = _index == _steps.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Tutorial'),
        actions: [
          TextButton(onPressed: _finish, child: const Text('SKIP TUTORIAL')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (_index + 1) / _steps.length,
                      color: AppColors.primaryContainer,
                      backgroundColor: AppColors.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Step ${_index + 1} of ${_steps.length}',
                    style: AppTypography.bodyBase.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // Phase 13: step changes are announced to assistive
              // technology as they happen.
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_step.title, style: AppTypography.headlineLg),
                    const SizedBox(height: AppSpacing.sm),
                    Text(_step.body, style: AppTypography.bodyBase),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (controller != null) ...[
                Center(
                  child: SizedBox(
                    width: 300,
                    height: 300,
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => BoardView(
                        state: controller.state,
                        legalMoveTargets: controller.legalMoveTargets,
                        wallPreview: controller.pendingWall != null
                            ? WallPreview(
                                anchor: controller.pendingWall!.anchor,
                                orientation:
                                    controller.pendingWall!.orientation,
                                isValid: controller.pendingWallFailure == null,
                              )
                            : null,
                        onCellTap: _step.interaction == _Interaction.move
                            ? controller.tapCell
                            : null,
                        onWallSlotTap: _step.interaction == _Interaction.wall
                            ? controller.tapWallSlot
                            : null,
                      ),
                    ),
                  ),
                ),
                if (_step.interaction != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildInteractionControls(controller),
                ],
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryActionButton(
                label: isLast ? 'FINISH' : 'NEXT',
                icon: isLast ? Icons.check : Icons.arrow_forward,
                onPressed: _stepComplete ? _next : null,
              ),
              if (!_stepComplete)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    _step.interaction == _Interaction.move
                        ? 'Make the move to continue.'
                        : 'Place a wall to continue.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyBase.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractionControls(LocalGameController controller) {
    if (_step.interaction == _Interaction.wall &&
        controller.pendingWall != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: controller.cancel, child: const Text('CANCEL')),
          const SizedBox(width: AppSpacing.md),
          FilledButton(
            onPressed: controller.pendingWallFailure == null
                ? controller.confirm
                : null,
            child: const Text('CONFIRM'),
          ),
        ],
      );
    }
    if (_step.interaction == _Interaction.wall) {
      return Text(
        'WALL mode — tap a slot between squares.',
        textAlign: TextAlign.center,
        style: AppTypography.bodyBase.copyWith(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
