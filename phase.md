# Wallforge — Development Phases

## Project Strategy

Build the project from the inside out:

```text
Rules
  ↓
Game Engine
  ↓
Tests
  ↓
Board UI
  ↓
Offline Modes
  ↓
Online Multiplayer
  ↓
Polish
  ↓
Release
```

Do not start with Firebase or visual polish before the game engine is reliable.

---

# Phase 0 — Project Foundation

## Goal

Create the Flutter project and establish the development standards.

### Tasks

- Create Flutter project.
- Enable Android.
- Enable iOS.
- Enable Web.
- Create Git repository.
- Add documentation files.
- Establish folder structure.
- Configure formatting/analyzer.
- Establish test structure.
- Create basic app shell.

### Exit criteria

- Flutter project runs.
- Android runs.
- Web runs.
- iOS project is configured.
- Tests run.
- Documentation exists.

---

# Phase 1 — Core Game Specification

## Goal

Freeze the initial game rules before visual implementation.

### Tasks

- Define board size.
- Define player starting positions.
- Define goal edges.
- Define movement.
- Define wall orientation.
- Define wall inventory.
- Define wall overlap rules.
- Define wall crossing rules.
- Define path-preservation rule.
- Define win condition.
- Define turn transition.
- Decide whether pawn-jump behavior is included.

### Exit criteria

Every rule has a deterministic answer. The complete specification is in
`game_spec.md` (version 1.0.4, Frozen — Phase 1 corrected four times).

---

# Phase 2 — Game Engine

Status: **COMPLETE** (commit `c15d51a`).

Phase 2.1 hardening is included as part of Phase 2 (not optional).

## Goal

Build the framework-independent game engine.

### Tasks

Create:

- Board model.
- Player model.
- Pawn model.
- Wall model.
- GameState.
- Turn state.
- Move validation.
- Wall validation.
- Pathfinding.
- Win detection.
- State transitions.

### Tests

Build extensive tests for:

- Movement.
- Walls.
- Pathfinding.
- Win.
- Turn handling.

### Exit criteria

The engine passes the `game_spec.md` test catalog. The game can be played
entirely through code without Flutter UI.

### Result

All five gates green (real output, measured 2026-09-21):

- `dart format --set-exit-if-changed lib test` → Formatted 37 files (0 changed).
- `dart analyze lib` → No issues found!
- `flutter test` → 174 tests, All tests passed!
- `check_spec_consistency.py` → OK: spec is consistent with the reference engine.
- `gen_engine_vectors.py` → 114 games, IDENTICAL to fixture.

---

# Phase 3 — Board Rendering

## Goal

Build the Wallforge board visual.

### Visual target

- Front-facing dark board.
- Dark navy grid.
- Green goal strip.
- Blue pawn.
- Red pawn.
- Blue walls.
- Red walls.
- Subtle 3D depth.
- Shadows.
- Glow.
- Rounded board container.

### Tasks

- Board renderer.
- Grid renderer.
- Goal renderer.
- Pawn renderer.
- Wall renderer.
- Wall preview.
- Legal-move highlighting.
- Responsive sizing.

### Exit criteria

The board correctly represents any valid GameState.

### Result

Phase 3 was re-verified during the Phase 4.1 correction on 2026-09-25. The earlier 313-test claim from the Phase 4 commit was not an application-layer baseline and is not repeated here.

- `dart format --set-exit-if-changed lib test` → `Formatted 60 files (0 changed)`.
- `flutter analyze` → `No issues found! (ran in 13.8s)`.
- `flutter test` → `835: All tests passed!`.
- `flutter build web` → `√ Built build\\web`.
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → `IDENTICAL`; generated and fixture sizes both 1,240,761 bytes.

Phase 3 deliverables include the native Stitch-aligned renderer, geometry/engine cross-checks, 219 board widget tests, five board goldens, goal-strip labels, and the visual-conformance checklist in `memory.md` §13h.

---

# Phase 4 — Interactive Local Game

## Goal

Make the board fully playable by two people.

### Tasks

- Tap/click movement.
- Wall selection.
- Wall placement.
- Wall preview.
- Turn indicator.
- Wall counter.
- Invalid-action feedback.
- Victory screen.
- Restart.
- Rematch.

### Exit criteria

Two players can complete a match without internet.

### Result

Phase 4.1 is complete and verified on 2026-09-25. The implementation remains in `lib/app/application` rather than being relocated to `lib/application/game`; the choice is recorded in `memory.md` §13i.

- Bug A fixed: the selected preview `BoardConfig` is passed as the `/game` route argument; deep links without arguments use the default config.
- Bug B fixed: desktop reuses the MOVE/WALL toggle above the shared action controls.
- Bug C fixed: pending wall validity is computed through the engine, invalid ghosts show their reason, and Confirm is disabled and controller-safe.
- Desktop parity audit found no additional mobile-only inventory, failure, Restart, or Back controls; the missing result overlay was added.
- Added 317 controller tests, 13 GameScreen/router tests, 12 board hit tests, and 3 tagged GameScreen goldens.
- Targeted coverage: controller 99.08% (108/109; unreachable wall-victory branch), GameScreen 100% (180/180).
- Full suite: `835: All tests passed!`.
- `flutter analyze` → `No issues found!`.
- `flutter build web` → `√ Built build\\web`.
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → `IDENTICAL`; generated and fixture sizes both 1,240,761 bytes.
- Manual Chrome acceptance was completed for 7×7 routing, wide and narrow layouts, valid wall placement, and invalid crossing feedback.

No Phase 5 work was started. Owner acceptance steps are recorded in `memory.md` §13i.

### Result — Phase 4.2 (2026-09-26)

Phase 4.2 fixes two confirmed interaction defects. No game rule changed.

- Bug D fixed: `BoardGeometry.wallAnchorAt` now snaps to the nearest logical slot
  instead of scanning exact groove rectangles. The perpendicular tolerance is
  22 px (half of the Stitch 44×44 px minimum target), capped at
  `cellSize / 2 - 0.5 px` so a cell-centre tap is never captured. Exact H/V ties
  resolve to horizontal. Beyond the tolerance the tap falls through to the cell,
  and `GameScreen` passes only the callback for the active interaction mode.
- Bug E fixed: the invalid ghost keeps its 50% crimson fill and adds a white
  dashed centre line plus a stronger outline, and a 2 px error ring is painted
  behind every placed wall the ghost overlaps, so it can never be read as a solid
  wall of the same owner.
- Tests: 102 board-geometry tests (was 73), 16 board hit tests (was 12), 321
  controller tests (was 317), 15 game-screen tests (was 13), 2 new board goldens
  and 1 new game-screen golden; `game_screen_mobile_invalid_wall.png`
  deliberately regenerated.
- Board coverage: `board_geometry.dart` 100%, `board_view.dart` 100%,
  `board_painter.dart` 98.79% (3 pre-existing `shouldRepaint` clauses).
- `dart format --set-exit-if-changed lib test` → `Formatted 60 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `876: All tests passed!`
- `flutter test --coverage test/presentation/board` → `363: All tests passed!`
- `flutter build web` → `√ Built build\\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → `IDENTICAL`; generated and fixture sizes both 1,240,761 bytes.
- Browser: the new invalid-ghost treatment was confirmed in a live Chrome build;
  the tap-driven reproduction could not be completed in the automated session
  (see `memory.md` §13j for the exact status).

### Result — Phase 4.3 (2026-09-26)

Phase 4.3 fixes the remaining wall-anchor defect: the axis that runs *along* a wall's
own bar still used a plain cell-floor, so a tap in the second half of a bar resolved
to the next anchor along and could be rejected as overlapping a wall the player never
aimed at. No game rule changed.

- Root cause confirmed by a diagnostic sweep run **before** any code change: 7 of 8
  sweeps failed, with the entire second half of a bar (`t = 4.00`–`4.90` of a bar
  spanning `t ∈ [3, 5)`) resolving one anchor to the right. The 5×5 sweep passed only
  because the board-edge clamp masked the bug there. `LocalGameController` was
  re-read and is not at fault.
- Fix: `_anchorCellIndex` snaps to the nearest **bar span centre** (`round(t - 1)`)
  instead of the cell containing the tap, clamped to `0..boardSize - 2`. Ownership
  boundaries move to the midpoints *between* adjacent bar centres. `_nearestAnchorLine`
  and `wallHitTolerance` are untouched.
- Two corrections to the phase brief, recorded because the files win: the suggested
  `- 0.5` formula is algebraically identical to the old `floor()` and would have
  changed nothing, and the "whole rendered width" invariant is impossible for
  overlapping two-cell bars — the tested invariant is the bar's central half.
- A real binary-float bug surfaced: an exact midpoint rounded down on board sizes 7
  and 11 (where `450 / 7` and `450 / 11` are not representable) and up on 5 and 9.
  Fixed with a `1e-9`-of-a-cell tie nudge and locked by a test on all four sizes.
- Tests: 114 board-geometry tests (was 102), 19 board hit tests (was 16) — empty-slot
  seven-position sweep, transition-zone determinism with non-flap, and a real
  `tester.tapAt` that saves the wall. Goldens unchanged; nothing visual moved.
- `dart format --set-exit-if-changed lib test` → `Formatted 60 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `891: All tests passed!`
- `flutter test --coverage test/presentation/board` → `378: All tests passed!`
  (`board_geometry.dart` 100%, `board_view.dart` 100%, `board_painter.dart` 98.79%)
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → unchanged; fixture still 1,240,761 bytes.
- Browser: the owner's complaint was **reproduced on a pre-fix build** ("Wall overlaps
  an existing wall.", CONFIRM disabled, not saved) and the identical tap sequence
  **saves** on the fixed build. Off-centre taps now place walls correctly. Phase 4.2's
  CDP blocker was solved by enabling Flutter's semantics tree and dispatching real
  `PointerEvent`s; see `memory.md` §13k.

### Addendum — rule change v2.0.0 applied after Phase 4 (2026-09-26)

Not a numbered phase — a deliberate, owner-approved change to the frozen rules,
applied between Phase 4 and Phase 5.

- A horizontal and a vertical wall may now share an anchor (a legal "+").
  `R-WALL-08` and `D-12` rewritten; `T-WALL-007` now expects success and new row
  `T-WALL-014` preserves overlap coverage; `Example 10` rewritten as a legal
  worked example; `game_spec.md` bumped to **2.0.0**.
- `wallCrosses` is **retired, not deleted**: unreachable, kept declared in §5.1 and
  in the Dart enum so the taxonomy, engine, and the owner-supplied oracle fixture
  (which still reserves code `k`) stay aligned. Removed from the §5.2 precedence
  chain and from `ActionValidator`/`MoveGenerator`.
- The generator's `_overlapsOrCrosses` was a second copy of the rule; removing it
  was required, otherwise crossing candidates stayed hidden from the player.
- Initial legal-action counts verified unchanged: **3 moves / 128 walls**.
- `check_spec_consistency.py` (owner-supplied, unmodified) → 2 problems before
  (T-WALL-007, Example 10) → `OK: spec is consistent with the reference engine.`
  with 80 catalog rows, 65 rule IDs, 65 in matrix.
- Oracle vectors → byte-identical to the new fixture (SHA-256 match, 1,229,568
  bytes); all 114 games replay with **no change to the oracle test**.
- `dart format --set-exit-if-changed lib test` → `Formatted 61 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `913: All tests passed!` (was 891; +19 new crossing tests,
  +1 controller, +1 board hit, +1 catalog row)
- `flutter build web` → `√ Built build\web`
- Full record, ledger and Open Questions: `memory.md` §13l; process recorded as
  `rules.md` Rule 19.

---

# Phase 5 — Offline AI

## Goal

Create an AI opponent.

### Version 1

Use:

- Shortest path.
- Opponent shortest path.
- Wall impact.
- Immediate tactical opportunities.

### Difficulty

- Easy.
- Medium.
- Hard.
- Expert.

Difficulty should be achieved through controlled search/evaluation complexity rather than simply random behavior.

### Exit criteria

AI completes legal matches without breaking game rules.

### Result — Phase 5 (2026-09-26)

Offline AI opponent. No game rule changed; the oracle vectors are byte-identical.

- Architecture: `lib/app/application/ai/` — `ai_difficulty.dart`,
  `ai_evaluator.dart`, `ai_opponent.dart`, plus `match_setup.dart` for the route.
  Depends only on the domain's public API; candidates come from
  `GameEngine.legalActions` and are applied through `GameEngine.apply`, so the AI
  can never bypass validation and the v2.0.0 crossing rule applies to it as it
  does to a human.
- Evaluation uses the four inputs `phase.md` asks for: own shortest path
  (reusing `Pathfinder.shortestRouteLength`, no second BFS), opponent shortest
  path, wall impact (the opponent's route already reflects every wall, with a
  small per-wall cost), and immediate win/loss (±1000). A monotone row-distance
  term was added after route lengths alone were measured producing games that
  never ended.
- Difficulty is **search depth + shortlist width, never randomness**: Easy 0/6,
  Medium 1/8, Hard 2/10, Expert 3/12, each a strict superset of the one below.
  Measured cost per move on 9×9: ~25 ms / ~25 ms / ~127 ms / ~1345 ms.
  Bounded by progressive widening and an interior wall-scan cap.
- Two defects found by measurement, not by inspection: the negamax leaf score was
  taken from the wrong player's perspective, which made the AI maximise its
  opponent's score and pick its worst move; and candidate scores were recomputed
  inside the sort comparator, making Expert 3× slower.
- Termination: 47 of 48 size × pairing combinations finish. The one exception,
  9×9 Hard vs Hard, is a forced stalemate where both players have spent all walls
  and every legal move recreates a seen position — unfixable by any evaluation,
  and the real fix is the still-Unresolved `game_spec.md` Q-01 repetition rule,
  which is the owner's decision. The stalled set is asserted against an explicit
  allowlist so any new stall fails the suite.
- UI: `START VS AI` plus a difficulty chip row on the existing board-preview entry
  screen, reusing current tokens. AI thinks for 300 ms so its turn is visible.
- Tests: 17 AI tests + 6 controller/route tests, including legality across sizes,
  difficulties and 60 seeded games; determinism; all AI-vs-AI pairings legal;
  and the strength check — **Expert beat Easy 4 / 0**.
- `dart format --set-exit-if-changed lib test` → `Formatted 67 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `936: All tests passed!`
- AI + application coverage → `345: All tests passed!`; `ai_opponent.dart` 97.14%,
  `ai_evaluator.dart` 96%.
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → byte-identical, SHA-256 unchanged (no rule change in Phase 5).
- Open: Q-5.1 (resolve Q-01 to close the stalemate), Q-5.2 (no AI screen is
  designed in `design.md` §20; a real one is Phase 11 UI work), Q-5.3 (no per-move
  time budget). Full record in `memory.md` §13m.

---

# Phase 6 — Local Persistence

## Goal

Preserve relevant local data.

### Tasks

- Settings.
- Tutorial completion.
- Local statistics.
- Optional unfinished game.
- AI progress if introduced.

### Exit criteria

Closing/reopening the application does not unexpectedly lose supported local data.

### Result — Phase 6 (2026-09-26)

Local persistence. No game rule changed; the spec checker and oracle vectors are
untouched and still green.

- Storage: **`shared_preferences`**, which is spec-derived rather than a new
  choice — `rules.md` §4 already lists it for exactly this purpose ("Small local
  settings / Tutorial completion / Simple local preferences"). Its caveat about a
  local database for *larger* storage was checked, not assumed: settings are a few
  hundred bytes and one 9×9 mid-game state is ~1–2 KB. Match history would cross
  that line and is not implemented.
- Layering follows the docs exactly: interfaces and persisted shapes in
  `lib/domain/repositories/`, implementations in `lib/data/local/`, and
  `LocalGameController` depending only on the interfaces. This is
  `architecture.md` §2.4 + §14 and `lib/data/README.md`'s `Data -> Domain
  interfaces`, so Phase 7 swaps the implementation without touching the
  application layer. Persistence is opt-in via `attachPersistence`, so the 328
  pre-existing controller tests needed no changes.
- Persisted: `confirmWallPlacement` and `aiDifficulty` (the only two real
  user-facing settings that exist), match results, and one unfinished match.
  The unfinished match reuses the engine's own `GameStateSerializer`, so a saved
  state that breaks a spec invariant is rejected by the same code as anywhere
  else.
- **Not persisted, honestly:** tutorial completion (no tutorial exists in the app
  — a documented always-false placeholder, nothing sets it, no UI reads it) and
  AI progress (the Phase 5 AI is a stateless evaluator with no rating or learning,
  so there is nothing true to record; `phase.md` says "if introduced"). No
  fabricated theme/sound/accessibility settings or match history either.
- Every repository method is total: missing, wrong-typed, unparseable or
  unreadable data falls back to a documented default and never throws, so a
  corrupt store cannot stop the app starting.
- UI: a `RESUME MATCH (9x9 vs expert)` affordance on the entry screen, shown only
  when a resumable match exists and hidden once the match finishes. The saved
  difficulty is preselected on open.
- Tests: 29 persistence tests (round-trips for all three shapes, per-field
  corruption fallbacks, an invariant-violating saved state, simulated restarts,
  and value semantics) + 9 integration tests (a partial match saved, an app
  restart simulated with a new controller, resumed and **continued legally**; a
  resumed AI match keeping opponent and difficulty; statistics recorded for both
  a human win and a human loss in real alternating games; no statistics
  mid-match; and a controller with no repositories attached doing nothing). +32
  overall.
- `dart format --set-exit-if-changed lib test` → `Formatted 67 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `968: All tests passed!`
- Persistence coverage → `552: All tests passed!`; in-memory repositories 100%,
  the three `shared_preferences` implementations 100% / 100% / 93.75% (one
  unreachable catch-path line).
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK` — explicitly unchanged: no rule change here.
- Oracle vectors → byte-identical, 1,229,568 bytes, SHA-256 unchanged.
- Process note: an earlier in-phase edit used a PowerShell `Get-Content` /
  `WriteAllText` round-trip, which mis-decoded UTF-8 and double-encoded 8 files
  (comments and Markdown only — tests and analyzer stayed green). Detected by an
  explicit UTF-8 + mojibake scan, repaired layer by layer, and recorded in
  `memory.md` §13n so it is not repeated.
- Open: Q-6.1 (replay/continue affordance after a finish), Q-6.2 (is Blue "the
  human" in pass-and-play?), Q-6.3 (where AI progress would live if ever
  introduced), Q-6.4 (single match slot; multi-slot history would justify a local
  database). Full record in `memory.md` §13n.

---

# Phase 7 — Firebase Foundation

## Goal

Connect Firebase without changing local game behavior.

### Tasks

- Create Firebase project.
- Keep project on Spark plan initially.
- Register Android app.
- Register iOS app.
- Register Web app.
- Configure FlutterFire.
- Add Firebase Core.
- Add Firebase Authentication.
- Add Cloud Firestore.
- Configure security rules.
- Create development/test environment.

Official Firebase's Flutter setup uses FlutterFire CLI and `flutterfire configure` to register supported platforms and generate `firebase_options.dart`. citeturn0search0

### Exit criteria

Each platform initializes Firebase correctly.

### Result — Phase 7 (2026-09-26)

Firebase foundation. No game rule changed; the spec checker and oracle vectors
are untouched and still green, and the app still launches and plays exactly as in
Phase 6.

- The one-line summary that matters: **the code side of this phase is done, the
  project side is not.** See "Not done, and why" below — the Firebase project has
  to be configured from the Console, and nothing in this repository may be
  allowed to pretend otherwise.
- Dependencies added exactly as the task list requires: `firebase_core ^4.15.0`,
  `firebase_auth ^6.7.0`, `cloud_firestore ^6.10.0`. All three were already
  sanctioned by `rules.md`, so no rules change was needed. Free tier / Spark only:
  the code uses nothing but `doc().get()`, `doc().set()` and `doc().delete()`.
- Layering mirrors Phase 6 exactly, which is the whole point of the Phase 6
  boundary: `lib/data/remote/` implements the *same* `SettingsRepository`,
  `StatisticsRepository` and `UnfinishedMatchRepository` interfaces, against a
  narrow `FirestoreClient` port. The application layer was not modified to
  accommodate them.
- Storage layout — three small documents per owner, so a user never reads a
  growing match-history collection:
  - `users/{uid}/settings`
  - `users/{uid}/statistics`
  - `users/{uid}/unfinishedMatch`
- **The app still defaults to `shared_preferences`.** The goal is "connect
  Firebase *without changing local game behavior*", and Phase 8 is where online
  data is actually used, so switching the default now would change behavior for
  no benefit. `PersistenceFactory.attachLocal` is what the router calls;
  `attachRemote` is available and tested but not on the default path. Recorded as
  Q-7.1.
- `FirebaseBootstrap` initialises at startup in `main()` and **catches every
  failure by design**: the repository deliberately ships no Firebase client
  config, so a fresh clone cannot initialise and must still launch on local
  storage. When the project id is a documented emulator id the status is
  `emulator`, otherwise `ready`; anything else is `unavailable` with a
  credential-free reason string for the log.
- An owner seam (`userId: () async => ...`) replaces an invented auth system. It
  is null until Phase 8 supplies a real uid, and a null owner means the
  repositories do nothing at all rather than writing under a shared placeholder.
- Two real defects were found by the tests rather than assumed absent:
  1. **Totality was delegated, not guaranteed.** The first draft relied on the
     *client* swallowing errors. A throwing client therefore propagated out of the
     repositories, which would crash the app. The guards now live in each
     repository, so "a failing store never breaks play" is a property of the
     repository and not of one implementation.
  2. **`dispose()` during an in-flight load asserted.** Persistence work is
     deliberately unawaited, so popping a route while a read was still in flight
     notified a disposed `ChangeNotifier`. Harmless-looking with
     `shared_preferences`; routine once the read is network-bound, which Phase 7
     just made it. `LocalGameController` now treats post-dispose completion as a
     no-op, and there is a test that hits the window deterministically.
- Tests: 18 conformance (all three repositories against the port: round-trips,
  per-field corruption fallbacks, owner scoping, schema versioning and injected
  transport failures) + 8 controller-boundary (the Phase 6 restart/resume
  scenarios re-run verbatim against the Firestore repositories, which is the
  actual proof the interface boundary held) + 9 bootstrap/factory. +35 overall.
- `dart format --set-exit-if-changed lib test` → `Formatted 88 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `1009: All tests passed!`
- Coverage of the new code: the three Firestore repositories 100% / 96.15% /
  95.45%, `in_memory_firestore_client.dart` 100%.
  **`cloud_firestore_client.dart` is 0%** — it can only be exercised against a
  real Firebase platform implementation or the emulator, and neither is
  available here. Not hidden, not papered over; see Q-7.5.
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → byte-identical, 1,229,568 bytes, SHA-256 `6f1e3c05…`, unchanged.
- `tool/encoding/scan_mojibake.py` → `0 files with mojibake` across 101 tracked
  text files.

### Not done, and why

These parts of the task list are **not** complete, and the phase should not be
read as if they were:

- **The Firebase project was not created or verified from here.** The existing
  project is `wallforge-efdb3`; no other project was created. Its id comes from
  the owner and could not be independently confirmed without Console access.
- **No platform was registered and no configuration was generated.** Committing
  `google-services.json` / `GoogleService-Info.plist` / `firebase_options.dart`
  is forbidden by `.gitignore` ("never merge exceptions for these paths") and
  `rules.md` §14, so these must be produced locally from the Console. The exact
  manual steps are in `memory.md` §13o.
- **`firebase_auth` is a dependency, not a feature.** No sign-in UI, no user
  record, no anonymous auth. That is Phase 8.
- **Security rules were not authored.** They depend on the real uid model and on
  what the Console already enforces, and Phase 10 is explicitly the phase for
  Firestore rules. Writing speculative rules now would be guesswork.
- **No live Firestore test ran.** The Firestore emulator is not installed and the
  CLI is not logged in, so the conformance suite runs against an in-process
  `InMemoryFirestoreClient` behind the same port. That proves the repositories'
  behaviour, not Firestore's.

Open: Q-7.1 (local stays the default until Phase 8 auth), Q-7.2 (device id vs
real uid), Q-7.3 (no emulator, so no live verification), Q-7.4 (project id
unverified from here), Q-7.5 (`CloudFirestoreClient` untested without a platform
implementation). Full record in `memory.md` §13o.

---

# Phase 8 — Online Rooms

## Goal

Allow two users to create and join matches.

### Tasks

- Authentication.
- Create room.
- Generate room ID/code.
- Join room.
- Match membership.
- Ready state.
- Match start.
- Leave/cancel room.

### Exit criteria

Two devices can enter the same match.

### Result — Phase 8 (2026-09-27)

Authentication and the two-player room lifecycle. No game rule changed; the spec
checker and oracle vectors are untouched and still green, and local and vs-AI play
are unaffected.

- **What "match start" means here:** both players are seated in one shared record
  with an agreed `BoardConfig` and side assignment. **Moves are not synchronised
  in this phase** — that is Phase 9 — and the lobby says so on screen rather than
  letting a player believe otherwise.
- **Auth: Firebase Anonymous.** Spec-derived, not a preference — `rules.md` §6
  ("an appropriate low-friction method such as anonymous authentication"),
  `PRD.md` §6.4 ("Anonymous or account-based authentication as appropriate").
  `rules.md` §6's warning is carried forward, not glossed: anonymous identity is
  not a durable account, so a reinstall loses access to that uid's cloud data.
  Phase 8 does not promise cross-device data restoration.
- **Layering:** `AuthGateway` and `RoomRepository` are declared in
  `lib/domain/repositories/` beside the Phase 6/7 contracts, and implemented in
  `lib/data/remote/`. Nothing above that line knows Firebase exists, so Phase 9
  attaches move sync to the same abstraction and tests substitute a double exactly
  as `InMemoryFirestoreClient` already does.
- **Storage:** one document per room at `matches/{code}`, extending
  `architecture.md` §11's `matches/{matchId}` structure. The room code *is* the
  document id, so joining is a single read — no query, no index, no collection
  scan. `currentPlayerId` / `turnNumber` / `winnerId` / `boardState` are
  deliberately absent: writing a board state before moves are exchanged would
  imply a synchronisation that does not exist. `version` is seeded at 1 for
  Phase 9's optimistic concurrency.
- **Creator takes Blue, joiner takes Red**, because Blue moves first
  (`game_spec.md` R-PLAYER-07) and Q-6.2 already treated Blue as the first player.
  Stored explicitly rather than implied by join order.
- **Room codes:** six characters from a 32-symbol alphabet excluding `0`, `O`,
  `1` and `I` (32^6 ≈ 1.07e9). No format is specified in any source document, so
  this is a reasoned default, chosen so a code read aloud is unambiguous. Input is
  case-insensitive and separator-tolerant. Collisions use a **bounded
  read-then-write retry with a verify-after-write**: a transaction or Cloud
  Function would need the Blaze plan, which `architecture.md` §10 forbids, so the
  confirming re-read detects a lost race and the repository tries the next code.
- **Leave is deliberately asymmetric.** The host leaving **deletes** the document
  (it could never be started, and it would occupy the 1 GiB storage quota
  forever); a guest leaving **reopens the seat** for the next player. Leaving after
  the start is refused as Phase 10's concern rather than half-done.
- **Failures are values, not exceptions**, per `rules.md` §7 and the existing
  `ActionResult` precedent: 13 distinguishable `RoomFailureReason`s, each with a
  player-facing message. No message leaks "Exception". One deliberate deviation from
  Phase 6/7: room writes report `networkUnavailable` instead of swallowing, because
  a swallowed write would report a room that does not exist.
- **Realtime:** `design.md` §19 requires the creator to see the opponent arrive, so
  `FirestoreClient` gained `watch(path)` — the widening Phase 7 anticipated, and
  the Phase 6/7 repositories were untouched by it. Cost verified against current
  Firebase docs rather than assumed: listeners are billed as document reads (one
  per document added or updated in the listener's result set), against a no-cost
  quota of 50,000 reads/day and 20,000 writes/day. Hence no polling and no periodic
  write anywhere in the repository.
- **Q-7.2 resolved:** a real authenticated uid now reaches the Phase 6/7 `userId`
  seam via `auth.currentUid`, with no change to those repositories. The "null means
  do nothing" contract is preserved and tested for all five entry points.
- **Q-7.1 deliberately still local**, now with a source rather than only a
  principle: `PRD.md` §9 ("local settings should be stored locally") and
  `rules.md` §4. Confirmed with the owner. Flipping is one line
  (`PersistenceFactory.attachRemote`) because the seam now resolves.
- **Three defects the tests caught:** the document version did not advance on a
  join (the change check compared the mutated room against itself); the host could
  not ready up once the opponent joined (the screen hid the toggle when the room
  filled); and nothing in the UI ever triggered sign-in, leaving the lobby in
  `needsSignIn` with no way out.
- Tests: 12 room-code + 56 room-lifecycle + 7 auth + 18 lobby-controller + 9 widget
  = +38 overall, 1072 → 1110.
- `dart format --set-exit-if-changed lib test` → `Formatted 101 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `1110: All tests passed!`
- New-code coverage: `firestore_room_repository.dart` 98.08%, `room.dart` 98.72%,
  `in_memory_firestore_client.dart` 100%, `room_code_generator.dart` 100%,
  `online_lobby_screen.dart` 95.40%, `auth.dart` 93.75%,
  `online_lobby_controller.dart` 87.60%.
  **Three files at 0%** — `firebase_auth_gateway.dart` (new), and
  `cloud_firestore_client.dart` / `online_lobby_factory.dart` — all because they
  need a live Firebase platform. Not hidden; see Q-8.2.
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → byte-identical, 1,229,568 bytes, SHA-256 `6f1e3c05…`. `git diff`
  also confirms `game_spec.md`, `lib/domain/engine` and `lib/domain/models` are
  untouched.
- `tool/encoding/scan_mojibake.py` → `0 files with mojibake`

### Not verified against a real backend

**The Phase 7 console setup (Q-7.4) has not been done** — confirmed with the owner
and confirmed by the absence of `firebase_options.dart`, `google-services.json`,
`GoogleService-Info.plist`, `.firebaserc` and `firebase.json`. So the following are
unproven and should not be read as working: anonymous sign-in succeeding, the
`matches/{code}` document being readable and writable, `snapshots()` converging
between two real devices, the read-then-write race behaving as the
verify-after-write logic assumes, and a real `set()` being as atomic as an
in-memory map assignment. All Firestore tests ran against an in-process double
behind the same port. The manual steps remain those in `memory.md` §13o; running
them plus the emulator or two real devices is what closes the gap.

Security rules are still unwritten — `architecture.md` §12 lists what they must
enforce and `phase.md` assigns them to Phase 10, which can now write them against
a real document shape. Until then the client is trusted for room contents, which
`architecture.md` §12 explicitly says is not a sufficient long-term position.

Open: Q-8.1 (code alphabet is a reasoned default), Q-8.2 (`firebase_auth_gateway`
0% coverage), Q-8.3 (`RoomStatus.cancelled` has no producer), Q-8.4 (`reconnecting`
connection state deferred to Phase 9), Q-8.5 (no lobby visual design exists), Q-8.6
(`GameScreen` never disposes its controller — pre-existing), Q-8.7 (security rules
deferred to Phase 10). Q-7.1/Q-7.2 resolved; Q-7.3/Q-7.4/Q-7.5 restated in §13p.
Full record in `memory.md` §13p.

# Phase 8.1 — Random Matchmaking

Added by owner request after Phase 8 shipped (2026-09-27): players should also be
auto-paired with a stranger, with no room code, alongside the existing code-based
create/join room flow. Recorded as a deliberate, dated, owner-approved addition to
the plan rather than folded in silently — the same treatment
[`game_spec.md`](game_spec.md) v2.0.0 received for the crossing-wall rule.

## Goal

Allow a player to find an opponent automatically, without a room code.

### Tasks

- Quick Match entry point, alongside Create Room and Join Room.
- Matchmaking queue: join, wait, get auto-paired.
- Atomic, race-free pairing, so no two players are ever double-booked and no
  waiting player is matched twice.
- Cancel while waiting.
- On pairing, produce a `Room` in the same shape Phase 8 already defined, so
  everything downstream — ready state, match start, and Phase 9's move sync —
  works identically regardless of how the room was formed.

### Exit criteria

Two independent clients that both request Quick Match at roughly the same time are
reliably paired into a single shared room, with no possibility of one client being
matched into two different rooms, or of one being left permanently unmatched while
a compatible partner is waiting.

### Result — Phase 8.1 (2026-09-27)

Random matchmaking, plus a real bug fix found while building it. No game rule
changed; the spec checker and oracle vectors are untouched and still green.

- **The Part A fix first.** `FirebaseAuthGateway` resolved
  `fb.FirebaseAuth.instance` in its constructor's initializer list, which throws
  `[core/no-app]` on a build with no Firebase config — before any `try`/`catch`
  in the class could run. Since the `/online` route builds the gateway during
  route construction, tapping "Online Play" threw and the app silently did
  nothing. Auditing found **four** defects of that class, not one: the
  constructor, plus unguarded `_auth` reads in `current()`, `currentUid()` (the
  resolver every repository is handed) and `authStateChanges()` (a `Stream`, so
  the `Future`-shaped guards never applied). All four fixed via a cached lazy
  getter, mirroring `CloudFirestoreClient`'s Phase 7 fix. A repo-wide `.instance`
  audit found no other instance.
- **Why Phase 8's suite missed it:** every Phase 8 test injected a fake gateway,
  so the real zero-argument path was never executed. The 0% coverage was recorded
  as a known gap — but recording a gap is not the same as the gap being safe, and
  a constructor is code. The new regression test builds the real gateway with no
  Firebase app and asserts the whole surface is total, and asserts its own
  premise so it cannot go vacuous.
- **Storage:** `matchmaking/{boardKey}/waiting/{uid}` for the queue and
  `matchmaking/{boardKey}/matched/{uid}` for the "you have been matched" record.
  The queue entry's document id *is* the uid, so one entry per player per board
  and re-queuing is idempotent.
- **Race-free pairing, and the reasoning rather than the claim.** The claim is a
  transaction that re-reads the candidate, so a lost race aborts and retries. The
  subtle part: that one transaction writes *both* participants' `matched`
  documents, which are the mutual-exclusion token. Two clients claiming each other
  simultaneously both write the same two documents, so Firestore detects a
  write-write conflict, aborts one, and the re-run sees itself already matched and
  backs off. Tested with simultaneous `Future.wait` calls, repeated 20 times with
  a fresh store each round.
- **An SDK constraint that shaped the design:** `cloud_firestore`'s
  `Transaction.get` takes only a `DocumentReference` and **cannot run a query**.
  Candidate discovery is therefore a query outside the transaction, and the
  transaction re-reads the single chosen candidate to confirm it is still
  claimable. The commit, the part that must be atomic, still is.
- **No new manual Firebase console step.** An equality filter plus an `orderBy`
  on a different field needs a *composite* index, which is a manual console step
  or a Blaze-plan deploy that `architecture.md` §10 rules out. Partitioning the
  queue by board config **in the path** reduces the only query needed to a bare
  `orderBy` + `limit`, served by the automatic single-field index. Verified
  against Firestore's indexing documentation, not assumed.
- **Compatibility scope:** exact `BoardConfig` match only. No source document
  specifies configurable online match settings, so this is a recorded ledger
  decision (Q-8.9), not a silent simplification — and it avoids pairing players
  onto a board size they did not choose.
- **Abandoned entries:** entries carry `queuedAt`, and any entry older than 60
  seconds is reaped before it can be claimed, so a player who closed the app
  cannot be "matched" into a room where nobody shows up. 60 seconds is a reasoned
  default (Q-8.10) and is injectable. Malformed entries are reaped too.
- **Same room, same flow.** A matched pair lands in the identical `Room` at the
  same `matches/{code}` path with the same serialised shape as a code room.
  `RoomRepository` is untouched: ready state, match start and Phase 9's move sync
  all run through the existing Phase 8 code. The player who was already waiting
  becomes the host in Blue, matching a code room's convention.
- **Two defects the tests caught:** the claimer never removed its *own* queue
  entry, leaving it seated in a room and still in the queue for someone else to
  pair with; and a player who lost a race was told matchmaking had failed, when
  the truthful answer — and the reachable one — is "still waiting".
- Tests: 12 gateway + 7 route navigation + 29 matchmaking + 12 interleaving and
  transaction mechanics + 11 quick-match controller/full flow + 7 quick-match
  screen = +78 overall, 1110 → 1188.
- `dart format --set-exit-if-changed lib test` → `Formatted 108 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → `1188: All tests passed!`
- New-code coverage: `firestore_matchmaking_repository.dart` 100%,
  `in_memory_firestore_client.dart` 100% (including the transaction and query
  paths), `room.dart` 100%, `room_code_generator.dart` 100%,
  `online_lobby_screen.dart` 96.46%, `firestore_room_repository.dart` 98.08%,
  `online_lobby_controller.dart` 93.83%, `matchmaking.dart` 93.75%,
  `auth.dart` 93.75%.
  `firebase_auth_gateway.dart` rose from **0% to 64.71%** thanks to the Part A
  tests. `cloud_firestore_client.dart` is at **2.56%** and now also carries the
  real `query` and `runTransaction` adapters, which need a live platform.
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors → byte-identical, 1,229,568 bytes, SHA-256 `6f1e3c05…`. `git diff`
  confirms `game_spec.md`, `lib/domain/engine`, `lib/domain/models` and
  `lib/domain/serialization` are untouched.
- `tool/encoding/scan_mojibake.py` → `0 files with mojibake`

### Not verified against a real backend

**The Q-7.4 console setup is still not done**, so this phase adds a second Firestore
write path on top of an unverified transport. Unproven: that anonymous sign-in
succeeds; that the `matches/{code}` and `matchmaking/` documents are readable and
writable; that `snapshots()` on a queue partition converges between two real
devices; that a real transaction retries as often as the double's deliberately
strict conflict detection implies; and that the write-write conflict on the shared
`matched` documents behaves as the pairing argument assumes. All of it ran against
the in-process double behind the same port. The "no composite index" conclusion is
a documentation finding, not an observed one, and should be re-confirmed in the
Console when it is set up. Manual steps remain those in `memory.md` §13o.

Open: Q-8.8 (no feedback for the pairing moment), Q-8.9 (exact-config matching
only), Q-8.10 (60-second staleness window is a reasoned default), Q-8.11
(first-come-first-served, no skill rating), Q-8.12 (`matched` documents are never
deleted). Q-8.1 … Q-8.7 remain as recorded in §13p except Q-8.2, materially
improved. Full record in `memory.md` §13q.


---

# Phase 9 — Online Game Synchronization

## Goal

Synchronize turns reliably.

### Tasks

- Match state model.
- Turn number.
- State version.
- Move records where appropriate.
- Firestore listeners.
- Write validation.
- Duplicate move protection.
- Reconnection.
- Conflict handling.
- Match completion.

### Exit criteria

Two players can complete a match across devices.

---

# Phase 10 — Online Reliability and Security

## Goal

Harden the multiplayer system.

### Tasks

- Firestore rules.
- Match authorization.
- Turn ownership.
- Version checks.
- Invalid state rejection.
- Reconnection.
- Timeout/disconnect UX.
- Abuse-resistant room behavior.

### Important

Document the limits of Firestore-only enforcement.

If stronger authoritative validation is required later, reassess backend architecture and Firebase billing.

### Exit criteria

The online mode has documented security boundaries and robust failure handling.

---

# Phase 11 — Full UI/UX

## Goal

Complete all product screens.

### Screens

- Splash.
- Home.
- Game modes.
- Local.
- AI difficulty.
- Online lobby.
- Create match.
- Join match.
- Main game.
- Result.
- Tutorial.
- Profile.
- Settings.

### Exit criteria

Every major user journey can be completed without dead ends.

---

# Phase 12 — Audio, Haptics and Animation

## Goal

Add feedback without distracting from strategy.

### Tasks

- Pawn movement.
- Wall placement.
- Invalid action.
- Turn change.
- Victory.
- UI transitions.
- Sound effects.
- Background music.
- Haptics.
- Reduced-motion mode.

### Exit criteria

Animations are smooth and can be disabled/reduced where required.

---

# Phase 13 — Accessibility

## Goal

Make the game usable by a wider range of players.

### Tasks

- Color assistance.
- Labels for player identity.
- High contrast.
- Reduced motion.
- UI scaling.
- Screen-reader-friendly UI outside the board where practical.
- Clear error states.

### Exit criteria

The game does not rely only on red/blue color differences.

---

# Phase 14 — Responsive Web

## Goal

Make the web version feel intentional rather than stretched mobile UI.

### Tasks

Mobile:

- Touch.
- Responsive board.

Desktop:

- Centered board.
- Side information panels.
- Mouse interaction.

Tablet:

- Balanced hybrid layout.

### Exit criteria

Web layouts are usable at common viewport sizes.

---

# Phase 15 — Performance

## Goal

Optimize after the feature set is stable.

### Tasks

- Profile board rendering.
- Optimize rebuilds.
- Optimize animations.
- Optimize asset sizes.
- Reduce Firestore reads/writes.
- Test low-end Android.
- Test Web performance.

### Exit criteria

No obvious rendering, memory, or network bottlenecks.

---

# Phase 16 — Testing and QA

## Goal

Validate the complete product.

### Tests

- Unit.
- Widget.
- Integration.
- Game-engine stress cases.
- Firebase emulator tests where appropriate.
- Offline/online transitions.
- Responsive layouts.

### Manual testing

- Android.
- iOS.
- Chrome/Web.
- Tablet.

### Exit criteria

No known game-breaking bugs.

---

# Phase 17 — Release Preparation

## Goal

Prepare production builds.

### Tasks

- App icon.
- Splash.
- Package/bundle identifiers.
- Release signing.
- Firebase production configuration.
- Firestore production rules.
- Privacy documentation.
- Store metadata.
- Error reporting.
- Analytics only if required and privacy-appropriate.
- Production smoke test.

### Exit criteria

Production builds can be generated and tested.

---

# Phase 18 — Post-MVP

Potential features:

- Ranked mode.
- Matchmaking.
- Leaderboards.
- Player progression.
- Cosmetics.
- New boards.
- Replays.
- Spectator mode.
- Tournaments.
- Advanced AI.

Do not begin these until MVP stability is established.
