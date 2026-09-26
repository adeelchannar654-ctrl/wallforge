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
