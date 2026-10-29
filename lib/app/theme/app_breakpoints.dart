import 'package:flutter/widgets.dart';

/// The app's single, shared responsive breakpoint definition
/// (Phase 14, `design.md` §27).
///
/// Before Phase 14 the only breakpoint in the app — `>= 768` — was a
/// hard-coded literal duplicated in the two game screens, the split
/// was strictly binary, and a 768-wide tablet silently inherited the
/// full desktop layout. §27 names four device categories (small
/// phones, large phones, tablets, desktop browsers) and forbids
/// merely scaling components proportionally, so there are now three
/// named tiers and every screen derives its tier from here.
///
/// Boundary values (design.md specifies no pixel values — chosen and
/// recorded in `memory.md` §13w):
///
/// * **phone**: width < [tabletMinWidth]. 768 is kept as the
///   phone/tablet boundary because it has been the project's
///   mobile/desktop split since Phase 3 and it is where portrait
///   tablets actually begin (the standard tablet viewport,
///   768×1024, must land in the tablet tier, not desktop's).
/// * **tablet**: [tabletMinWidth] ≤ width < [desktopMinWidth].
/// * **desktop**: width ≥ [desktopMinWidth]. 1024 because the
///   desktop game layout (two 280px rails + a useful board) needs
///   roughly 1000px before the board is squeezed, and because
///   large tablets in landscape and small laptops — the devices
///   that genuinely have room for side rails — start there.
///
/// This is about the app adapting automatically to the viewport. It
/// is a different axis from Phase 13's `uiScale`, which the player
/// sets deliberately; the two compose (a scaled UI inside whichever
/// tier the viewport selects), and both are tested together.
enum AppBreakpoint {
  phone,
  tablet,
  desktop;

  bool get isPhone => this == AppBreakpoint.phone;
  bool get isTablet => this == AppBreakpoint.tablet;
  bool get isDesktop => this == AppBreakpoint.desktop;

  /// Whether this tier is at least tablet-sized (tablet or desktop).
  bool get isTabletOrWider => this != AppBreakpoint.phone;
}

abstract final class AppBreakpoints {
  /// The smallest width that counts as a tablet (Phase 3's original
  /// boundary, kept — see the class documentation).
  static const double tabletMinWidth = 768;

  /// The smallest width that counts as desktop.
  static const double desktopMinWidth = 1024;

  /// The largest content width for the game screens' tablet hybrid
  /// layout: the single column is capped and centered so the board
  /// grows relative to a phone's, without jumping to desktop rails.
  static const double tabletGameContentMaxWidth = 680;

  /// The largest content width for form/menu screens on tablet.
  static const double tabletContentMaxWidth = 680;

  /// The largest content width for form/menu screens on desktop,
  /// where several screens also change arrangement (grids, two
  /// columns) rather than only widening.
  static const double desktopContentMaxWidth = 960;

  /// The tier for a viewport [width] in logical pixels.
  static AppBreakpoint tierForWidth(double width) {
    if (width >= desktopMinWidth) return AppBreakpoint.desktop;
    if (width >= tabletMinWidth) return AppBreakpoint.tablet;
    return AppBreakpoint.phone;
  }

  /// The tier of the current [context]'s viewport.
  static AppBreakpoint of(BuildContext context) =>
      tierForWidth(MediaQuery.sizeOf(context).width);

  /// Whether the viewport is a **landscape phone**: wider than tall
  /// but phone-short. Portrait-first is the design (PRD.md), and the
  /// recorded Phase 14 decision is that landscape phones borrow the
  /// game screens' side-panel pattern (with compact rails) instead
  /// of squeezing the portrait column — see `memory.md` §13w.
  static bool isLandscapePhone(Size size) =>
      size.width > size.height && size.height < 500;

  /// The [isLandscapePhone] check for the current [context].
  static bool isLandscapePhoneOf(BuildContext context) =>
      isLandscapePhone(MediaQuery.sizeOf(context));
}
