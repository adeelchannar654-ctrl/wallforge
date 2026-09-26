# Wallforge — Project Memory

## Purpose

This file is the persistent project memory for Wallforge.

It records important decisions, current status, completed work, known constraints and the purpose of major project changes.

AI coding agents should read this file before continuing work.

---

# 1. Project Identity

**Name:** Wallforge

**Product:** Cross-platform two-player strategic board game.

**Platforms:**

- Android
- iOS
- Web

**Framework:**

- Flutter

**Backend:**

- Firebase

**Initial backend plan:**

- Firebase Spark/no-cost plan.

---

# 2. Core Game Concept

Two players compete on a grid.

Players:

- Blue
- Red

Each player has a limited number of walls.

On each turn:

- Move one legal step, OR
- Place one legal wall.

The first player to reach the opposite goal edge wins.

Walls change the available routes.

A wall may not create a state in which either player has no possible route to their goal.

---

# 3. Visual Direction Decision

IMPORTANT:

The board is NOT an isometric tabletop board.

The required visual direction is:

- Front-facing.
- Dark navy.
- Grid-based.
- Rounded board.
- Green goal area.
- Circular 3D blue/red player pieces.
- Blue/red rectangular walls.
- Subtle 3D depth.
- Shadows.
- Glow.
- Highlights.

The board should feel like a digital strategy arena with 3D-rendered pieces.

---

# 4. Stitch Decision

The Stitch design system in `stitch_wallforge_ui_design_system/` (design system "Tactical Neon Arena", 5 screens) is now the visual source of truth for production.

Decision (2026-09-21):

**The Stitch design system is the visual source of truth for production.**

The shipped Flutter app must look like these Stitch designs. This means:

- The app's colours, typography, spacing, radii, elevation, board layers, goal strips, pawns, walls, ghost walls, legal-move rings, inventory notches, logo and wordmark all follow the Stitch designs natively in Flutter.
- The app does NOT depend on the Stitch folder at build or run time (no HTML/Tailwind/CDN/PNG loading; native Flutter implementation).
- The Stitch folder stays in the repo as design reference only.

This reverses the earlier "do not use Stitch" decision. All project documents (PRD, rules, architecture, design) have been updated accordingly.

Stitch files referenced:

- `stitch_wallforge_ui_design_system/stitch_wallforge_ui_design_system/tactical_neon_arena/DESIGN.md` (tokens)
- `stitch_wallforge_ui_design_system/stitch_wallforge_ui_design_system/main_gameplay_screen/` (board measures)
- `stitch_wallforge_ui_design_system/stitch_wallforge_ui_design_system/wallforge_strategic_logo/` (logo SVG)
- Four other screens: splash, home_launcher, game_setup_modes

---

# 5. Current Documentation Set

The project documentation consists of:

```text
PRD.md
architecture.md
rules.md
phase.md
design.md
memory.md
game_spec.md
```

All seven files should remain consistent.

---

# 6. Architecture Decision

The game engine must be separated from UI.

The architecture is:

```text
Presentation
    ↓
Application
    ↓
Game Engine / Domain
    ↑
Repositories
    ↓
Local + Firebase
```

The game engine must not depend on Flutter UI or Firebase.

---

# 7. Game Engine Requirements

The engine must own:

- Board state.
- Player state.
- Pawn positions.
- Wall positions.
- Remaining walls.
- Turn.
- Legal moves.
- Legal walls.
- Pathfinding.
- Win detection.
- State transitions.

Logical coordinates must be used.

Never use pixel positions as game state.

---

# 8. Firebase Decision

Firebase is the initial online backend.

Use:

- Firebase Authentication.
- Cloud Firestore.

Optional later:

- Crashlytics.
- Cloud Messaging.

The project initially targets the Firebase Spark plan.

Important:

Spark quotas are limited.

Do not create unnecessary Firestore writes or reads.

---

# 9. Online Security Decision

The client must not be trusted.

Firestore Security Rules should constrain:

- Authentication.
- Match membership.
- Turn ownership.
- State structure.
- Version progression.
- Completed-match writes.

However, Firestore Security Rules are not a complete authoritative game server for complex pathfinding/game validation.

If strong competitive anti-cheat requirements emerge, revisit the backend architecture.

---

# 10. Current Development Status

## Phase 0 — Project Foundation: COMPLETE

## Phase 1 — Core Game Specification: COMPLETE

## Phase 1.1 — Specification Correction: COMPLETE
## Phase 1.2 — Second Specification Correction: COMPLETE
## Phase 1.3 — Third Specification Correction: COMPLETE
## Phase 1.4 — Fourth Specification Correction: COMPLETE
## Phase 2 — Game Engine Implementation: COMPLETE (commit c15d51a)

The engine core is implemented (commit `d6c7af2`) and hardened (commit `c15d51a`). Phase 2 is complete.

## Phase 3 — Board Rendering: COMPLETE (commits 81923b4 + 7f0a2a5)

The native Stitch-aligned board renderer, preview screen, geometry cross-checks, widget coverage, and goldens are complete. See §13h.

## Phase 4 — Interactive Local Game: COMPLETE (Phase 4.1 verification 2026-09-25)

The local pass-and-play controller, responsive game screen, route configuration, wall feedback, result overlay, and application/game-screen tests are complete. See §13i.

## Phase 4.2 — Wall Hit Tolerance + Invalid-Ghost Clarity: COMPLETE (2026-09-26)

Wall taps snap to the nearest logical slot within a documented tolerance, and an invalid ghost can no longer be mistaken for a solid wall of either owner. See §13j.

See §13b, §13c, §13d, §13e, §13f, §13g, §13h, §13i, and §13j below for the Phase records.

### Completed (Phase 0 + Phase 1 + Phase 1.1 + Phase 1.2 + Phase 1.3 + Phase 1.4)

- All Phase 0 items (see §13a).
- Frozen game specification in `game_spec.md` (v1.0.4, corrected four times).
- Board size, start positions, goal edges, movement, wall rules, path
  preservation, win condition, turn transition, and pawn-jump behavior all
  formalized with deterministic answers.
- 18 decisions (D-01 through D-18) documented in Decision Log.
- 15 project-specific rules in `rules.md` preserved. New Rule 16 added
  (game_spec.md is single source of truth).
- Documentation cross-references updated (PRD, rules, architecture, phase,
  README, domain README).
- Phase 1.1 corrected 10 defect categories (1.1–1.10):
  - Wall blocking table: both anchors per direction.
  - Board diagram: all rows labeled.
  - Example 17: route corrected (old path crossed blocked edge).
  - Example 18: replaced with verified sealed-pocket example.
  - Test catalog: exact expected results for pathfinding and wall tests.
  - Coverage matrix: updated for corrected test IDs.
  - D-18: jump-failure classification taxonomy added.
  - R-NOLEGAL-01: proof strengthened.
  - Added: Decision Log, Open Questions, Out of Scope, Phase-1 Task Mapping,
    Scripted Game, Finished-State JSON sections.
- Phase 1.2 corrected 12 defect categories (2.1–2.12):
  - Board ASCII diagram: row 0 = Blue GOAL, row 8 = Red GOAL.
  - Invalid in-progress states fixed (Example 4, T-MOVE-003/004, T-WIN-002/003).
  - Vague test descriptions replaced with exact values.
  - Coverage matrix: all "Implicit"/"Argument-based" entries replaced with explicit test refs.
  - R-NOLEGAL-01 proof rewritten (route existence + legal move, not wall action type).
  - §3.4 R-MOVE-03 reworded (MUST NOT instead of ambiguous MUST).
  - Examples 3a/3b added for second-anchor blocking.
  - Scripted game rewritten — 17 actions ending in Blue win.
  - D-18 clarified, Open Questions cleaned up.
  - Reference model built: 125 tests, all PASS.

### Not yet completed

- AI.
- Firebase integration.
- Online rooms.
- Online synchronization.
- Complete product UI/UX.
- Local persistence.
- Audio.
- Haptics.
- Production QA.

---

# 11. Immediate Next Work

The recommended next implementation order is:

1. Finalize detailed game rules. (DONE - Phase 1)
2. Create Flutter project. (DONE - Phase 0 complete and verified)
3. Create domain models. (DONE - Phase 2)
4. Implement game engine. (DONE - Phase 2)
5. Implement BFS/pathfinding. (DONE - Phase 2)
6. Implement wall validation. (DONE - Phase 2)
7. Write engine tests. (DONE - Phase 2)
8. Build board renderer. (DONE - Phase 3)
9. Build interactive local mode. (DONE - Phase 4/4.1/4.2)
10. Build AI.
11. Add local persistence.
12. Configure Firebase.
13. Build online rooms.
14. Build online synchronization.
15. Complete UI.
16. Polish.
17. QA.
18. Release.

---

# 12. AI Continuation Rules

When an AI agent continues this project:

### First

Read:

```text
PRD.md
architecture.md
rules.md
phase.md
design.md
memory.md
game_spec.md
```

### Then

Inspect the existing source code and tests.

### Before changing rules

Explain the proposed rule change and update documentation.

### Before adding dependencies

Explain why the dependency is necessary.

### Before changing architecture

Update `architecture.md`.

### After completing a phase

Update this `memory.md`.

---

# 13. Do Not Assume

AI must not assume:

- A screenshot is an exact technical specification.
- Firebase rules can perform arbitrary server-side game logic.
- Client-side validation is sufficient for competitive security.
- A package is compatible with every target without checking.
- A game rule exists merely because it is common in similar games.

When something is undefined, mark it as a decision that must be made rather than silently inventing a rule.

---

# 13a. Phase 0 Record (Project Foundation)

Status: **complete and verified.**

Decisions and facts established in Phase 0:

- Flutter project identifier: `wallforge`; application display name:
  `Wallforge`.
- Supported targets: Android, iOS, Web. iOS was not compiled (Windows
  environment has no Xcode toolchain).
- Architecture boundary folders established as documented in `architecture.md`
  section 15: `lib/app`, `lib/core`, `lib/domain`, `lib/application`,
  `lib/data`, `lib/presentation`.
- The domain, application and data layers contain boundary README markers only.
  No game logic was implemented, because the rules are not yet frozen (Phase 1)
  and the engine belongs to Phase 2.
- The board rendering package and any state-management package were
  deliberately NOT introduced. Phase 0 uses plain Flutter `StatelessWidget` and
  `ThemeData` with a centralized `onGenerateRoute` router. This avoids
  committing to a framework before the game engine exists.
- No Firebase dependency was added and no Firebase configuration file exists.
  The application launches fully offline.
- Runtime dependencies are limited to `flutter` and `cupertino_icons`.
  Development dependencies are `flutter_test` and `flutter_lints`. No
  third-party runtime packages were added.
- A `.gitignore` was created that excludes Firebase configuration, service
  accounts, keystores and `.env` files. No secrets are committed.
- Environment limitation: `flutter doctor` reports Flutter on a non-standard
  `[user-branch]` channel. This is an environment property, not a project
  defect; builds and tests succeed regardless.
- The six documentation files were renamed to their canonical names
  (`PRD.md`, `architecture.md`, `rules.md`, `phase.md`, `design.md`,
  `memory.md`). No documentation content was otherwise deleted or rewritten.

---

# 13b. Phase 1 Record (Core Game Specification)

Status: **complete.**

Decisions and facts established in Phase 1:

- Created `game_spec.md` (v1.0.0, Frozen) as the canonical game rulebook.
- Board: configurable NxN (default 9x9, N odd, N >= 5).
- Players: Blue and Red. Blue starts at (8,4), Red at (0,4). Blue moves first.
- Goals: Blue reaches row 0; Red reaches row 8.
- Turn: exactly one action (move or wall), no pass, turnNumber starts at 0.
- Movement: 4-directional, wall-blocked edges, pawn jumping included.
- Jumping: straight jump + diagonal side-step when straight is blocked.
- Walls: 10 per player, horizontal/vertical, 2 cells long, on grid lines.
- Anchors: 0..7 on both axes for 9x9 board (total 128 wall slots).
- Overlap: same orientation walls offset by <= 1 are illegal.
- Crossing: H and V at same anchor are illegal.
- Path preservation: both players must always have a route; pawns ignored.
- Win: reaching own goal row wins immediately; game stops accepting actions.
- No draw/repetition rule in core spec (deferred).
- No-legal-action situation proven impossible with current rules.
- Canonical ordering: moves before walls, sorted by destination/anchor.
- Error taxonomy: 12 named failure reasons with deterministic precedence.
- Serialization contract (draft): JSON with schemaVersion field.
- Test catalog: 60+ test cases across 9 categories with coverage matrix.
- Documentation updates: PRD, rules (new Rule 16), architecture, phase,
  README, domain README all updated with cross-references.
- All 15 original project-specific rules preserved.

### What was NOT done

- No Dart code was written (Phase 2 boundary).
- No new dependencies added.
- No Firebase or presentation code touched.
- Open questions deferred (not resolved): Q-01 (draw/repetition),
  Q-02 (board edge behavior for wall anchors at N-2), Q-03 (turn limit).

---

# 13c. Phase 1.1 Record (Specification Correction)

Status: **complete.**

Defects corrected in `game_spec.md` (v1.0.0 → v1.0.1):

| Defect | Description | Fix |
|--------|-------------|-----|
| 1.1 | Wall blocking table showed only one anchor per direction | Added both anchors with edge-case notes |
| 1.2 | Board ASCII diagram missing row labels on odd rows | All 9 rows now labeled |
| 1.3 | Example 17 Blue route crossed a blocked edge | Corrected to route via (5,5)->(4,5) |
| 1.4 | Example 18 used 5 overlapping invalid walls | Replaced with verified H(7,0)+V(7,1) sealed pocket |
| 1.5 | Test catalog had vague results | Exact expected results for T-PATH-002/004, T-WALL-011/012 |
| 1.6 | Coverage matrix referenced wrong test IDs | Updated for corrected T-JUMP-004 |
| 1.7 | No jump-failure classification taxonomy | D-18 added to Decision Log |
| 1.8 | R-NOLEGAL-01 proof was weak | Strengthened with explicit path-preservation dependency |
| 1.9 | Missing sections | Added Decision Log, Open Questions, Out of Scope, Phase-1 Task Mapping, Scripted Game, Finished-State JSON |
| 1.10 | Minor consistency issues | Fixed throughout |

All examples and test results verified by Python reference script (`tool/spec_verification/verify_game_spec.py`).

### What was NOT changed

- No game rules changed — all corrections are text/table/example/test accuracy.
- No Dart code touched.
- No new dependencies.
- Decision D-18 is a taxonomy clarification, not a rule change.

---

# 13d. Phase 1.2 Record (Second Specification Correction)

Status: **complete.**

Defects corrected in `game_spec.md` (v1.0.1 → v1.0.2):

| Defect | Description | Fix |
|--------|-------------|-----|
| 2.1 | Board ASCII diagram had row 0 = Red GOAL, row 8 = Blue GOAL (backwards) | Corrected: row 0 = Blue GOAL, row 8 = Red GOAL |
| 2.2 | Invalid in-progress states (Example 4 Blue at row 0, T-MOVE-003/004 Blue at row 0, T-WIN-002 Blue at row 0, T-WIN-003 Red at row 1) | Fixed pawn positions to valid in-progress states |
| 2.3 | Vague test descriptions (T-PATH-002/003/005/006) | Replaced with exact values verified by reference script |
| 2.4 | Coverage matrix had "Implicit"/"Argument-based" entries | All replaced with explicit test ID references |
| 2.5 | R-NOLEGAL-01 proof claimed wall action type exists even when rejected | Rewritten: relies on route existence + legal move |
| 2.6 | §3.4 R-MOVE-03 "No wall MUST separate" ambiguous | Reworded with MUST NOT clarification |
| 2.7 | No second-anchor blocking examples | Added Examples 3a (H second segment) and 3b (V second segment) |
| 2.8 | Scripted game (§15) had 10 actions, no win | Rewritten: 17 actions ending in Blue win |
| 2.9 | D-18 jump-failure taxonomy unclear | Clarified: straight checked first, diagonal only when straight unavailable |
| 2.10 | Open Questions stale (Q-02 already resolved) | Q-02 marked Resolved |
| 2.11 | No executable reference model | Built tool/spec_verification/verify_game_spec.py (125 tests, all PASS) |
| 2.12 | No verification output | Captured to tool/spec_verification/verify_output.txt |

All examples and test results verified by Python reference script (`tool/spec_verification/verify_game_spec.py`).

### What was NOT changed

- No game rules changed — all corrections are text/table/example/test accuracy.
- No Dart code touched.
- No new dependencies.

---

# 14. Documentation Maintenance

This file should be updated whenever:

- A major architecture decision changes.
- A phase is completed.
- A core rule is changed.
- A major dependency is added/removed.
- Firebase architecture changes.
- The visual direction changes.
- A major blocker is discovered.

Keep entries factual and concise.

---

# 15. Project Principle

The most important principle is:

> **Build a reliable strategy game first, then make it beautiful.**

Game correctness has priority over visual effects.

The visual system should make the rules easier to understand rather than hide them.


---

# 13e. Phase 1.3 Record (Third Specification Correction)

Status: **complete.**

Defects corrected in `game_spec.md` (v1.0.2 → v1.0.3):

- Removed verify_game_spec.py references which falsely claimed 125 passes.
- Fixed R-JUMP IDs and added R-BOARD-06, R-NOLEGAL-02 to matrix.
- Corrected invalid states where Red was on row 8 prematurely.
- Fixed wrong/vague tests (T-WIN-003, T-JUMP-006, T-WALL-013, T-DET-001).
- Added second-anchor and edge coverage tests.
- Clarified jump-failure taxonomy (D-18) and updated R-NOLEGAL-01 proof.
- Replaced scripted game and JSON with valid 17-action sequence.
- Restored full decision log and formatted open questions.

The independent consistency checker `tool/spec_verification/check_spec_consistency.py` was not yet committed in the repo at the time of v1.0.3, so the "passes" claim was not reproducible. The checker file was committed later.

### What was NOT changed

- No game rules changed.
- No Dart code touched.
- No new dependencies.

---

# 13f. Phase 1.4 Record (Fourth Specification Correction)

Status: **complete.**

Defects corrected in `game_spec.md` (v1.0.3 → v1.0.4):

| Defect | Description | Fix |
|--------|-------------|-----|
| 1.1 | T-JUMP-009 wrong (H(2,4) does not block jump) and duplicated | Deleted duplicate; replaced with verified T-JUMP-009..013 |
| 1.2 | R-WIN-05 matrix cited T-WIN-003 (stale after split) | Changed to T-WIN-003 and T-WIN-006 |
| 1.3 | Decision Log D-01..D-18 didn't match owner's table | Replaced with owner's canonical D-01..D-18 |
| 1.4 | R-NOLEGAL-01 missing property-test wording | Added "property test" to §3.9 and T-DET-005 |
| 1.5 | Stray test rows in coverage matrix section | Removed |

The independent consistency checker `tool/spec_verification/check_spec_consistency.py` passes with code 0 (`OK`). Real output committed to `check_output.txt`.

`dart format`, `flutter analyze`, and `flutter test` were NOT run — this was a documentation-only change.

### What was NOT changed

- No game rules changed.
- No Dart code touched.
- No new dependencies.

---

# 13g. Phase 2 Record (Game Engine Implementation)

Status: **complete** (commit `c15d51a`; historical Phase 2.1 baseline retained below).

### Files that actually exist

```text
lib/domain/wallforge_domain.dart              — barrel export
lib/domain/models/models.dart                 — model barrel
lib/domain/models/board_config.dart           — board geometry (9x9, 10 walls)
lib/domain/models/cell.dart                   — (row, column) coordinate
lib/domain/models/player_id.dart              — blue/red enum
lib/domain/models/wall_orientation.dart       — h/v enum
lib/domain/models/wall.dart                   — wall model (anchor, orientation, owner)
lib/domain/models/game_action.dart            — sealed GameAction (move | wall)
lib/domain/models/game_status.dart            — inProgress | finished
lib/domain/models/game_state.dart             — game snapshot
lib/domain/models/action_failure.dart         — 12-reason taxonomy
lib/domain/engine/engine.dart                 — engine barrel
lib/domain/engine/pathfinder.dart             — BFS route check
lib/domain/engine/move_generator.dart         — legal action generator
lib/domain/engine/action_validator.dart       — action validator
lib/domain/engine/game_engine.dart            — state transitions
lib/domain/serialization/serialization.dart   — serial barrel
lib/domain/serialization/game_state_serializer.dart — GameState JSON
```

### Test files that actually exist

```text
test/domain/spec_catalog_test.dart  — spec catalog (T-* IDs) coverage
test/domain/oracle_vectors_test.dart — cross-check against the oracle fixture
test/widget_test.dart               — minimal app shell widget test
```

### Spec conformance table (source of truth: `game_spec.md` v1.0.4)

| Concern | Spec | Dart symbol |
|---------|------|-------------|
| Board size / config | §2 (odd, >=5; default 9) | `BoardConfig` |
| Walls per player | §2 (default 10) | `BoardConfig.wallsPerPlayer` |
| Start cells (Blue bottom, Red top) | §3 R-BOARD-03 | `BoardConfig.blueStart`, `BoardConfig.redStart` |
| Goal rows | §3 R-BOARD-04 | `BoardConfig.blueGoalRow`, `BoardConfig.redGoalRow` |
| Coordinate order `(row, column)` | §3 R-BOARD-01 | `Cell` |
| Wall identity (anchor + orientation + owner) | §3 R-WALL-01 | `Wall` |
| Single action type (move or wall) | §4 / §5 | `GameAction`, `MoveAction`, `WallAction` |
| Current player from turn parity | §3 R-TURN-01 | `GameState.currentPlayer` |
| Match status | §3 R-WIN-01 | `GameStatus` |
| State JSON shape | §7.1 / §16 | `GameStateSerializer` |
| Failure reasons (12) | §5.1 | `ActionFailure` |
| Failure precedence | §5.2 | `ActionValidator` |
| Canonical action order | §3 R-ORDER-01 | `MoveGenerator` |

### Quality gates (real baseline, measured 2026-09-20, start of Phase 2.1)

| Gate | Command | Result |
|------|---------|--------|
| Formatting | `dart format --output=none --set-exit-if-changed lib test` | 11 files changed |
| Analyzer | `flutter analyze` | 165 issues found (mostly `prefer_const_constructors` infos; one `unused_element_parameter` warning) |
| Domain tests | `flutter test` | `+69: All tests passed!` |
| Spec checker | `python tool/spec_verification/check_spec_consistency.py game_spec.md` | `OK: spec is consistent with the reference engine.` |
| Oracle determinism | `python tool/spec_verification/gen_engine_vectors.py` vs fixture | byte-identical (1240761 bytes each) |

These gates are the honest starting point. Phase 2.1 must take format and analyze
to zero and add the missing per-rule tests before Phase 2 can be declared
complete. (An earlier version of this record claimed "Clean (24 files)",
"0 issues" and "79/79 pass" for files that do not exist; those claims were false.)

### Known gaps to close in Phase 2.1

- `GameStateSerializer.fromJson` returns `null` instead of a structured failure,
  and does not validate R-STATE-01..05 invariants. `BoardConfig` relies on
  `assert` (disabled in release). Action JSON (§7.2) is not implemented.
- `spec_catalog_test.dart` has 66 tests for 79 catalog rows; nine IDs are
  untested (T-JUMP-004, T-JUMP-010, T-MOVE-010, T-PATH-003, T-SERIAL-006,
  T-TURN-004, T-WALL-009, T-WALL-013, T-WIN-004) and some rows are batched.
- No `GameEngine.legalActions(GameState)` public helper; `GameState` exposes
  mutable collections; blocked-edge logic is duplicated across `pathfinder.dart`
  and `action_validator.dart`; BFS uses `queue.removeAt(0)`; unreachable branch
  in `GameEngine.apply`.

### What was NOT changed

- No game rules changed.
- No new dependencies added.
- `pubspec.yaml` and `analysis_options.yaml` untouched.

---

# 13h. Phase 3 Record (Stitch Design System + Board Rendering)

Status: **complete.** (Commits `81923b4` + `7f0a2a5`; Phase 4.1 verification 2026-09-25)

### Goal

Build the visual identity and board rendering, using the Stitch design system as the visual source of truth. Replace the Phase 0 shell with a real board preview screen.

### Design decision

Stitch design system (`stitch_wallforge_ui_design_system/`) is the visual source of truth for production. App built natively in Flutter, no runtime dependency on Stitch folder.

### Files created/modified (Phase 3)

```text
lib/app/app.dart                                  — Root MaterialApp with theme + router
lib/app/theme/app_colors.dart                     — Design tokens: colours
lib/app/theme/app_typography.dart                 — Design tokens: Inter family
lib/app/theme/app_spacing.dart                    — Design tokens: 4px module
lib/app/theme/app_radii.dart                      — Design tokens: corner radii
lib/app/theme/app_elevation.dart                  — Design tokens: shadows
lib/app/theme/app_theme.dart                      — ThemeData build
lib/presentation/board/board.dart                 — Barrel (exports geometry, painter, view, notches)
lib/presentation/board/board_geometry.dart         — Pure geometry — cellRect, wallRect, cellAt, wallAnchorAt
lib/presentation/board/board_painter.dart          — CustomPainter — grid, goal strips, tiles, walls, pawns, ghost, legal rings, glow, coord labels, goal strip labels
lib/presentation/board/board_view.dart             — StatelessWidget wrapping Painter + GestureDetector hit-testing
lib/presentation/board/wall_inventory_notches.dart — Notch display widget
lib/presentation/screens/board_preview/board_preview_screen.dart — Main preview screen
lib/core/constants/app_info.dart                   — App name/tagline
test/presentation/board/board_geometry_test.dart   — 73 geometry tests
test/presentation/board/board_golden_test.dart     — 5 golden tests
test/presentation/board/board_view_widget_test.dart — 219 widget tests (14 original + 200 seeded random)
test/presentation/board/wall_geometry_cross_check_test.dart — 10 wall↔engine cross-check tests
test/presentation/board/goldens/                   — 5 golden PNGs
```

### Source ledger

| Design value | Source | File |
|---|---|---|
| Player 1 = Blue = cyan `#00E5FF` | DESIGN.md §Colors + game_spec.md D-03/D-04/D-05 | `lib/app/theme/app_colors.dart` |
| Player 2 = Red = crimson `#FF4B6E` | DESIGN.md §Colors + game_spec.md D-03/D-04/D-05 | `lib/app/theme/app_colors.dart` |
| Tile colour `#17233F` | main_gameplay_screen/code.html L89,91 | `lib/presentation/board/board_painter.dart` |
| Groove `#2C3A5C` | main_gameplay_screen/code.html L89 (grid gap bg) | `lib/presentation/board/board_painter.dart` |
| Grid surface `#090E19` | main_gameplay_screen/code.html L89 | `lib/presentation/board/board_painter.dart` |
| Background `#0E131E` | DESIGN.md §Colors `surface` | `lib/app/theme/app_colors.dart` |
| Board outer `#0E1526` | main_gameplay_screen/code.html L76 | `lib/presentation/board/board_painter.dart` |
| Goal emerald `#10B981` | DESIGN.md §Colors `tertiary` | `lib/app/theme/app_colors.dart` |
| Goal strip gradient | main_gameplay_screen/code.html L81 (20%→80%→20%) | `lib/presentation/board/board_painter.dart` |
| Board corner radius 16px | main_gameplay_screen/code.html L76 `rounded-2xl` | `lib/presentation/board/board_painter.dart` |
| Tile corner radius 6px | DESIGN.md §Shapes, code.html L91 `rounded` | `lib/presentation/board/board_painter.dart` |
| Pawn gradient (P1) | main_gameplay_screen/code.html L168 `from-[#d9fbff] via-[#00daf3] to-[#004f58]` | `lib/presentation/board/board_painter.dart` |
| Pawn gradient (P2) | main_gameplay_screen/code.html L120 `from-[#ff8fa3] via-[#e6004c] to-[#67001f]` | `lib/presentation/board/board_painter.dart` |
| Pawn specular | code.html L169-170, DESIGN.md §Elevation | `lib/presentation/board/board_painter.dart` |
| Pawn contact shadow | code.html L166, DESIGN.md §Elevation | `lib/presentation/board/board_painter.dart` |
| Wall bevel catchlight | code.html L214-215, DESIGN.md §Elevation | `lib/presentation/board/board_painter.dart` |
| Wall corner radius 4px | DESIGN.md §Shapes "4px corner radius" | `lib/presentation/board/board_painter.dart` |
| Ghost wall 35% valid, crimson 50% invalid | DESIGN.md §Components | `lib/presentation/board/board_painter.dart` |
| Legal move ring | main_gameplay_screen/code.html L146-148, DESIGN.md §Components | `lib/presentation/board/board_painter.dart` |
| Active glow P1 `rgba(0,229,255,0.5)` | DESIGN.md §Elevation | `lib/presentation/board/board_painter.dart` |
| Active glow P2 `rgba(255,75,110,0.5)` | DESIGN.md §Elevation | `lib/presentation/board/board_painter.dart` |
| Notch 6×12px, lit = player colour | main_gameplay_screen/code.html L257-267 | `lib/presentation/board/wall_inventory_notches.dart` |
| Coordinate label `9px mono 30% opacity` | main_gameplay_screen/code.html L91 | `lib/presentation/board/board_painter.dart` |
| Coordinate naming `a1=(size-1,0)` | main_gameplay_screen/code.html L203-211 | `lib/presentation/board/board_painter.dart` |
| Inter font family | DESIGN.md §Typography, code.html | `pubspec.yaml` |
| Tabular figures for numerics | DESIGN.md §Typography | `lib/app/theme/app_theme.dart` |
| Spacing 4px module | DESIGN.md §Spacing | `lib/app/theme/app_spacing.dart` |
| Radii: 4,8,12,16,24,9999 | DESIGN.md §Rounded | `lib/app/theme/app_theme.dart` |
| Max board 420px mobile, 640px desktop | DESIGN.md §Layout | `lib/presentation/board/board_view.dart` |
| Min touch target 44×44px | DESIGN.md §Layout | `lib/presentation/board/board_geometry.dart` |
| P1 goal = row 0 (top), P2 goal = row size-1 (bottom) | game_spec.md §3 | `lib/presentation/board/board_painter.dart` |
| P1 (Blue) starts bottom, P2 (Red) starts top | game_spec.md D-03/D-04 | `lib/domain/models/board_config.dart` |
| Wall H(r,c) blocks two edges | game_spec.md §3.6, BlockedEdges | `lib/presentation/board/board_geometry.dart` |
| Wall V(r,c) blocks two edges | game_spec.md §3.6, BlockedEdges | `lib/presentation/board/board_geometry.dart` |

### Visual-conformance checklist

| Stitch attribute | Status | Evidence |
|---|---|---|
| Front-facing dark navy grid | Yes | `board_painter.dart`; board geometry and five board goldens |
| Rounded board and recessed surface | Yes | `BoardPainter._drawBoardArena`; board goldens |
| Green goal strips | Partial | Goal strips render, but the token conflict between `#10B981` and `#5BE9AD` remains open |
| Blue pawn | Yes | Blue gradient, specular highlight, contact shadow; board goldens |
| Red pawn | Yes | Red gradient, specular highlight, contact shadow; board goldens |
| Blue/red walls | Yes | Wall gradients and bevel catchlights; board goldens |
| Ghost wall states | Yes | Valid/invalid alpha and colour paths in `BoardPainter`; Phase 4.1 game-screen goldens |
| Legal move rings | Yes | `BoardPainter._drawLegalMoveRings`; board view widget tests |
| Active-turn glow | Yes | `BoardPainter._drawActiveGlow`; game-screen widget tests |
| Inventory notches | Yes | `wall_inventory_notches.dart`; desktop and mobile HUD tests |
| Coordinate labels | Yes | `BoardPainter._drawCoordinates`; board geometry tests and goldens |
| Inter typography and tabular numerals | Yes | Theme typography and numeric styles; game-screen goldens |
| Responsive composition | Partial | Phase 4.1 verifies mobile and desktop game layouts; broader responsive product work remains Phase 14 |
| Stitch gameplay HUD parity | Yes for Phase 4 scope | Player information, turn banner, board, mode toggle, wall counters, failure feedback, result overlay, restart/rematch |

### Open questions

- **Q-4.1 — Goal colour:** the Stitch references disagree between `#10B981` and `#5BE9AD`; the current token uses `AppColors.tertiaryContainer` (`#5BE9AD`). No rule decision is implied.
- **Q-4.2 — Result statistics:** `design.md` §21 requires statistics, but does not define which statistics or retention rules. Phase 4.1 shows only state-backed turn and remaining-wall values; persistence is deferred.
- **Q-4.3 — Wall orientation affordance:** the current board derives H/V from the tapped groove. A separate orientation selector may be preferable for accessibility, but no source defines its exact placement or interaction.
- **Q-4.4 — Settings persistence:** confirm-wall-placement currently resets with the controller; persistence is deferred to the settings/persistence phase.
- **Q-4.5 — Desktop hover feedback:** `design.md` §28 lists hover highlights, while Phase 4.1 verifies pointer/tap feedback; the exact hover treatment and accessibility behavior remain a later desktop polish decision.
- **Q-4.6 — Dense-board wall target (raised in Phase 4.2):** the Stitch minimum is 44×44 px, but a cell centre sits exactly half a cell from its two bounding grooves, so a 22 px radius cannot be honoured on boards where `cellSize/2 < 22.5` without capturing cell-centre taps. Phase 4.2 caps the radius at `cellSize/2 - 0.5 px` (39.9 px target on an 11×11 board rendered at 450 px). Open: raise the minimum rendered board size, add an explicit orientation selector, or accept the smaller target on dense boards. Related: Q-4.3.
- **Q-4.7 — Invalid-ghost colour token (raised in Phase 4.2):** Stitch `tactical_neon_arena/DESIGN.md` §Components specifies the invalid ghost as `#EF4444` at 50%, while the token actually in use is `AppColors.error` = `#FFB4AB` (Stitch front-matter `error`). The owner instruction for Phase 4.2 was to keep `AppColors.error`, so it was kept. Open: align the ghost with `#EF4444` or amend the Stitch prose.

### What is NOT built (deferred)

- HUD cards, turn banner, action controls (Phase 4/11)
- Chronometer/turn clocks (not in spec, Q-01/Q-03)
- Undo, hint, shortest-path stat (later phases)
- Splash telemetry (do not fake)
- Online/AI/timer/rating/undo UI (out of scope)

### Quality gates (real output, re-verified 2026-09-25)

| Gate | Command | Result |
|------|---------|--------|
| Formatting | `dart format --set-exit-if-changed lib test` | `Formatted 60 files (0 changed)` |
| Analyzer | `flutter analyze` | `No issues found! (ran in 13.8s)` |
| Tests | `flutter test` | `835: All tests passed!` |
| Build | `flutter build web` | `√ Built build\\web` |
| Spec checker | `python tool/spec_verification/check_spec_consistency.py game_spec.md` | `OK: spec is consistent with the reference engine.` |
| Oracle vectors | `gen_engine_vectors.py` compared with `test/fixtures/engine_vectors.json` | `IDENTICAL`; 1,240,761 bytes each |

The earlier Phase 4 commit message claimed 313 passing tests without application-layer tests. That historical claim is not used as the current baseline; the count above is from the final Phase 4.1 run.

### Phase 3 gap-closing steps (commit `7f0a2a5`)

- Step 0.1: Wall-geometry ↔ engine cross-check test (10 tests, all sizes 5/7/9/11)
- Step 0.2: Widget tests expanded to 219 (200 seeded random engine-played states × 4 viewports)
- Step 0.3: Goal strip labels ("P1 GOAL STRIP" / "P2 GOAL STRIP") on both goal strips

---

# 13i. Phase 4 Record (Interactive Local Game)

Status: **complete — Phase 4.1 correction verified 2026-09-25.** No Phase 5 work was started.

### Scope and architecture choice

Phase 4 remains a local pass-and-play mode. The implementation keeps the existing `lib/app/application` location rather than relocating it to `lib/application/game`; this is the current project convention and is now recorded consistently in the Phase 4.1 tests and documentation. The application controller imports `flutter/foundation.dart` only and delegates all rule decisions to the domain engine.

### Files created/modified

```text
lib/app/application/local_game_controller.dart       — ChangeNotifier controller and pending-wall validation state
lib/app/router/app_router.dart                       — Typed BoardConfig route argument with default fallback
lib/domain/engine/game_engine.dart                    — Public validation wrapper; no rule behavior change
lib/presentation/screens/board_preview/board_preview_screen.dart — Preset config navigation and narrow-width toggle wrapping
lib/presentation/screens/game/game_screen.dart         — Mobile/desktop controls, validity feedback, result overlay
lib/presentation/board/board_view.dart                 — Existing cell/wall callback surface used by GameScreen
lib/app/application/application.dart                  — Application barrel
test/application/local_game_controller_test.dart      — 317 controller/property tests
test/presentation/screens/game/game_screen_test.dart   — 13 GameScreen/router/widget tests
test/presentation/screens/game/game_screen_golden_test.dart — 3 golden tests tagged `golden`
test/presentation/screens/game/goldens/                — Mobile valid/invalid and desktop toggle goldens
test/presentation/board/board_hit_test.dart            — 12 hit-testing tests
```

### Controller API

| Member | Purpose |
|---|---|
| `LocalGameController(config:)` | Starts a match with a supplied `BoardConfig` |
| `startMatch(config:)` | Resets the match and presentation state |
| `restart()` / `rematch()` | Resets while retaining the current config |
| `setMode(InteractionMode)` | Switches MOVE/WALL and clears transient selection/pending state |
| `toggleConfirmWallPlacement()` | Switches immediate versus confirmed wall placement |
| `tapCell(Cell)` | Applies a legal move or records the engine failure |
| `tapWallSlot(Cell, WallOrientation)` | Sets a pending wall or applies immediately when confirmation is off |
| `pendingWallFailure` | Recomputes pending-wall legality through `GameEngine.validate` |
| `confirm()` / `cancel()` | Confirms only a currently valid pending wall, or cancels it |
| `dismissResult()` | Hides the finished-result overlay |
| `state`, `mode`, `selectedCell`, `pendingWall`, `lastFailure`, `showingResult`, `winner` | Read-only presentation/application state |
| `failureMessage(ActionFailure)` | Exhaustive switch over all 12 failure reasons |

### Phase 4.1 root causes and fixes

| Bug | Root cause | Fix |
|---|---|---|
| A — selected preset ignored | `BoardPreviewScreen` pushed `/game` without arguments; `AppRouter` always constructed the default controller | Pass `_state.boardConfig` as the named-route argument; read `BoardConfig` in the router and fall back to the default for deep links |
| B — desktop wall mode unavailable | `_buildDesktopLayout` omitted `_buildModeToggle`, while mobile included it | Reuse `_buildModeToggle` in the desktop center column above the shared action controls |
| C — invalid wall ghost looked valid | `GameScreen` hard-coded `WallPreview.isValid: true`; the controller exposed no pending-wall validation | Add `pendingWallFailure` backed by `GameEngine.validate`, render crimson invalid ghosts and the reason, disable Confirm, and make controller confirmation a safe no-op for invalid pending walls |

The desktop audit found no additional mobile-only wall inventory, failure-feedback, Restart, or Back control: those already use shared methods and both side rails render inventory notches. The result overlay was missing despite the Phase 4 victory task; it was added with state-backed turn/wall statistics plus Rematch and Home actions. The shared action row was changed to `Wrap` so a failure message and controls remain usable at narrow widths.

### P4 decision ledger

The earlier Phase 4 brief did not persist stable P4 IDs in this file. The following ledger records the same decisions under stable IDs; sources are the earlier Phase 4 implementation brief, this Phase 4.1 owner prompt, and the cited project documents.

| ID | Decision | Source |
|---|---|---|
| P4-1 | Local mode is two humans sharing one device; AI, online, timers, persistence, and rating remain out of scope | Earlier Phase 4 brief; `phase.md` Phase 4; this prompt §0 |
| P4-2 | The application controller coordinates user actions; widgets never own authoritative rules | `architecture.md` §2.1–2.3; earlier Phase 4 brief |
| P4-3 | Use one `ChangeNotifier` controller and `ListenableBuilder`; no new state-management dependency | `rules.md` §2.3 and §3.3; earlier Phase 4 brief |
| P4-4 | Gameplay legality, turn changes, and victory remain engine-owned | `game_spec.md` §§3–6; `architecture.md` §2.1–2.3; this prompt §0 |
| P4-5 | MOVE highlights legal destinations; WALL exposes logical wall-slot feedback | `design.md` §§10–11; earlier Phase 4 brief |
| P4-6 | Wall confirmation is enabled by default in the current controller; Cancel remains available | `design.md` §11 and §23; earlier Phase 4 implementation brief; revisit only through an explicit owner decision |
| P4-7 | Selected preview `BoardConfig` is the single source passed into the started match | This prompt Bug A; `board_preview_screen.dart` preset state |
| P4-8 | Mobile and desktop use separate compositions while sharing the same game state and controls | `architecture.md` §17; `design.md` §16; this prompt Bug B |
| P4-9 | Finished games expose a result state with Rematch and Home; statistics are limited to state-backed values | `design.md` §21; `phase.md` Phase 4 tasks |
| P4-10 | No engine rule changes, dependencies, or runtime Stitch access; quality gates and tests are mandatory | This prompt §0 and §3; `rules.md` §§3.2–3.3 |

### Tests and coverage

- `test/application/local_game_controller_test.dart`: 317 tests, including the 17-action §15 replay with exact §16 JSON, all 12 failure messages, wall validity cases, finished-state locking, and 300 seeded legal/illegal property games.
- `test/presentation/screens/game/game_screen_test.dart`: 13 tests covering mobile/desktop toggles, valid/invalid ghosts, disabled Confirm, failure feedback, result/Rematch/Home, Restart/Back, preview navigation, custom route config, default fallback, and the 768px desktop breakpoint.
- `test/presentation/screens/game/game_screen_golden_test.dart`: 3 `golden`-tagged tests for mobile valid wall, mobile invalid wall plus message, and desktop mode toggle.
- Targeted coverage run: 330 tests passed; `lib/app/application/local_game_controller.dart` 108/109 lines (99.08%), with only the unreachable wall-placement victory branch uncovered; `lib/presentation/screens/game/game_screen.dart` 180/180 lines (100%).

### Quality gates (real output, final Phase 4.1 run)

| Gate | Command | Result |
|------|---------|--------|
| Formatting | `dart format --set-exit-if-changed lib test` | `Formatted 60 files (0 changed)` |
| Analyzer | `flutter analyze` | `No issues found! (ran in 13.8s)` |
| Full tests | `flutter test` | `835: All tests passed!` |
| Targeted coverage | `flutter test --coverage test/application/local_game_controller_test.dart test/presentation/screens/game/game_screen_test.dart` | `330: All tests passed!` |
| Build | `flutter build web` | `√ Built build\\web` |
| Spec checker | `python tool/spec_verification/check_spec_consistency.py game_spec.md` | `OK: spec is consistent with the reference engine.` |
| Oracle vectors | `gen_engine_vectors.py` compared with fixture | `IDENTICAL`; generated and fixture sizes both 1,240,761 bytes |

### Owner acceptance script

Run these steps in Chrome after `flutter run -d chrome`:

1. Open the preview screen and select `Initial 7×7`.
2. Tap `START LOCAL MATCH`.
3. Confirm the game route shows a 7×7 board, with Blue at `d1` and Red at `d7`.
4. Resize to a wide desktop window. Confirm `PLAYER 1 | BOARD | PLAYER 2`, wall inventory notches, `MOVE`, `WALL`, `RESTART`, and `BACK` are visible.
5. Switch to `WALL`, tap an open wall groove, and confirm the valid ghost and enabled `CONFIRM` appear.
6. Confirm the wall. Confirm the turn changes and the wall inventory decreases.
7. Switch to `WALL` again and tap a crossing slot. Confirm the crimson ghost, `Wall crosses an existing wall.`, disabled `CONFIRM`, and working `CANCEL`.
8. Resize to a narrow browser window. Repeat steps 4–7; the MOVE/WALL control and valid/invalid feedback must remain usable.
9. Finish a scripted or manually won match. Confirm the result overlay, Rematch, and Home actions.
10. Use Restart and Back and confirm the expected reset/navigation behavior.

Manual verification completed on 2026-09-25 against the current Chrome build: steps 1–8 were exercised, including the 7×7 route, wide and narrow layouts, valid placement, and crossing-slot invalid feedback. The browser showed the expected state labels, turn/wall-count changes, crimson ghost, reason text, and disabled Confirm.

### Deferred and open

- No Phase 5 AI work was started.
- Local persistence, online play, clocks, undo, hints, audio, haptics, and rating remain deferred.
- Open questions are listed with the Phase 3 visual-conformance record above, especially the goal-colour token conflict and result-statistics definition.

---

# 13j. Phase 4.2 Record (Wall Hit Tolerance + Invalid-Ghost Clarity)

Status: **complete — verified 2026-09-26.** No Phase 5 work was started. No game rule changed.

## Confirmed root causes (from my own reading of the code)

**Bug D — wall hit-testing had no tolerance and no snapping.** The pre-fix
`BoardGeometry.wallAnchorAt` (`board_geometry.dart`, old lines 97-138) looped over
the horizontal grooves and then the vertical grooves and returned the first
rectangle that *exactly contained* the tap. There was no nearest-slot search and
no tolerance. The target band was `grooveWidth * 1.5` where
`grooveWidth = cellSize * 0.04`, so on the 640 px 9×9 board the band was ~4.3 px
tall and ~2.8 px wide. A tap a few pixels off returned `null`, and a tap that
drifted into a neighbouring band silently returned that neighbour's anchor.
`BoardView._handleTap` (`board_view.dart:104-120`) tested the wall slot first and
only then the cell, so a near-miss was also swallowed instead of falling through.

**Bug E — the invalid ghost had no pattern and no link to the conflicting wall.**
The pre-fix `BoardPainter._drawGhostWall` (`board_painter.dart`, old lines
307-329) drew every invalid ghost as a flat `AppColors.error` fill at 50% alpha
plus a 40%-alpha stroke, with no pattern. When the collision was with a wall of
the *same owner* the translucent crimson sat on top of the owner's solid bar, and
the two read as one shape. Nothing marked which placed wall was involved.

## Fixes

**D — nearest-slot snapping (`board_geometry.dart`).** The return type and
semantics are unchanged: `({int row, int col, WallOrientation orientation})?`.
- `_anchorCellIndex` keeps the pre-4.2 along-wall mapping
  (`floor((coord - padding) / cellSize)`, clipped to `0..boardSize - 2`) so each
  anchor stays centred on its own two-cell bar.
- `_nearestAnchorLine` finds the nearest interior grid line on the perpendicular
  axis (index = `line - 1`, clipped to the valid anchor range).
- The closer of the two lines decides the orientation; a tap farther than
  `wallHitTolerance` from both returns `null`, so a cell-centre tap is never
  reported as a wall slot and `BoardView` falls through to the cell.
- `GameScreen` now passes only the callback for the active `InteractionMode`
  (`game_screen.dart:126-131`), so wall snapping can never swallow a move tap
  and a move tap can never be read as a wall.

**E — invalid-ghost clarity (`board_painter.dart`).** The invalid ghost keeps the
DESIGN-specified 50% crimson fill and gains a white dashed centre line plus a
95%-alpha outline. A 2 px `AppColors.error` ring is painted *behind* every placed
wall whose rect overlaps the ghost, so the placed wall stays fully visible while
the conflict is still obvious. The highlight is purely geometric
(`Rect.overlaps`) and never decides legality; end-to-end touching walls do not
overlap and are not marked. `pendingWallFailure` from Phase 4.1 is still the only
source of validity.

## Phase 4.2 source ledger

| ID | Value / behaviour implemented | Source |
|----|--------------------------------|--------|
| P4.2-1 | Tolerance radius = 22 px (half of the 44×44 minimum target) | Stitch `tactical_neon_arena/DESIGN.md` §Layout & Spacing: "Interactive grid points, wall slots, and control pills require an absolute minimum hit-target clearance of 44×44px." `design.md` §26 and §28 contain **no** numeric minimum — the Stitch file is the only source. |
| P4.2-2 | Radius is capped at `cellSize / 2 - 0.5 px` | Own decision, forced by the requirement that a cell-centre tap is never captured: a cell centre sits exactly half a cell from its two bounding grooves, so any radius ≥ half a cell would capture it. The 0.5 px guard keeps an exactly centred tap outside the band. |
| P4.2-3 | The reachable target is `2 × wallHitTolerance` | Consequence of P4.2-2. 9×9 at 640 px → 22 px radius (44 px target); 9×9 at 450 px → 21.72 px; 11×11 at 450 px → 19.95 px (39.9 px target). Below the DESIGN minimum on dense boards — logged as **Q-4.6**. |
| P4.2-4 | An exact H/V distance tie resolves to horizontal | `game_spec.md` §3.10 R-ORDER-03 orders walls H before V; the pre-fix scan also tested H first. |
| P4.2-5 | A coordinate exactly between two parallel lines resolves to the higher line index | Deterministic rounding. No source defines it. |
| P4.2-6 | Along-wall anchor index = the cell containing the tap | Preserves the pre-4.2 mapping; keeps each anchor centred on its own two-cell bar. **Superseded by P4.3-1** — the claim that this "keeps each anchor centred" was wrong; see §13k. |
| P4.2-7 | Invalid ghost = 50% `AppColors.error` fill + white dashed centre line + 95% outline | Stitch DESIGN.md §Components "Wall Ghost" specifies only "Flashes intense translucent crimson (#EF4444) at 50%" and **no pattern**. A diagonal hatch was implemented first and rejected: at the rendered bar thickness (`grooveWidth * 1.5` ≈ 2.8-4.3 px) 1.5 px diagonal strokes merge into a solid fill. A dashed centre line stays legible at every board size and is independent of owner colour. |
| P4.2-8 | Conflict emphasis = 2 px `AppColors.error` ring behind each overlapping placed wall | `design.md` §11 and §29 specify no treatment. Smallest change that ties the failure to the existing segment without hiding it. |
| P4.2-9 | Mode-exclusive board callbacks | `design.md` §11 (wall feedback) and §28 (input); `architecture.md` §2.1 keeps input handling in presentation. |
| P4.2-10 | The prompt's claim that `design.md` §26 states a minimum touch target is **not** supported by the file | `design.md` read in full; the number exists only in the Stitch DESIGN.md (§Layout & Spacing). Recorded because the file wins over the prompt. |

## Tests added or updated

- `test/presentation/board/board_geometry_test.dart`: 102 tests (73 in the §13h record). New
  per-size cases for board sizes 5/7/9/11: tolerance derivation, every cell
  centre returns null, out-of-board returns null, every valid anchor resolves at
  its grid line, a tap up to 95% of the tolerance off the groove keeps the same
  anchor, the tolerance boundary is inclusive, the cell-centre band is null, a
  near-miss does not drift to the neighbouring groove, and the nearer of two
  equidistant grooves wins deterministically (H on a tie).
- `test/presentation/board/board_hit_test.dart`: 16 tests (was 12). New widget
  cases for a tap inside the tolerance, a tap beyond the tolerance falling
  through to the cell, a cell-centre tap never becoming a wall, and the owner's
  scenario end-to-end: a near-miss 90% of the tolerance from the conflicting
  groove still resolves to the same anchor and still reports `wallCrosses`.
- `test/application/local_game_controller_test.dart`: 321 tests (was 317). Legal
  touching walls stay valid through the engine — T-junction `V(4,3)` after
  `H(3,3)` (spec §8 Example 11), L-junction `V(3,4)` after `H(3,3)`, end-to-end
  `H(3,5)` after `H(3,3)` (Example 9) — plus a dedicated same-anchor
  opposite-orientation test asserting `wallCrosses` and a no-op confirm.
- `test/presentation/screens/game/game_screen_test.dart`: 15 tests (was 13). A
  move-mode tap inside the wall-snap range still moves the pawn, and a legal wall
  beside an existing wall still shows a valid ghost with Confirm enabled.
- Goldens: `board_invalid_ghost_same_owner.png` and
  `board_valid_ghost_beside_wall.png` added; `game_screen_mobile_crossing_own_wall.png`
  added; `game_screen_mobile_invalid_wall.png` deliberately regenerated for the
  new dashed treatment.

## Quality gates (real output, 2026-09-26)

| Gate | Command | Result |
|------|---------|--------|
| Formatting | `dart format --set-exit-if-changed lib test` | `Formatted 60 files (0 changed)` |
| Analyzer | `flutter analyze` | `No issues found!` |
| Full tests | `flutter test` | `876: All tests passed!` |
| Board coverage | `flutter test --coverage test/presentation/board` | `363: All tests passed!` — `board_geometry.dart` 70/70 (100%), `board_view.dart` 43/43 (100%), `board_painter.dart` 244/247 (98.79%; lines 508-510 are the pre-existing `selectedCell` / `showCoordinates` / `activeGlow` clauses of `shouldRepaint`), `wall_inventory_notches.dart` 0/27 (not exercised by this folder) |
| Build | `flutter build web` | `√ Built build\web` |
| Spec checker | `python tool/spec_verification/check_spec_consistency.py game_spec.md` | `Checked game_spec.md: 79 catalog rows, 65 rule IDs, 65 in matrix.` / `OK: spec is consistent with the reference engine.` |
| Oracle vectors | `gen_engine_vectors.py` vs `test/fixtures/engine_vectors.json` | `generated_bytes=1240761 fixture_bytes=1240761`, `FC: no differences encountered` |

`game_spec.md`, the spec checker, the vector generator, `test/fixtures/engine_vectors.json`,
`lib/domain/`, and `pubspec.yaml` were **not** modified.

## Browser verification (honest status)

- `flutter run -d chrome --web-port 7360` and `flutter run -d web-server --web-port 7370`
  both launched; the Phase 4.2 build loads and runs in Chrome at 1280×900.
- The new invalid-ghost treatment was confirmed rendering in the live browser:
  the owner's scenario state (Blue `H(6,5)` placed, pending `V(6,5)`) showed the
  dashed crimson ghost, the error ring around the Blue wall, the text
  "Wall crosses an existing wall." and a disabled CONFIRM
  (`C:\Users\User\AppData\Local\Temp\opencode\wf42-00-start.png`).
- **The tap-driven reproduction could not be completed.** Synthesized CDP pointer
  events reached Material buttons (preview CTA, MOVE/WALL toggle) but never the
  board's `GestureDetector`; pixel sampling at the exact groove coordinates showed
  no state change. The instance renders at `devicePixelRatio` 1.5 and neither CSS
  nor device coordinates resolved onto the board hit box, and a preceding
  `mouseMoved` did not help. This is a limitation of the automated input harness in
  this session, not evidence of a product defect: the same taps are simulated with
  real pointer events by `flutter_test` (`tester.tapAt`) in the 16 board hit tests,
  including the near-miss → `wallCrosses` case, and the visuals are locked by three
  goldens. Re-run by hand in a normal browser to close this out.

## Deferred and open

- Q-4.6 (dense-board target) and Q-4.7 (invalid-ghost colour token) are new.
- Q-4.1 to Q-4.5 remain open and unchanged.
- No Phase 5 work was started.

---

# 13k. Phase 4.3 Record (Cross-Axis Wall-Anchor Snapping)

Status: **complete — verified 2026-09-26.** No Phase 5 work was started. No game rule
changed. The owner's original complaint is reproduced on the pre-fix build and gone
after the fix, in a real browser.

## §1 diagnostic result: the hypothesis is CONFIRMED

The diagnostic sweep was written and run **before** any implementation change
(commit `ff9e15e`, test named `DIAGNOSTIC 4.3`). It swept the cursor across the full
rendered `wallRect` of one anchor, on the groove line, for both orientations, on all
four board sizes.

Result: **7 of the 8 sweeps failed.** For anchor `H(3,3)` on a 7×9-cell board
(`areaSize` 450) the real failure output was:

```
x=257.14 (t=4.00) -> (col: 4, orientation: WallOrientation.h, row: 3)
x=263.57 (t=4.10) -> (col: 4, orientation: WallOrientation.h, row: 3)
...
x=315.00 (t=4.90) -> (col: 4, orientation: WallOrientation.h, row: 3)
```

`t` is the fractional cell coordinate. The bar spans `t ∈ [3, 5)`; samples with
`t < 4` resolved to the intended anchor 3 and **every sample from `t = 4.00` to
`t = 4.90` — the entire second half of the bar — resolved to anchor 4, one column
to the right.** The V sweep showed the same drift on rows, plus the documented
orientation tie at exactly `t = 4.00`.

The 5×5 H sweep passed **only by accident**: `c = 3` is the last valid anchor on
that board, so the old clamp to `0..boardSize - 2` absorbed the drift. The bug was
present on every board size for any non-final anchor.

So `BoardGeometry._anchorCellIndex` was indeed doing a plain `floor()` on whichever
whole cell contained the tap, with no tolerance and no centring. `LocalGameController`
was re-read in full and is **not** at fault: `tapWallSlot` clears `_pendingWall`
correctly and `pendingWallFailure` calls `GameEngine.validate` with the right player
and orientation. The cause is purely the cross-axis coordinate mapping.

## Two corrections to the prompt's own suggestions (the files win)

- The prompt proposed `((coordinate - padding) / cellSize - 0.5).round()`. That is
  **algebraically identical to `floor(t)`** for the relevant range, so it would have
  changed nothing. The value that actually centres a two-cell bar is `round(t - 1)`,
  because a bar anchored at `c` has its centre at `c + 1`. Implemented that instead.
- The prompt asked the diagnostic to assert that *every* sample across the bar's
  **full rendered width** returns the same anchor. That invariant is geometrically
  impossible: adjacent bars overlap by one cell (`H(c)` spans `c..c+2`, `H(c+1)`
  starts at `c+1`), so no single anchor can own its whole 2-cell width. The permanent
  test asserts the achievable invariant — the bar's **central half**, `t ∈ [c+0.5,
  c+1.5)`, which is centred on the bar's visual midpoint — and that the midpoint
  itself resolves to the bar. This was reported rather than quietly dropped.

## The fix (`board_geometry.dart`, one function)

`_anchorCellIndex` now snaps to the nearest **bar span centre** instead of the cell
containing the tap:

```dart
final anchor = ((coordinate - padding) / cellSize - 1 + _anchorMidpointNudge).round();
```

- Ownership boundaries move to the midpoints *between* adjacent bar centres
  (`t = c + 1.5`) instead of arbitrary interior cell boundaries (`t = c + 1`).
- A bar now owns the right half of its first cell plus the left half of its second
  cell, so the whole central half — including the visual midpoint — is stable.
- Clamping to `0..boardSize - 2` is retained; no cross-axis `null` cutoff was added
  (see P4.3-4).
- `_nearestAnchorLine` and `wallHitTolerance` are **untouched** — no evidence showed
  the primary axis was defective, and the prompt scoped them out.

### A real float bug the new tests exposed

The first implementation used a bare `.round()` and broke
`every valid anchor resolves at its exact grid line` on board sizes **7 and 11 only**.
Cause: the fractional cell coordinate comes from a division, and `450 / 7` and
`450 / 11` are not representable in binary, so a value that is mathematically exactly
`k + 0.5` arrived as `k + 0.5 - 1e-15` and rounded **down**. Sizes 5 and 9 divide
exactly and were unaffected. Fixed with `_anchorMidpointNudge = 1e-9` of a cell
(~1e-7 px on a 640 px board, far below pointer precision), which only decides exact
ties. Locked by `ownership changes only at the midpoint between two bar centres`,
which asserts the exact boundary resolves to the higher anchor on all four sizes.

## Phase 4.3 source ledger

| ID | Value / behaviour implemented | Source |
|----|--------------------------------|--------|
| P4.3-1 | Cross-axis anchor = nearest bar span centre, `round(t - 1)`, clamped to `0..boardSize - 2` | `game_spec.md` §3.6 defines a wall anchor as covering **two** edges/cells, and `test/presentation/board/wall_geometry_cross_check_test.dart` asserts the bar's rect spans `c .. c + 2` against `BlockedEdges`. The span centre is therefore `c + 1`. **Supersedes P4.2-6.** |
| P4.3-2 | Ownership boundary = midpoint between adjacent bar centres; exact boundary → higher anchor | No source defines it. Smaller predictable behaviour: it is the perpendicular bisector of the two competing spans, so neither bar can steal the other's centre, and it is symmetric with the existing primary-axis rule (P4.2-5). |
| P4.3-3 | Midpoint ties are nudged by `1e-9` of a cell before rounding | Own decision, forced by measurement: without it the same tap resolved differently on board sizes 7 and 11 than on 5 and 9 (see above). Recorded so the constant is not "simplified" away later. |
| P4.3-4 | No cross-axis `null` cutoff; clamping to the valid anchor range is sufficient | Own decision, as the prompt required a justification. The cross-axis coordinate is only consulted *after* a primary-axis line has already won within `wallHitTolerance`, and a tap past the last valid anchor is outside the board or already resolved to another line. Adding a second radius would create a new dead zone for no gain. |
| P4.3-5 | A V bar's exact midpoint still resolves to horizontal | Unchanged from P4.2-4. A V bar's cross-axis midpoint lies exactly on a horizontal grid line, where both orientations are legal, so `R-ORDER-03` (H before V) still decides. Now explicitly tested. |
| P4.3-6 | Ghost rendering is unchanged | `BoardPainter._drawGhostWall` draws from the logical `WallPreview.anchor` via `wallRect` and does no coordinate math of its own, so the fix changes *which* anchor a tap resolves to, never where a ghost is drawn. Confirmed: all 891 tests, including 7 board and 4 game-screen goldens, pass with no golden update. |

## Before / after evidence for the owner's complaint

End-to-end regression in `test/presentation/board/board_hit_test.dart`, built through
`LocalGameController` (engine-backed, not hand-built state): Blue `H(6,3)` and Red
`H(6,6)` are placed, then Blue aims at the genuinely empty, legal `H(6,1)` (offset 2
from `H(6,3)`) from seven cursor positions across that slot.

- **Before the fix — 3 of 3 new tests failed.** `aiming across an empty slot
  footprint resolves to that slot`:
  `Expected (col: 1) / Actual (col: 2)`. `a real tap on the empty slot saves the
  wall` failed with a null-check on `pendingWall`, and `the transition zone is
  deterministic and stable` failed the same way.
- **After the fix — all pass**, `pendingWallFailure == null` at every one of the
  seven positions, and a real `tester.tapAt` on the bar's centre saves the wall and
  passes the turn.

### Real browser, before and after (headless Chrome, CDP)

The Phase 4.2 blocker was that synthesized CDP input never reached the board's
`GestureDetector`. That was solved this session by enabling Flutter's semantics tree
(`flt-semantics-placeholder`) so app state can be read as text, and dispatching real
`PointerEvent` pairs at the `flt-glass-pane` coordinates. The same pointer tap
sequence was run against a pre-fix build and the fixed build:

| Step (identical taps) | Pre-fix build | Fixed build |
|---|---|---|
| tap 1, row 4, `t = 3.5` | wall saved, turn passes | wall saved, turn passes |
| tap 2, row 4, `t = 2.3`, aiming at the empty bar centred at `t = 2.0` | **"Wall overlaps an existing wall."**, CONFIRM **disabled**, **not saved** | no failure, CONFIRM enabled, **saved** (Red 10 → 9), turn passes to Blue |

Further fixed-build checks: a bar-centre tap saved (Blue 10 → 9), and two more walls
placed at deliberately off-centre positions (`t = 2.3`, `t = 6.8`) both saved, ending
Blue 8 / Red 8. Screenshots: `wf43-prefix-repro.png` (pre-fix rejection) and
`wf43-fixed-after.png` (fixed, four walls on the board).

## Tests added or updated

- `test/presentation/board/board_geometry_test.dart`: 114 tests (was 102). Per size
  5/7/9/11: the H bar holds its anchor across the whole central half of its rendered
  width; the same for V (excluding the exact midpoint, which is the documented H tie,
  asserted separately in both directions); and ownership changes only at the midpoint
  between two bar centres, including the exact boundary.
- `test/presentation/board/board_hit_test.dart`: 19 tests (was 16). New
  `BoardView cross-axis anchor selection (Phase 4.3)` group: the empty-slot
  seven-position sweep asserting `pendingWallFailure == null`; transition-zone
  determinism and non-flap across five repeats; and a real `tester.tapAt` on the bar
  centre that saves the wall and passes the turn.
- `test/presentation/board/wall_geometry_cross_check_test.dart` and every other board
  test were read in full and need **no** change — none of them call `wallAnchorAt`.
- Goldens: **no update.** Nothing visual moved (P4.3-6).

## Quality gates (real output, 2026-09-26)

| Gate | Command | Result |
|------|---------|--------|
| Formatting | `dart format --set-exit-if-changed lib test` | `Formatted 60 files (0 changed)` |
| Analyzer | `flutter analyze` | `No issues found!` |
| Full tests | `flutter test` | `891: All tests passed!` (876 after Phase 4.2, +15) |
| Board coverage | `flutter test --coverage test/presentation/board` | `378: All tests passed!` — `board_geometry.dart` 70/70 (100%), `board_view.dart` 43/43 (100%), `board_painter.dart` 244/247 (98.79%, the same 3 pre-existing `shouldRepaint` clauses), `wall_inventory_notches.dart` 0/27 (not exercised by this folder) |
| Build | `flutter build web` | `√ Built build\web` |
| Spec checker | `python tool/spec_verification/check_spec_consistency.py` | `Checked game_spec.md: 79 catalog rows, 65 rule IDs, 65 in matrix.` / `OK: spec is consistent with the reference engine.` |
| Oracle vectors | `gen_engine_vectors.py` vs `test/fixtures/engine_vectors.json` | no diff, `git status --porcelain` clean; fixture still 1,240,761 bytes |

`game_spec.md`, the spec checker, the vector generator, `test/fixtures/engine_vectors.json`,
`lib/domain/`, and `pubspec.yaml` were **not** modified.

## Deferred and open

- Q-4.6 (dense-board target) and Q-4.7 (invalid-ghost colour token) remain open and
  unchanged. Q-4.1 to Q-4.5 remain open and unchanged.
- **Q-4.8 (new)** — the primary axis still snaps with a bare `.round()` in
  `_nearestAnchorLine` (P4.2-5) and therefore has the same exact-midpoint float
  fragility that P4.3-3 fixed on the cross axis. No test currently exercises a primary
  axis tie, so no failing test proves it is a defect, and the prompt scoped the primary
  axis out. Left unchanged on purpose; if a primary-axis tie ever needs to be
  guaranteed, reuse `_anchorMidpointNudge`.
- **Q-4.9 (new, prompt-vs-file)** — the prompt stated that every sample across a
  bar's *full* rendered width must resolve to that bar. That is impossible for
  overlapping two-cell spans; the implemented and tested invariant is the central
  half. Needs owner confirmation that the weaker invariant is acceptable.
- **Q-4.10 (new)** — the manual browser harness works only because Flutter's
  semantics tree is force-enabled, so state can be read as DOM text. Without it,
  board taps are still unverifiable through CDP. Worth capturing as a repeatable
  script if more manual browser verification is needed.
- No Phase 5 work was started.

---

# 13l. Part A Record — Rule change v2.0.0 (crossing walls are now legal)

Date: 2026-09-26. **Deliberate, owner-approved rule change — not a bug fix.**
No Phase 5 work was started.

## What changed

A horizontal wall `H(r,c)` and a vertical wall `V(r,c)` may now both exist at the
same anchor, forming a "+". Each still blocks exactly its own two edges
(R-WALL-05 / R-WALL-06 are untouched), so the pair blocks four distinct edges
around that corner. Rationale recorded in the changelog: denser, more tactical
wall play at intersections.

Unchanged and re-verified: same-orientation overlap (R-WALL-07 / D-11), anchor
bounds (R-WALL-04), inventory (R-WALL-10), path preservation (R-PATH-01), win
condition, turn order, jump rules, and the initial legal-action counts
(**3 moves / 128 walls**, pinned by the checker's own sanity assertion) — no wall
exists on the first move, so a crossing cannot arise there.

## IDs — verified in the file, not assumed

The brief said "verify the exact ID, do not assume". Confirmed by reading
`game_spec.md`: **R-WALL-08** was the crossing rule, **R-WALL-07** the
same-orientation overlap rule, **D-12** the crossing decision, **D-11** the
overlap decision, **T-WALL-007** the crossing catalog row, **Example 10** the
crossing worked example. D-12 was repurposed rather than deleted so D-01…D-18
numbering stays intact, and R-WALL-08 was rewritten rather than superseded so
§14 and the coverage matrix keep resolving.

## The `wallCrosses` fate decision — retired, not deleted

**Decision: keep `ActionFailure.wallCrosses` declared and documented as
retired/unreachable.** Justification:

1. The owner-supplied `test/fixtures/engine_vectors.json` and
   `gen_engine_vectors.py` — which must not be edited — still list `wallCrosses`
   in their `REASONS` table and still reserve its code `k`
   (`CODE = {r: chr(ord("a")+i) ...}`, so `wallOverlaps`='j', `wallCrosses`='k',
   `wallBlocksPath`='l'). Deleting the Dart enum value would desynchronise the
   engine from the independent ground truth I am required to match.
2. `wallBlocksPath` keeps code `l` only because `wallCrosses` still occupies `k`.
   Removing the enum without touching the fixture would invite exactly the kind
   of silent drift the oracle exists to catch.
3. It is part of the published §5 taxonomy surface; keeping it costs one
   documented enum member and makes a future reintroduction trivial.

So: removed from the **validation precedence chain** (§5.2, `ActionValidator`),
kept in the **declared** taxonomy (§5.1) marked unreachable, kept in the Dart
enum, and the controller's exhaustive `failureMessage` switch keeps its case with
a comment. Spec language now reads "12 named failure reasons, of which 11 are
reachable". Verified unreachable by an exhaustive test over every wall candidate
on the default board in a state that already contains a crossing pair.

## Engine changes (scoped to the one check)

- `action_validator.dart`: deleted the same-anchor opposite-orientation loop.
- `move_generator.dart`: **this was a second, easily-missed copy of the rule** —
  `_overlapsOrCrosses` pruned crossing candidates before the validator ever saw
  them. Renamed to `_overlaps` and the crossing branch removed, otherwise
  `legalActions` would still have hidden crossing walls from the player (and the
  oracle comparison would have failed).
- `blocked_edges.dart`: **no change needed**, as expected. It unions every
  wall's two edges into a set regardless of orientation, so a crossing pair
  blocks all four edges automatically. Re-verified by test through the engine's
  own `BlockedEdges`, not a re-derivation.
- `action_failure.dart` / `local_game_controller.dart`: documentation of the
  retired value only; no logic.

## Independent ground truth — before/after

| Check | Before | After |
|-------|--------|-------|
| `check_spec_consistency.py` vs unmodified spec | `2 PROBLEM(S)`: `[T-WALL-007] Then says wallCrosses but reference engine says legal`, `[Example 10] Result says wallCrosses, reference engine says legal` | `Checked game_spec.md: 80 catalog rows, 65 rule IDs, 65 in matrix.` / `OK: spec is consistent with the reference engine.` |
| `gen_engine_vectors.py` vs fixture | — | byte-identical, SHA-256 `6F1E3C05…94BA96`, 1,229,568 bytes both sides |
| Oracle vectors test | 114 games replaying under the old rule | 114 games replay **unchanged** against the new fixture with no test edit — the strongest evidence the engine matches the reference exactly |

`cmp` is not available on this Windows shell, so determinism was verified with a
raw-byte `cmd /c` redirect plus SHA-256 comparison; the first attempt via
PowerShell `>` produced a 2× file from UTF-16 re-encoding and was discarded as a
harness artefact, not a real difference.

## Tests

- `test/domain/crossing_walls_test.dart` (**new, 19 tests**): for sizes 5/7/9/11
  — the crossing pair blocks all four edges of the 2×2 corner (asserted via
  `BlockedEdges.fromWalls`, the engine's own function, and proven symmetric);
  the crossing placement validates and coexists with inventory/turn effects;
  all four same-orientation duplicate/offset cases still return `wallOverlaps`;
  path preservation still rejects a crossing that would seal a pocket; the
  crossing candidate is offered by `MoveGenerator` while the same-orientation
  duplicates are still pruned; both owners may hold one wall each at an anchor
  and a third is always `wallOverlaps`; plus an exhaustive proof that no input
  produces `wallCrosses`.
- `spec_catalog_test.dart`: T-WALL-007 rewritten to expect success; **T-WALL-014
  added** (`V(3,3)` exists → `W V 3,3` → `wallOverlaps`). T-WALL-004 already
  covered the H/H identical duplicate, so the new row deliberately covers the
  previously-untested V/V mirror rather than duplicating T-WALL-004.
- `worked_examples_test.dart`: Example 10 now expects success and asserts the
  full after-state.
- `cross_checks_test.dart`: the **independent naive validator** re-implemented the
  crossing rule; updated so the cross-check still tracks the engine.
- `local_game_controller_test.dart`: the two crossing tests now assert the new
  legal behaviour and that the wall saves and passes the turn; a new test keeps
  the same-anchor same-orientation duplicate asserting `wallOverlaps` and a
  no-op confirm. The 12-entry `failureMessage` map is unchanged (the enum value
  still exists, as decided).
- `board_hit_test.dart`: the Phase 4.2 tolerance test used a crossing wall as its
  conflict fixture. Rather than delete it and lose the Phase 4.2 coverage, it was
  **re-based onto a same-orientation neighbour** (identical tap geometry) and
  now asserts `wallOverlaps`. A **new** widget test covers the v2.0.0 behaviour
  through the real `tester.tapAt` path: tapping the crossing shows a *valid*
  ghost and saves.
- `game_screen_golden_test.dart` + golden: the `…_crossing_own_wall.png` golden
  depicted a now-impossible state, so it was **re-based onto an overlap**, renamed
  to `game_screen_mobile_overlap_own_wall.png`, and regenerated deliberately
  (only that one test, via `--update-goldens`) and visually reviewed. The other
  three game-screen goldens and all seven board goldens are byte-unchanged.
- Nothing was silently deleted; every re-based test carries a comment naming what
  changed and why.

## Open Questions

- **Q-2.1 (new)** — the owner-supplied fixture still declares
  `"specVersion": "1.0.4"` even though the spec is now v2.0.0. Harmless today
  because no test reads that field (the oracle test replays `games` only), and
  the file must not be edited, so it was left alone. If a future test starts
  asserting the version, the fixture needs regenerating.
- Q-4.1 … Q-4.10 from Phase 4 are unaffected by this change.
- Historical phase records above that state the old rule (e.g. §13h "Crossing:
  H and V at same anchor are illegal", Phase 4.1/4.2 browser notes) were
  deliberately **not** rewritten: they are dated records of what was true then.
  This section supersedes them.

---

# 13m. Phase 5 Record (Offline AI Opponent)

Status: **complete and verified 2026-09-26**, with one documented limitation that
needs an owner decision (Q-5.1). No game rule changed. No Phase 6 work started.

## Architecture

Placed in `lib/app/application/ai/`, matching the `architecture.md` layering
decision already taken in Phase 4 (§13i) that application code lives in
`lib/app/application` rather than `lib/application/game`.

| File | Role |
|------|------|
| `ai/ai_difficulty.dart` | The four levels: `searchDepth`, `candidateWidth`, `label`, `description`. |
| `ai/ai_evaluator.dart` | Static scoring of a position. Reuses `Pathfinder.shortestRouteLength`. |
| `ai/ai_opponent.dart` | Negamax search + candidate shortlist + loop guards. |
| `match_setup.dart` | Route argument: config + versusAi + difficulty. |

The AI depends only on the domain's public API and never on presentation, and it
**never bypasses validation**: candidates come from `GameEngine.legalActions` and
the chosen action is applied through `GameEngine.apply`, so the v2.0.0 crossing
rule applies to the AI exactly as it does to a human.

## Evaluation (the four `phase.md` "Version 1" inputs)

```
score = -1.0 x progress        (row distance to own goal; strictly monotone)
      - 0.5 x ownRouteLength   (detour preference + wall self-cost)
      + 1.0 x opponentRoute    (wall impact: this IS the blocking term)
      - 0.4 x wallsOwned       (architecture.md "wall cost")
      +/- 1000                 (immediate win / loss)
```

`progress` is the load-bearing term and was **not** in my first design, which used
route lengths only. That version never finished a single game: once the opponent
walls a detour in, the shortest route can *grow* while the pawn stands still, so
sideways shuffles and backward steps score equal to real progress and both sides
oscillate forever. Row distance cannot be increased by any wall, so anchoring on it
guarantees the AI keeps closing on its goal.

## Difficulty: depth-limited negamax, no randomness

| Level | Search depth | Candidate width | Measured move cost (9x9, 2 walls) |
|-------|--------------|-----------------|-----------------------------------|
| Easy | 0 | 6 | ~25 ms |
| Medium | 1 | 8 | ~25 ms |
| Hard | 2 | 10 | ~127 ms |
| Expert | 3 | 12 | ~1345 ms |

Each level is a strict superset: strictly greater depth *and* strictly wider
shortlist, ranked by the same evaluation, so a wider level can only add
candidates. Asserted by a test. No randomness, no clock, no time budget, so a
position always yields the same move (asserted by a determinism test).

Two bounding techniques keep it usable, both measured rather than guessed:
- **Progressive widening** — interior nodes halve the width (floor 4).
- **Interior wall-scan cap** of 16 candidates; the root still scans everything,
  since that is the decision actually played.
- Candidate scores are computed **once** and cached. Recomputing inside the
  comparator cost two BFS per comparison and made Expert 3x slower (13.0 s → 4.1 s
  after caching, → 1.3 s after the scan cap).

## A real bug found by measurement: the leaf perspective

The first working-looking search was **choosing its worst move**. In negamax the
leaf score must be from the *side to move's* perspective; mine was from the AI's
fixed perspective and the root then negated it, so the AI maximised the
*opponent's* score at every depth. It announced walls with visibly worse scores
than the best available move. Found by printing the score breakdown of the root
candidates rather than by reading the code again. This is the kind of defect that
looks like "the AI is just bad at this game".

## Termination: four mechanisms, and the one that works

`game_spec.md` Q-01 (draw / repetition rule) is Unresolved and explicitly says
"decide before Phase 5 (AI)", so the engine legitimately allows a position to
repeat forever and nothing forces a match to end. Four approaches were tried:

1. **Route-greedy only** — both sides oscillated vertically, then sideways.
2. **Penalise the cell just vacated** (asymmetric) — killed every 2-cell loop;
   survivors were 3-cell loops that stepped out and back without reversing.
3. **Penalise a symmetric set of visited cells** — failed outright. In a cluttered
   endgame the pawn often has 2-3 legal moves and *all* are already visited, so
   every candidate takes the same penalty, nothing is discriminated, loop
   continues. A symmetric penalty is structurally incapable of fixing a trap.
4. **Rank "unseen positions first", falling back to least-recently-seen** — this
   is what shipped, as a *ranking* rule rather than a penalty.

All four are documented in the code at the point of use so the next person does
not "simplify" one away.

### The one remaining stalemate (Q-5.1, needs an owner decision)

Enumerating all 48 combinations (sizes 5/7/9 x 16 pairings): **exactly one does
not terminate — 9x9 Hard vs Hard.** Root cause, measured: both Hard players spend
all ten walls early, then each is reduced to two or three legal moves every one of
which recreates a seen position. Passing is illegal, so a deterministic must-move
agent is trapped, and *no evaluation can escape it* because placing a wall is the
only thing that can change the position and no walls remain. Least-recently-seen
does not help: traversing a 3-cycle in reverse is the same cycle.

The correct fix is a repetition/draw rule, which is Q-01 and therefore the owner's
call — `rules.md` §10 forbids inventing a game rule. The test asserts the stalled
set equals an explicit allowlist (`{'9:Hard:Hard'}`), so this case cannot rot
silently and **any new stalling pairing fails the suite**. Raising `wallCost` from
0.1 to 0.4 (so walls are played only when they clearly pay) is what made every
other combination terminate.

## Tests

- `test/ai/ai_opponent_test.dart` (17 tests): evaluator units in isolation (own
  route length, opponent route length, wall impact positive/negative, immediate
  win/loss detection, score direction); difficulty superset + honest labels;
  legality on initial states for every size x difficulty x colour; legality across
  60 seeded games against a random opponent; determinism; null on finished match
  or wrong turn; all 36 AI-vs-AI matches legal with only the known stalemate
  persisting; self-play speed; the v2.0.0 crossing rule interacting with the AI;
  and the strength-ordering check.
- `test/application/ai_controller_test.dart` (6 tests): the AI replies after
  exactly the think delay, plays one legal action, passes the turn, keeps
  R-STATE-02 for Red, pass-and-play is unaffected, restart keeps opponent and
  difficulty, and the route accepts `MatchSetup` / bare `BoardConfig` / no argument.
- **Strength ordering: Expert beat Easy 4 / 0** over 4 games (5x5 and 7x7, both
  colour assignments). "Not worse" = win rate at least equal, asserted directly.
  This is a sanity check on a small deterministic sample, **not** an ELO-style
  proof, and is not claimed as one.
- Termination against a *random* opponent is deliberately **not** asserted: a
  random player can shuffle until the ply cap and that is not an AI defect.

## UI

Minimal, per `design.md` §20, which specifies only the four options, a brief
explanation, and no "perfect AI" claims. Added to the existing board-preview entry
screen (the project's real local-match entry point): a `START VS AI` button and a
`ChoiceChip` difficulty row with the description beneath. No new visual language —
same tokens (`AppColors`, `AppSpacing`, `AppTypography`) and the same
segmented/caption shape as the rest of the screen. The existing HUD already shows
whose turn it is, so the AI's turn is visible with no new component. See Q-5.2.

The AI thinks for **300 ms** before moving (`kAiThinkDelay`) so its turn is
visible and the UI does not appear to hang. `design.md` is silent on AI timing;
this is a recorded own decision.

## Quality gates (real output, 2026-09-26)

| Gate | Result |
|------|--------|
| `dart format --set-exit-if-changed lib test` | `Formatted 67 files (0 changed)` |
| `flutter analyze` | `No issues found!` |
| `flutter test` | `936: All tests passed!` (913 after Part A, +23) |
| AI + application coverage | `345: All tests passed!` — `ai_opponent.dart` 68/70 (97.14%), `ai_evaluator.dart` 48/50 (96%), controller 162/173 (93.64%) |
| `flutter build web` | `√ Built build\web` |
| `check_spec_consistency.py` | `Checked game_spec.md: 80 catalog rows, 65 rule IDs, 65 in matrix.` / `OK` |
| Oracle vectors | byte-identical, SHA-256 `6F1E3C05…94BA96` — **unchanged by Part B**, as required (no rule change) |

Controller coverage note: the 11 uncovered lines are pre-existing getters
(`winner`, `isFinished`, `legalMoveTargets`, covered by the presentation tests
that were outside this coverage run) plus 3 documented-unreachable branches — the
pre-existing wall-victory branch and the AI's defensive `!SuccessResult` guard.

## Open Questions

- **Q-5.1 (new, needs an owner decision)** — resolve `game_spec.md` Q-01 (draw /
  repetition rule) to close the 9x9 Hard-vs-Hard stalemate. Recommended default
  is unchanged from Q-01: 3-fold repetition. This matters well beyond self-play:
  in Phase 9 online play a deliberate replayer needs a rule, and a client-trusted
  one would not be acceptable.
- **Q-5.2 (new)** — `design.md` §20 specifies the AI options and their wording
  but no AI *screen*: no layout, no player card treatment, no "AI is thinking"
  indicator, no rematch/change-difficulty flow. The addition here is deliberately
  minimal and consistent with the existing HUD. A real AI mode screen is Phase 11
  UI work and was not invented here.
- **Q-5.3 (new)** — no time budget per move. Expert takes ~1.3 s of synchronous
  search on a 9x9 mid-game position (measured), run on a timer so no frame blocks.
  On a much slower device that could become user-visible; if so the fix is a node
  budget or a Web Worker, not a change to the evaluation.
- Q-4.1 … Q-4.10 and Q-2.1 remain open and unaffected.
- No Phase 6 work was started.
