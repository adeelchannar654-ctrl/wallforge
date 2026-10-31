/// The per-move time controls the app offers (Phase 16.5).
///
/// One list, used by the room-creation picker, the Settings
/// default, the local/vs-AI start path and the rules' create
/// check, so the four can never drift apart. `0` means the
/// clock is off — always available for local play, so a player
/// is never trapped by a clock they did not choose.
const List<int> kTimeControlOptionsSeconds = <int>[0, 15, 30, 60];

/// Quick Match's fixed control: one default for everyone, so
/// the matchmaking queue stays a single pool keyed by board
/// config alone (the queue key does not include the clock).
const int kQuickMatchTimeControlSeconds = 60;

/// The grace after a turn deadline before a timeout claim is
/// accepted, in milliseconds (D16.5-3): covers the snapshot
/// delivery latency of a move already in flight at the
/// deadline. Mirrored in `firestore.rules` (2 s) and in
/// `FirestoreMatchRepository.timeoutGraceMs` — all three must
/// move together.
const int kTimeoutGraceMs = 2000;

/// Player-facing label for a time control value.
String timeControlLabel(int seconds) =>
    seconds == 0 ? 'Off' : '$seconds seconds per move';

/// Short label for chips and HUD chips.
String timeControlShortLabel(int seconds) =>
    seconds == 0 ? 'Off' : '${seconds}s';
