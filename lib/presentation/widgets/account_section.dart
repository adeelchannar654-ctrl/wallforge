import 'package:flutter/material.dart';

import '../../app/application/account/account_controller.dart';
import '../../app/router/app_router.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../domain/repositories/auth.dart';
import '../screens/account/account_copy.dart';
import 'app_chrome.dart';

/// The shared account summary (Phase 16.6, Part D): the same
/// section inside Settings' ACCOUNT group and Profile's ACCOUNT
/// card, so the two surfaces can never disagree about who is
/// signed in.
///
/// It is a summary plus an entry point — the forms, the conflict
/// choice, verification, sign-out warnings and deletion all live
/// on the Account screen (`/account`), which this opens. Rendered
/// only when the accounts feature is on and the app installed a
/// controller; with the flag off, both host screens render
/// exactly what they rendered before this phase.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.controller});

  /// The app's one account controller.
  final AccountController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: AppSpacing.md),
            SecondaryActionButton(
              label: state.isAccount ? 'MANAGE ACCOUNT' : 'SIGN IN',
              icon: Icons.account_circle_outlined,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.account),
            ),
          ],
        );
      },
    );
  }

  String _statusLine(AuthState state) {
    if (state.isGuest) return AccountCopy.guestStatus;
    if (state.isAccount) {
      return state.providerId == AuthProviders.google
          ? AccountCopy.signedInGoogle
          : AccountCopy.signedInEmail;
    }
    if (state.status == AuthStatus.unavailable) {
      return 'Playing as guest';
    }
    return AccountCopy.notStarted;
  }

  String _explainer(AuthState state) {
    if (state.isGuest) return AccountCopy.guestExplainer;
    if (state.isAccount) {
      return state.providerId == AuthProviders.password && !state.emailVerified
          ? AccountCopy.verificationPending
          : 'Your online identity is saved with your account and '
                'follows you across devices.';
    }
    if (state.status == AuthStatus.unavailable) {
      return AccountCopy.unavailable;
    }
    return 'Sign in to keep your online identity on new devices.';
  }
}
