/// Asset paths for the custom badge-style button icons
/// (`assets/icons/`, owner-supplied set, 2026-10-31).
///
/// The badge artwork carries its own navy tile and palette colours, so
/// call sites render it with [Image.asset] at a fixed size instead of a
/// tinted Material [Icon]. Keep new menu artwork in this family so the
/// product surfaces stay visually consistent.
abstract final class AppIcons {
  static const String play = 'assets/icons/play.png';
  static const String local = 'assets/icons/local.png';
  static const String ai = 'assets/icons/ai.png';
  static const String online = 'assets/icons/online.png';
  static const String resume = 'assets/icons/resume.png';
  static const String tutorial = 'assets/icons/tutorial.png';
  static const String profile = 'assets/icons/profile.png';
  static const String settings = 'assets/icons/settings.png';
  static const String statistics = 'assets/icons/statistics.png';
  static const String createRoom = 'assets/icons/create_room.png';
  static const String joinRoom = 'assets/icons/join_room.png';
  static const String quickMatch = 'assets/icons/quick_match.png';
  static const String rematch = 'assets/icons/rematch.png';
  static const String home = 'assets/icons/home.png';
  static const String move = 'assets/icons/move.png';
  static const String wall = 'assets/icons/wall.png';
  static const String check = 'assets/icons/check.png';
  static const String logout = 'assets/icons/logout.png';
}
