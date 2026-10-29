import 'package:flutter/widgets.dart';

import '../../app/theme/app_breakpoints.dart';

/// Centers [child] and caps its width for the current breakpoint
/// tier (Phase 14, `design.md` §27).
///
/// Phone content runs full-width (the historical layout). On tablet
/// and desktop the content stops stretching edge-to-edge — the
/// "stretched mobile UI" this phase exists to fix — and sits at a
/// deliberate measure in the middle of the viewport instead. Screens
/// whose wide layout also *rearranges* (grids, two columns) compose
/// this with their own tier checks from [AppBreakpoints].
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.tabletMaxWidth = AppBreakpoints.tabletContentMaxWidth,
    this.desktopMaxWidth = AppBreakpoints.desktopContentMaxWidth,
  });

  final Widget child;

  /// Content cap on the tablet tier.
  final double tabletMaxWidth;

  /// Content cap on the desktop tier.
  final double desktopMaxWidth;

  @override
  Widget build(BuildContext context) {
    final tier = AppBreakpoints.of(context);
    if (tier.isPhone) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: tier.isTablet ? tabletMaxWidth : desktopMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
