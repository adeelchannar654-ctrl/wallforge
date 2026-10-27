import 'package:flutter/material.dart';

import '../../core/feedback/feedback_scope.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../domain/models/player_id.dart';

/// Shared building blocks for the Phase 11 product screens.
///
/// Everything here is composed from the existing token system
/// (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadii`) and the card /
/// button conventions `design.md` §14–§15 describe — dark surface, subtle
/// border, small radius, controlled shadow; a strong primary button, a
/// quieter bordered secondary, and destructive actions kept visually
/// distinct. No new visual language.

/// The standard card: dark surface, 1px subtle border, 16px radius.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Primary action (design.md §14): strong contrast, rounded, clear label.
/// Player-accent fill — cyan for the default product accent.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed == null
            ? null
            : () {
                // Phase 12: the button-press cue (§25) fires from this
                // shared kit, so every primary action sounds the same.
                FeedbackScope.maybeOf(context)?.onButtonPress();
                onPressed!();
              },
        icon: Icon(icon ?? Icons.play_arrow, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.surfaceContainerLowest,
          textStyle: AppTypography.titleMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    );
  }
}

/// Secondary action (design.md §14): darker, bordered, lower visual weight.
class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed == null
            ? null
            : () {
                FeedbackScope.maybeOf(context)?.onButtonPress();
                onPressed!();
              },
        icon: Icon(icon ?? Icons.arrow_forward, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.outlineVariant),
          textStyle: AppTypography.titleMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
    );
  }
}

/// A small section heading in the app's label style.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.labelCaps.copyWith(
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

/// A player's pawn as a disc with its letter — the `design.md` §26 pattern
/// (colour + letter + label, never colour alone), reused wherever a player
/// "piece" is shown outside the board (Result §21's "player piece").
class PlayerPawnDisc extends StatelessWidget {
  const PlayerPawnDisc({super.key, required this.player, this.size = 56});

  final PlayerId player;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isBlue = player == PlayerId.blue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: isBlue
              ? const [AppColors.primaryFixed, AppColors.primaryContainer]
              : const [AppColors.secondaryFixedDim, Color(0xFFFF4B6E)],
        ),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        isBlue ? 'B' : 'R',
        style: AppTypography.headlineMd.copyWith(
          color: AppColors.surfaceContainerLowest,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// A settings row for a feature that does not exist yet (Phase 12/13):
/// visibly inert — disabled control, greyed label, and an honest
/// "Not yet available" note, per the project's never-fake-a-feature rule.
class UnavailableSettingsRow extends StatelessWidget {
  const UnavailableSettingsRow({
    super.key,
    required this.label,
    required this.availableIn,
  });

  final String label;

  /// The phase/update the feature belongs to, e.g. "Phase 12".
  final String availableIn;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.bodyBase),
                Text(
                  'Not yet available — arrives with $availableIn.',
                  style: AppTypography.bodyBase.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Switch(value: false, onChanged: null),
        ],
      ),
    );
  }
}
