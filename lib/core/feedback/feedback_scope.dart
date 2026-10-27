import 'package:flutter/widgets.dart';

import 'feedback_controller.dart';
import 'feedback_timing.dart';

/// The reduced-motion seam (Phase 12, prompt §2): one place every
/// animated widget consults, instead of each widget inferring the state
/// on its own.
///
/// Reduced motion is active when **either** signal is on:
///
/// * the platform's own accessibility setting, exposed by Flutter as
///   `MediaQuery.disableAnimations`, or
/// * the user's in-app Reduced motion toggle (persisted via the Phase 6
///   settings repository, carried by the [FeedbackController]).
///
/// "Reduced" means the animation is skipped and its end state applied
/// instantly ([FeedbackTiming.reduced]) — the recorded §2 decision.
class FeedbackScope extends InheritedNotifier<FeedbackController> {
  const FeedbackScope({
    super.key,
    required FeedbackController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The app's feedback controller, or null outside the app root (unit
  /// tests that pump a bare board, for example — feedback is then simply
  /// absent, never an error).
  static FeedbackController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeedbackScope>()?.notifier;

  /// Whether reduced motion is active for [context] by either signal.
  static bool reducedMotionActive(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return true;
    return maybeOf(context)?.reducedMotionInApp ?? false;
  }

  /// [normal] shortened by the reduced-motion decision: the full
  /// duration normally, [FeedbackTiming.reduced] (zero) when reduced.
  static Duration durationOf(BuildContext context, Duration normal) =>
      reducedMotionActive(context) ? FeedbackTiming.reduced : normal;
}
