/// Identifies a player in a Wallforge match.
///
/// Mirrors spec §4.2: exactly two players, Blue and Red.
enum PlayerId {
  blue,
  red;

  /// Returns the opponent of this player.
  PlayerId get opponent => switch (this) {
    PlayerId.blue => PlayerId.red,
    PlayerId.red => PlayerId.blue,
  };
}
