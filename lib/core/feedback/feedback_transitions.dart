import 'package:flutter/widgets.dart';

import 'feedback_controller.dart';
import 'feedback_scope.dart';
import 'feedback_timing.dart';

/// The app's page transition (Phase 12): a short fade with a slight rise.
///
/// Purposeful by `design.md` §24's rule — it communicates "a new screen
/// replaced the old one" (a state change), and nothing more. Duration is
/// [FeedbackTiming.uiTransition]; under reduced motion the child is
/// returned unanimated (the end state, instantly).
Widget wallforgePageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (FeedbackScope.reducedMotionActive(context)) return child;
  final curved = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// A page route with the §24 UI-transition duration.
///
/// The in-app reduced-motion toggle is read from the shared controller
/// at construction (the router has no `BuildContext` of its own); the
/// platform signal is applied inside [wallforgePageTransition], which
/// returns the page unanimated when it is on.
class WallforgePageRoute<T> extends PageRouteBuilder<T> {
  WallforgePageRoute({super.settings, required WidgetBuilder builder})
    : super(
        transitionDuration:
            (FeedbackService.shared?.reducedMotionInApp ?? false)
            ? FeedbackTiming.reduced
            : FeedbackTiming.uiTransition,
        reverseTransitionDuration:
            (FeedbackService.shared?.reducedMotionInApp ?? false)
            ? FeedbackTiming.reduced
            : FeedbackTiming.uiTransition,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: wallforgePageTransition,
      );
}
