import 'package:flutter/material.dart';

import '../../../app/theme/app_breakpoints.dart';

import '../../../app/router/app_router.dart';
import '../../../core/feedback/feedback_scope.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_settings_repository.dart';
import '../../../data/remote/firebase_auth_gateway.dart';
import '../../../domain/repositories/repositories.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/responsive_content.dart';

/// The Settings screen (`design.md` §23), with the honesty boundary §23
/// and the phase plan require:
///
/// * **Gameplay is real.** Confirm wall placement is the persisted Phase 6
///   setting — the same store the game HUD toggle writes, so the two never
///   disagree. Movement assistance is the Phase 11 feature §23 lists:
///   while Move is selected, the board draws the current player's shortest
///   route to their goal.
/// * **Audio and Haptics are real (Phase 12).** Music, Sound effects,
///   Volume and Haptic feedback are live controls over the feedback
///   layer: every save is applied to it immediately, not just persisted.
/// * **Reduced motion is real (Phase 12)** — the recorded cross-document
///   correction (`memory.md` §13t): `phase.md`'s Phase 12 task list names
///   reduced-motion mode itself, and it controls the animation system
///   Phase 12 builds, so it could not wait for Phase 13.
/// * **Accessibility is fully real (Phase 13).** Color assistance, High
///   contrast and UI scale are live controls: every save is applied by
///   the app root in the same moment it is persisted — the palette swap
///   and the text scale take effect app-wide, this screen included.
/// * **Account is real**: the anonymous sign-in state, and Sign out through
///   the Phase 8 auth gateway.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.settingsRepository = const SharedPreferencesSettingsRepository(),
    this.authGateway,
  });

  final SettingsRepository settingsRepository;
  final AuthGateway? authGateway;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = AppSettings.defaults;
  AuthState _authState = const AuthState.signedOut();
  bool _loaded = false;

  AuthGateway get _auth => widget.authGateway ?? FirebaseAuthGateway();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.settingsRepository.load();
    final auth = await _auth.current();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _authState = auth;
      _loaded = true;
    });
  }

  Future<void> _save(AppSettings next) async {
    setState(() => _settings = next);
    // Phase 12: the feedback layer gates live behaviour, so a save is
    // applied to it in the same moment it is persisted.
    FeedbackScope.maybeOf(context)?.applySettings(next);
    await widget.settingsRepository.save(next);
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _settingsGroups();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        // Phase 14: capped and centered on tablet; two group columns
        // on desktop (see _settingsGroups).
        child: ResponsiveContent(
          desktopMaxWidth: 1120,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (AppBreakpoints.of(context).isDesktop)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            groups[0],
                            const SizedBox(height: AppSpacing.lg),
                            groups[1],
                            const SizedBox(height: AppSpacing.lg),
                            groups[2],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          children: [
                            groups[3],
                            const SizedBox(height: AppSpacing.lg),
                            groups[4],
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  for (var i = 0; i < groups.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.lg),
                    groups[i],
                  ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The five settings groups, built once and arranged per tier by
  /// [build] (Phase 14): a single column on phone and tablet; two
  /// columns on desktop (GAMEPLAY/AUDIO/HAPTICS left,
  /// ACCESSIBILITY/ACCOUNT right).
  List<Widget> _settingsGroups() => <Widget>[
    _group(
      'GAMEPLAY',
      children: [
        _toggleRow(
          label: 'Confirm wall placement',
          description: 'Ask for confirmation before a wall is placed.',
          value: _settings.confirmWallPlacement,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(confirmWallPlacement: v))
              : null,
        ),
        Divider(color: AppColors.outlineVariant),
        _toggleRow(
          label: 'Movement assistance',
          description:
              'Show the shortest route to the goal while Move '
              'is selected.',
          value: _settings.movementAssistance,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(movementAssistance: v))
              : null,
        ),
        Divider(color: AppColors.outlineVariant),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tutorial', style: AppTypography.bodyBase),
                  Text(
                    'Replay the guided tour.',
                    style: AppTypography.bodyBase.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.tutorial),
              child: const Text('REPLAY'),
            ),
          ],
        ),
      ],
    ),
    _group(
      'AUDIO',
      children: [
        _toggleRow(
          label: 'Music',
          description: 'Background music while you play.',
          value: _settings.musicEnabled,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(musicEnabled: v))
              : null,
        ),
        Divider(color: AppColors.outlineVariant),
        _toggleRow(
          label: 'Sound effects',
          description: 'Sounds for moves, walls and results.',
          value: _settings.effectsEnabled,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(effectsEnabled: v))
              : null,
        ),
        Divider(color: AppColors.outlineVariant),
        _volumeRow(),
      ],
    ),
    _group(
      'HAPTICS',
      children: [
        _toggleRow(
          label: 'Haptic feedback',
          description:
              'Subtle vibration on game actions. '
              'Off while reduced motion is on.',
          value: _settings.hapticsEnabled,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(hapticsEnabled: v))
              : null,
        ),
      ],
    ),
    _group(
      'ACCESSIBILITY',
      children: [
        _toggleRow(
          label: 'Reduced motion',
          description:
              'Animations jump straight to their end state. '
              'Combines with your device\'s reduce-motion '
              'setting — either one turns it on.',
          value: _settings.reducedMotion,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(reducedMotion: v))
              : null,
        ),
        Divider(color: AppColors.outlineVariant),
        _toggleRow(
          label: 'Color assistance',
          description:
              'Player colours switch to a colour-blind-safe '
              'blue and orange on the board and player chips.',
          value: _settings.colorAssistance,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(colorAssistance: v))
              : null,
        ),
        Divider(color: AppColors.outlineVariant),
        _toggleRow(
          label: 'High contrast',
          description:
              'Black surfaces with brighter text and borders, '
              'applied across the whole app.',
          value: _settings.highContrast,
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(highContrast: v))
              : null,
        ),
        Divider(color: AppColors.outlineVariant),
        _uiScaleRow(),
        Divider(color: AppColors.outlineVariant),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'Player identity is never shown by colour alone: '
            'pawns always carry their B and R letters.',
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
    _group(
      'ACCOUNT',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account information', style: AppTypography.bodyBase),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _authState.isSignedIn
                  ? 'Signed in anonymously (Guest). No email or '
                        'password is attached to this account.'
                  : 'Not signed in. Online play signs you in '
                        'anonymously.',
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        if (_authState.isSignedIn) ...[
          const SizedBox(height: AppSpacing.md),
          SecondaryActionButton(
            label: 'SIGN OUT',
            icon: Icons.logout,
            onPressed: _signOut,
          ),
        ],
      ],
    ),
  ];

  Widget _group(String title, {required List<Widget> children}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  /// The §23 Volume row, real since Phase 12: dragging applies the new
  /// volume to the feedback layer live (so the change is audible while
  /// dragging); the value is persisted when the drag ends.
  Widget _volumeRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Volume', style: AppTypography.bodyBase),
        Text(
          'How loud music and sound effects play.',
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        Slider(
          value: _settings.volume,
          onChanged: _loaded
              ? (v) {
                  final next = _settings.copyWith(volume: v);
                  setState(() => _settings = next);
                  FeedbackScope.maybeOf(context)?.applySettings(next);
                }
              : null,
          onChangeEnd: _loaded
              ? (v) => _save(_settings.copyWith(volume: v))
              : null,
        ),
      ],
    );
  }

  /// The §23 UI scale row (Phase 13): a slider over the range the
  /// layout tests verify (100%–150%). Dragging applies the scale live
  /// through the same save path (the app root re-derives the
  /// TextScaler from the settings snapshot); the value persists on
  /// every change, like the toggles.
  Widget _uiScaleRow() {
    final percent = (_settings.uiScale * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('UI scale', style: AppTypography.bodyBase),
            ),
            Text(
              '$percent%',
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          'Make text and controls across the app larger.',
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        Slider(
          value: _settings.uiScale,
          min: AppSettings.defaultUiScale,
          max: AppSettings.maxUiScale,
          divisions: 5,
          label: '$percent%',
          onChanged: _loaded
              ? (v) => _save(_settings.copyWith(uiScale: v))
              : null,
        ),
      ],
    );
  }

  Widget _toggleRow({
    required String label,
    required String description,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodyBase),
              Text(
                description,
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
