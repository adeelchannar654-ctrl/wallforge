import 'package:flutter/material.dart';

import '../../../app/application/ai/ai_difficulty.dart';
import '../../../app/application/match_setup.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../domain/wallforge_domain.dart';
import '../../board/board.dart';
import '../../widgets/wallforge_logo.dart';
import '../../widgets/wallforge_wordmark.dart';

/// Board preview screen — replaces the Phase 0 shell.
///
/// Dev/preview screen; the real Stitch home is Phase 11.
/// Shows the board with controls for state selection, legal moves,
/// coordinates, and wall ghost demo.
class BoardPreviewScreen extends StatefulWidget {
  const BoardPreviewScreen({super.key});

  @override
  State<BoardPreviewScreen> createState() => _BoardPreviewScreenState();
}

class _BoardPreviewScreenState extends State<BoardPreviewScreen> {
  // --- State management ------------------------------------------------------

  GameState _state = GameState.initial();
  int _selectedPresetIndex = 0;
  bool _showLegalMoves = false;
  bool _showCoordinates = true;
  bool _showGhostWall = false;
  WallOrientation _ghostOrientation = WallOrientation.h;
  int _ghostAnchorRow = 0;
  int _ghostAnchorCol = 0;
  int _scriptedStep = 0;

  /// Phase 5: difficulty chosen for a match against the offline AI.
  AiDifficulty _aiDifficulty = AiDifficulty.easy;

  // --- Presets ---------------------------------------------------------------

  late final List<({String label, GameState state})> _presets;

  @override
  void initState() {
    super.initState();
    _presets = [
      (label: 'Initial 9×9', state: GameState.initial()),
      (
        label: 'Initial 7×7',
        state: GameState.initial(const BoardConfig(size: 7)),
      ),
      (
        label: 'Initial 5×5',
        state: GameState.initial(const BoardConfig(size: 5)),
      ),
      (
        label: 'Initial 11×11',
        state: GameState.initial(const BoardConfig(size: 11)),
      ),
      (label: 'Scripted Game', state: _buildScriptedGameState()),
      (label: 'Finished (Blue wins)', state: _buildFinishedState()),
      (label: 'Dense Walls', state: _buildDenseWallsState()),
    ];
  }

  // --- Scripted game state (step N of the 17-action game) --------------------

  GameState _buildScriptedGameState() {
    var state = GameState.initial();
    final actions = _scriptedActions;
    for (var i = 0; i <= _scriptedStep.clamp(0, actions.length - 1); i++) {
      final (player, action) = actions[i];
      final r = GameEngine.apply(state, player, action);
      if (r is SuccessResult) state = r.state;
    }
    return state;
  }

  static final List<(PlayerId, GameAction)> _scriptedActions = [
    (PlayerId.blue, const GameAction.move(Cell(row: 7, column: 4))),
    (PlayerId.red, const GameAction.move(Cell(row: 1, column: 4))),
    (PlayerId.blue, const GameAction.move(Cell(row: 6, column: 4))),
    (PlayerId.red, const GameAction.move(Cell(row: 2, column: 4))),
    (PlayerId.blue, const GameAction.move(Cell(row: 5, column: 4))),
    (
      PlayerId.red,
      const GameAction.wall(
        orientation: WallOrientation.v,
        anchor: Cell(row: 6, column: 3),
      ),
    ),
    (
      PlayerId.blue,
      const GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 6, column: 5),
      ),
    ),
    (PlayerId.red, const GameAction.move(Cell(row: 3, column: 4))),
    (PlayerId.blue, const GameAction.move(Cell(row: 4, column: 4))),
    (
      PlayerId.red,
      const GameAction.wall(
        orientation: WallOrientation.h,
        anchor: Cell(row: 1, column: 3),
      ),
    ),
    (PlayerId.blue, const GameAction.move(Cell(row: 2, column: 4))),
    (PlayerId.red, const GameAction.move(Cell(row: 4, column: 4))),
    (PlayerId.blue, const GameAction.move(Cell(row: 2, column: 5))),
    (PlayerId.red, const GameAction.move(Cell(row: 5, column: 4))),
    (PlayerId.blue, const GameAction.move(Cell(row: 1, column: 5))),
    (PlayerId.red, const GameAction.move(Cell(row: 6, column: 4))),
    (PlayerId.blue, const GameAction.move(Cell(row: 0, column: 5))),
  ];

  // --- Pre-built states ------------------------------------------------------

  static GameState _buildFinishedState() {
    var state = GameState.initial();
    for (final (player, action) in _scriptedActions) {
      final r = GameEngine.apply(state, player, action);
      if (r is SuccessResult) state = r.state;
    }
    return state;
  }

  static GameState _buildDenseWallsState() {
    var state = GameState.initial();
    // Place walls for both sides until dense.
    final wallActions = <(PlayerId, GameAction)>[
      (
        PlayerId.blue,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 4, column: 0),
        ),
      ),
      (
        PlayerId.red,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 4, column: 2),
        ),
      ),
      (
        PlayerId.blue,
        const GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 3, column: 4),
        ),
      ),
      (
        PlayerId.red,
        const GameAction.wall(
          orientation: WallOrientation.v,
          anchor: Cell(row: 3, column: 5),
        ),
      ),
      (
        PlayerId.blue,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 6, column: 5),
        ),
      ),
      (
        PlayerId.red,
        const GameAction.wall(
          orientation: WallOrientation.h,
          anchor: Cell(row: 2, column: 5),
        ),
      ),
    ];
    for (final (player, action) in wallActions) {
      final r = GameEngine.apply(state, player, action);
      if (r is SuccessResult) state = r.state;
    }
    // Move pawns into the scene.
    final moveActions = <(PlayerId, GameAction)>[
      (PlayerId.blue, const GameAction.move(Cell(row: 7, column: 4))),
      (PlayerId.red, const GameAction.move(Cell(row: 1, column: 4))),
      (PlayerId.blue, const GameAction.move(Cell(row: 6, column: 4))),
      (PlayerId.red, const GameAction.move(Cell(row: 2, column: 4))),
    ];
    for (final (player, action) in moveActions) {
      final r = GameEngine.apply(state, player, action);
      if (r is SuccessResult) state = r.state;
    }
    return state;
  }

  // --- Legal move targets ----------------------------------------------------

  Set<Cell> get _legalTargets {
    if (!_showLegalMoves) return {};
    return GameEngine.legalActions(_state)
        .whereType<MoveAction>()
        .map((a) => a.destination)
        .toSet();
  }

  // --- Ghost wall validity ---------------------------------------------------

  bool get _ghostIsValid {
    if (!_showGhostWall) return false;
    final action = GameAction.wall(
      orientation: _ghostOrientation,
      anchor: Cell(row: _ghostAnchorRow, column: _ghostAnchorCol),
    );
    final result = GameEngine.apply(_state, _state.currentPlayer, action);
    return result is SuccessResult;
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              // --- Logo & wordmark ---
              const WallforgeLogo(size: 64),
              const SizedBox(height: AppSpacing.sm),
              const WallforgeWordmark(fontSize: 28),
              const SizedBox(height: AppSpacing.lg),

              // --- Board ---
              Center(
                child: BoardView(
                  state: _state,
                  legalMoveTargets: _legalTargets,
                  wallPreview: _showGhostWall
                      ? WallPreview(
                          anchor: Cell(
                            row: _ghostAnchorRow,
                            column: _ghostAnchorCol,
                          ),
                          orientation: _ghostOrientation,
                          isValid: _ghostIsValid,
                        )
                      : null,
                  showCoordinates: _showCoordinates,
                  activeGlow: _state.status == GameStatus.inProgress
                      ? _state.currentPlayer
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // --- Start local match button ---
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.game, arguments: _state.boardConfig);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'START LOCAL MATCH',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // --- Start versus AI (Phase 5) ---
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.game,
                      arguments: MatchSetup.versusAi(
                        _state.boardConfig,
                        _aiDifficulty,
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primaryContainer,
                    foregroundColor: AppColors.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'START VS AI',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildAiDifficultySelector(),
              const SizedBox(height: AppSpacing.lg),

              // --- Status ---
              _buildStatus(),
              const SizedBox(height: AppSpacing.md),

              // --- Preset selector ---
              _buildPresetSelector(),
              const SizedBox(height: AppSpacing.md),

              // --- Scripted step slider ---
              if (_selectedPresetIndex == 4) ...[
                _buildScriptedSlider(),
                const SizedBox(height: AppSpacing.md),
              ],

              // --- Toggles ---
              _buildToggles(),
              const SizedBox(height: AppSpacing.md),

              // --- Ghost wall demo ---
              _buildGhostWallDemo(),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  /// Phase 5 AI difficulty picker.
  ///
  /// `design.md` §20 requires the four difficulty options and a brief honest
  /// explanation, and explicitly forbids "perfect AI" style claims, so the
  /// description shown is the one carried by [AiDifficulty] itself. No new
  /// visual language: this reuses the same segmented-button shape, tokens and
  /// caption style as the rest of the screen.
  Widget _buildAiDifficultySelector() {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final difficulty in AiDifficulty.values)
              ChoiceChip(
                label: Text(difficulty.label),
                selected: _aiDifficulty == difficulty,
                onSelected: (_) => setState(() => _aiDifficulty = difficulty),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _aiDifficulty.description,
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatus() {
    final blue = _state.pawnPosition(PlayerId.blue);
    final red = _state.pawnPosition(PlayerId.red);
    final size = _state.boardConfig.size;
    final blueLabel =
        '${String.fromCharCode(0x61 + blue.column)}${size - blue.row}';
    final redLabel =
        '${String.fromCharCode(0x61 + red.column)}${size - red.row}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            _state.status == GameStatus.finished
                ? 'GAME OVER — ${_state.winner?.name.toUpperCase()} WINS'
                : 'TURN ${_state.turnNumber} — ${_state.currentPlayer.name.toUpperCase()}',
            style: AppTypography.labelCaps.copyWith(
              color: _state.status == GameStatus.finished
                  ? AppColors.tertiary
                  : _state.currentPlayer == PlayerId.blue
                  ? AppColors.primaryContainer
                  : AppColors.secondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Blue $blueLabel (${_state.wallsRemaining(PlayerId.blue)}W)  •  '
            'Red $redLabel (${_state.wallsRemaining(PlayerId.red)}W)',
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetSelector() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < _presets.length; i++)
          ChoiceChip(
            label: Text(_presets[i].label),
            selected: _selectedPresetIndex == i,
            onSelected: (_) => _selectPreset(i),
            selectedColor: AppColors.primaryContainer.withValues(alpha: 0.2),
            labelStyle: AppTypography.labelCaps.copyWith(
              color: _selectedPresetIndex == i
                  ? AppColors.primaryContainer
                  : AppColors.onSurfaceVariant,
            ),
            side: BorderSide(
              color: _selectedPresetIndex == i
                  ? AppColors.primaryContainer
                  : AppColors.outlineVariant,
            ),
          ),
      ],
    );
  }

  void _selectPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      if (index == 4) {
        // Scripted game — use current step.
        _state = _buildScriptedGameState();
      } else {
        _state = _presets[index].state;
        _scriptedStep = 0;
      }
      _showGhostWall = false;
    });
  }

  Widget _buildScriptedSlider() {
    return Column(
      children: [
        Text(
          'Step $_scriptedStep / ${_scriptedActions.length}',
          style: AppTypography.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        Slider(
          value: _scriptedStep.toDouble(),
          max: _scriptedActions.length.toDouble(),
          divisions: _scriptedActions.length,
          activeColor: AppColors.primaryContainer,
          onChanged: (v) {
            setState(() {
              _scriptedStep = v.round();
              _state = _buildScriptedGameState();
            });
          },
        ),
      ],
    );
  }

  Widget _buildToggles() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _buildToggle('Legal Moves', _showLegalMoves, (v) {
          setState(() => _showLegalMoves = v);
        }),
        _buildToggle('Coordinates', _showCoordinates, (v) {
          setState(() => _showCoordinates = v);
        }),
        _buildToggle('Ghost Wall', _showGhostWall, (v) {
          setState(() => _showGhostWall = v);
        }),
      ],
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: AppColors.primaryContainer.withValues(alpha: 0.2),
      labelStyle: AppTypography.labelCaps.copyWith(
        color: value ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
      ),
      side: BorderSide(
        color: value ? AppColors.primaryContainer : AppColors.outlineVariant,
      ),
    );
  }

  Widget _buildGhostWallDemo() {
    if (!_showGhostWall) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            'GHOST WALL DEMO',
            style: AppTypography.labelCaps.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Orientation toggle
              IconButton(
                icon: Icon(
                  _ghostOrientation == WallOrientation.h
                      ? Icons.swap_horiz
                      : Icons.swap_vert,
                  color: AppColors.primaryContainer,
                ),
                onPressed: () {
                  setState(() {
                    _ghostOrientation = _ghostOrientation == WallOrientation.h
                        ? WallOrientation.v
                        : WallOrientation.h;
                  });
                },
              ),
              const SizedBox(width: AppSpacing.md),
              // Anchor controls
              _buildAnchorControl(
                'Row',
                _ghostAnchorRow,
                _state.boardConfig.maxAnchor,
                (v) => setState(() => _ghostAnchorRow = v),
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildAnchorControl(
                'Col',
                _ghostAnchorCol,
                _state.boardConfig.maxAnchor,
                (v) => setState(() => _ghostAnchorCol = v),
              ),
              const SizedBox(width: AppSpacing.md),
              // Validity indicator
              Icon(
                _ghostIsValid ? Icons.check_circle : Icons.cancel,
                color: _ghostIsValid
                    ? AppColors.primaryContainer
                    : AppColors.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnchorControl(
    String label,
    int value,
    int max,
    ValueChanged<int> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label:',
          style: AppTypography.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        IconButton(
          iconSize: 16,
          icon: const Icon(Icons.remove, color: AppColors.onSurfaceVariant),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.numericStat.copyWith(
              fontSize: 14,
              color: AppColors.onSurface,
            ),
          ),
        ),
        IconButton(
          iconSize: 16,
          icon: const Icon(Icons.add, color: AppColors.onSurfaceVariant),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
