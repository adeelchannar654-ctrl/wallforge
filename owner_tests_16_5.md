# Phase 16.5 — Owner manual-test script (Windows)

Everything in this phase is unit/widget/repository tested in
the Linux VM. What remains needs your machines: the Firestore
emulator (Java networking is blocked in the VM), two real
devices, and your Windows Flutter for the golden masters.
Work top to bottom; each step says what "good" looks like.

## 0. One-time setup

1. Pull the latest `main` and run `flutter pub get`.
2. **Deploy the rules** (nothing online in this phase works
   live without them — this also finally deploys the Phase 10
   rules):

   ```bat
   firebase login
   firebase deploy --only firestore:rules --project wallforge-efdb3
   ```

   Good: the deploy succeeds and the Console rules playground
   shows the new transitions (`timeoutClaimWrite`,
   `lbEntitlement`, `rematchTargetValid`).
3. **Run the rules test suite** (needs a JDK 17+ for the
   emulator; `JAVA_HOME` must point at it):

   ```bat
   cd tool\rules_tests
   npm install
   cd ..\..
   tool\rules_tests\node_modules\.bin\firebase emulators:exec --only firestore --project demo-wallforge "node --test tool\rules_tests\test\"
   ```

   Good: every test passes, including the clock, resign,
   rematch-seat and leaderboard sections added in this phase
   (they were written in the VM but could not be executed
   there).

## 1. Two-device clocked online match to a timeout

You need two devices (or one device + the web build) signed
in to the live project.

1. Device A: Online → Create a room with MOVE CLOCK = 15s.
   Device B: join with the code. Both ready, A starts.
2. Good: both boards show a countdown chip beside Blue (A);
   both count down together (they read the same server
   deadline — if the two devices' clocks differ by minutes,
   the countdowns must still agree within a second).
3. A plays; the chip moves to Red with a fresh 15 s.
4. B does nothing. At 0 the grace (2 s) passes and A's app
   ends the match on its own: **Red loses on time** on both
   screens, result reads "Blue wins · Timeout".
5. Repeat with B's device clock set 10 minutes fast, then
   10 minutes slow: the outcome and timing must be the
   same — server time judges, not device clocks.

## 2. Resign (all three modes)

1. Online: mid-match, B opens the app-bar menu → Resign
   match → confirm. Good: both devices show A as winner,
   "· Resignation" on the result; the match is in both
   devices' History (Home → MATCH HISTORY) as a resign.
2. Vs AI: RESIGN button → the AI wins; the result and
   history record agree.
3. Pass-and-play: RESIGN resigns the side to move; BACK
   during a match offers Keep playing / Leave (match stays
   resumable) / Resign — check all three paths once.

## 3. Rematch with swapped sides

1. Finish any online match, then on the Result screen one
   player taps REMATCH and the other accepts.
   Good: a new room opens where **the colours are swapped**
   (last game's Blue is now Red), the host is the new Blue,
   the board/clock match the finished game, and the lobby
   flow (ready → start) works as usual.
2. Decline path: propose again and have the other player
   ignore it — after about a minute the proposal lapses.
3. Vs AI: finish a game, REMATCH — you now play Red and
   the AI opens as Blue. REMATCH again — you are Blue again.
4. Restart (in-game) must NOT swap sides.

## 4. History after restart

1. Play two local games and one online game to finishes.
2. Fully close and reopen the app. Home → MATCH HISTORY.
   Good: all three records are there, newest first, with
   the right outcomes/reasons; filters (mode, Won/Lost)
   narrow the list; a record's detail shows its move list.
3. Delete one record from its detail screen; clear-all
   from the list's trash icon (both ask first).

## 5. Achievement unlock

1. Win any match (a pass-and-play game you drive to a Blue
   win is fastest). Good: a toast "Achievement unlocked:
   First Win" (or a count if several land together) appears
   over the result; Profile → ACHIEVEMENTS shows First Win
   unlocked with today's date, and streak progress as text.

## 6. Share on web and Android

1. **Web** (`flutter run -d chrome` or the hosted build):
   finish a match → SHARE RESULT. Good: a PNG of the result
   card downloads and the result text is on the clipboard
   (paste it somewhere to check: outcome + facts, no room
   code). Repeat from a History detail.
2. **Android**: SHARE RESULT copies the text and previews
   the card with a note that direct image sharing is not in
   this build yet. (Known limitation, by design — see the
   Phase 16.5 report.)

## 7. Leaderboard, before and after the rules deploy

1. **Before step 0.2** (skip if you already deployed): open
   Home → WEEKLY LEADERBOARD. Good: it opens without
   crashing, showing the empty state (through the current
   client an undeployed ruleset reads as an empty board —
   recorded limitation).
2. **After deploying**: play an online match of 10+ plies
   to a finish on two devices. Open the leaderboard on
   both. Good: both players appear with generated names
   (e.g. "Swift Falcon 42"), winner on 3 points, loser on
   1; your row is tagged YOU; the reset countdown reads
   the time to Monday 00:00 UTC.
3. REGENERATE changes your name (on the board immediately,
   since you have an entry). Play 4 matches against the
   same opponent: only 3 count (points stop rising on the
   4th) — the caps are real.
4. Debug builds show the board by default; a release build
   needs `--dart-define=FEATURE_LEADERBOARD=true` to show
   it at all. Verify once:

   ```bat
   flutter build web --release
   ```

   Good: no WEEKLY LEADERBOARD card on Home. Then rebuild
   with the define and confirm the card appears.

## 8. Golden masters on Windows

The golden masters in the repo are Linux-rendered (Phases
16/16.5 regenerated some in the VM). On your machine:

```bat
flutter test --update-goldens
flutter test
```

Good: the full suite passes with Windows-rendered masters.
Commit the regenerated PNGs if you want your machine to be
the reference renderer from now on.

## What "done" still does not include

- No ranked mode, Elo, XP, accounts, ads or notifications
  (deliberate non-goals, unchanged).
- The Phase 15 device/browser performance checks and the
  Phase 16 Part D items (two-device full match to a goal on
  real hardware, Expert timings in `--profile`, iOS on a
  Mac) are still open — see `memory.md` §13y/§13z.
- Q-01 (the repetition/stalemate rule) is still an owner
  decision; the clock does not settle it.
