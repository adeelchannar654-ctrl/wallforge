import 'package:flutter/material.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_settings_repository.dart';
import '../../../data/remote/firebase_auth_gateway.dart';
import '../../../domain/repositories/repositories.dart';
import '../../widgets/app_chrome.dart';

/// The Settings screen (`design.md` §23), with the honesty boundary §23
/// and the phase plan require:
///
/// * **Gameplay is real.** Confirm wall placement is the persisted Phase 6
///   setting — the same store the game HUD toggle writes, so the two never
///   disagree. Movement assistance is the Phase 11 feature §23 lists:
///   while Move is selected, the board draws the current player's shortest
///   route to their goal.
/// * **Audio and Haptics are Phase 12** and **Accessibility is Phase 13**:
///   those features do not exist yet, so their rows are rendered visibly
///   inert and labelled "Not yet available" — never as working-looking
///   toggles that control nothing.
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
    await widget.settingsRepository.save(next);
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _group(
                'GAMEPLAY',
                children: [
                  _toggleRow(
                    label: 'Confirm wall placement',
                    description:
                        'Ask for confirmation before a wall is placed.',
                    value: _settings.confirmWallPlacement,
                    onChanged: _loaded
                        ? (v) =>
                              _save(_settings.copyWith(confirmWallPlacement: v))
                        : null,
                  ),
                  const Divider(color: AppColors.outlineVariant),
                  _toggleRow(
                    label: 'Movement assistance',
                    description:
                        'Show the shortest route to the goal while Move '
                        'is selected.',
                    value: _settings.movementAssistance,
                    onChanged: _loaded
                        ? (v) =>
                              _save(_settings.copyWith(movementAssistance: v))
                        : null,
                  ),
                  const Divider(color: AppColors.outlineVariant),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tutorial',
                              style: AppTypography.bodyBase,
                            ),
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
              const SizedBox(height: AppSpacing.lg),
              _group(
                'AUDIO',
                children: const [
                  UnavailableSettingsRow(
                    label: 'Music',
                    availableIn: 'Phase 12',
                  ),
                  Divider(color: AppColors.outlineVariant),
                  UnavailableSettingsRow(
                    label: 'Sound effects',
                    availableIn: 'Phase 12',
                  ),
                  Divider(color: AppColors.outlineVariant),
                  _VolumeRow(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _group(
                'HAPTICS',
                children: const [
                  UnavailableSettingsRow(
                    label: 'Haptic feedback',
                    availableIn: 'Phase 12',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _group(
                'ACCESSIBILITY',
                children: [
                  const UnavailableSettingsRow(
                    label: 'Reduced motion',
                    availableIn: 'Phase 13',
                  ),
                  const Divider(color: AppColors.outlineVariant),
                  const UnavailableSettingsRow(
                    label: 'Color assistance',
                    availableIn: 'Phase 13',
                  ),
                  const Divider(color: AppColors.outlineVariant),
                  const UnavailableSettingsRow(
                    label: 'High contrast',
                    availableIn: 'Phase 13',
                  ),
                  const Divider(color: AppColors.outlineVariant),
                  const UnavailableSettingsRow(
                    label: 'UI scale',
                    availableIn: 'Phase 13',
                  ),
                  const Divider(color: AppColors.outlineVariant),
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
              const SizedBox(height: AppSpacing.lg),
              _group(
                'ACCOUNT',
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account information',
                        style: AppTypography.bodyBase,
                      ),
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
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

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

/// The §23 Volume row, Phase 12's like the rest of Audio: a disabled
/// slider, labelled as not yet available.
class _VolumeRow extends StatelessWidget {
  const _VolumeRow();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Volume', style: AppTypography.bodyBase),
          Text(
            'Not yet available — arrives with Phase 12.',
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const Slider(value: 0.5, onChanged: null),
        ],
      ),
    );
  }
}
