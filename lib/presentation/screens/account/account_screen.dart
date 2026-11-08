import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/application/account/account_controller.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../data/local/shared_preferences_leaderboard_name_repository.dart';
import '../../../domain/repositories/auth.dart';
import '../../../domain/repositories/leaderboard.dart';
import '../../widgets/app_chrome.dart';
import '../../widgets/app_icons.dart';
import '../../widgets/responsive_content.dart';
import 'account_copy.dart';

/// The Account screen (Phase 16.6, Part D): every account state
/// and action in one place, reached from Settings, Profile and
/// the leaderboard's guest prompt.
///
/// Guest is the default and nothing here blocks play: the screen
/// opens on the guest status, sign-in is an offer, and every form
/// is optional. All copy lives in [AccountCopy]; every error the
/// player can hit is the typed [AuthError] mapping from there,
/// announced through a live region with an icon as well as colour
/// (Phase 13's non-colour rule).
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    this.controller,
    this.nameRepository = const SharedPreferencesLeaderboardNameRepository(),
  });

  /// Injected in tests; the app uses the installed shared
  /// controller (`AccountService`).
  final AccountController? controller;

  /// Where display-name generations live.
  final LeaderboardNameRepository nameRepository;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AccountController? _controller;
  final TextEditingController _emailField = TextEditingController();
  final TextEditingController _passwordField = TextEditingController();
  bool _showPassword = false;
  bool _createMode = false;
  String? _notice;
  String? _formError;
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AccountService.shared;
    final controller = _controller;
    if (controller != null) {
      controller.addListener(_onControllerChanged);
      if (!controller.isStarted) unawaited(controller.start());
      unawaited(_loadName());
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _emailField.dispose();
    _passwordField.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    unawaited(_loadName());
  }

  Future<void> _loadName() async {
    final uid = _controller?.state.uid;
    if (uid == null) {
      if (_displayName != null && mounted) setState(() => _displayName = null);
      return;
    }
    final generation = await widget.nameRepository.loadGeneration(uid);
    if (!mounted || _controller?.state.uid != uid) return;
    setState(() => _displayName = generateDisplayName(uid, generation));
  }

  Future<void> _regenerateName() async {
    final uid = _controller?.state.uid;
    if (uid == null) return;
    final generation = await widget.nameRepository.loadGeneration(uid);
    await widget.nameRepository.saveGeneration(uid, generation + 1);
    await _loadName();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Account'),
      ),
      body: SafeArea(
        child: ResponsiveContent(
          child: _controller == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Accounts are not enabled in this build. '
                      'You are playing as a guest, as always.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListenableBuilder(
                  listenable: _controller!,
                  builder: (context, _) => _body(_controller!),
                ),
        ),
      ),
    );
  }

  Widget _body(AccountController controller) {
    final state = controller.state;
    final busy = controller.isBusy;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.lastFailure != null && controller.conflict == null)
            _banner(
              icon: Icons.error_outline,
              text: AccountCopy.errorMessage(controller.lastFailure!.error),
              isError: true,
            ),
          if (_notice != null)
            _banner(icon: Icons.info_outline, text: _notice!, isError: false),
          _card(
            title: 'ACCOUNT',
            children: [
              Text(_statusLine(state), style: AppTypography.bodyBase),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _explainer(state),
                style: AppTypography.bodyBase.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (state.isAccount && state.email != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  state.email!,
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (state.isSignedIn && _displayName != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'You play as $_displayName',
                        style: AppTypography.bodyBase,
                      ),
                    ),
                    TextButton(
                      onPressed: busy ? null : _regenerateName,
                      child: const Text('REGENERATE'),
                    ),
                  ],
                ),
                Text(
                  'That generated name is the only identity other '
                  'players ever see — never your email.',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          if (controller.conflict != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _conflictCard(controller),
          ] else if (state.isGuest) ...[
            const SizedBox(height: AppSpacing.lg),
            _signInCard(controller),
          ],
          if (state.isAccount &&
              state.providerId == AuthProviders.password &&
              !state.emailVerified) ...[
            const SizedBox(height: AppSpacing.lg),
            _verificationCard(controller),
          ],
          if (state.isSignedIn) ...[
            const SizedBox(height: AppSpacing.lg),
            _sessionCard(controller),
          ],
          const SizedBox(height: AppSpacing.lg),
          _deleteCard(controller),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  // --- Cards --------------------------------------------------------------------

  Widget _signInCard(AccountController controller) {
    final busy = controller.isBusy;
    return _card(
      title: 'SIGN IN',
      children: [
        PrimaryActionButton(
          label: 'CONTINUE WITH GOOGLE',
          onPressed: busy
              ? null
              : () async {
                  setState(() => _notice = null);
                  await controller.connectGoogle();
                },
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'or use an email address',
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _emailField,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          style: AppTypography.bodyBase.copyWith(color: AppColors.onSurface),
          decoration: _fieldDecoration('Email'),
          onChanged: (_) {
            if (_formError != null) setState(() => _formError = null);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _passwordField,
          obscureText: !_showPassword,
          autofillHints: [
            _createMode ? AutofillHints.newPassword : AutofillHints.password,
          ],
          textInputAction: TextInputAction.done,
          style: AppTypography.bodyBase.copyWith(color: AppColors.onSurface),
          decoration: _fieldDecoration('Password').copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          onSubmitted: (_) => _submitEmail(controller),
        ),
        if (_createMode)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'At least ${AccountPolicy.minPasswordLength} characters.',
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        if (_formError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 18, color: AppColors.error),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _formError!,
                      style: AppTypography.bodyBase.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(
          label: _createMode ? 'CREATE ACCOUNT' : 'SIGN IN',
          onPressed: busy ? null : () => _submitEmail(controller),
        ),
        const SizedBox(height: AppSpacing.xs),
        // An OverflowBar, not a Row: at UI scale 1.5 the two
        // buttons together are wider than a phone card, and the
        // mode toggle must wrap rather than overflow (the
        // Phase 16.6 matrix caught exactly that).
        OverflowBar(
          alignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      _createMode = !_createMode;
                      _formError = null;
                    }),
              child: Text(
                _createMode
                    ? 'Already have an account? Sign in'
                    : 'New here? Create an account',
              ),
            ),
            if (!_createMode)
              TextButton(
                onPressed: busy ? null : () => _forgotPassword(controller),
                child: const Text('Forgot password?'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _conflictCard(AccountController controller) {
    final conflict = controller.conflict!;
    final busy = controller.isBusy;
    return _card(
      title: 'ONE MOMENT',
      children: [
        Row(
          children: [
            Icon(Icons.swap_horiz, color: AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text(
                AccountCopy.conflictTitle,
                style: AppTypography.bodyBase,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          conflict.providerId == AuthProviders.google
              ? AccountCopy.conflictGoogleBody
              : AccountCopy.conflictEmailBody(conflict.email ?? ''),
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(
          label: 'SIGN IN TO THAT ACCOUNT',
          onPressed: busy
              ? null
              : () async {
                  await controller.resolveConflictUseExisting();
                  if (!mounted) return;
                  if (controller.conflict == null &&
                      controller.state.isAccount) {
                    setState(
                      () =>
                          _notice = 'Signed in. Your account identity is back.',
                    );
                  }
                },
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryActionButton(
          label: 'KEEP THIS GUEST',
          onPressed: busy ? null : controller.resolveConflictCancel,
        ),
      ],
    );
  }

  Widget _verificationCard(AccountController controller) {
    final busy = controller.isBusy;
    return _card(
      title: 'VERIFY YOUR EMAIL',
      children: [
        Text(
          AccountCopy.verificationPending,
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryActionButton(
          label: "I'VE VERIFIED — REFRESH",
          onPressed: busy
              ? null
              : () async {
                  await controller.refreshAccount();
                  if (!mounted) return;
                  if (controller.state.emailVerified) {
                    setState(
                      () => _notice = 'Email verified. Your matches now count.',
                    );
                  }
                },
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryActionButton(
          label: 'RESEND EMAIL',
          onPressed: busy
              ? null
              : () async {
                  final result = await controller.resendVerification();
                  if (!mounted) return;
                  if (result is AuthSuccess) {
                    setState(() => _notice = AccountCopy.verificationSent);
                  }
                },
        ),
      ],
    );
  }

  Widget _sessionCard(AccountController controller) {
    final busy = controller.isBusy;
    return _card(
      title: 'ON THIS DEVICE',
      children: [
        Text(
          AccountCopy.localDataNote,
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SecondaryActionButton(
          label: 'SIGN OUT',
          iconAsset: AppIcons.logout,
          onPressed: busy ? null : () => _confirmSignOut(controller),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryActionButton(
          label: "CLEAR THIS DEVICE'S PROGRESS",
          icon: Icons.delete_sweep_outlined,
          onPressed: busy ? null : () => _confirmClearProgress(controller),
        ),
      ],
    );
  }

  Widget _deleteCard(AccountController controller) {
    final state = controller.state;
    return _card(
      title: 'DELETE ACCOUNT',
      children: [
        Text(
          AccountCopy.deleteExplainer,
          style: AppTypography.bodyBase.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (state.isAccount)
          SecondaryActionButton(
            label: 'DELETE ACCOUNT',
            icon: Icons.delete_forever_outlined,
            onPressed: controller.isBusy
                ? null
                : () => _confirmDelete(controller),
          )
        else
          Text(
            'Guests have no account to delete. Clearing this '
            'device\u2019s progress (above) removes what is stored '
            'here.',
            style: AppTypography.bodyBase.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  // --- Actions ---------------------------------------------------------------------

  Future<void> _submitEmail(AccountController controller) async {
    final email = _emailField.text.trim();
    final password = _passwordField.text;
    setState(() {
      _notice = null;
      _formError = null;
    });
    final AuthResult result;
    if (_createMode) {
      result = await controller.createEmailAccount(
        email: email,
        password: password,
      );
    } else {
      result = await controller.signInWithEmail(
        email: email,
        password: password,
      );
    }
    if (!mounted) return;
    if (result is AuthSuccess) {
      _passwordField.clear();
      if (_createMode) {
        setState(
          () => _notice =
              'Account created. Check your inbox to verify '
              'your email.',
        );
      }
    }
  }

  Future<void> _forgotPassword(AccountController controller) async {
    final email = _emailField.text.trim();
    if (email.isEmpty) {
      setState(() => _formError = AccountCopy.resetNeedsEmail);
      return;
    }
    final result = await controller.sendPasswordReset(email: email);
    if (!mounted) return;
    if (result is AuthSuccess) {
      setState(() => _notice = AccountCopy.resetSent);
    }
  }

  Future<void> _confirmSignOut(AccountController controller) async {
    final isGuest = controller.state.isGuest;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          isGuest
              ? AccountCopy.signOutGuestWarning
              : AccountCopy.signOutAccountNote,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.signOutToFreshGuest();
    if (!mounted) return;
    setState(() => _notice = 'Signed out. You are a new guest now.');
  }

  Future<void> _confirmClearProgress(AccountController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AccountCopy.clearProgressTitle),
        content: const Text(AccountCopy.clearProgressBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('CLEAR'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.clearDeviceProgress();
    if (!mounted) return;
    setState(() => _notice = "This device's progress was cleared.");
  }

  Future<void> _confirmDelete(AccountController controller) async {
    final needsPassword = controller.state.providerId == AuthProviders.password;
    // The dialog owns its text controller (see _DeleteAccountDialog):
    // disposing a controller from here, while the dialog's exit
    // transition still has its field mounted, is a use-after-dispose.
    final password = await showDialog<String?>(
      context: context,
      builder: (context) => _DeleteAccountDialog(needsPassword: needsPassword),
    );
    if (password == null || !mounted) return;
    final result = await controller.deleteAccount(
      password: needsPassword ? password : null,
    );
    if (!mounted) return;
    if (result is AuthSuccess) {
      setState(
        () => _notice =
            'Your account was deleted. You are playing as a '
            'new guest.',
      );
    }
  }

  // --- Pieces ------------------------------------------------------------------------

  Widget _card({required String title, required List<Widget> children}) {
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

  Widget _banner({
    required IconData icon,
    required String text,
    required bool isError,
  }) {
    final color = isError ? AppColors.error : AppColors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodyBase.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceContainer,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
    );
  }

  String _statusLine(AuthState state) {
    if (state.isGuest) return AccountCopy.guestStatus;
    if (state.isAccount) {
      return state.providerId == AuthProviders.google
          ? AccountCopy.signedInGoogle
          : AccountCopy.signedInEmail;
    }
    if (state.status == AuthStatus.unavailable) return 'Playing as guest';
    return AccountCopy.notStarted;
  }

  String _explainer(AuthState state) {
    if (state.isGuest) return AccountCopy.guestExplainer;
    if (state.isAccount) {
      return 'Your online identity is saved with your account '
          'and follows you across devices.';
    }
    if (state.status == AuthStatus.unavailable) {
      return AccountCopy.unavailable;
    }
    return 'Sign in to keep your online identity on new devices.';
  }
}

/// The delete-account confirmation: the plain-language explainer,
/// plus — for email accounts — the password field the
/// re-authentication needs. Pops with the entered password (or
/// an empty string) on confirm, null on cancel.
///
/// A widget of its own so the text controller lives and dies
/// with the dialog's own state.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.needsPassword});

  final bool needsPassword;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _passwordField = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AccountCopy.deleteExplainer),
          if (widget.needsPassword) ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _passwordField,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              style: AppTypography.bodyBase.copyWith(
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Password (to confirm)',
                filled: true,
                fillColor: AppColors.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_passwordField.text),
          child: const Text('DELETE ACCOUNT'),
        ),
      ],
    );
  }
}
