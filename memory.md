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
  search on a 9x9 mid-game position (measured). **Correction (Phase 15,
  §13y):** the original wording "run on a timer so no frame blocks" was
  wrong — a timer only delays when synchronous work starts; once the
  search began, no frame could be produced until it returned (measured
  worst event-loop block 1.58 s on 9×9, 3.30 s on 11×11). Fixed in
  Phase 15: the search now yields between root candidates
  (`AiOpponent.chooseActionAsync`), bounding the worst block to one
  candidate's subtree (~150 ms / ~346 ms on the same VM), with choices
  bit-identical to the synchronous search. A node budget remains the
  fallback if owner device measurements ever demand one; the
  evaluation itself is unchanged.
- Q-4.1 … Q-4.10 and Q-2.1 remain open and unaffected.
- No Phase 6 work was started.

---

# 13n. Phase 6 Record (Local Persistence)

Status: **complete and verified 2026-09-26.** No game rule changed; the spec
checker and the oracle vectors are untouched and still green. No Phase 7 work
started.

## Storage approach — spec-derived, not my own default

`shared_preferences`. This was **not** a judgement call: `rules.md` §4 already
lists the package with exactly this purpose —

> ### shared_preferences — Purpose: Small local settings. Tutorial completion.
> Simple local preferences. *For larger local game storage, select a maintained
> local database only when requirements justify it.*

— which is the Phase 6 task list almost verbatim. The same entry's caveat about a
local database for *larger* storage was checked rather than assumed: settings are
a few hundred bytes and a single 9×9 mid-game `GameState` is roughly 1–2 KB, both
comfortably inside the "small local preferences" bucket. A full match *history*
would cross that line; it is not needed, and the largest thing stored is one
resumable match.

Package added to `pubspec.yaml` (`shared_preferences: ^2.3.2`). This is the first
runtime dependency beyond Flutter and `cupertino_icons`, and it is sanctioned by
`rules.md` §4 rather than being a new choice under §3.3.

## Architecture — the boundary was already specified

`architecture.md` §2.4 says repositories "expose domain-friendly interfaces to
the application layer", §14 says "Keep persistence behind repository interfaces.
Do not let UI widgets directly read/write storage", and `lib/data/README.md`
states the direction as `Data -> Domain interfaces`. So:

```
lib/domain/repositories/   interfaces + persisted shapes (pure Dart, no dart:io)
lib/data/local/            shared_preferences implementations + in-memory doubles
lib/app/application/       LocalGameController — depends on the interfaces only
```

`LocalGameController` imports `domain/repositories/repositories.dart` and has no
idea whether the bytes come from `shared_preferences` or, in Phase 7, from
Cloud Firestore. That is the whole point of the boundary and it is what makes the
Phase 7 swap a `pubspec`/implementation change rather than an application change.

Persistence is **opt-in** via `attachPersistence(...)`. With nothing attached the
controller performs no persistence at all, which is why the 328 pre-existing
controller/application tests needed no changes — a valuable property, and the
reason it was done this way rather than by giving every controller a store.

## What is persisted — and what is honestly not

Scope was verified against the code first. A grep for real user-facing toggles
found exactly two, and both are persisted:

| Persisted | Source in the app |
|---|---|
| `confirmWallPlacement` | `LocalGameController.toggleConfirmWallPlacement()`, shown in the game HUD |
| `aiDifficulty` | the difficulty `ChoiceChip` row on the entry screen |
| match results | derived from `GameStatus.finished` + `winner` |
| one unfinished match | `GameState` via the engine's own `GameStateSerializer` |

**Not persisted, deliberately:**

- **Tutorial completion** — there is **no tutorial in the app**. `design.md` §22
  tutorial UX is later UI work, and a grep for "tutorial" across `lib/` returns
  nothing. The flag exists in `AppSettings` as a documented, always-`false`
  placeholder so the persistence shape is complete for when a tutorial lands,
  rather than needing a migration later. Nothing sets it and no UI reads it — it
  is a reserved field, not a fake feature.
- **AI progress** — the Phase 5 AI is a **stateless** evaluator: no rating, no
  per-player model, no level unlocks, nothing learned across matches. There is
  nothing true to record, and inventing a skill rating would be fabricating a
  feature. `phase.md` says "AI progress **if introduced**"; it was not. The
  difficulty the player picks is a *setting*, not progress, and is stored as one.
- No theme / sound / haptics / accessibility settings — none of those exist yet.
- No match history, replays or rankings — no data source for them.

## Notable implementation decisions

- **`aiDifficulty` is stored as a validated string, not a parallel enum.**
  `AiDifficulty` lives in the application layer and the domain must not depend on
  it. Declaring a second enum in the domain would create two lists that must be
  kept in sync, and forgetting a fifth difficulty in one of them would silently
  fall back. `AppSettings.knownAiDifficulties` plus an explicit check cannot
  drift. `AppSettings.defaults` deliberately does *not* read that list, so the
  default can never be an unknown value.
- **Resuming reuses the engine's decoder.** `UnfinishedMatch.fromJson` calls
  `GameStateSerializer.fromJson`, so a saved state that violates a spec invariant
  is rejected by exactly the same code that rejects it anywhere else. A test
  feeds it a state with both pawns on one cell (R-STATE-01) and expects `null`.
- **Every repository method is total.** None of them throws: a missing key, a
  wrong type, unparseable JSON or a storage error all resolve to the documented
  default. A corrupt store must never stop the app starting.
- **Statistics attribution for pass-and-play.** With no AI the "human" is taken
  as Blue (the first player), and those matches are keyed under `"local"` rather
  than a difficulty name. `phase.md` does not define this, so it is recorded as
  Q-6.2 rather than presented as spec-derived.
- A finished match clears the resumable save, and the entry screen also clears a
  stale save whose state is already finished.

## Tests

- `test/data/persistence_test.dart` (29 tests): JSON round-trip for all three
  shapes; `MatchStatistics` win/loss recording and win rate; per-field fallback
  for malformed settings and statistics; malformed buckets dropped while good
  ones survive; `UnfinishedMatch` returning `null` for a bad board size, a
  non-map state, an unknown schema version and an invariant-violating state;
  `shared_preferences` implementations for save/reload/simulated-restart/clear;
  corrupt stored values degrading to defaults; and value semantics (`copyWith`,
  `==`, `hashCode`, `toString`) so equality bugs cannot cause flaky tests.
- `test/application/persistence_integration_test.dart` (9 tests): settings and
  difficulty surviving a restart; a **partial match saved, an app "restart"
  simulated with a brand new controller over the same stores, resumed, and play
  continuing legally**; a resumed AI match keeping its opponent and difficulty; a
  finished match not being resumable; statistics recorded for a human win *and* a
  human loss (both played as real alternating legal games, not hand-built
  states); no statistics mid-match; and a controller with no repositories
  attached performing no persistence without throwing.
- Three failures during this work were all **test-authoring** bugs, not product
  bugs, and are worth recording because the second is a genuine trap: an illegal
  tap does **not** pass the turn, so a single wrong cell in a scripted sequence
  makes every later tap move the *other* pawn. The helpers now only use verified
  orthogonal steps, and Blue's start cell differs per board size.
- Coverage of the new code: `in_memory_repositories.dart` 100%,
  `shared_preferences_settings_repository.dart` 100%,
  `shared_preferences_unfinished_match_repository.dart` 100%,
  `shared_preferences_statistics_repository.dart` 93.75% (one unreachable
  catch-path line).

## Quality gates (real output, 2026-09-26)

| Gate | Result |
|------|--------|
| `dart format --set-exit-if-changed lib test` | `Formatted 67 files (0 changed)` |
| `flutter analyze` | `No issues found!` |
| `flutter test` | `968: All tests passed!` (936 after Phase 5, +32) |
| Persistence coverage | `552: All tests passed!` on `test/data` + `test/application` + `test/domain` |
| `flutter build web` | `√ Built build\web` |
| `check_spec_consistency.py` | `Checked game_spec.md: 80 catalog rows, 65 rule IDs, 65 in matrix.` / `OK` — **unchanged, as required: no rule change in this phase** |
| Oracle vectors | byte-identical, SHA-256 `6F1E3C05…94BA96`, 1,229,568 bytes — **unchanged** |

`game_spec.md`, the spec checker, the vector generator, `test/fixtures/engine_vectors.json`
and `lib/domain/engine/` were **not** modified. The only new domain files are
pure data models and repository interfaces under `lib/domain/repositories/`, which
contain no rules.

## A process failure worth recording

While moving the Phase 5 result block in `phase.md` I used PowerShell
`Get-Content` + `WriteAllText` to do the edit. `Get-Content` defaults to the
system ANSI code page, not UTF-8, so the em-dashes and `§` in the file were
decoded as Latin-1 and written back as UTF-8 — double-encoding the whole file.
`flutter analyze` and `flutter test` were both still green, because the damage
was confined to comments and Markdown.

A repo-wide scan found **8 corrupted files**, including two already committed and
pushed in Phase 5 (`ai_opponent.dart` had been through three round-trips, so its
em-dashes were triple-encoded). They were repaired by reversing the mis-encoding
layer by layer, per line, verified by decoding every tracked `.md`/`.dart`/`.py`
file as UTF-8 and asserting no mojibake markers remain, then re-running format
and analyze. Repaired in commit `ee39281`.

The lesson for future phases: on this shell, edit Markdown and Dart sources with
the editor tools or an explicit UTF-8 read, never a bare `Get-Content`/
`Add-Content` round-trip, and scan for mojibake before declaring a phase done.

**Correction, found in Phase 7.** The Phase 6 repair did **not** actually finish
the job. Its per-line loop only *counted* a line as fixed when the reversed line
had zero markers left, but it wrote the file unconditionally — so lines that
reversed only partially were written back still containing mojibake. An
independent re-scan after `ee39281` found 10 residual instances of the
three-character sequence `U+00E2 U+20AC U+201D` (an em dash, UTF-8 `E2 80 94`,
decoded as CP1252) in doc comments in
`lib/app/application/ai/ai_evaluator.dart` (4) and
`lib/app/application/ai/ai_opponent.dart` (6). The original scan also missed them
because its marker set did not include the `U+00E2 U+20AC` lead pair that a
*truncated* sequence produces.
The replacement scan is committed at
`tool/encoding/scan_mojibake.py`. It differs from the first one by decoding
strictly, matching a much wider character class — the `U+00E2 U+20AC` pair and
its continuations, `U+00E2 U+201A`, the mis-encoded `U+00A7` / `U+00B0` /
`U+00B1` / `U+00A0` characters, `U+00C3`, the mis-encoded dashes and quotation
marks, and U+FFFD — excluding the read-only Stitch reference folder, and printing
each hit with `ascii()` so the console's own encoding cannot hide the evidence.
It reported `FILES_WITH_MOJIBAKE=2` before the fix and `RESULT: 0 files with
mojibake` after it; that output — not an assertion — is the confirmation.
`dart format` and `flutter analyze` remained green throughout, since the damage
was doc comments only.

Note for whoever runs the scan next: this paragraph deliberately names the
offending code points instead of reproducing the byte sequences, because a scan
that flags its own documentation can never report zero.

## Open Questions

- **Q-6.1 (new)** — should a *finished* match offer a "play again with the same
  settings" path that also pre-seeds statistics? Not implemented; the current
  resume affordance deliberately disappears once a match ends.
- **Q-6.2 (new)** — for pass-and-play, is attributing results to Blue (the first
  player) the right definition of a "win"? `phase.md` says "local statistics"
  without defining it, and with two local players there is no single human. The
  alternative would be per-seat records, which is more honest but more UI. Chose
  the simpler option and recorded it.
- **Q-6.3 (new)** — no AI progress is persisted, because the AI has none to
  persist (stateless evaluator, no rating). If a rating, opening-strength or
  adaptive difficulty is ever introduced, this schema is where it belongs.
- **Q-6.4 (new)** — the unfinished match is a single slot, last-write-wins.
  Multi-slot match history is deliberately not implemented and would be the point
  at which `rules.md` §4's "larger local storage" caveat starts to apply and a
  local database becomes justified.
- **Q-5.1** (resolve `game_spec.md` Q-01 to close the 9×9 Hard-vs-Hard AI
  stalemate) is unchanged and still open; persistence does not affect it, though
  the stalemate is now *resumable across a restart* rather than lost.
- Q-4.1 … Q-4.10, Q-2.1 remain open and unaffected.

---

# 13o. Phase 7 Record (Firebase Foundation)

## The honest headline

The code side of Phase 7 is done and tested; the project side is not, and cannot
be from here. The repository is required to ship **no** Firebase client config, so
every "register the Android/iOS/Web app" item on the task list is a manual Console
action. Writing a result that implied otherwise would be the actual failure here.

## Layering — the Phase 6 boundary paid for itself

`lib/data/remote/` implements the *same three interfaces* Phase 6 defined, so
nothing in `lib/app` needed to change shape. The evidence is
`test/application/firestore_controller_integration_test.dart`: it re-runs the
Phase 6 restart-and-resume scenarios verbatim against the Firestore repositories
and not one line of application code differs. That is the concrete payoff of
putting the interfaces in `lib/domain/repositories/` a phase earlier.

A narrow `FirestoreClient` port sits between the repositories and both the real
`CloudFirestoreClient` and the test `InMemoryFirestoreClient`. The port exists
because the repositories' *contract* is worth testing independently of Firestore,
not to avoid testing the adapter — see the coverage gap below.

## Storage layout

`users/{uid}/settings`, `users/{uid}/statistics`, `users/{uid}/unfinishedMatch` —
three small documents per owner. Deliberately **not** a growing match-history
collection: reading a user's whole history to draw a stats screen costs more the
longer they play, and Firestore bills per document read. Free tier / Spark safe:
only `doc().get()`, `doc().set()`, `doc().delete()`.

## Why local storage is still the default

The goal is "connect Firebase **without changing local game behavior**", and the
exit criterion is "each platform initializes Firebase correctly" — not "serves
settings from the cloud". Phase 8 is where online data is used. Defaulting to
Firestore now would change behavior for no user-visible benefit while introducing
a network dependency into the app's startup path. `PersistenceFactory.attachLocal`
is the default; `attachRemote` exists, is tested, and is not wired to the default
path. This is the single most likely thing for the owner to disagree with, hence
Q-7.1.

## The owner seam instead of invented auth

Repositories take `userId: () async => String?` rather than a uid string. It
returns null until Phase 8 supplies a real authenticated uid, and **null means the
repository does nothing at all** — not "write under a shared placeholder id",
which would silently merge every install's data into one document. The temporary
per-install device id belongs in the *caller*, not baked into the repositories.

## Two defects the tests actually caught

1. **Totality was delegated instead of guaranteed.** The first draft of the three
   repositories assumed the *client* would swallow every error, so totality held
   only for `CloudFirestoreClient`. The conformance test injected a *throwing*
   client and all three "a transport failure does not throw" cases failed. The
   guards now live in each repository, which is where the Phase 6 local
   implementations put them, so the guarantee belongs to the repository rather
   than to one implementation of the port.
2. **`dispose()` during an in-flight load asserted.** Persistence calls are
   deliberately unawaited, so popping a route while a read was in flight called
   `notifyListeners()` on a disposed `ChangeNotifier`. This existed in Phase 6 but
   was near-unreachable with `shared_preferences`; Phase 7 makes the read
   network-bound, which turns it into a routine path. `LocalGameController` now
   treats post-dispose completion as a no-op, with a test that drives the window
   deterministically via a `Completer`-controlled repository. Worth remembering
   that this was a Phase 6 latent bug that only Phase 7's timing made visible.

Also fixed: `CloudFirestoreClient` resolved `FirebaseFirestore.instance` in its
constructor, so merely *constructing* it threw on an unconfigured build. Resolution
is lazy now, and `PersistenceFactory.attachRemote` falls back to local storage when
the bootstrap result is not usable rather than handing out repositories that can
never reach a project.

## Quality gates (real output, 2026-09-26)

- `dart format --set-exit-if-changed lib test` → `Formatted 88 files (0 changed)`
- `flutter analyze` → `No issues found!`
- `flutter test` → `1009: All tests passed!` (was 974; +35)
- New-code coverage: settings 100%, statistics 96.15%, unfinished match 95.45%,
  in-memory client 100%, `persistence_factory.dart` 63.16%,
  `firebase_bootstrap.dart` 55.56%, **`cloud_firestore_client.dart` 0.00%**
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors byte-identical: 1,229,568 bytes, SHA-256 `6f1e3c05…`, no diff
  against HEAD
- `tool/encoding/scan_mojibake.py` → `0 files with mojibake` (101 tracked files)

The 0% on `cloud_firestore_client.dart` is the one number here that needs
explaining rather than excusing: it is ~50 lines of `doc().get()/set()/delete()`
inside `try/catch`, and it can only be exercised against a real Firebase platform
implementation or the Firestore emulator. Neither exists in this environment, and
mocking `FirebaseFirestorePlatform` for a thin adapter is not worth the test-only
plumbing. The contract every caller depends on *is* covered, via the port. Q-7.5.

## What the owner has to do manually (Q-7.4 blocks this)

Nothing below can be automated from here, and none of it may be committed:

1. Open `https://console.firebase.google.com/project/wallforge-efdb3/overview`
   and confirm the project id is exactly `wallforge-efdb3` on the **Spark** plan.
2. Add a Web app; add the Android app with the release/debug package name used
   in `android/app/build.gradle`; add the iOS app with the bundle id in
   `ios/Runner.xcodeproj`. The Android package name and the SHA-1/SHA-256 signing
   keys must be registered before auth can work later.
3. Install the FlutterFire CLI with `dart pub global activate flutterfire_cli`, then
   run `flutterfire configure --project=wallforge-efdb3` and select android, ios and
   web. This writes `lib/firebase_options.dart` locally.
4. Android: download `google-services.json` into `android/app/`.
   iOS: download `GoogleService-Info.plist` into `ios/Runner/`.
   Both are git-ignored on purpose — do **not** add exceptions.
5. Create the Firestore database, then re-run `flutter run` on each platform.
   `FirebaseBootstrap` will log `ready` instead of `unavailable`; that log line is
   the verification. Note that Phase 7 ships no `firebase_options.dart`, so on web
   `FirebaseBootstrap.initialize()` must be given those options explicitly until
   that file exists.
6. For a dev environment, add a second Firestore database and point
   `CloudFirestoreClient` at it with `useFirestoreEmulator` on a debug-only path.
   The `FirebaseStatus.emulator` value already exists for this.

## Open Questions

- **Q-7.1 (new)** — local `shared_preferences` remains the default even though
  Firestore is available. Defensible as "no behavior change", but it means Phase 7
  ships capability the app does not use. If the intent was for cloud persistence to
  be live at the end of Phase 7, this is the decision to revisit, and it needs a
  real uid from Phase 8 first.
- **Q-7.2 (new)** — the temporary per-install device id is not implemented, only
  the seam for it. Until Phase 8 there is no way to identify an install, so remote
  persistence is inert. Deliberate: inventing an id scheme here would be thrown
  away the moment auth lands.
- **Q-7.3 (new)** — no live Firestore verification. The emulator is not installed,
  the CLI is not logged in, and no config exists. Conformance is proven against an
  in-process double behind the same port. A schema or rules mistake would not be
  caught by these tests.
- **Q-7.4 (new)** — the project id `wallforge-efdb3` is owner-supplied and could
  not be independently verified without Console access. The manual steps above are
  the first thing that would surface a mismatch.
- **Q-7.5 (new)** — `cloud_firestore_client.dart` has 0% coverage. Revisit when an
  emulator is available; an emulator-based integration test is the right fix, not a
  mock of the Firestore platform.
- **Q-7.6 (new)** — security rules were not authored. They depend on the real uid
  model, and `phase.md` assigns Firestore rules to Phase 10. Worth confirming that
  is the intent rather than an omission.
- Q-6.1 … Q-6.4, Q-5.1, Q-4.1 … Q-4.10, Q-2.1 remain open and unaffected.

---

# 13p. Phase 8 Record (Online Rooms)

## The honest headline

Anonymous auth plus a two-player room lifecycle, tested end to end against an
in-process Firestore double. **The Firebase console setup from Q-7.4 has not been
done** — confirmed with the owner during this phase, and confirmed by the absence
of `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`,
`.firebaserc` and `firebase.json` in the working tree. So every claim about *this
code* is verified, and every claim about *real Firebase* is not. The three
platform-bound adapters sit at 0% coverage and are named below rather than
quietly counted as "tested".

## Auth: anonymous, and it is spec-derived

Not a preference. `rules.md` §6: "Authentication can initially use an appropriate
low-friction method such as anonymous authentication", and the same paragraph
anticipates account linking "if the product later needs durable cross-device
identity". `PRD.md` §6.4 says "Anonymous or account-based authentication as
appropriate". `architecture.md` §10 only asks for something that identifies
users.

The limitation `rules.md` §6 explicitly warns about is carried into
`AuthGateway`'s docs rather than glossed: **anonymous identity is not a durable
account.** A user who clears app data or reinstalls loses that uid and their
cloud data becomes unreachable. Phase 8 does not promise cross-device data
restoration, and `PRD.md` §6.5's display names / avatars remain unimplemented
because nothing in the product needs them yet.

`AuthGateway` is declared in the domain layer and implemented in
`lib/data/remote/firebase_auth_gateway.dart`, matching the Phase 6/7 repository
pattern. Failure is total: every path returns `AuthState.unavailable(reason)`
rather than throwing, following the non-fatal `FirebaseStatus` convention Phase 7
established. `AuthStatus.unavailable` is deliberately distinct from `signedOut`
because retrying automatically is reasonable for the first and not the second.

`AuthState.isSignedIn` rejects an **empty** uid as well as null. Found by a test:
the first version accepted `''`, which would have let a document be written under
a blank key — the same failure mode the Phase 6/7 repositories guard against with
`uid == null || uid.isEmpty`.

## Room model

One document per room at `matches/{code}`, extending `architecture.md` §11's
conceptual `matches/{matchId}` structure. The room code **is** the document id,
which is what makes joining a single document read: no query, no index, no
collection scan.

```text
matches/{code}
  code, status, boardSize, wallsPerPlayer
  hostId
  blue: { playerId, ready }
  red:  { playerId, ready }
  createdAt, updatedAt, version, schemaVersion
```

`currentPlayerId`, `turnNumber`, `winnerId` and `boardState` from §11 are
deliberately **absent**. Writing a `boardState` before moves are exchanged would
imply a synchronisation that does not exist. `version` is seeded at 1 because it
is monotonic bookkeeping Phase 9 extends and `PRD.md` §9 asks for monotonic
turn/version values.

`RoomStatus` (`waiting` / `ready` / `started` / `cancelled`) is a separate
application/data concept, **not** a reuse of `GameStatus`. A room exists before
any `GameState` does, and `GameStatus` is only `inProgress` / `finished`
(`game_spec.md` §6.1) — it cannot express "waiting for an opponent".

`RoomStatus.ready` is *derived* on every write from the seats
(`_withDerivedStatus`), so there is no code path that reaches `ready` without both
players present and readied. Status can therefore never drift from the seats.

### Side assignment

The **creator takes Blue**, the joiner takes Red. `game_spec.md` R-PLAYER-07
("Blue moves first") fixes Blue as the first player, and Q-6.2 already settled
that the local code treats Blue as the first player. Note the prompt's suggested
check: D-03/D-04 turned out to be about board orientation (row 0 is the top edge,
orthogonal adjacency), *not* sides — the side rules are R-PLAYER-01/02/03, with
start cells `(size-1, size~/2)` for Blue and `(0, size~/2)` for Red.

The assignment is stored explicitly in the document rather than implied by join
order, so it survives a re-join and is readable without re-deriving anything.

## Room codes: format and collisions

No format is specified anywhere in the source documents — `PRD.md` §6.4 and
`design.md` §19 both list only "Room code" — so this is a reasoned default:
**six characters from a 32-symbol alphabet excluding `0`, `O`, `1` and `I`**, giving
32^6 ≈ 1.07e9 combinations. Omitting the visually ambiguous symbols is the whole
point: a code read aloud or copied off a screenshot must be unambiguous.
`RoomCode.tryParse` is case-insensitive and strips separators, so `"ab3-9hk"`,
`"AB39HK"` and `" ab39hk "` are the same room.

**Collision handling is a bounded read-then-write retry, and the write is verified
afterwards.** A read-then-write cannot be made atomic without a transaction or a
Cloud Function, and Cloud Functions require the Blaze plan, which
`architecture.md` §10 forbids depending on. So rather than pretend the check is
atomic, the repository re-reads after writing: if the confirming read shows a
different host, another creator won the race and we try the next code. That closes
the race instead of documenting it away. Bounded at 5 attempts, after which the
result is `codeGenerationFailed` — a distinct reason from `networkUnavailable`,
because a transport failure is not a code-space problem and retrying it five times
would only produce a misleading error. A test asserts exactly that distinction.

## Lifecycle and the leave asymmetry

| Step | Behaviour |
| --- | --- |
| create | Generates a code, seats the creator in Blue, status `waiting` |
| join | Fills the free seat; a re-join by a seated player is a no-op, not an error |
| ready | Only ever the caller's own seat; a non-member is refused |
| start | Host-only, and only once both seats are filled and both are ready |
| leave (host) | **Deletes the document** |
| leave (guest) | **Reopens the seat** for the next player |
| leave (started) | Refused as `roomAlreadyStarted`; disconnect is Phase 10 |

The asymmetry is deliberate, because the two situations are not the same. A host
leaving strands a room with no host, nothing able to start it, and nobody to
maintain it — deleting it also frees the code and stops it occupying the 1 GiB
no-cost storage quota indefinitely. A guest leaving leaves a healthy room the host
is still waiting on, so the seat simply reopens.

`RoomStatus.cancelled` is modelled but unused by the shipped paths. That is
recorded rather than papered over: a room is never left in a cancelled state,
because deleting is strictly better for both the quota and the code space.

## Failure handling: values, not exceptions

`rules.md` §7 says expected invalid states must return structured failures, and
the domain already had a precedent (`ActionResult` / `FailureResult`). So
`RoomResult` is a sealed union of `RoomSuccess` and `RoomRejected`, and
`RoomRejected` carries a `RoomFailure` with a machine-readable
`RoomFailureReason` **and** a player-facing message.

Thirteen reasons, each distinguishable, because "that room is full" and "that room
does not exist" call for different actions: `notAuthenticated`,
`invalidRoomCode`, `roomNotFound`, `roomFull`, `roomCancelled`,
`roomAlreadyStarted`, `notAMember`, `playersNotReady`, `notTheHost`,
`invalidRoomDocument`, `codeGenerationFailed`, `networkUnavailable`. A test
asserts no message leaks the word "Exception", which is `rules.md` §7's explicit
bad-example check.

One deliberate deviation from the Phase 6/7 repositories, for a stated reason: the
Phase 7 persistence repositories swallow write failures (a lost setting must not
break the app), but here a swallowed write would report a room that does not
exist or a ready state the opponent never received. So room writes return
`networkUnavailable` instead of pretending to succeed.

## Realtime listening, and what it actually costs

`design.md` §19 requires "opponent status", so the creator has to see the joiner
arrive — that means a listener, which meant widening the `FirestoreClient` port
with `watch(path)`. Phase 7 anticipated exactly this ("Phase 8+ can widen this
interface ... without touching the repositories"), and the Phase 6/7
repositories were not touched by it.

Cost was **checked against current Firebase documentation rather than assumed**:
"real-time updates are billed as standard document reads — you are charged one
read each time a document is added or updated in the listener's result set." So a
listener is not a separate charge, but each write costs one extra read per
watching client. The no-cost quota is 50,000 reads/day and 20,000 writes/day
(stored data 1 GiB, 20,000 deletes/day, 10 GiB/month egress), which is ample for
two players and a handful of writes per room. The design consequence is why
`FirestoreRoomRepository` contains **no polling and no periodic write** — every
write is a state change a player asked for.

`InMemoryFirestoreClient.watch` is a broadcast stream so two simulated clients can
watch one document, which is how the test proves the creator sees the opponent
arrive. It needs a file-level `close_sinks` suppression because the controllers
must outlive a single subscriber; `closeWatchers()` is called in `tearDown`.

## Interface boundary

`RoomRepository` sits in `lib/domain/repositories/repositories.dart` next to the
Phase 6/7 contracts; `Room`, `RoomSeat`, `RoomCode`, `RoomResult` and the failure
types sit in `lib/domain/repositories/room.dart`; the Firestore implementation is
in `lib/data/remote/firestore_room_repository.dart`. Phase 9 can attach
move-synchronisation to the same abstraction, and the test double substitutes
exactly as `InMemoryFirestoreClient` already does.

## Q-7.1 and Q-7.2, resolved

**Q-7.2 (the `userId` seam) — resolved.** `FirestoreRoomRepository` takes the same
`UserIdResolver` the Phase 6/7 repositories take, and
`OnlineLobbyFactory.firebase` passes `auth.currentUid` into it. A real
authenticated uid now reaches the seam exactly as Phase 7 designed it to, with no
change to the repositories. The "null means do nothing" contract is preserved: with
no uid, every room operation refuses with `notAuthenticated` and **nothing is
written under a placeholder identity** — tested for all five entry points.

**Q-7.1 (local vs remote storage for settings/statistics) — deliberately still
local, now with a source rather than just a principle.** Phase 7 kept local
storage to honour "without changing local game behavior". That reasoning still
holds, and it now has explicit backing: `PRD.md` §9 says "Local game state and
local settings should be stored locally", and `rules.md` §4 lists `shared_preferences`
for "small local settings / tutorial completion / simple local preferences" and
names the online Firestore documents as "online matches, user cloud data, match
metadata" — not device settings. Confirmed with the owner during this phase, who
chose to keep storage local. Flipping it is now a one-line change
(`PersistenceFactory.attachRemote`) should that ever be wanted, because the
uid-resolving seam already exists.

## Two defects the tests caught

1. **The document version did not advance on a join.** `_persistSeated` compared
   the mutated room against *itself* to decide whether to bump the version, which
   is never true, so a join that only filled a seat left `version` at 1. Phase 9
   will rely on that version for optimistic concurrency, so this was a real latent
   bug, caught by asserting the version increases across a join. Fixed by passing
   the previously-read room in and comparing against that.
2. **The host could not ready up once the opponent joined.** The lobby screen hid
   the ready toggle whenever the room was full, which is exactly when it matters.
   Caught by a widget test, not by a controller test — the controller was always
   capable, the screen just never offered it. Ready-up is now always available to
   a seated player.

A third, smaller one: nothing in the UI ever triggered sign-in, so the lobby sat
in `needsSignIn` with no way out — `createRoom` and `joinRoom` both refuse without
a uid, making the screen unusable. Anonymous auth exists precisely to remove
friction (`rules.md` §6), so the screen now signs in on entry. The auto-sign-in
path also made the "sign-in failed" state reachable and testable.

## Tests

- `test/data/room_code_test.dart` — 12: format, alphabet properties, case and
  separator normalisation, rejection cases, generator validity/uniqueness, and
  determinism under a seeded `Random`.
- `test/data/room_lifecycle_test.dart` — 56: the full lifecycle against two
  independent repositories over one shared store, the real document layout, every
  failure reason, the leave asymmetry, collision retry and exhaustion, transport
  failure, identity safety, realtime watching (including two watchers on one
  document), serialisation rejection cases, and value semantics.
- `test/data/auth_state_test.dart` — 7: `AuthState` semantics, and a compile-time
  proof that `currentUid` matches the `UserIdResolver` shape the repositories take.
- `test/application/online_lobby_controller_test.dart` — 18: sign-in success and
  failure, create/wait, opponent arriving via the watch, per-player ready state,
  host-only start, leave/cancel from both sides, and robustness including a
  dispose during an in-flight create.
- `test/presentation/screens/online/online_lobby_screen_test.dart` — 9: entry
  state, generated code and seats, malformed and unknown codes, per-player ready
  rendering, the started view and its no-synchronisation notice, and controller
  ownership on teardown.

+38 tests overall, 1072 → 1110.

One existing test needed a fix rather than a code change: a `game_screen_test`
case scrolled to a preset chip and then tapped the start button, which worked only
because the entry page had not grown. Adding the online button made the page
longer and the button scrolled out of view. It now calls `ensureVisible` on the
button it taps, so the assertion no longer depends on page length.

## Quality gates (real output, 2026-09-27)

- `dart format --set-exit-if-changed lib test` → `Formatted 101 files (0 changed)`
- `flutter analyze` → `No issues found!`
- `flutter test` → `1110: All tests passed!`
- New-code coverage: `firestore_room_repository.dart` 98.08%, `room.dart` 98.72%,
  `in_memory_firestore_client.dart` 100%, `room_code_generator.dart` 100%,
  `online_lobby_screen.dart` 95.40%, `auth.dart` 93.75%,
  `online_lobby_controller.dart` 87.60%.
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors byte-identical: 1,229,568 bytes, SHA-256 `6f1e3c05…`, no diff
  against HEAD. `git diff` also confirms `game_spec.md`, `lib/domain/engine` and
  `lib/domain/models` are untouched — the domain rule layer did not move.
- `tool/encoding/scan_mojibake.py` → `0 files with mojibake`

### Coverage gaps, named rather than hidden

Three files are at **0%**, all for the same single reason — they need a live
Firebase platform, and there is neither a configured project nor an emulator
(Q-7.3/Q-7.4):

- `firebase_auth_gateway.dart` (28 lines) — **new this phase.** Anonymous sign-in
  against real `FirebaseAuth`. Not exercised by any test.
- `cloud_firestore_client.dart` (19 lines) — the Phase 7 adapter, still 0% as
  Q-7.5 recorded, now also carrying the `watch` implementation.
- `online_lobby_factory.dart` (9 lines) — only wires the two above together.

`FirebaseAuthGateway` is the honest gap to care about: its error mapping
(`FirebaseAuthException` → `unavailable`, no-app → `unavailable`) is exactly the
logic that decides whether a player sees a clear message or a crash, and it is
unverified. Exercising it needs `FirebaseAuthPlatform` mocked or an emulator, so
it is Q-8.2 rather than something quietly skipped.

The 2% and 1.4% shortfalls in the repository and controller are a watch-stream
`onError` path and a defensive branch that current leave semantics make
unreachable (the Blue-seat branch of `_seatPlayer` cannot be hit, because the only
player who can leave the Blue seat is the host, and the host's departure deletes
the document). Left in place deliberately.

## What is not verified against a real backend

Everything below is unproven and will stay unproven until the console work is
done:

- That anonymous sign-in succeeds, and what it does when disabled in the Console.
- That `matches/{code}` is readable and writable, and that the document shape
  above is accepted.
- That `snapshots()` delivers room changes to a second device in practice, and how
  long a real listener takes to converge.
- Whether the read-then-write race actually behaves as the verify-after-write
  logic assumes.
- Whether a real `set()` is as atomic as the in-memory double's map assignment.
  The double cannot model a partial write.

To close all of it, the Q-7.4 steps in §13o must be completed and either the
Firestore emulator or two real devices used. Nothing in this phase should be read
as evidence that the backend works.

## Open Questions

- **Q-8.1 (new)** — the room code alphabet is a reasoned default with no source in
  the documents. Six characters from 32 symbols is a judgement call about how often
  players mistype codes. If playtesting shows too many failures, 8 characters is
  the obvious change; the document id stays the code either way.
- **Q-8.2 (new)** — `firebase_auth_gateway.dart` has 0% coverage. The fix is an
  emulator-based integration test or a `FirebaseAuthPlatform` fake, not a mock of
  the gateway itself. Worth doing before trusting anonymous sign-in in the field.
- **Q-8.3 (new)** — `RoomStatus.cancelled` has no producer. It exists for a future
  cancel affordance and Phase 10's timeout handling. If neither arrives it should
  be deleted rather than left as decoration.
- **Q-8.4 (new)** — `design.md` §19 lists a `reconnecting` connection state, and
  this phase does not implement it. Detecting it properly means reading Firestore
  snapshot metadata (a snapshot served from cache rather than the server), which
  is meaningful once Phase 9 streams moves but would be a guess here. Phase 9
  should add it.
- **Q-8.5 (new)** — `design.md` §19 specifies the lobby's *contents* but no visual
  treatment, and no Stitch screen covers a lobby. This screen reuses existing
  tokens and component shapes, following the pattern Phase 5 set for the AI
  selector. A real lobby design belongs with the Phase 11 UI work.
- **Q-8.6 (new)** — `GameScreen` never disposes the `LocalGameController` the
  `/game` route builds for it, so those controllers outlive the route. Pre-existing
  since Phase 4 and out of scope here; the new online screen avoids it with an
  explicit `ownsController` flag. Worth fixing rather than leaving a known leak.
- **Q-8.7 (new)** — security rules were still not authored. `architecture.md` §12
  lists what they must enforce (authenticated identity, match membership, turn
  ownership, expected types, monotonic version) and `phase.md` assigns Firestore
  rules to Phase 10. The document shape now exists, so Phase 10 can finally write
  them against something real. Until then the default test-mode rules are the only
  protection, and the app trusts the client for room contents — which
  `architecture.md` §12 explicitly says is not a sufficient long-term position.
- Q-7.1 and Q-7.2 are resolved above; Q-7.3, Q-7.4 and Q-7.5 remain open and are
  restated honestly in §13o.
- Q-6.1 … Q-6.4, Q-5.1, Q-4.1 … Q-4.10, Q-2.1 remain open and unaffected.

---

# 13q. Phase 8.1 Record (Random Matchmaking) — and the Part A auth fix

Two pieces of work in one session, recorded together because they were requested
together: a bug fix found by reading the Phase 8 code rather than by trusting its
green test run, and a new owner-approved feature.

## Part A — `FirebaseAuthGateway` resolved Firebase eagerly

### The bug, and it was wider than reported

`FirebaseAuthGateway` resolved `fb.FirebaseAuth.instance` in its **constructor's
initializer list**. That expression runs at construction, before any `try`/`catch`
in the class, and it throws `[core/no-app]` when no Firebase app is
initialised — which is the real state of a fresh clone, since `.gitignore`
forbids committing the client config.

Confirmed empirically before fixing anything, with a throwaway test:

```
Expected: return normally
  Actual: <Closure: () => FirebaseAuthGateway>
   Which: threw FirebaseException:<[core/no-app] No Firebase App '[DEFAULT]'
   has been created - call Firebase.initializeApp()>
```

Because `OnlineLobbyFactory.firebase()` constructs the gateway, and the `/online`
route builds the lobby during route construction, tapping "Online Play" threw
before any screen was built. The app silently did nothing. That is the
owner-reported symptom, and the route-level test in
`test/presentation/screens/online/online_entry_navigation_test.dart` now pins it.

Auditing the file properly found **four** defects of the same class, not one:

| # | Location | Defect |
| --- | --- | --- |
| 1 | constructor | `_auth` resolved eagerly, before any guard |
| 2 | `current()` | `_auth.currentUser` read outside a try/catch, so it *threw* instead of reporting `unavailable` |
| 3 | `currentUid()` | same, and this one is the `userId` resolver handed to **every** Phase 6/7/8 repository, so a throw escaped `load()` and `save()` |
| 4 | `authStateChanges()` | a `Stream`, so no `Future`-shaped try/catch protected it; `_auth` was touched when the method was *called* |

Only #1 was in the original report. #3 is arguably worse, because it sits on the
seam every repository depends on. All four are fixed: resolution moved to a
cached `_auth` getter, every `Future` method is guarded, and `authStateChanges()`
returns a single `unavailable` event when Firebase cannot be resolved rather than
throwing to its caller.

A repo-wide grep for `.instance` found no other eager resolution:
`cloud_firestore_client.dart` resolves inside a getter (Phase 7's fix) and
`firebase_bootstrap.dart` calls `initializeApp()` inside a try/catch. **No other
instance of this bug class exists.**

### Why the Phase 8 test suite missed it

Every Phase 8 test injected a fake: `FakeAuthGateway` in the controller tests,
`_StubAuth` in the widget tests, `_StubAuth2` for the second simulated device. The
real class was only ever constructed with the `auth:` parameter, which skips the
faulty expression entirely. The zero-argument path — the only one production uses
— was never executed by a single test.

The honest part: Phase 8's own record *named* this as a 0%-coverage gap (Q-8.2).
Recording a coverage gap is not the same as the gap being safe, and this is the
second time in two phases that a documented gap turned out to be a real defect
(the first being the `dispose()`-during-load bug in Phase 7). The lesson worth
keeping: **an adapter with no tests is untested code, not "covered by the tests
that exist"** — and a constructor is code.

### The regression test

`test/data/firebase_auth_gateway_test.dart` constructs the **real,
zero-argument** gateway with no Firebase app and asserts the whole public surface
is total: construction does not throw, `signInAnonymously` resolves to
`unavailable` (with a timeout, so a hang fails rather than stalls),
`currentUid` resolves to null, and `authStateChanges` can be obtained and reports
`unavailable`.

It also asserts its own premise — that `fb.FirebaseAuth.instance` throws — so the
file cannot silently become vacuous if a future test environment ever
initialises a Firebase app.

## Part B — Phase 8.1: Random Matchmaking

Owner-approved and added to the plan itself (`phase.md`, between Phase 8 and Phase
9) rather than folded in silently.

### Document layout

```text
matchmaking/{boardKey}/waiting/{uid}    a player waiting; the doc id is the uid
matchmaking/{boardKey}/matched/{uid}    "you have been matched"; value is the room
matches/{code}                         the Phase 8 room, written by the claimer
```

The waiting entry's document id being the uid means a player can hold at most one
queue entry per board, and re-queuing is idempotent.

### Why pairing is race-free

Two mechanisms, and the second is the subtle one.

**1. The claim is a transaction.** Claiming candidate `X` re-reads `X` inside the
transaction, so if another client already claimed it, `X` is gone and the claim
aborts; the loser retries with a different candidate.

**2. One transaction writes *both* participants' `matched` documents.** Those
shared documents are the mutual-exclusion token. If A claims B while B
simultaneously claims A, both transactions write `matched/A` and `matched/B`, so
Firestore detects a write-write conflict, aborts one, and re-runs it; the re-run
sees its own `matched` document already present and backs off.

The two-simultaneous-requests case, concretely, from an empty queue:

- A and B each write their own `waiting` entry. Different documents, so no
  conflict. Then each queries and finds the other.
- A's and B's claim transactions both run, and both write `matched/A` and
  `matched/B`. They conflict; one commits.
- The winner returns its room directly. The loser, on retry, finds
  `matched/{self}` present, abandons its claim, re-reads its own matched document
  and returns **the same room**.

Exactly one room exists, both players are in it, and neither is double-booked or
left waiting. Tested with `Future.wait` over simultaneous `findMatch` calls, and
repeated 20 times with a fresh store each round so one lucky interleaving cannot
hide a failure.

The waiting player learns about the match through a listener on its own `matched`
document — no polling and no periodic write.

### An SDK constraint that shaped the design

`cloud_firestore`'s `Transaction.get` accepts only a `DocumentReference`; **it
cannot run a query**. So candidate discovery is a plain query *outside* the
transaction, and the transaction re-reads the single chosen candidate to confirm
it is still claimable. The commit — the part that genuinely has to be atomic —
still is. This is recorded in the port's own documentation because it is not an
obvious limitation, and designing a "query inside the transaction" approach first
would have produced code that cannot compile.

### No new manual Firebase console step

Firestore serves an equality filter plus an `orderBy` on a *different* field only
from a **composite** index, which is a manual console step or a Blaze-plan deploy
— and `architecture.md` §10 rules Cloud Functions and Blaze out. Verified against
current Firestore indexing documentation rather than assumed.

The queue is therefore partitioned by board configuration **in the path**
(`matchmaking/s9w10/waiting/...`), so the only query needed is a bare
`orderBy('queuedAt')` + `limit` on one subcollection, which the automatic
single-field index serves. **No composite index, no manual console step.** Had the
board config been a document field instead, this feature would have required the
owner to create an index before a single match could be found.

### Compatibility scope: exact `BoardConfig` only

No source document specifies configurable online match settings — `PRD.md` §6.4
and `design.md` §19 list only "create match / join match / room code / opponent
status / connection state". So matchmaking pairs **only on an exact `BoardConfig`
match**, recorded as a ledger decision (Q-8.9) rather than a silent
simplification. It also avoids the ambiguity of "compatible but not equal" boards,
where a player could be dropped into a board size they did not choose.

### Abandoned queue entries

A player who closes the app mid-wait leaves an entry nothing will ever clear;
without a rule, that entry would eventually be claimed into a room whose opponent
never appears, stranding the claimer in a lobby forever. So entries carry a
`queuedAt` timestamp, and `findMatch` reaps any entry older than `staleAfter`
(default **60 seconds**) before considering it. Reaping is a plain write, not a
transaction, because the worst case is two clients deleting the same stale entry.

Sixty seconds is a reasoned default, not a documented figure — someone unpaired
for a minute has almost certainly left. Recorded as Q-8.10. A malformed entry
(missing `uid`) is reaped too, so it cannot block the queue.

### Two defects the tests caught

1. **The claimer never removed its own queue entry.** After a successful claim the
   client was seated in a room *and* still in the queue, so a third player could
   pair with someone already in a match. The "nobody is left stranded" assertion
   found it. Fixed by deleting the claimer's own entry in the same transaction,
   and a fourth read was added to the transaction to refuse claiming a candidate
   who is *already* matched — closing the related case of a leftover entry from an
   earlier session.
2. **A player who lost a race was told matchmaking had failed.** The first rule was
   "if I saw a partner and never committed, report a failure", which misfired
   whenever the loss was a *race* rather than a commit failure — and a lost race
   leaves the client's own queue entry intact, so it was queued all along. The
   deciding question is now "am I actually in the queue?", checked directly. The
   truthiness is also better: a player who is genuinely waiting is told they are
   waiting.

### Reuse, not duplication

A matched pair lands in the **same** `Room`, at the same `matches/{code}` path,
with the same serialised shape as a code-created room. `RoomRepository` is
untouched: after matchmaking, ready state, match start and Phase 9's move sync all
work through the existing Phase 8 code, and a test asserts a quick-matched room
is loaded and mutated by the Phase 8 repository like any other. The only
difference is how the two players found each other.

The player who was *already waiting* becomes the host in Blue, matching the
convention of a code room: whoever set the room up is Blue, and Blue moves first
(`game_spec.md` R-PLAYER-07).

`MatchmakingRepository` is optional on `OnlineLobbyController`, so a build without
it keeps the code flow working and simply does not offer Quick Match.

## Quality gates (real output, 2026-09-27)

- `dart format --set-exit-if-changed lib test` → `Formatted 108 files (0 changed)`
- `flutter analyze` → `No issues found!`
- `flutter test` → `1188: All tests passed!` (was 1129; +59)
- New-code coverage: `firestore_matchmaking_repository.dart` 100%,
  `in_memory_firestore_client.dart` 100% (including the transaction and query
  paths), `room.dart` 100%, `room_code_generator.dart` 100%,
  `online_lobby_screen.dart` 96.46%, `firestore_room_repository.dart` 98.08%,
  `auth.dart` 93.75%, `matchmaking.dart` 93.75%, `online_lobby_controller.dart`
  93.83%.
- `flutter build web` → `√ Built build\web`
- `check_spec_consistency.py` → `OK: spec is consistent with the reference engine.`
- Oracle vectors byte-identical: 1,229,568 bytes, SHA-256 `6f1e3c05…`. `git diff`
  confirms `game_spec.md`, `lib/domain/engine`, `lib/domain/models` and
  `lib/domain/serialization` are untouched — no game rule moved.
- `tool/encoding/scan_mojibake.py` → `0 files with mojibake`

Tests added: 12 (`firebase_auth_gateway_test.dart`) + 7 (online entry navigation) +
29 (matchmaking) + 12 (interleaving/transaction mechanics) + 11 (quick-match
controller and full flow) + 7 (quick-match screen) = 78 across Part A and Part B,
against a 1110 baseline.

### Gaps, named rather than hidden

- `cloud_firestore_client.dart` is at **2.56%** — it now also carries the real
  `query` and `runTransaction` adapters, and those cannot be exercised without a
  live Firebase platform. The in-memory double covers the *logic*; only the SDK
  call itself is unverified. This is Q-7.5, unchanged in kind and now larger in
  surface.
- `firebase_auth_gateway.dart` rose from 0% to **64.71%** thanks to Part A's
  tests, which now cover the real unconfigured path. The remaining third is the
  *success* paths, which need a live project. Q-8.2 stands, but it is materially
  less blind than it was.
- `online_lobby_factory.dart` is at 70%: the uncovered part is the `firebase()`
  constructor body, which only runs where a platform exists.
- The in-memory double models transaction atomicity and conflicts, but it cannot
  model a real partial write, and its conflict detection is coarse — *any* write
  aborts an in-flight transaction. That makes retry testing stricter than reality,
  not laxer, but the retry counts it reports are not Firestore's.

### Still unverified against a real backend

Unchanged from Phase 8 and worth restating, because matchmaking adds a second
write path: anonymous sign-in succeeding; `matches/{code}` and the two
`matchmaking/` subcollections being readable and writable; `snapshots()` on a
queue partition converging between two real devices; whether a real transaction
retries as often as the double's coarse conflict detection implies; and whether
the write-write conflict on the shared `matched` documents behaves as the pairing
argument assumes. The Q-7.4 console steps in §13o must be completed before any of
this can be checked. The no-new-index conclusion is a documentation finding, not
an observed one — it should be re-confirmed in the Console when it is set up.

## Open Questions

- **Q-8.1 … Q-8.7** remain as recorded in §13p, except Q-8.2, which Part A
  materially improved (0% → 64.71%).
- **Q-8.8 (new)** — a waiting player is told when they are matched, but there is
  no "opponent found" sound, animation or notification of any kind. `design.md`
  §19 specifies opponent status and connection state, which are covered, but says
  nothing about feedback for the pairing moment. Whether that needs designing or
  is implied by the existing motion language is a UI question, not a rules one.
- **Q-8.9 (new)** — matchmaking pairs only on an exact `BoardConfig` match. A
  player who wants a 7x7 cannot be paired with someone queueing for 9x9, and
  there is no way to express "any size" in the queue. If playtesting shows
  mismatched expectations, the fix is a wildcard partition such as `sAny`, which
  the path-partitioned design supports at no extra index cost.
- **Q-8.10 (new)** — the 60-second staleness window is a reasoned default with no
  documented source. It is a balance parameter, not a rule, and 30 or 120 seconds
  could both be defensible. It is injectable precisely because it is a guess.
- **Q-8.11 (new)** — the pairing algorithm is "first come, first served" by
  `queuedAt`. There is no skill rating, no rating-based matching, and no widening
  search window. `PRD.md` §6.4 says nothing about matchmaking quality, and Phase 5
  established the AI is stateless with no rating, so there is no skill signal to
  match on. Recorded so it is not mistaken for a skill-based system later.
- **Q-8.12 (new)** — a `matched` document is never deleted. It is overwritten when
  the same player queues for the same board again, and `cancel` deliberately
  leaves it alone so an opponent walking into the room is not stranded. That means
  one small document per (player, board) persists indefinitely — negligible
  against the 1 GiB quota, but it is unbounded in principle and a Phase 10 cleanup
  policy may be wanted.
- Q-7.1 and Q-7.2 remain resolved as recorded in §13p. Q-7.3, Q-7.4, Q-7.5 remain
  open.
- Q-6.1 … Q-6.4, Q-5.1, Q-4.1 … Q-4.10, Q-2.1 remain open and unaffected.

---

## 13q. Phase 9 — Online Game Synchronization (2026-09-28)

### What was built

The online mode went from a lobby that could start a room and then said so
plainly ("turns are not synchronised between devices yet") to a real two-client
match protocol. Layers, outside in:

| Layer | Files |
| --- | --- |
| Domain | `lib/domain/repositories/room.dart` (schema 2, `RoomStatus.finished`), `lib/domain/repositories/match.dart` (`SharedMatchDocument`, `MatchMove`, `MatchSyncFailure`, `MatchRepository`, `MatchSeating`) |
| Port | `lib/data/remote/firestore_client.dart` — `watchWithMetadata`, `FirestoreSnapshot.fromCache`, `query(startAfterDocumentId:)` |
| Data | `firestore_match_repository.dart` (transactional protocol, paged recovery), `firestore_room_repository.dart` (seeds the initial snapshot on start), `in_memory_firestore_client.dart` (conflicts, offline, cache metadata, cursor) |
| Application | `lib/app/application/game_interaction.dart` (extracted from `LocalGameController`, no behaviour change), `online_game_controller.dart` |
| Presentation | `online_game_screen.dart`, plus the lobby's `PLAY` transition |

### Schema as built

`matches/{code}` is the room document. One document, not two, so seating,
lifecycle and board state are written as a single atomic fact:

```text
matches/{code}                        # schemaVersion 2
  status          waiting | ready | started | finished | cancelled
  blue / red      { playerId, ready }
  hostId
  boardSize       int
  wallsPerPlayer  int
  version         int   # +1 per shared-state-changing write
  turnNumber      int   # must equal boardState.turnNumber
  currentPlayerId ?uid  # null once finished
  winnerId        ?uid  # derived from the engine only
  boardState      GameState (nested, authoritative)

matches/{code}/moves/{NNNNNN}         # zero-padded, so the id is the ply
  playerId, turnNumber, action, notation, createdAt, resultingVersion
```

Schema 1 rooms stay readable; new fields are written as explicit `null` before
the match starts so a reader never has to distinguish "absent" from "null".

### Protocol

One atomic write per action. The transaction reads the match document and the
move record, re-validates the action **against the stored snapshot through
`GameEngine`** (never the client cache), then stages the new room document and
the move record together. Firestore forbids querying inside a transaction, so
candidate and move-log reads happen before it.

Turn ownership, staleness and duplicates are decided in this order: not a member
→ finished → wrong turn → already applied → conflicting duplicate → stale turn
→ `invalidRemoteData` if the denormalised `turnNumber` disagrees with the
snapshot → engine validation.

### Listener and verification

One `watchWithMetadata` on the match document. `fromCache` is the connectivity
signal: a cached snapshot is shown as-is and never re-verified, because
`rules.md` §9 requires preserving local state and a cached copy cannot have
moved. A live snapshot is verified before adoption — one turn of reachability, a
version gap proportional to the number of turns missed, or replay from the log.
Anything that fails all three stops the match with a stated error rather than
showing a board the player would act on.

Connectivity is derived from **the match document itself**, not from the room
state. That distinction is not cosmetic: an earlier version read a field of the
room document, which may arrive after the match document and is never re-read,
so the chip sat on `WAITING` for a perfectly healthy match.

### Q-9.1 — Board orientation: unchanged (decided)

Phase 9 does **not** flip the board. The canonical orientation stays and the
player's own seat is marked (`YOU` next to the seat row, an outline as well as a
colour). A flip is presentation, Phase 9's job is correctness, and Phase 11 owns
the result presentation. Cost of reversal is one board-orientation transform if
playtesting disagrees.

### Q-9.2 — Rematch: deferred (decided)

Rematch is a new room with a fresh seat assignment and an explicit consent step
from both players. It is **not** Phase 9: it needs its own room lifecycle
decision, and Phase 10 already owns timeout/forfeit/turn clocks. Recorded here
so "rematch" is not read as implied by "match completion".

### Q-9.3 — Phase 9 reconnects only this client (decided)

This client preserves its state, shows `RECONNECTING`, and converges when the
snapshot returns. What the *opponent* sees when someone stays gone — turn clocks,
forfeit, abandonment — is Phase 10, as is anything that would require a server
authority. Phase 9 deliberately contains no timer, because a timer that fires
without authority is worse than no timer.

### Q-9.4 — Move-log recovery pages to the end (decided, and the first answer was wrong)

The original bound was one page of 500, documented as exceeding the longest game
in the oracle vectors (431 plies). **Random full-game testing found a 501-ply
game**, so that claim was false and, worse, the failure was silent: the caller
received a 500-record *prefix* that is indistinguishable from a complete log,
and a caller rebuilding state from a prefix concludes it is up to date.

`FirestoreClient.query` now takes `startAfterDocumentId`, because Firestore has
no offset and ordering by the zero-padded document id makes the cursor agree
with the page boundary. `readMoves` follows pages to the end (200 per page, 25
pages maximum). A log too long to be a legal game yields an empty log and a log
line — reported, never quietly cut.

### Defects found by the 201 random full games

67 games each on 5x5, 7x7 and 9x9, seeded per game so a failure reproduces.
They were not green when written.

1. **A legal position could not be stored.** `GameStateSerializer` still
   rejected two perpendicular walls sharing an anchor as "crossing" — a v1 check
   left over from before R-WALL-08 (spec v2.0.0) made that shape legal, at which
   point `ActionValidator` also lost its `wallCrosses` branch. The engine produced
   such positions freely. The first legal "+" in a match therefore produced a
   state that could neither be stored nor read back: the shared document became
   undecodable, every later submission was refused as `invalidRemoteData`, and
   the match was permanently wedged. **The codec was wrong, not the rules.** The
   codec was corrected and `game_spec.md` is untouched — the oracle fixture is
   byte-identical (1,229,568 bytes, SHA-256 `6f1e3c05…`).

   The general lesson: a codec that rejects a state the rules permit is a
   product bug, and the two authorities can drift apart silently because each is
   internally consistent. Round-tripping engine output through the codec is now a
   test, not an assumption.

2. **Silent truncation on recovery** (Q-9.4 above).

Three more, found while building the UI, are recorded in the commit log:
`Room.copyWith` could not clear `currentPlayerId` (a nullable parameter already
means "keep", so the repository's `null` on completion did nothing, and a
finished document still named a player to act); a finished match could be deleted
by leaving, which reopened its host seat to a third player; and the connection
chip described above.

### Verification

- `flutter analyze` clean; `flutter test` 1,470 passing; `flutter build web
  --release` succeeds.
- Spec consistency green (80 rows, 65 rule IDs, 65 in matrix); oracle fixture
  unchanged; `game_spec.md` and `rules.md` untouched.
- Q-8.6 resolved: `GameScreen.ownsController` disposes the controller a route
  created, and the injected-controller case is covered.

### Open, and the blocker

**Q-7.4 (owner action) is still open, so the Phase 9 exit criterion "two players
can complete a match across devices" is NOT verified.** There is no
`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`,
`.firebaserc` or `firebase.json`. Every result above comes from two independent
client stacks over one `InMemoryFirestoreClient` — a faithful model of
transactions, conflicts, offline failure, listeners and cache metadata, but not
Firestore.

Unverified until then, and only against live Firebase or the emulator:
`CloudFirestoreClient.watchWithMetadata`, its query cursor (`startAfter` on the
document id) and its transaction adapter; listener convergence and per-document
read cost against real quotas; Security Rules and match authorization (Phase 10).

### Owner acceptance script (requires Firebase setup first)

Before testing, create or confirm project `wallforge-efdb3`, keep it on Spark,
register the Web/Android/iOS apps, enable **Anonymous** in Authentication, create
the Firestore database, and run `flutterfire configure --project=wallforge-efdb3`
for the platforms under test. Keep the generated `firebase_options.dart`,
`google-services.json` and `GoogleService-Info.plist` local and uncommitted. If
you choose Firestore test mode for this temporary check, its rules allow
unrestricted client access and expire after **one month**; replace them with
proper rules before relying on the database. Firebase's [Firestore quickstart](https://firebase.google.com/docs/firestore/quickstart)
describes test mode; the [Firebase release notes](https://firebase.google.com/support/releases)
confirm the one-month auto-expiry policy for Firestore test rules.

Use two genuinely distinct anonymous users: two tabs in one Chrome profile share
the same persisted uid. Use a normal and incognito profile, two Chrome profiles,
or Chrome and an Android emulator.

1. Device A creates a room and shares its six-character code.
2. Device B joins by code; confirm each sees the other player's seat.
3. Both players ready; A starts the match. Both must navigate to the online board
   from the same initial snapshot, with opposite turn ownership.
4. Play a complete game, including legal movement and wall placement. Confirm
   each accepted move appears on the other device without refresh and the
   non-active player's input is disabled.
5. During the active player's turn, disconnect that device, make/hold one action,
   then reconnect. Confirm `RECONNECTING` appears, the board is preserved, and
   the same action lands at most once; also disconnect while the opponent moves
   and confirm catch-up.
6. Finish the game. Both devices must show the same engine-derived winner, and
   further actions must be refused.
7. Inspect `matches/{code}` and `moves`: versions and turns must be monotonic,
   `turnNumber` must equal `boardState.turnNumber`, and there must be exactly one
   move record per accepted action.
8. Check Firestore usage after accounting for transaction reads plus one listener
   document read per client per accepted action. The in-memory estimate is about
   4 reads / 2 writes per action; the live usage dashboard is the acceptance
   evidence for real billing.

### Q-9.5 (new) — the match document is the room document

One `matches/{code}` carries lobby fields and the board snapshot together, rather
than a `rooms/` document plus a `matches/` document. This keeps seating,
lifecycle and state a single atomic fact, at the cost of mixing two concerns in
one schema. If Phase 10's authorization rules become hard to write against a
document with both kinds of field, splitting is the change to make.

### Q-9.6 (new) — no board flip, and the cost of changing that

Decided in Q-9.1. The reason it is recorded rather than merely done: a flip is
not only a transform, it changes which goal row reads as "yours", so the result
screen, the seat colours and any future animation all key off it. Doing it
inside Phase 9 would have mixed a presentation change into a correctness phase.

### Q-9.7 (new) — `pending` is the answer to a lost acknowledgement

An action that cannot be sent is held and resubmitted, rather than queued in
Firestore or discarded. The interesting case is the one the design has to get
right: a move whose acknowledgement was lost may appear to have succeeded while
the client believes it failed. Resolving that is why an *echo* — a document
identical to the local view — still clears the pending action. Without that, the
pending action is stuck forever behind a move that actually landed.

### Q-9.8 (new) — random full games are the only reason two of these were found

Neither the crossing-wedge nor the silent truncation was reachable from a
hand-written scripted game or from unit tests of the individual pieces. Both
needed a long, legal, *unusual* sequence produced by the engine itself. Any
future work on serialization or the move log should assume a scripted game is
insufficient evidence, and that property-based coverage is the cheapest defect
finder available here — it runs in ~15 seconds and needs no Firebase.

Q-7.1 and Q-7.2 remain resolved as recorded in §13p. Q-7.3, Q-7.4, Q-7.5 remain
open. Q-8.3 remains open (the unused `cancelled` status is preserved); Q-8.4 is
resolved by the Phase 9 metadata-backed connection states; Q-8.6 is resolved by
route-owned `GameScreen` disposal. Other Q-8.x remain as recorded in §13p.
Q-6.1 … Q-6.4, Q-5.1, Q-4.1 … Q-4.10, Q-2.1 remain open and unaffected.

### Online board interaction correction (2026-10-12)

The owner reported that two browser sessions could join and start the same live
match, but both boards stayed stationary. The presentation root cause was
confirmed against the pre-fix source: `OnlineGameScreen`'s `BoardView` call at
`lib/presentation/screens/online/online_game_screen.dart:256-268` ended after
`activeGlow`, without `onCellTap` or `onWallSlotTap`. The local equivalent wires
both at `lib/presentation/screens/game/game_screen.dart:148-153`. In
`lib/presentation/board/board_view.dart:67,91-97`, the gesture detector is only
installed when a callback exists, so the callback-free online board could not
report taps. `GameInteraction.tapCell` and `tapWallSlot` check
`isInputEnabled` (`lib/app/application/game_interaction.dart:175-197`), while the
online controller supplies the online turn/connectivity gate at
`lib/app/application/online/online_game_controller.dart:174-181`; the screen
doesn't need a second copy of that check.

The online screen now wires the two callbacks at
`lib/presentation/screens/online/online_game_screen.dart:269-274`, only in their
matching modes, as the local screen does. `BoardView` has no
`onWallSlotHover` API in this checkout;
neither the local screen nor its current board construction wires hover, so no
hover or board-renderer API was added for this presentation fix.

The prior online-screen widget tests checked turn banners, connection status,
semantics and layout, but never tapped the rendered board. The focused widget
coverage now taps a legal cell and verifies the pawn and turn change, taps a wall
slot and confirms it through the screen controls, and taps while Blue is out of
turn to verify the state stays unchanged (`test/presentation/screens/online/online_game_screen_test.dart:143-249`). The full online-screen widget file
passed all 15 tests; the complete suite passed all 1,473 tests. `dart format
--set-exit-if-changed lib test` reported 122 files, 0 changed; `flutter analyze`
reported no issues; the release web build succeeded. The spec checker reported
80 catalog rows, 65 rule IDs and 65 in the matrix; generated oracle output was
byte-identical to the 1,229,568-byte fixture. `game_spec.md`, `rules.md`, and
domain, sync and controller code were not changed. This verifies input through
the widget tree against the in-memory Firestore double; it does not substitute
for repeating the owner's two-session live Firebase test. Phase 9 remains open
until the owner confirms both clients can move and place walls with turns
converging live.

### Online board live verification (2026-10-26)

At the owner's instruction, the fix was re-verified on this working copy and
the missing live check was performed against the live Firebase project
`wallforge-efdb3`, using the release web build of this exact checkout in two
independent browser sessions.

One further presentation gap was found and fixed first: the online screen's
mobile/narrow layout had no mode toggle and no Confirm/Cancel actions at all —
the 2026-10-12 wiring existed only in the wide layout path, so on a phone-width
viewport a player could select a wall slot but never confirm it. The narrow
layout now builds the same mode toggle and action row as the wide layout
(`_buildModeToggle`/`_buildActions` in
`lib/presentation/screens/online/online_game_screen.dart`); the `BoardView`
callbacks cited above now sit at lines 278–284. A phone-width (390×844)
wall-placement tap test was added to the online-screen widget file, which now
passes 16/16.

Gates re-run 2026-10-25 on this copy: `dart format --set-exit-if-changed lib
test` reported 122 files, 0 changed; `flutter analyze` reported no issues; the
spec checker reported the spec consistent with the reference engine; generated
oracle output was byte-identical to the 1,229,568-byte fixture. The full suite
ran 1,474 tests: 1,465 passed and 9 failed, all 9 being golden-pixel
comparisons that fail identically on the pristine upstream tree in the Linux
verification environment (the reference images were generated on the owner's
Windows machine), so they are environmental, not regressions.

Live results (screenshots from both clients plus the server-side match
documents agree):

- Match `6QH974`: Blue's pawn move e1→e2 was submitted from the board tap,
  recorded as `moves/000000` (notation `M 7,4`), the stored `boardState`
  advanced to turn 1 with Red to move, and Red's client rendered the move with
  the turn banners correct on both sides. Red's answering move was interrupted
  by a transport drop in the test environment; the client showed its
  reconnecting state and held the move, which was never written. The match was
  abandoned as a test artifact.
- Match `H3NQY2`: a complete four-action sequence was played live — Blue wall
  (horizontal, anchor row 7, column 3), Red move e9→e8, Blue move e1→f1, Red
  wall (horizontal, anchor row 1, column 3) — recorded in order as
  `moves/000000`–`000003`. The final stored state reads turn 4, Blue to move,
  9 walls remaining per player, status in progress; both clients rendered both
  walls and both pawn positions identically, and Blue's offered legal targets
  after its own wall correctly excluded the walled-off cell.

Early live attempts on 2026-10-25/26 that appeared to show rooms expiring were
invalidated by an error in the test harness (automated taps landing on the
room screen's Leave control), not by the app; the sequence above is the valid
run. With this, the Phase 9 live criterion — both clients can move and place
walls with turns converging live — is met for web. A full-length match played
to a winner live has still not been done.

### Phase 9 source ledger

| Source | Decision applied |
| --- | --- |
| `PRD.md` §6.4, §9 and §10 | A player's uid and seat determine input ownership; verified shared state, not local intent or a declared winner, determines the board and result. Rematch remains deferred; accounts, rating and ranked play stay out of scope. |
| `architecture.md` §10–§13 | Stay on the Spark-compatible client architecture with no Cloud Functions. Extend `matches/{code}` and its `moves` subcollection as §11 documents; keep Firestore Rules and their enforcement limits in Phase 10. |
| `rules.md` §§3.6, 5, 7, 9, 10, 16, 17 and 19 | Validate stored state through `GameEngine`; write only accepted actions; return structured failures; keep offline state and use idempotent retries; do not write for pointer/UI changes. |
| `design.md` §§16, 19, 21, 26 and 29; Stitch tactical arena and gameplay screen | Reuse the existing HUD and board; show all five connection states, the player's seat and accessible status/failure descriptions; keep canonical board orientation. |
| `phase.md` §§9–11 | Phase 9 covers this client's recovery and convergence; Phase 10 owns the other player's timeout/abandonment response, clocks, security and authorization; Phase 11 owns larger UI and rematch decisions. |
| `game_spec.md` v2.0 §§4, 6, 7, 15 and 16 | Keep the engine's action/state JSON and scripted-game outcome. Legal perpendicular walls can share an anchor; the Phase 9 codec fix changes no rule. |
| `memory.md` §§13m–13q | Preserve room lifecycle and asymmetric pre-start leave behavior. The code-room creator is Blue; a Quick Match's waiting player becomes host/Blue. Both entry flows start from the same shared initial snapshot. |
| Domain, Firestore port and application code | Keep the domain repository interface as the boundary; widen the Firestore port only for metadata and cursor recovery, with the in-memory implementation modeling those capabilities. |

The Phase 9 prompt's illustrative nested `boardConfig` object is **not** used:
the existing room wire shape already stores `boardSize` and `wallsPerPlayer` as
flat fields. `architecture.md` §11 now records that shape. `schemaVersion` was
bumped from 1 to 2 for the additive match fields; readers continue accepting
version 1. A started document with no decodable `boardState` is rejected as
invalid remote data. `RoomStatus.finished` is separate from game status;
`cancelled` remains its own unused value (Q-8.3), never a synonym for completion.

### Q-8 carry-forward resolution

- **Q-8.3 remains open:** `RoomStatus.cancelled` still has no producer. It was
  not repurposed; finished games use `RoomStatus.finished`.
- **Q-8.4 is resolved:** `watchWithMetadata` distinguishes cached/offline and
  pending-write states, and the controller exposes all five design states.
- **Q-8.6 is resolved:** the `/game` route opts into `GameScreen.ownsController`,
  and `game_screen_disposal_test.dart` proves a route pop disposes its controller
  while the borrowed-controller case remains caller-owned.

### Snapshot and free-tier accounting (checked 2026-10-01)

The compact UTF-8 JSON shape produced by `GameStateSerializer.toJson` measured
**1,573 bytes** for a 9x9 state with 20 wall records and the normal 10-wall
starting inventory. This serializer-shape measurement counts the exact fields
and compact encoding; the synthetic wall list is not a legality fixture. It is
payload size only, excluding Firestore document and index overhead. Each game
also retains one small move document per ply; those
append-only records dominate accumulated storage. No live Firestore storage
measurement is available before Q-7.4 is closed.

The Firestore Standard/Spark free quota was checked against the official
[Firestore quota table](https://firebase.google.com/docs/firestore/quotas) and
[billing guide](https://firebase.google.com/docs/firestore/pricing): 50,000
document reads/day, 20,000 writes/day, 20,000 deletes/day and 1 GiB stored data
(plus 10 GiB/month outbound transfer). Each applied action does two transaction
document reads (match + that turn's move record), and each of the two clients
receives one changed match document through its listener: approximately **4
reads and 2 writes per action**. Start-up adds roughly five room writes (create,
join, two ready changes, start), initial listener snapshots and room reads. A
811-ply accounting case costs about 3,244 action reads plus start-up and 1,622
action writes plus five room writes. At approximately 3,248 reads and 1,627
writes, writes are the limiting quota: **12 full games/day** at this length
(floor(20,000 / 1,627)); reads alone would allow about 15. This is a client-side
estimate; transaction retries, reconnect listener re-reads, future security-rule
lookups and recovery pages add reads. Recovery reads one document per move, only
when verification fails. Storage includes indexes and metadata and has not been
observed on a configured backend.

For an 811-ply sizing case with a 9x9 board, 20 wall moves, 28-character
anonymous uids and compact JSON records, the measured payload is 152,560 bytes
for move documents plus 21,897 bytes of document paths and the 1,573-byte state
payload: **176,030 raw bytes**. This excludes the parent room's other fields and
Firestore's metadata/index overhead, so it is a lower bound, not an observed
database storage size. The exact 811-ply maximum was measured in the reproducible
201-game suite on 2026-10-01 at seed `20269982`; that random-game config has six
walls per player. The 20-wall payload calculation is a conservative size case
using the standard 9x9 inventory, not a claim that this exact seeded game placed
20 walls. The exact longest legal game is not known. The spec's 431-ply oracle
maximum is lower than the repository's observed random games and is therefore
not used as a capacity bound.

### Current quality-gate run (2026-10-01)

- `dart format --set-exit-if-changed lib test` → `Formatted 121 files (0 changed)`.
- `flutter analyze` → `No issues found! (ran in 75.7s)`.
- `flutter test --coverage` → `1470: All tests passed!` (6m48s).
- After adding seed values to random-game test names and failure messages,
  `flutter test --no-pub --reporter compact test/data/random_full_game_test.dart`
  → `201: All tests passed!` (32s); failures now print the exact replay seed.
  The longest game measured by a temporary run-only counter was 811 plies at
  seed `20269982`; the counter was removed after measurement.
- `flutter build web --release` → `√ Built build\\web` (75.7s).
- Spec checker → `OK: spec is consistent with the reference engine.`
- Generated vectors and checked-in fixture both measured 1,229,568 bytes and
  SHA-256 `6f1e3c0542f876d841d31ec2738d2798d3ad437ef176f3cbea1a63ea5394ba96`;
  byte-identical.
- Mojibake scanner → `scanned 145 tracked text files ... RESULT: 0 files with mojibake`.
- `coverage/lcov.info`: `online_game_controller.dart` 161/193 (83.4%);
  `firestore_match_repository.dart` 134/146 (91.8%);
  `in_memory_firestore_client.dart` 108/109 (99.1%);
  `online_game_screen.dart` 132/152 (86.8%); `cloud_firestore_client.dart`
  1/48 (2.1%). Its real Firestore metadata listener, transaction adapter and
  document-id cursor are unverified without a Firebase SDK/emulator. The zero-hit
  declarative files are `match_setup.dart`, `app_colors.dart`, `app_radii.dart`,
  `app_spacing.dart`, `app_typography.dart` and `app_info.dart`.

## 13r. Phase 10 — Online Reliability and Security (2026-10-26)

### Phase 10 source ledger

| Source | What it fixed for Phase 10 |
|---|---|
| `architecture.md` §12 | The eight enforcement items the rules must implement; the "Important limitation" paragraph Phase 10 had to demonstrate, now backed by two named emulator tests. |
| `architecture.md` §11 (as corrected in Phase 9) + `Room.toJson` / `MatchMove.toJson` | The real document shapes the rules validate. All Firestore writes are full-document `set`s; move submission is one transaction writing the room and the move record together; an identical retry writes nothing. |
| PRD §9 | Monotonic turn/version and valid-shape checks; no opponent-timeout duration is specified anywhere — the 120 s threshold is Phase 10's reasoned default, recorded below. |
| `phase.md` Phase 10 | Task list and exit criterion; Phase 11 owns the full UI (and therefore the rematch consent flow). |
| `design.md` §21 | Result-screen/rematch placement — the second reason rematch is deferred whole rather than half-built. |
| Q-9.2, Q-9.3 | The two decisions Phase 10 had to close: rematch (deferred, below) and opponent-side timeout (built, below). |

### What was built

**`firestore.rules`** (new, repository root; `firebase.json` gained only a
rules pointer and emulator config — no credentials). Rules are written in
the canonical full form, `match /databases/{database}/documents { … }`.
Enforced, each with allow and deny coverage in the emulator suite:

- `matches/{code}` create: two shapes only — the code room (creator is
  host and Blue, Red seat empty) and the Quick Match room (both seats
  filled, valid only inside the claim transaction: `getAfter` requires
  both players' `matched` documents to land with the identical payload).
- Updates are a single versioned step (`version` +1, `updatedAt`
  non-decreasing, timestamps not more than 5 minutes in the future) and
  exactly one transition kind: pre-start change (join/ready/leave, with
  the status the seats derive), match start (host only, both seats ready,
  `boardState` exactly `GameState.initial` for the config), a move write
  (requester is the stored player-to-move; turn +1; the denormalised
  copies — `turnNumber`, `currentPlayerId`, remaining walls, pawn
  positions — must agree with the snapshot, including R-STATE-05 parity),
  or an abandonment claim (below). An identical rewrite by a member is
  allowed as the idempotent no-op. Identity fields (`hostId`, board
  config, `createdAt`, seats' owners) never change; `schemaVersion` may
  migrate 1→2 for legacy documents.
- A finished or abandoned match accepts no further transitions.
- `moves/{NNNNNN}`: created only by the player to move, in the same
  transaction as the room write (id must equal the turn it records,
  `resultingVersion` must be the room's next version); immutable
  thereafter except the byte-identical retry by its own player; readable
  only by the two players.
- Delete: host only, and only before the match starts (the pre-start
  leave path).
- `matchmaking/{boardKey}`: `waiting/{uid}` is owner-written; deletable
  by its owner, by the claiming opponent (proven via `getAfter` on the
  matched pair), or by anyone signed in when the entry is stale
  (> 60 s) or malformed — Phase 8.1's reaping design. `matched/{uid}` is
  readable only by its owner and written only inside the claim
  transaction.
- `users/{uid}/{document=**}` and `playerRooms/{uid}`: owner-only.

**The demonstrated limit (prompt §3).** The suite's LIMIT test contains
two writes the rules ACCEPT: Blue's pawn teleports (8,4)→(5,4) in an
otherwise fully valid move write, and Blue seals the board with five
horizontal walls across row 4 (anchors' columns 0, 2, 4, 6, 7,
`remainingWalls.blue` = 5). Rules check structure, authorization and
arithmetic coherence; legality — adjacency, per-wall placement rules,
path preservation (R-PATH-01) — would require re-implementing the engine
in the rules language. Compensation, unchanged from Phase 9: clients
verify snapshots against the engine before adopting them, so an honest
client never *plays* an illegal state. The residual risk is stated
plainly in `security_model.md`: a malicious client can write a state the
opponent's client will refuse, wedging that match. Closing it needs a
trusted backend (Cloud Functions) and therefore billing; Phase 10 does
not add one, and the exit criterion does not require it.

**Timeout and abandonment (Q-9.3, resolved).** Threshold:
`opponentInactivityThreshold` = 120 s in
`lib/domain/repositories/match.dart`, mirrored in the rules as
120 000 ms between the stored `updatedAt` and the server's
`request.time`. `OpponentPresence` is derived in
`OnlineGameController` (a 5 s periodic re-check; listeners only fire on
document changes, and a stalled opponent produces none). The waiting
player sees "Your opponent seems to have disconnected" with a
confirm-then-claim action; `FirestoreMatchRepository.claimAbandonment`
runs the checks inside a transaction and writes status `abandoned` +
`abandonedById` + `version` +1. `winnerId` stays null: abandonment is
not a played result (new `RoomStatus.abandoned`, deliberately distinct
from `cancelled` and `finished`). Race handling is symmetric: whichever
of the move and the claim commits first wins, and the loser is refused
with a typed reason (`AbandonmentFailureReason` / the move path's
`matchFinished`). Documented limit: `updatedAt` is written by the acting
player's device clock, so clock skew shifts the effective wait.

**Abuse resistance, v1.** One open code room per player, guarded by the
`playerRooms/{uid}` pointer (`openRoomCode`, nullable; set on
create/join, cleared on start/leave; trusted only after re-reading the
room it names, so a stale pointer heals itself). Rules cannot enforce
the one-room limit (they cannot query), so the boundary is the per-room
rules; the pointer is a client-side guard and `security_model.md` says
so. Quick Match is not pointer-guarded (that would break the claim
transaction's atomicity); it is bounded structurally. No server-side
sweep of stale pre-start rooms exists on Spark.

**Rematch (Q-9.2, resolved by deferral).** Deferred to Phase 11 with the
reasoning recorded in `phase.md`'s Phase 10 Result: rematch is a new
room with fresh seats plus a two-player consent flow, and both the
result screen and the consent UI are Phase 11 work (`design.md` §21).
Nothing in the Phase 10 rules blocks it when it lands.

### Open-question ledger after Phase 10

- **Q-8.3 closed.** `RoomStatus.cancelled` is retained with no persisted
  producer, deliberately: host leave deletes the document (Phase 8's
  recorded behaviour), and `cancelled` remains the value `leave()`
  returns for that case. It was not repurposed for abandonment; Phase 10
  added `abandoned` instead.
- **Q-9.2 closed** (deferred to Phase 11, above). **Q-9.3 closed**
  (built, above). **Q-9.5** (match document is the room document) needed
  no split in Phase 10 either; the rules validate the combined shape.
  **Q-8.12 unchanged**: `matched` documents are still never deleted.
- **Q-7.x carried forward:** Q-7.3/Q-7.5 remain as last recorded; Q-7.4
  was closed by the 2026-10-26 live verification (Phase 9 record).
- **New (Phase 10 finding) — the storage port's per-user paths are not
  Firestore document paths.** The port names documents
  `users/{uid}/settings` (and `statistics`, `unfinishedMatch`): an odd
  segment count, which the real Firestore SDK rejects as a document
  reference (the in-memory double accepts any string, so Phase 7's tests
  could not see this). The Firestore-backed settings/statistics/
  unfinished-match repositories have therefore never been able to write
  to a real backend; the app defaults to local storage, so nothing user-
  visible depends on it yet. The rules already guard the whole
  `users/{uid}` subtree, so whichever layout replaces it (a document at
  `users/{uid}` or documents inside the named subcollections) needs no
  rules change. Fixing the layout belongs with the phase that first
  enables the Firestore-backed repositories for real.

### Test-harness findings (Phase 10)

- The rules suite caught one of its own tests being vacuous:
  `staleStartedRoom` ignored its overrides argument, so the first
  abandonment-claim test passed as an idempotent rewrite and the
  "too early" case seeded a stale room. Fixed; the claim tests now
  exercise the real transitions (and a boundary probe confirmed the
  rules deny claims at 0–119 s of inactivity and allow them at ≥ 121 s
  against the emulator's server clock).
- Two emulator environment quirks in the sandbox, both recorded in
  `security_model.md`: the emulator JVM needs
  `-Djava.net.preferIPv4Stack=true` (its internal loopback channels fail
  on IPv6-preferred hosts), and that build evaluates rule paths as
  absolute paths — one reason the rules use the canonical
  `/databases/{database}/documents` wrapper form.
- Widget tests dispose controllers in the test body, not in
  `addTearDown`: `OnlineGameController`'s presence timer is periodic, and
  the test binding's pending-timer check runs before tear-down
  callbacks. Relatedly, a test must not call `connect()` twice on one
  controller: the second call awaits the first subscription's
  cancellation, which never completes in a fake-async zone while the
  watch stream is idle. (In the app each controller is connected exactly
  once; noted here as a sharp edge for Phase 11 test work.)
- Three `room_lifecycle_test.dart` assertions now count only
  `matches/`-prefixed documents and assert the pointer document's value:
  the Phase 10 pointer is a legitimate second document in the store.

### Current quality-gate run (2026-10-26, Phase 10)

- `dart format --set-exit-if-changed lib test` → `Formatted 125 files (0 changed)`.
- `flutter analyze` → `No issues found!`
- `flutter test` → 1,502 tests: **1,493 passed, 9 failed** — the 9 are
  the known environmental golden-image failures, identical on the
  pristine Phase 9 tree in this VM; Phase 10 changed no rendering code.
  28 of the 1,502 are new Phase 10 tests (abandonment 10, open-room
  limit 7, opponent presence 6, presence UI 5).
- `flutter build web --release` → succeeds.
- Spec checker → `OK: spec is consistent with the reference engine`
  (80 catalogue rows, 65 rule IDs, 65 in matrix).
- Oracle fixture → 1,229,568 bytes, SHA-256
  `6f1e3c0542f876d841d31ec2738d2798d3ad437ef176f3cbea1a63ea5394ba96`,
  byte-identical.
- Rules suite (`tool/rules_tests/`, Firestore emulator) → **33 tests,
  33 passed, 0 failed.**
- `game_spec.md` and `rules.md`: unmodified.

## 13s. Phase 11 Record — Full UI/UX (completed 2026-10-26)

Authorized 2026-10-26 with the owner's full Phase 11 prompt. Scope: every
screen in `phase.md` Phase 11 (Splash, Home, Game modes, Local, AI
difficulty, Online lobby, Create match, Join match, Main game, Result,
Tutorial, Profile, Settings), real navigation with no dead ends, the
shared Result screen, the online rematch consent flow (Q-9.2), and the
retirement of the `BoardPreviewScreen` dev tool as the app entry point.
Out of scope: audio/haptics systems (Phase 12), accessibility
infrastructure (Phase 13) — those Settings groups are built visibly
inert — and any change to the engine, `game_spec.md`, Firestore rules,
or move-sync logic.

### Source ledger (§0 — every screen cites its source)

| Screen / element | Source |
|---|---|
| Splash | Stitch `splash_screen` (emblem, wordmark, tagline layout). Its telemetry (`60 FPS`, `ONLINE ARENA`, `SHADERS: CACHED`, fake load percentages, hard-coded `V1.4.0`) is fabricated mock data and is excluded per the prompt. No version string is shown (no `package_info` dependency exists, and `rules.md` §3.3 bars adding one for a label; the real version lives in `pubspec.yaml`: 1.0.0+1). |
| Logo mark | Stitch `wallforge_strategic_logo` SVG (shield tile, crossed cyan/crimson wall bars, two pawns), redrawn as a Flutter widget (`WallforgeLogo`) from the app tokens; also used on Home. |
| Home | `design.md` §17 (logo, tagline, Play, mode options, profile/settings access, small board visual) + Stitch `home_launcher` layout only. The mock's ranked ladder, ELO, streak counter, "Cyber Citadel" event, Academy, Daily Tactic, recent-activity row and stats ribbon are fabricated and excluded. Real data only: a resume card when `UnfinishedMatchRepository` holds a match, and a statistics summary when `MatchStatistics.matchesPlayed > 0`. |
| Game Modes | `design.md` §18 — verified by direct read: three modes with exact one-line descriptions (Local "Two players on one device.", Vs AI "Single player against AI.", Online "Remote two-player match."), each mode needing icon/title/description/action; §18 contains NO pickers. The board-size and wall-count pickers come from the Stitch `game_setup_modes` mock, legitimised by the prompt §2 (the app already supports configurable `BoardConfig`); the chosen config is carried forward in memory to the mode's next screen and is not persisted as a setting. The mock's Chronometer (turn clock) and "Fair Path Integrity" toggle are not features and are excluded. |
| Local | `phase.md` list + §18 flow: Modes (Local selected, config chosen) → Start Local Match → the existing local `GameScreen`. There is no separate local-setup source anywhere; recorded as the mapping for the phase list's "Local" entry. |
| AI difficulty | `design.md` §20 (Easy/Medium/Hard/Expert, `AiDifficulty`'s own descriptions verbatim, AI is always Red, "AI is thinking…" with input disabled while it thinks, never "perfect AI" claims). No Stitch screen exists. Resolves Q-5.2. Starts via the existing `MatchSetup` route argument — no second AI pathway. |
| Online lobby / Create / Join | `design.md` §19 (contents only: create match, join match, room code, opponent status, connection state; states named Connecting/Waiting/Connected/Reconnecting/Disconnected; no layout, no Quick Match mention — Quick Match is a shipped Phase 8.1 feature kept as-is). No Stitch screen. Decision: one lobby screen with three distinct cards (Create / Join / Quick Match) rather than split routes — §19 mandates contents, not routes; create and join share one live controller and room stream, and splitting them across routes would duplicate that lifecycle. `architecture.md` §18's `/online/create` and `/online/join` paths are registered as aliases that open the lobby focused on the matching section, so no §18 path is a dead route. |
| Main game | Existing `GameScreen` / `OnlineGameScreen` + `BoardView` (Phases 3/4/9/10), layout per `design.md` §16. Not rebuilt; navigation into and out of them is what this phase adds. |
| Result | `design.md` §21 — verified by direct read: it names elements only (winner: victory heading, player piece, statistics, Rematch, Home; loser: "Match complete.", statistics, Rematch, Home; no humiliating language) and specifies NO exact strings and NO statistic fields. Chosen and recorded: the heading follows the app's existing result-overlay convention (`BLUE WINS!` / `RED WINS!`; the side that did not win in AI/online play is headed "Match complete."); the player piece is the winner's pawn disc with its B/R letter (§26 pattern); statistics are `Turns played` (actions played from the finished state), `Walls used — Blue` and `Walls used — Red` (configured walls − remaining walls) — all derived from the real finished `GameState`, never invented. One shared screen for local, AI and online endings. |
| Tutorial | `design.md` §22 — verified by direct read: real board, one concept at a time, an *example* sequence (Goal → Move → Wall → Block → Race), skip and revisit allowed; NO step copy, progress or first-run rule exists in any source. `PRD.md` §6.7's teach list (Goal, Movement, Wall placement, Limited wall inventory, Winning) covers the same ground. Chosen and recorded: five steps following the §22 example (Goal, Move, Wall, Block, Race — with the limited wall inventory taught inside the Wall step, per PRD §6.7), all step copy written for this phase, each step's board a real `GameState` driven by the real engine through `LocalGameController`, and the Move/Wall steps advance only when the learner performs the action. Completion or skipping writes the Phase 6 reserved flag `AppSettings.tutorialCompleted` (its recorded meaning from this phase: the first-run offer has been resolved; replay stays available from Home and Settings regardless). First run: the tutorial does not auto-start; Home shows the tutorial card prominently until the flag is set (no source mandates auto-start; the prompt §4 offer is met by the prominent card). |
| Profile | `design.md` §15 card use "Profile statistics" only — no Profile section exists in `design.md`. Data is exactly what `MatchStatistics` stores (played / wins / losses / win rate, `byDifficulty` buckets with pass-and-play under `local`, `byBoardSize` buckets); online matches are not recorded in that repository and the screen says so rather than implying coverage. Anonymous uid shown when signed in (PRD §10 non-goals: no named accounts, ranking or avatars). |
| Settings | `design.md` §23 — verified by direct read: five groups in order (Gameplay, Audio, Haptics, Accessibility, Account); item names only, no control types, defaults or definitions anywhere in the section. Gameplay: Confirm wall placement = the real persisted Phase 6 setting (same source as the game HUD toggle); Movement assistance has NO definition in §23 — scoped by this phase, per the prompt §3's own example, as shortest-path highlighting while Move is selected, and implemented for real (see the schema note below). Audio (Music/Effects/Volume), Haptics (Haptic feedback) and Accessibility (Reduced motion/Color assistance/High contrast/UI scale) are Phase 12/13 features: rendered as disabled rows labelled as not yet available, so nothing looks functional while doing nothing. Account: account information = the real anonymous-auth state; Sign out is real, via the Phase 8 auth gateway. There is no Data/reset group in §23 and none was built. |
| Navigation | `architecture.md` §18 route list, plus `/` (the splash) as the entry and `/online/game` for the online match screen (the §18 list names `/game` only; the online screen needs its own route because its arguments are a room and a seat, not a `MatchSetup`). Centralised in `AppRouter`; no widget-instance pushes. |
| Board orientation (Q-9.1 revisited) | **Kept: no flip.** Phase 11 re-examined the Phase 9 default as the prompt required. Reasons: the canonical orientation plus the `YOU` seat marking (text + outline, not colour alone, §26) already answers "which side is mine"; the Result screen, seat rows and HUD all key off the canonical orientation (Q-9.6's knock-on list); and no playtest complaint exists. Reversal cost remains one board-orientation transform. Q-9.1 is closed as decided-in-Phase-11, not merely inherited. |
| Online rematch (Q-9.2) | New room, fresh seats, explicit two-player consent, built on the existing matchmaking claim pattern. The finished room document is locked by the Phase 10 rules (no transition matches it), so consent is signalled through the shipped matchmaking namespace, which the rules deliberately make generic over `{boardKey}`: a proposal is a waiting entry under the finished match's own config key `s{size}w{walls}`; the opponent's result screen watches that queue for the finished opponent's uid and offers Accept/Decline; Accept runs the standard claim transaction (proposer = host/Blue as waiter, acceptor = Red; both `matched` docs + the new room in one transaction), and both clients enter the new room's existing ready/start flow — the ready handshake is the second consent. Decline = no claim (or navigate Home); a proposal lapses with the queue's 60 s staleness window or when the proposer cancels. Known limit, recorded honestly: a proposal entry is indistinguishable in shape from an ordinary queue entry, and a third player's Quick Match claim could consume it first; the proposer's client detects that outcome (the matched room's other seat is not the finished opponent) and leaves that room, ending the proposal. `firestore.rules` is unchanged; emulator tests were added proving the claim shape works for this use. |
| Movement assistance (schema note) | `AppSettings` gains one field, `movementAssistance` (bool, default false) — the single persisted-schema extension of this phase, recorded per the prompt §5 rule: §23 lists the row with no definition, the prompt §3 sanctions defining a small real feature (its example is this one), and a non-persisted toggle would reset silently. Scoped as: while Move is selected, the current player's shortest route to their goal row — computed on the engine's own wall graph (`BlockedEdges` BFS, pawns ignored, exactly the `Pathfinder` semantics) — is drawn on the board in the local, AI and online game screens. |

### Route map (as built)

```text
/                   SplashScreen — entry; replaces itself with /home
/home               HomeScreen
/modes              GameModesScreen (config chosen here, passed along)
/local              (alias → /modes with Local preselected; §18 path kept live)
/ai                 AiDifficultyScreen (config passed from /modes)
/online             OnlineLobbyScreen (Create / Join / Quick Match cards)
/online/create      (alias → /online focused on the Create card)
/online/join        (alias → /online focused on the Join card)
/online/game        OnlineGameScreen (room + seat arguments)
/game               GameScreen (local / AI, MatchSetup arguments)
/result             ResultScreen (shared: local, AI, online)
/tutorial           TutorialScreen
/profile            ProfileScreen
/settings           SettingsScreen
```

Every screen above has a route back to `/home` (directly, or via its
parent in the map) and the navigation test walks this map.

### Completion record (2026-10-26)

All thirteen screens are built and routed as the ledger above records.
Two wording corrections to the ledger, from what the build actually does:
the tutorial's interactive steps do not auto-advance — performing the
action *completes* the step and enables NEXT (a disabled NEXT plus a
"Make the move / Place a wall to continue." hint is what an unfinished
interactive step shows); and the Wall step opens already in wall mode, so
its copy teaches staging a wall in a slot and confirming it (there is no
WALL toggle inside the tutorial).

Three defects were found by this phase's own tests and fixed in-phase:

1. **Matched-document liveness read the wrong document.**
   `FirestoreMatchmakingRepository` decided whether a pairing was still
   live from the *matched* document — a snapshot written at pairing time
   whose embedded status still says `waiting` after the match has ended.
   Left as it was, no player could ever pair twice on the same board
   configuration: not for a rematch, and not for a second Quick Match.
   Liveness is now read from the room document itself, both in the
   repository's shortcuts and inside the claim transaction, and
   `watchForMatch` follows the named room document so it falls silent
   when the room finishes. Covered by
   `test/data/rematch_matchmaking_test.dart`.
2. **`BoardView` threw for a small `maxSize`.** Its size clamp assumed
   `maxSize >= 280`; Home's small board visual (176) made `clamp` throw
   an `ArgumentError`. The 280 floor now applies only when the cap
   allows it. Rendering at every previously used size is unchanged.
3. **The splash could hijack the top route.** A deep initial route
   builds `/` underneath the target screen; the buried splash's timer
   later fired `pushReplacementNamed('/home')` against whatever route
   was on top. The splash now hands over only when its own route
   `isCurrent`.

Also in-phase: Profile's by-difficulty rows now show the `AiDifficulty`
label ("Vs AI — Hard") instead of the raw stored key.

`firestore.rules` is unchanged. One emulator test was added
(34/34): a rematch claim after a finished match — both matched
documents overwritten, both queue entries consumed, new room created —
succeeds under the shipped rules.

Gates (2026-10-26): format 139 files 0 changed; analyze — no issues;
full suite 1,571 tests — 1,562 passed, 9 golden-image failures
re-determined environmental (the identical 9 fail on the pristine
Phase 10 tree, worktree-verified this phase); web release build OK;
spec checker OK; oracle byte-identical (1,229,568 bytes, SHA-256
6f1e3c05…); rules emulator 34/34; mojibake scan clean.

Open Questions disposition: Q-5.2 closed (dedicated AI difficulty
screen, §20 wording verbatim); Q-9.1 closed as decided in this phase
(no flip; reasoning in the ledger); Q-9.2 closed (rematch consent flow
built as recorded); Q-8.5 closed (lobby contents per §19, visuals
aligned to the shared Phase 11 card/button kit). Q-6.1 (a finished
local match's "play again") is answered in practice by the Result
screen's Rematch for local and AI play. No new Open Questions were
raised by this phase. Phase 12 was not started.


## 13t. Phase 12 Record — Audio, Haptics and Animation (completed 2026-10-27)

Authorized 2026-10-27 with the owner's full Phase 12 prompt. Scope:
sound effects, background music, haptics, board and UI animation, and
Reduced Motion, exactly as `phase.md` Phase 12 lists them. Out of
scope: the rest of Accessibility (Phase 13), and any rule, engine,
sync or security change — none was made (`firestore.rules` untouched,
oracle byte-identical).

### Source ledger (§0 — every effect cites its source)

| Effect | Source | Timing / treatment |
|---|---|---|
| Pawn movement animation | `design.md` §8 "Moving: smooth translation" + §24 band | 350 ms (`FeedbackTiming.pawnMovement`, band 250–450) |
| Landing bounce | §8 "Landing: small bounce" | Final 30% of the move: scale swell 1 + 0.14·sin(πu) |
| Wall placement animation | §9 "Small scale/opacity animation into final position" | 240 ms (`wallPlacement`, band 180–300), scale 0.7→1 + fade, from the confirmed ghost's slot to the placed wall |
| Active pawn glow | §8 "Active: slight glow/pulse" | The Phase 3 static glow already existed (verified, not duplicated); the *pulse* is applied as a one-shot swell (300 ms, UI band) when the turn changes, per §24's purposeful rule — a perpetual pulse was rejected as decoration and as a test/perf hazard (it would keep `pumpAndSettle` and the frame loop busy forever) |
| Selected ring | §8 "Selected: stronger ring/highlight" | **Gap found by verification:** `selectedCell` was plumbed from controller → BoardView → BoardPainter since Phase 4 but no code ever drew it, and no screen ever passed it. Phase 12 draws the ring (3 px, current player's colour, fading in over the 140 ms micro band) and passes `controller.selectedCell` from the local and online game screens |
| Goal-strip animation | §7 "Use animation only when appropriate: goal proximity, victory. Do not constantly animate" | Proximity pulse 500 ms (victory-band floor); victory pulse inside the 750 ms celebration. *Proximity* is recorded as: the pawn newly reached the row adjacent to its goal row (Blue row 1, Red row size−2) — one step from the goal edge, decidable without pathfinding (`rules.md` §16) |
| Victory celebration | §7 + §8 "Goal: celebration animation" + §24 band | 750 ms (`victory`, band 500–1000): winning pawn swell + its goal strip's pulse |
| UI transitions | §24 UI band + `phase.md` task list | 240 ms (`uiTransition`, band 180–300): `WallforgePageRoute` fade + slight rise for every route; the turn banner cross-fades via `AnimatedSwitcher` in both game screens |
| Sound cues | §25's exact list: move, wall placement, invalid action, turn change, victory, button press | One synthesized clip per cue (below) |
| Background music | `PRD.md` §6.6 + `phase.md` task list (§25 does not list it separately) | One 6 s loopable pad (Am–F–C–G), toggled independently from effects per §23's grouping |
| Haptics | §25 "subtle, optional, disabled by reduced-motion where appropriate" | Move = light impact, wall = medium, invalid = heavy, victory = medium, button = selection click, **turn change = none** (decided and recorded: the turn returning is already announced by sound and the banner; a buzz on every opponent move would not be "subtle"). No haptic is ever the only signal — every cue pairs with the existing visual/text treatment (§26; the invalid action keeps its Phase 4.2 text/shape feedback) |

Timing constants live in one place, `lib/core/feedback/feedback_timing.dart`
(`FeedbackTiming`): microFeedback 140 (band 100–180), uiTransition 240
(180–300), pawnMovement 350 (250–450), wallPlacement 240 (180–300),
victory 750 (500–1000), turnGlowPulse 300, goalProximityPulse 500.

### The Reduced Motion correction (§2, recorded as required)

`design.md` §23 files Reduced Motion under Accessibility, and Phase 11
labelled that group Phase 13 because no animation system existed to
reduce. `phase.md`'s Phase 12 task list names "Reduced-motion mode"
itself, and Phase 12's exit criterion is "animations are smooth and
can be disabled/reduced where required" — so **Reduced Motion is real
in Phase 12**: it is the control for the system this phase built, and
deferring it would have shipped animations with no off switch. Color
assistance, High contrast and UI scale remain visibly inert and
Phase-13-labelled (a settings test pins exactly three disabled,
Phase-13-labelled switches), because nothing in this phase touches
colour, contrast or scale. (Phase 13's own task list also names reduced
motion; that is now satisfied early, and Phase 13 inherits it as
done.)

The seam is `FeedbackScope.reducedMotionActive(context)`: platform
`MediaQuery.disableAnimations` **OR** the persisted in-app toggle —
either one activates it. "Reduced" is recorded as: **skip the animation
and apply the end state instantly** (duration zero), applied
consistently by the board animator, the page route and the banner
switchers, and mirroring Flutter's own treatment of the platform
signal. Haptics are suppressed while reduced motion is active (§25);
sound is not motion and is never muted by it.

### Architecture (as built)

- The feedback layer is `lib/core/feedback/` — `core/` because
  `architecture.md` §15 already places cross-cutting code there and the
  layer serves controllers (application), widgets (presentation) and
  the router (app) alike. `FeedbackController` exposes the six cue
  methods and owns the settings snapshot and music lifecycle;
  `SoundBackend`/`HapticsBackend` are interfaces so tests substitute
  fakes; `FeedbackScope` is the widget-side seam; `FeedbackService`
  holds the one shared instance for context-free callers (the router,
  controller factories). The class is `FeedbackService`, not `Feedback`:
  Flutter already exports a `Feedback` widget and the names collided.
- Cues trigger from the shared `GameInteraction` mixin at the point an
  action resolves (local success/failure), from `LocalGameController`
  (victory; the AI's turn return), and — for online play — from
  `OnlineGameController`'s verified-snapshot adoption, **not** at submit
  time: a submit's verdict is asynchronous, so `cuesOnAttempt` is false
  online, own-action cues fire when the snapshot adopts them (the Phase
  9 echo verdict makes double-firing impossible), opponent actions fire
  the turn-change cue, a finish fires victory, and only an
  `invalidAction` rejection fires the invalid cue. Catch-up jumps
  (>1 ply) attribute no action and fire nothing except a finish. The
  first adopt after connecting is joining, not an event, and fires
  nothing (the echo verdict counts as adopted — this was a real bug
  caught by the phase's own online cue test, which at first saw the
  mover's cue swallowed by exactly this guard).
- Board animation respects the Phase 3 painter architecture: the
  painter gained an optional `BoardAnimator` (registered as its
  `repaint` listenable, so frames repaint only the board's
  `RepaintBoundary`) and an idle frame renders byte-for-byte the
  pre-Phase-12 board. Animations react to transitions in
  `BoardView.didUpdateWidget` (single-ply only; jumps animate nothing),
  never cause engine work, and never feed back into state — a new
  transition mid-animation simply replaces the effect.
- Settings: `AppSettings` gained `musicEnabled` (default on),
  `effectsEnabled` (on), `volume` (default 0.5 — the value the Phase 11
  inert slider displayed, so activation did not silently move it;
  clamped 0–1 on load), `hapticsEnabled` (on), `reducedMotion` (off),
  all with total `fromJson` fallbacks and round-trip tests. Every
  Settings save applies to the live feedback layer in the same moment
  it persists.

### Packages and assets (§3.3 vetting)

- **Audio: `audioplayers` 6.8.1** (added via `flutter pub add`).
  Purpose: Flutter has no built-in audio playback. Compatibility
  verified on pub.dev (2026-10-27): "works for Android, iOS, Linux,
  macOS, Windows, and web" — covering the project's three targets;
  actively maintained (package updated 2026-06). No animation package:
  Flutter's built-ins sufficed, as `rules.md` §4 requires be shown
  first. Haptics: **no package** — the built-in `HapticFeedback` API
  covers every §25 need.
- **Assets are produced, not sourced**: every file in `assets/audio/`
  is synthesized by `tool/audio/generate_audio.py` (deterministic,
  seeded) and released under CC0 (`assets/audio/LICENCE.txt`, following
  the fonts folder's licence-file convention). Effects are 22050 Hz
  mono WAV (2–34 KB each); the music loop is a 6 s MP3 at 96 kbps
  (73 KB). Total 152 KB. This avoided any third-party licence question
  entirely and keeps the project's zero-cost posture.

### Performance profile (§3/§16, real findings)

- The animator's ticker runs **only while an effect is in flight** and
  stops itself when the last effect drains (asserted in tests via
  `isAnimating` after every animation test); an idle board schedules
  no frames. Repaints are confined to the board's existing
  `RepaintBoundary` (the painter's `repaint` listenable); no other
  widget rebuilds per frame.
- Animations never run pathfinding or legal-move calculation:
  proximity is a row check on the already-known pawn positions, and
  every other effect keys off the state transition itself.
- Flurry test: 12 plies delivered at 50 ms intervals (faster than any
  animation) through the real `BoardView` — state stays exact, effects
  are replaced rather than queued, everything drains, no exceptions;
  the full new board-animation suite (11 tests incl. full rendering)
  completes in seconds on this 2-CPU VM.
- Audio: effects play on one low-latency player (a new cue replaces,
  never queues behind, the previous); all backend calls are
  failure-tolerant — on the web a browser may refuse playback before
  the first user gesture, and that refusal is logged, never surfaced,
  and never blocks play.

### Completion record (2026-10-27)

New tests: 48 (feedback gating + cue mapping, controller cue wiring,
online exactly-once cue counts across the scripted two-client game —
18 cues on the host, 17 on the guest, exactly as the cue rules predict,
board animation timing/reduced/flurry, settings gating). One Phase 11
settings test was updated where Phase 12 legitimately changed the
behaviour it pinned (the inert-rows test now pins the three remaining
Phase 13 rows).

Gates (2026-10-27): format 149 files 0 changed; analyze — no issues;
full suite 1,619 tests — 1,610 passed, 9 golden-image failures
**re-verified environmental**: the identical 9 (5 board + 4 game
goldens) fail on the pristine Phase 11 tree (worktree at `d132be9`,
verified this phase), unchanged in set from Phases 10–11; web release
build OK; spec checker OK; oracle byte-identical (1,229,568 bytes,
SHA-256 6f1e3c05…); mojibake scan clean. `firestore.rules` untouched;
rules-emulator suite not re-run (no rules or sync change this phase).

Also in-phase, a one-line repair outside the phase's scope but in its
path: the Phase 11 `// ignore: close_sinks` in
`firestore_matchmaking_repository.dart` sat one statement below the
declaration the lint reports on, so `flutter analyze` showed one info;
the comment now sits on the declaration it describes. No code changed.

Open Questions: none raised by this phase. The music is a synthesized
pad, not a composed track — replacing it with a recorded/composed loop
later is an asset swap behind `FeedbackAssets.music`, not a code
change. Phase 13 was not started.

## 13u. Phase 12 Correction — the local-play regression (found and fixed 2026-10-28)

**The original Phase 12 report (§13t) was wrong.** It stated the phase
was complete and gate-verified. In the real app, local pass-and-play
and vs-AI play were both broken: the pawn did not move and walls did
not place. Online play worked. The owner found this running the
Drive copy on their laptop; §13t's gates had not caught it, for the
reasons below. This section is the correction: the real root cause
(found by reproduction, not assumed), the fix, and the test that now
stands guard.

### Root cause (proven, with the evidence)

The Phase 12 feedback wiring in the `/game` route builder
(`app_router.dart`) did two things inside the route's `builder:`:

1. it created the match's `LocalGameController` there
   (`_controllerFor(settings)`), and
2. it read the feedback layer with
   `FeedbackScope.maybeOf(context)` — a `dependOnInheritedWidgetOfExactType`
   call, which **subscribes the calling element to that inherited
   widget's notifications**.

`FeedbackScope` is an `InheritedNotifier<FeedbackController>`, and the
controller the route creates starts an async settings load
(`PersistenceFactory.attachLocal` → `loadPersisted()`), which on
completion calls `feedback?.applySettings(loaded)` — and
`applySettings` calls `notifyListeners()`. So the sequence on entering
a local game was: route builds → controller A created → its load
completes → feedback notifies → **the subscribed route element
rebuilds → the builder runs again → controller B (a fresh match)
created** → B's load completes → notify → controller C… an unbounded
loop, one brand-new controller per frame. A player's tap was applied
correctly by whichever controller was current — and that controller
was discarded and replaced by a fresh initial-state controller before
the next frame, so the move was never visible. Walls identically.

Evidence, all gathered before any fix:

- A tap-driven test pumping the real `WallforgeApp` (router, feedback
  scope, persistence) and navigating to `/game` could not even settle:
  `pumpAndSettle` timed out — the screen scheduled a new frame
  forever. Probing showed **zero transient callbacks** (no ticker or
  animation running) with `hasScheduledFrame` stuck true: a rebuild
  loop, not an animation.
- The same test then read the controller off the built `GameScreen`
  twice, one second apart: **two different instances**
  (`identical()` false). After the fix: the same instance.
- Bisecting the ingredients (bare GameScreen; GameScreen + scope +
  assigned feedback; router without the app root) — all settle. The
  loop needs all three together: a `FeedbackScope` ancestor, feedback
  assigned to the controller, and the persisted-settings load. That
  combination existed only in the real app, which is precisely why
  §13t's gates missed it: every Phase 12 test either pumped the game
  screen directly (no router builder, no scope), used the router
  *without* a `FeedbackScope` above it (`maybeOf` found nothing, no
  subscription was created, feedback stayed null, the settings load
  had nothing to notify, and the builder ran once), called controllers
  directly, or pumped the full app without navigating to `/game`.

Online play was immune for a structural reason: its controller is
created once by the lobby and reaches the screen via route
*arguments*; the `/online/game` builder reuses it (`feedback ??=`), so
even when that builder re-ran, the match survived. Pass-and-play and
vs-AI share `LocalGameController` and the `/game` route, so both
failed identically — through the same blocked path, not two paths.

**The reviewer's hypothesis was investigated and is not the cause.**
The shared `GameInteraction` mixin does not wait for any snapshot
adoption in local play: `tapCell` calls `attemptAction` synchronously,
the engine applies the action, and only *then* do cues fire
(`cuesOnAttempt` is true for local; every cue call is guarded and
unawaited in the feedback layer, so a cue cannot throw into or delay
the action path). The defect was not in the interaction layer at all —
it was the route builder treating a per-navigation object as
per-build, and subscribing itself to the very notifications its own
object's startup produced.

### The fix

Two changes, both in `app_router.dart`, aimed at the mechanism rather
than the symptom:

1. **The `/game` controller is created once, in `onGenerateRoute`** —
   which runs exactly once per navigation — and the route builder
   only captures it. A route builder may re-run for reasons outside
   the game's control (any ancestor change); the match must not be
   recreated when it does. This restores the invariant Phases 4–11
   enjoyed by accident (nothing above the Navigator ever notified)
   and makes it structural.
2. **Route builders no longer read the feedback layer with
   dependOn.** Feedback is assigned from `FeedbackService.shared` —
   the mechanism `FeedbackService`'s own documentation designates for
   the router — in both the `/game` and `/online/game` routes. A
   builder subscribing to feedback notifications is what closed the
   loop; no route builder does it anymore.

Gameplay never depended on feedback and still does not: cues fire
after the action applies, from the controllers, fully guarded (§13t's
cue design is unchanged and correct). What changed is that feedback
*wiring* can no longer recreate gameplay state.

### The regression test

`test/presentation/screens/game/local_play_regression_test.dart` —
two tests that boot the real `WallforgeApp` (the only tree in which
the bug can exist) and play through the real `GameScreen` with real
taps, in the category of the Phase 9 online tap tests:

- **Pass-and-play**: a full 5×5 match played tap by tap — greedy legal
  moves chosen from the targets the controller itself advertises, one
  wall placed by real taps (WALL mode → slot tap → CONFIRM) — with an
  assertion after *every* tap that the match advanced by exactly one
  ply, and a final assertion that the screen holds the same controller
  instance it started with.
- **Vs-AI**: a full 5×5 match — human taps, AI replies inside its
  think delay — asserting each human tap advances the match and each
  AI reply follows, to a finished match with a winner.

Verified against the pre-fix tree (77bf6ec): **both fail** (the game
screen never settles — the loop's signature). With the fix: **both
pass**, repeatedly.

### Gate corrections to §13t

§13t's suite line also does not reproduce and is corrected here. Run
twice on the fixed tree on this machine, the full suite is **1,607
tests — 1,596 passed, 11 failed**, and the failing set is:

- the same 9 golden-image failures (5 board + 4 game), re-verified
  environmental on the pristine Phase 11 tree, and
- **2 failures in `online_game_presence_test.dart`** ("claiming
  through the confirmation ends the match", "the claimed player sees
  the abandoned state, not a win") that are **pre-existing**: they
  fail identically on the pristine Phase 11 tree (`d132be9`) and the
  pristine Phase 12 tree (`77bf6ec`), standalone and in the suite.
  They are unrelated to Phase 12 and to this fix (their failing set
  is unchanged by it), and they are recorded here as an open item
  rather than silently absorbed: the abandonment-claim confirmation
  does not surface the abandoned state in this environment, and the
  cause has not been investigated yet.

§13t's other gates stand as recorded (format 0 changed, analyze
clean — after this session also removed two redundant-argument lint
infos in the Phase 12 feedback test and one in the new test — spec
OK, oracle byte-identical, web build OK), and are re-verified for the
fix below.

Gates for this correction (2026-10-28): format 150 files 0 changed;
analyze — no issues; full suite as above (1,607 / 1,596 / 11, failing
set identical to the pre-fix trees); web release build OK; spec
checker OK (80 catalog rows, 65 rule IDs); oracle byte-identical
(1,229,568 bytes, SHA-256 6f1e3c05…).

### Process corrections

- Phase 12's commits were pushed to GitHub on 2026-10-28 (remote
  `main` verified at `77bf6ecc613f485079025eba0ec900749d2bdc90`), and
  this correction's commits follow immediately. **Standing rule from
  the owner, recorded 2026-10-28: push after every phase's final
  commit, every time, without being asked. "Not pushed" is an
  incomplete phase.** (Consistent with the owner's standing
  condition: no personal information or credentials in the repo —
  every push is diff-scanned first; `firebase_options.dart` and
  `firebase.json` are never committed.)
- A test that would have caught this — full-app, tap-driven, local —
  now exists and runs in the suite. Phases that wire app-level
  services (anything installed above the Navigator) must include a
  full-app navigation-and-play test in their gates; screen-level and
  controller-level tests are not sufficient for wiring that lives in
  the router or the app root.

Open items carried forward: the 2 pre-existing presence-test failures
(above); everything §13t listed as open is unchanged. Phase 13 was
not started.

## 13v. Phase 13 Record — Accessibility (completed 2026-10-29)

Phase 13 makes the game usable by a wider range of players, per
`phase.md` Phase 13 and `design.md` §26. The exit criterion — *the
game does not rely only on red/blue color differences* — is now
backed by automated tests, not a visual pass.

### Source ledger (every value cites its source)

| Decision/value | Source |
|---|---|
| Player identity = name + colour + text label together, never colour alone | `design.md` §26 (exact pattern) |
| Wall states must use shape, opacity, icons, text | `design.md` §26 |
| "red/blue color must not be the only player identifier" | `PRD.md` §6.4 principle 7 |
| "Keyboard accessibility where practical" (web) | `PRD.md` §4 (Web users) |
| Accessibility/color assistance is a named feature; UI scale "where practical" | `PRD.md` §6.6 Settings list |
| Settings groups: Reduced motion / Color assistance / High contrast / UI scale under "Accessibility" | `design.md` §23 |
| Accessibility is a presentation-layer responsibility; no new state-management package; justify any new package | `architecture.md` §2.1; `rules.md` §2.3/§3.3 — **no package was added** |
| Colour-assistance mechanism (palette swap) | *Not specified* in §26 beyond "never colour alone" — chosen and recorded here (below) |
| UI scale range 1.0–1.5 in 0.1 steps | *Not specified* — chosen and recorded here: 1.5 is the largest factor at which every screen was layout-verified |
| Keyboard scope boundary (board excluded) | *Not specified* — decided and recorded here (below) |

### What was built

1. **Persisted settings** (`AppSettings`, following the `reducedMotion`
   pattern exactly): `colorAssistance` (bool, default off),
   `highContrast` (bool, default off), `uiScale` (double, default 1.0;
   `fromJson` clamps to 1.0–1.5, substitutes defaults for malformed
   values, never throws). Round-trip/clamp/malformed tests included.
2. **Palette system** (`lib/app/theme/app_palette.dart`): the colour
   tokens moved from compile-time constants into an `AppPalette`
   object; `AppColors` now delegates every token to the current
   palette (235 call sites unchanged except lost `const` in const
   contexts). The **default palette is bit-identical to the
   pre-Phase-13 constants** — pinned by a snapshot test — so the
   standard appearance does not change. The app root
   (`ListenableBuilder` on the settings-carrying feedback controller;
   §13u-safe: it rebuilds the MaterialApp widget only, the Navigator
   state persists, no route regenerates) applies
   `AppPalette.resolve(highContrast, colorAssistance)` before the
   subtree builds and injects `TextScaler.linear(uiScale)` via
   `MediaQuery`. The Settings screen's three formerly inert rows are
   now a live toggle, a live toggle, and a live slider (100–150%)
   saving through the existing path.
3. **Color assistance — mechanism chosen:** the player-identity
   colours (board pawns/walls/rings/glow/ghost, lobby seat chips)
   swap to the **Okabe–Ito colour-blind-safe pair**: blue `#0072B2`,
   orange `#E69F00`, with matching pawn gradients. Chosen because it
   is the published standard pair designed for colour-vision
   deficiency, and verified here by simulation (Machado, Oliveira &
   Fernandes 2009 matrices, severity 1.0, implemented in the test):
   simulated RGB distance between the two player colours is
   **244.6 (protanopia), 261.9 (deuteranopia), 246.1 (tritanopia)**
   of a 441 maximum, and a simulated-lightness gap is retained under
   all three (129 / 151 / 16.5). For honesty: the default neon pair
   also separates by distance (204.8 / 215.0 / 337.3) — the assisted
   pair's claim is that it is the *designed-safe* standard, not that
   the default is indistinguishable. §26's structural redundancy
   (letters + words everywhere) holds in both modes.
4. **High contrast — computed ratios (WCAG formula, asserted in
   tests):** onSurface on background **21.00**, on surfaceContainer
   **18.36**; onSurfaceVariant on surfaceContainer **13.22**;
   primaryContainer (banner blue text) on surfaceContainerHigh
   **10.76**; secondary (banner red text) on surfaceContainerHigh
   **9.71**; error on surfaceContainer **10.81**; outlineVariant on
   background **4.59** (non-text ≥ 3). Every asserted text pair meets
   AA (≥ 4.5); the main pairs meet AAA (≥ 7). The default palette's
   main text pairs already meet AA (onSurface/background 14.39,
   onSurfaceVariant/container 9.64) — **except one real failure the
   audit found**: the turn banner's Red text used `secondaryContainer`
   (#B0003A) on surfaceContainerHigh at **1.99:1**. Fixed in both game
   screens: banner identity text now uses the light tint token
   (`secondary`, #FFB2B9) — **8.42:1** default, 9.71:1 high contrast.
   (The board's groove lines on tiles are 2.01:1 in high contrast —
   decorative grid texture; no information rests on them.)
5. **UI scale:** `TextScaler` at the app root (Flutter's mechanism,
   no hand-rolled font math). Layout-verified at 1.5× across screens
   at 320×568 (Home, Game Modes, Settings, the local game) plus the
   pre-existing viewport matrix at 1.0× — **no overflow anywhere, no
   accommodation changes were needed**; scrollable screens scroll,
   the game screen's strips/banners wrap within their containers.

### Player-identity audit (§26 pattern, per surface)

- **Pawns — GAP FOUND AND FIXED.** The Settings screen claimed
  "pawns always carry their B and R letters", but the painter drew
  **no letters** — pawn identity on the canvas rested on colour and
  start position alone. The painter now draws `B`/`R` on each pawn
  (`BoardPainter.pawnLetter`, near-black on the gradient mid-tone),
  in both colour modes. This — not eyeballing — is the phase's
  headline fix.
- **Board walls — confirmed + one tint fix.** Valid ghost = solid
  fill/outline; invalid ghost = error fill + a **white dashed centre
  line** (shape) + stronger outline + the failure **text** beside the
  board: §26's shape/opacity/icon/text redundancy already held
  (Phase 4.2). One identity wart fixed: the valid ghost was always
  Blue's colour even on Red's turn; it now carries the current
  player's identity colour. Placed walls already tint by owner;
  their gradients now resolve through the same identity tokens.
- **HUD/banners — confirmed + the contrast fix above.** Turn banner
  is words ("BLUE'S TURN"); rails/strips name PLAYER 1/PLAYER 2 (or
  P1/P2) in text; goal strips are text-labelled ("P1 GOAL STRIP").
- **Result — confirmed.** Heading is words ("BLUE WINS!"); the pawn
  disc renders its letter as real text (`PlayerPawnDisc`).
- **Lobby seats — confirmed.** Rows are text-labelled BLUE/RED with
  (YOU) and ready state in words.
- **Rematch consent — confirmed.** The rematch section speaks in
  words ("waiting for opponent", player names as text) — no
  colour-only signalling.
- **Automated proof** (`phase13_accessibility_test.dart`): pawn
  glyph mapping; banner words + named rails + board semantics
  naming both pawns; result heading + disc letter; lobby BLUE/RED/
  (YOU) labels.

### Semantics (§1's survey, closed)

Baseline survey confirmed first-hand: explicit `Semantics(` existed
only in `board_view.dart` and `online_game_screen.dart`. Added:
shared `SectionTitle` is now a semantics **header** (covers Settings
groups, lobby, modes, profile sections at once); the wordmark is a
header (Home, Splash); the local turn banner is a **live region**
(mirroring online's); the Result heading is header + live region;
Tutorial step title/body are a live region; local failure messages
are live regions with an error icon; the lobby error box is a live
region. Buttons/sliders/switches already expose correct roles via
Material; the keyboard tests below exercise them as controls.

### Keyboard (PRD "where practical") — scope decision

Non-board screens are fully keyboard-operable: every control is a
Material control (focusable, Enter/Space activation), focus order
follows the layout, and `AppTheme` now sets a visible `focusColor`/
`hoverColor` from the token system. Tests drive real Tab traversal:
Tab reaches the Settings switches and Space toggles one (persisted);
Tab + Enter activates Game Modes controls and navigates.
**Board decision (recorded):** keyboard *board play* is excluded as
not practical for this phase — the board is a single pointer-geometry
canvas; a keyboard model would be a parallel interaction system
(cursor, wall-orientation/confirm flow) rivalling Phase 4's input
work, and the board's state is already fully exposed to assistive
technology through its semantics label. Everything *around* the
board (mode toggle, confirm/cancel, navigation) is keyboard
operable. Revisit if the owner wants keyboard play as its own phase.

### Error-state audit (§6)

Checked: the 12 engine `ActionFailure` messages (plain language
already; now icon + live region in the local screen), online
`MatchSyncFailureReason`/`RoomFailureReason` messages (plain; lobby
error box already icon + text, now live region), persistence load
(falls back to defaults silently — by design, nothing to show),
Firestore-rejected writes (surface as the same plain room/sync
messages). **One leak fixed:** the lobby's sign-in failure read
"Could not sign in. Online play is unavailable
(FirebaseAuthException(anonymous-disabled))." — exception type names
shown to players. The message is now the plain sentence alone; the
detail is logged, not displayed (test asserts the exact string and
the absence of "Firebase"/"Exception"). Settings/Profile never
rendered the auth detail (checked).

### Reduced motion — verified, not rebuilt

Phase 12's implementation stands untouched: the persisted toggle,
the platform signal combination at the feedback seam, and its tests
all still pass (the Phase 12 settings suite runs green in this
phase's full run). One Phase 12-era test *wording* changed only
because the neighbouring rows went live.

### Gates (real output, 2026-10-29)

- `dart format --set-exit-if-changed lib test`: **153 files, 0 changed.**
- `flutter analyze`: **No issues found.**
- `flutter test` (full): **1,632 tests — 1,619 passed, 13 failed.**
  Baseline (Phase 12 corrected) was 1,607 / 11. Delta accounted:
  **+25 tests are this phase's** (palette/settings/contrast/
  simulation + identity/semantics/keyboard/layout/app-root), all
  passing. Failures: 11 golden-image tests and the 2 pre-existing
  `online_game_presence_test` failures (unchanged, pre-Phase-12).
  Of the goldens, 9 fail exactly as at baseline (environmental pixel
  differences in this VM); **2 are new — the board "valid ghost" and
  "invalid ghost" goldens** — because the ghost preview now carries
  the current player's colour (above), an intentional rendering
  change. **The golden masters must be regenerated on a reference
  machine** (`flutter test --update-goldens`): Phase 13 intentionally
  changes pawn rendering (the new B/R letters) and the ghost tint,
  so the masters are stale by design, not by accident.
- `flutter build web`: **✓ Built build/web.**
- Spec checker: **OK (80 catalog rows, 65 rule IDs).** Oracle
  vectors: untouched (no domain change; the in-suite oracle replay
  passes).
- Mojibake scan over tracked files: **317 files, 0 hits.**
- No rule, engine, sync, or security change: `firestore.rules`,
  `lib/domain`, and the sync layer are untouched by this phase's
  diff (the only domain-layer file changed is
  `app_settings.dart`, the settings snapshot).

### Open questions

- None new. Carried: the 2 pre-existing presence-test failures
  (uninvestigated, pre-Phase-12), golden-master regeneration on a
  reference machine (above), `firebase deploy --only firestore:rules`
  pending the owner's Firebase login, and the full live online match
  to a winner (never run). Phase 14 was not started.

## 13w. Phase 14 Record — Responsive Web (completed 2026-10-29)

Phase 14 makes the web version feel intentional rather than
stretched mobile UI, per `phase.md` Phase 14 and `design.md` §27.
Exit criterion: *web layouts are usable at common viewport sizes* —
now exercised by automated tests at five viewport sizes for every
screen.

### Source ledger

| Decision/value | Source |
|---|---|
| Adapt to small phones, large phones, tablets, desktop browsers; "do not simply scale every component proportionally"; the board may change relative size, panels change layout | `design.md` §27 (primary) |
| "Portrait-first gameplay where practical"; "Responsive desktop and tablet layouts"; "Responsive board sizing" | `PRD.md` §4/§6 |
| Mouse: hover highlights, click movement, click wall placement | `design.md` §28 |
| A resize must not recalculate legal moves or re-run pathfinding | `rules.md` §16 (performance) |
| No new package for what MediaQuery/LayoutBuilder already does | `rules.md` §2.3/§3.3 — **no package was added** |
| Breakpoint values 768 / 1024 | *Not specified* in §27 — chosen and recorded below |
| Tablet hybrid shape per screen; content caps (680/720/880/960/1120) | *Not specified* — chosen per screen and recorded below |
| Landscape-phone treatment | *Not specified* beyond "portrait-first where practical" — decided and recorded below |
| Board floors must never overflow their slot | Found by this phase's landscape test (below) — a correctness fix, recorded here |

### Audit (verified first-hand, as the prompt's §1 predicted)

The `>= 768` literal existed in exactly two places
(`game_screen.dart`, `online_game_screen.dart`), the split was
binary, and 768×1024 inherited the full desktop 3-column layout. **No
non-game screen had any width treatment at all** — every one
stretched its phone column edge-to-edge at desktop widths. Splash
was the exception (centered by construction; unchanged). No hover
support existed anywhere (`design.md` §28's "hover highlights" were
unimplemented).

### Centralized breakpoints

`lib/app/theme/app_breakpoints.dart`: `AppBreakpoint {phone,
tablet, desktop}`, `AppBreakpoints.of(context)` /
`tierForWidth(width)`. **phone < 768** (768 is kept as the boundary:
it has been the project's split since Phase 3 and it is where
portrait tablets begin — the standard 768×1024 viewport must be
tablet, not desktop); **tablet 768–1023**; **desktop ≥ 1024** (the
desktop game layout — two 280px rails plus a useful board — needs
~1000px; large tablets in landscape and small laptops start there).
Every literal was replaced; a test scans `lib/` and fails if a raw
comparison literal reappears outside the definition.

### What each tier does, per screen

- **Game screens (local + online).** Phone: unchanged single
  column. **Tablet: the balanced hybrid** — the same single column
  (strips, not rails) centered under a 680px cap, so the board grows
  substantially relative to a phone (measured in tests: >100px wider
  than at 390px, ≤680) while panels keep the strip arrangement
  instead of inheriting desktop's rails. Desktop: the existing
  3-column rails layout, unchanged.
- **Home:** menu column capped (680 tablet / 720 desktop), centered.
- **Game Modes:** tablet pairs Local + Vs AI in a row with Online
  full-width below; desktop puts all three mode cards in one row;
  parameters card follows; content capped 680/960.
- **AI Difficulty:** paired rows of two on tablet and desktop;
  single column on phone.
- **Settings:** tablet keeps one column at a 680 cap; **desktop
  splits the five groups into two columns** (GAMEPLAY/AUDIO/HAPTICS
  left, ACCESSIBILITY/ACCOUNT right) under a 1120 cap.
- **Tutorial:** desktop places the step text and the board side by
  side (880 cap); tablet 680 cap, stacked; phone unchanged.
- **Online Lobby:** desktop arranges the entry as two columns
  (QUICK MATCH + CREATE stacked left, JOIN right); tablet/phone keep
  the single column at the capped measure; the in-room view is
  capped the same way.
- **Profile:** capped 680/960. **Result:** capped 560 on both wide
  tiers (a single focused message at a deliberate measure).
  **Splash:** already centered at every width; no change.

### Landscape phones — decision (recorded, per PRD "portrait-first where practical")

Portrait remains the designed-for orientation. A landscape phone
(wider than tall, height < 500 — detected in `AppBreakpoints`) is
**not** squeezed into the portrait column: the game screens borrow
the desktop side-panel arrangement with **compact 200px rails**,
which uses the wide-short space the way it is shaped. Proven by
tests at 844×390 on both game screens. Non-game screens are
scrollable columns and work in landscape unchanged (also rendered
in the test matrix at 844×390).

**Bug the landscape test caught:** both game screens (and
`BoardView` itself) clamped the board to a minimum size (280 local /
240 online / 280 board floor) regardless of the offered height —
in the ~200px-tall landscape center slot that overflowed the column
by exactly the difference (80px local, 72px online). Fixed with one
principle in all three places: *a board floor never overflows its
slot; below the floor the board takes what is offered.* No golden
render is affected (goldens render at sizes above the floors).

### Mouse and touch parity (§28)

There was no hover anywhere. `BoardView` now tracks a mouse-hover
ghost internally (so the stateless screens needed no new state):
hovering a wall slot in WALL mode shows the preview before any
click, validity from the engine's own `GameEngine.validate` — the
same call the staged preview makes, so they cannot disagree; the
staged preview always wins while one exists; touch never triggers
it. Wired into the local, online (own-turn only) and tutorial
boards. Buttons/controls already expose Material hover states, now
with the Phase 13 theme's token-based hover/focus colours. The test
hovers a real slot with a mouse gesture and asserts the painter's
preview (anchor, orientation, validity) appears and clears on exit.

### Resize discipline (§16) — findings

Code-path check: every tier branch in the diff only selects widgets
(caps, rows, rails); no layout code calls a controller, the engine,
or pathfinding. Behavioural proof: the resize test plays a real
move, then resizes through all five viewports and asserts the game
state is the **identical object** afterwards (same instance, same
turn, same legal-target set) — layout changes cannot recompute game
logic because the layout layer holds no path to it. Repaints on
resize still happen (the painter must redraw at a new size); that
is rendering, not game logic.

### Phase 13 composition

The app-root test stores `uiScale: 1.5` in the real settings seam
and pumps the full app at 320×568, 768×1024 and 1440×900: Home is
reached with no overflow at every size — the player-chosen scale
and the viewport-chosen tier compose (the tier picks the layout,
the scaler enlarges text inside it).

### Existing-test accommodations (recorded, per Phase 13's precedent)

Two tests in `online_game_screen_test.dart` ('Blue is told it is
their turn', 'Red is told to wait') asserted single occurrences of
banner texts at the default 800×600 test viewport, which Phase 14
makes the tablet tier — whose narrow column carries the banner
twice by design (Phase 10). They are pinned to an explicit desktop
viewport (1440×900), the layout they were written against; the
wording assertions are unchanged.

### Gates (real output, 2026-10-29)

- `dart format --set-exit-if-changed lib test`: **157 files, 0 changed.**
- `flutter analyze`: **No issues found.**
- `flutter test` (full): **1,693 tests — 1,680 passed, 13 failed.**
  Baseline (Phase 13) was 1,632 / 13. Delta accounted: **+61 tests
  are this phase's** (two new files), all passing; the failure set
  is **identical** to baseline — 11 goldens (7 board + 4 game) and
  the 2 pre-existing `online_game_presence_test` failures. **The
  Phase 13 golden-regeneration follow-up was NOT done** (no
  reference machine in this environment): the masters are still the
  pre-Phase-13 ones, so the ghost/pawn-letter renders still differ
  from them exactly as reported in §13v; this phase adds no new
  golden failures.
- `flutter build web`: **✓ Built build/web.**
- Spec checker: **OK (80 catalog rows, 65 rule IDs).** Oracle
  vectors untouched (no domain change; the in-suite oracle replay
  passes).
- Mojibake scan: **313 tracked files, 0 hits.**
- Housekeeping: the golden-failure diagnostic PNGs were swept into
  this phase's commits by broad `git add`s (the Phase 13 mistake,
  repeated). They are untracked again and `test/**/failures/` is
  now in `.gitignore`, so it cannot recur.
- No rule, engine, sync or security change: `firestore.rules`,
  `lib/domain`, and the sync layer are untouched; the BoardView
  change is sizing + hover only.

### Open questions

- None new. Carried: golden-master regeneration on a reference
  machine (now covering Phases 13+14 renders), the 2 pre-existing
  presence-test failures, `firebase deploy --only firestore:rules`
  pending the owner's Firebase login, and the full live online
  match to a winner (never run). Phase 15 was not started.

## 13x. The 13 failing tests — diagnosed and resolved (2026-10-29, post-Phase 14)

- **Baseline actually observed** (this VM: Linux x86_64, Flutter 3.47.8 /
  Dart 3.13.7): the documented set reproduces exactly — 1,693 tests,
  1,680 passed, **13 failed** (11 goldens + 2 presence). Environment
  record kept because everything below depends on it: the golden
  masters were generated on the owner's Windows machine with an
  earlier engine, and have never been regenerated since.
- **The 2 presence failures — ROOT CAUSE FOUND, and it is not the
  claim flow.** Diagnostic tests (temporary, deleted after use) drove
  both scenarios end to end: the claim transaction returns `claimed`,
  the stored document lands `status: abandoned, abandonedById` set,
  both controllers adopt it (`isAbandoned` / `claimedByMe` true), and
  the screen renders the abandoned result with the correct
  claimant / claimed wording and no win text. What the two tests
  asserted was the **Phase 10 terminal presentation** — an in-screen
  `MATCH ABANDONED` banner and the claimed sentence as a standalone
  `Text`. **Phase 11 deliberately replaced that presentation** with
  the shared Result screen (the early return in
  `online_game_screen.dart`'s `_build`, commented as such): heading
  `Match complete.`, the sentence embedded in the room subtitle
  (`Room <code> · …`), and the Result row value `Abandoned`. The two
  Phase 10 tests were never updated to the new presentation — which is
  why they fail on every tree from Phase 11 onward (the §13u pristine-
  tree checks), and why Phase 11/12's original gate figures, which
  reported goldens only, were wrong. The `_buildBanner` abandoned
  branch that still computes a `MATCH ABANDONED` label is unreachable
  (the `_build` early return pre-empts it) — vestigial, left as is.
- **Fix (tests only, no app code):** the two tests now assert the
  Phase 11 presentation — `find.text('Abandoned')` plus the claimed /
  opponent-claimed sentence via `textContaining` (it lives inside the
  subtitle) — with a comment recording why. Every contract assertion
  is untouched: the stored document's `RoomStatus.abandoned`, the
  cancellation test's still-`started`, and the claimed player's
  explicit not-a-win check. Result: the presence file passes 5/5,
  each previously-failing test also passes individually.
- **The 11 goldens — renderer verified correct; masters stale plus a
  platform rasterization floor; NOT regenerated here.** Every failure
  image pair was measured pixel-wise (diff %, per-pixel delta
  distribution, connected-component clusters of large deltas, sampled
  colours) and representative renders reviewed visually:
  *Structural board goldens (5):* the only large-delta clusters are
  two ~60 px glyphs at the pawn centres — the **B/R pawn letters
  Phase 13 added** (masters predate them; the sampled centre pixel
  goes from flat pawn colour in the master to the dark glyph in the
  render). Everything else is ≤16-delta anti-aliasing on circle and
  goal-row edges (0.15–0.40 % of pixels).
  *Ghost goldens (2):* large deltas concentrated in the preview —
  the **Phase 13 current-player ghost tint** (sampled tint
  191,245,255 → 230,252,255) — plus the same pawn letters.
  *Game-screen goldens (4):* pawn letters, the ghost tint (the three
  ghost scenarios), the **Phase 13 banner text-colour fix** in the
  top banner glyphs, and one 1-px hairline (the mode toggle's
  indicator) that rasterizes one pixel lower in the master — sampled
  rows show identical colours, shifted coverage.
  The residual class is engine rasterization of the painter's
  gradient shaders, `withValues` alpha blends and hairlines across
  platforms/engine builds; both golden files already load the bundled
  Inter font explicitly, so text is not the variable. No rendering
  regression was found anywhere; game rules and engine untouched.
- **Why not `--update-goldens` here:** this work's brief reserves
  regeneration to the reference environment, and this project's
  masters are Windows-born — masters regenerated in this Linux VM
  would pass here and fail on the owner's machine by the same
  measured noise floor, relocating the failure rather than resolving
  it. The remaining step is one command on the owner's machine —
  `flutter test --update-goldens` on the two golden files, review,
  commit the PNGs — after which the masters carry the Phase 13
  rendering and this VM keeps only its documented rasterization
  delta. If the owner prefers this VM declared the reference instead,
  regeneration here is a single instruction away.
- **Gates after the fix:** presence file 5/5 (and each fixed test
  individually); board goldens +0 −7 and game goldens +0 −4 (the
  documented 11, unchanged signatures); `dart format` 157 files
  0 changed; `flutter analyze` clean; full suite **1,693 tests —
  1,682 passed, 11 failed**, the failing set being exactly the 11
  documented goldens (both presence tests pass in-suite).

## 13y. Phase 15 Record — Performance (2026-10-30)

Status: **complete except owner-run device/browser checks** (the Phase 9
honest pattern). Everything measurable in the headless VM was measured;
real frame timing, low-end Android behaviour and browser load metrics
were not faked — the owner measurement script is at the end of this
record.

### Source ledger and targets

- No document sets numeric performance targets (verified again by
  search of `PRD.md`, `architecture.md`, `design.md`): every target
  below is a recorded decision of this phase. Targets chosen: (T1) the
  UI thread must never be blocked by one AI search for its full
  duration — the event loop must turn between root candidates;
  (T2) no Firestore operation may be spent that a document already in
  hand proves unnecessary; (T3) counts and invariants are asserted in
  tests, wall-clock numbers are printed and reported, never asserted
  (shared-VM timing is noise); (T4) nothing is optimized without a
  measured problem, and an after-number that is not better reverts
  the change.
- Baseline confusion resolved first: the Phase 15 brief expected
  1,693 tests / 13 failures, but the 2 presence failures were already
  fixed on 2026-10-29 (commit `0959d0b`, §13x). The true Phase 15
  baseline at `0959d0b` is **1,693 tests — 1,682 passed, 11 failed**,
  all 11 being golden masters (format 157 files 0 changed; analyze
  clean; spec OK; oracle SHA-256 `6f1e3c05…94ba96`, 1,229,568 bytes;
  mojibake clean).

### Part A

- **A.2 presence failures — closed with the full evidence chain.** The
  §13x diagnosis (stale Phase 10 expectations vs Phase 11's Result
  screen; claim flow proven working) was re-verified three ways:
  (i) the fixed presence file passes **20/20 isolation runs** —
  deterministic, not flaky; (ii) the first-failing-state bracket: at
  Phase 10 HEAD `f989d07` the original file passes 5/5, at Phase 11
  HEAD `d132be9` the same 2 tests fail — the regression window is
  exactly Phase 11, whose UI change orphaned them; (iii) the Phase 11
  record's "presence timer needs addTearDown" note is a harness
  property the tests already handle by explicit disposal, unrelated
  to the failures. The suite's only failures are now the golden
  masters awaiting the owner's reference machine
  (`flutter test --update-goldens` — still NOT done here, by design).
- **A.3 real-app resize regression** —
  `test/presentation/screens/game/real_app_resize_regression_test.dart`:
  boots the real `WallforgeApp` (router + feedback scope +
  persistence), plays real taps at 390×844, resizes phone → tablet →
  desktop → landscape phone → phone between taps, and after every
  resize asserts the screen holds the **identical controller
  instance** and the **identical state object**, finishing at exactly
  4 plies for 4 taps. Passes.
- **A.4 clean-clone documentation + hardening.** How options reach the
  app today (read from `main.dart`, `FirebaseBootstrap`, `web/`,
  `pubspec.yaml`): the committed `main.dart` passed NO options, so a
  clean clone could never initialise Firebase on web (native
  platforms read their git-ignored config files); the owner's working
  copies carry an edited `main.dart` importing a local
  `firebase_options.dart` — i.e. there was **no supported way without
  editing tracked files**. Smallest supported mechanism added:
  `lib/data/remote/firebase_options_from_defines.dart` — web options
  built from `--dart-define` values (`FIREBASE_API_KEY`, …), null
  unless all required values are present, with `main.dart` passing
  them on web only; the pure mapping is unit-tested with fake values
  (`test/data/firebase_options_from_defines_test.dart`, 4 tests). No
  new packages, no committed credentials. `lib/firebase_options.dart`
  is now in `.gitignore` alongside `google-services.json` and the
  plist (it was missing — verified). README gained the exact
  "Running with online play from a clean `git clone`" section.

### The AI (B.2.1) — the phase's headline fix

Measured with `tool/bench_engine_ai.dart` on seeded mid-game
positions (move-biased self-play — uniformly random play spends all
walls within plies and collapses the branching factor; the first
bench run made exactly that mistake and reported a flattering
Expert-9×9 of 19 ms; the corrected positions reproduce Q-5.3's 1.3 s):

| Difficulty | 7×7 | 9×9 | 11×11 |
|---|---|---|---|
| Easy | ~10–16 ms | ~17–22 ms | ~48–50 ms |
| Medium | ~8 ms | ~17–22 ms | ~48–49 ms |
| Hard | ~46–48 ms | ~95–101 ms | ~253–265 ms |
| Expert | ~565–569 ms | **~1,284–1,357 ms** | **~3,208–3,256 ms** |

The cost driver is `GameEngine.legalActions` (3.5–5.5 ms per call at
9×9, 10–17 ms at 11×11 in wall-rich positions — every wall slot is
path-validated), paid at every search node; route-length BFS is
negligible (0.03–0.10 ms). The engine is frozen and legality is never
re-implemented in the AI, so the fix is scheduling, not search
surgery:

- **`AiOpponent.chooseActionAsync`** — identical shortlist, identical
  per-candidate search, identical tie-breaking; it yields to the
  event loop between root candidates. `LocalGameController` now runs
  it (the think-delay timer only schedules the start) and drops the
  result if the match was restarted/disposed or the turn changed
  while the search was in flight.
- **Measured effect** (event-loop probe in the bench: a self-requeuing
  task records the longest gap between its turns): worst event-loop
  block for an Expert search fell from **1,578 ms → 150 ms** (9×9)
  and **3,299 ms → 346 ms** (11×11) — bounded by one root candidate's
  subtree instead of the whole search. Total CPU per search is
  unchanged (it is the same search); what changed is that frames,
  input and timers interleave with it.
- **Determinism/strength evidence:** `test/ai/ai_async_test.dart` —
  async == sync choices on seeded positions for every difficulty at
  7×7 and 9×9 plus 11×11 Expert; a probe test proving event-loop work
  completes mid-search; a restart-during-search test proving stale
  results never land. The pre-existing AI suite (legality, strength
  ordering, AI-vs-AI games) passes unchanged. No AI behaviour change:
  same evaluation, same search, same choices.
- **Evaluated and reverted:** alpha-beta pruning inside `_search`
  measured only −1…−5% (Expert 9×9 1,284 → 1,214 ms) because the cost
  sits in shortlist generation at each visited node, not in leaf
  count. Per T4 it was reverted — a wider equivalence-proof surface
  for a noise-level gain. **Evaluated and rejected:** background
  isolates — web (this phase's platform) has no true parallel
  isolates in this Flutter version, so an isolate path would still
  need the chunked path for web; chunking alone met T1 on every
  platform with zero serialization or determinism surface. The
  remaining known lever, if owner device numbers ever demand it, is
  finer-grained yielding inside the search or a deterministic node
  budget (Q-5.3 keeps that note).

### Firestore recount (B.2.2) — including the rules lookups Phase 9 predicted

Counted through the real repositories over a `CountingFirestoreClient`
decorator (`test/perf/phase15_perf_test.dart`, exact-count asserts):

- Happy-path action, BEFORE: **2 transaction reads** (match + move
  record) + 2 writes. AFTER: **1 transaction read** + 2 writes.
- The saved read: `submitAction`'s idempotency read of the move
  record. It is provably unnecessary when the match document shows
  the expected turn AND version on every signal — the record and the
  match update commit in the same transaction, so a record for the
  expected turn can exist only if the document already advanced past
  it. When the document does not prove freshness, the read runs
  exactly as before; every outcome (applied / alreadyApplied /
  staleTurn / conflictingDuplicate) is preserved, and `match_sync`,
  the online controller tests and the presence suite all pass
  unchanged. (One corrupt-corner note: a started room whose snapshot
  is missing AND has a same-action record previously threw inside the
  transaction and surfaced as `networkUnavailable`; it now rejects
  cleanly as `invalidRemoteData` — unreachable in real data.)
- Security-rule lookups, counted statically from `firestore.rules`:
  the move-record create calls `parent()` = one `get()` of the match
  document (cached within the evaluation) → **+1 billed read per
  action** — the cost Phase 9's arithmetic explicitly deferred
  ("future security-rule lookups add reads") and Phase 10 introduced.
  The match update itself uses only `before()`/`after()` (0 lookups).
  Quick-match room creation costs 2 `getAfter` reads (one-time per
  matchmaking, not per action); room create/join/ready/start and the
  abandonment claim cost 0.
- **Recount per action: 4 reads / 2 writes** — 1 transaction read +
  2 listener deliveries (one per client) + 1 rules read; 2 writes
  (match + move record). The headline matches Phase 9's "~4 and 2",
  but the composition is now fully accounted: Phase 10's rules read
  replaced the transaction read Phase 15 removed.
- Presence verified zero-write by construction and by measurement:
  the 5-second timer only re-derives presence from `updatedAt` and
  notifies on a flip (no repository call in the handler); the
  counting test asserts 0 writes across connect + resyncs. Exactly
  **one** match listener per controller, cancelled on dispose
  (asserted: active watchers 1 → 0).
- Quotas re-checked against current Firebase documentation
  (2026-10-30): Spark no-cost = 50,000 reads/day, 20,000 writes/day,
  20,000 deletes/day, 1 GiB stored — **unchanged** from Phase 9's
  check. Games/day recomputed: at Phase 9's 811-ply accounting case,
  reads ≈ 3,254/game → ~15 games/day by reads; writes ≈ 1,627/game
  → **12 games/day, writes still limiting** (unchanged headline;
  reads moved from co-limiting to comfortable). At a typical ~60-ply
  game: ~160 games/day by writes, ~200 by reads.
- The emulator rules suite was NOT re-run: `firestore.rules` and
  `tool/rules_tests` are byte-identical to the verified Phase 11
  state (`git diff` empty) and the JS-SDK suite cannot observe a
  Dart-client read pattern; two attempts here also stalled before
  emulator boot (empty log — the CLI never started in this VM).

### Rendering, rebuilds, startup, web weight (B.2.3/B.2.4)

- Painter record cost (PictureRecorder, dense-wall boards, this VM):
  5×5 1.31 ms, 7×7 1.60 ms, 9×9 1.83 ms, 11×11 0.93 ms per paint —
  ≈1–2 ms with no size blow-up (CPU record cost only; GPU frame time
  is owner-measured). Board sits under a `RepaintBoundary` (Phase 3).
- Notifications: one human move produces a small bounded count
  (asserted ≤6 synchronously, ≤8 after settle — against Phase 12's
  unbounded loop); a pure resize fires **zero** controller
  notifications (asserted across all three tiers + landscape).
- Idle board: after settle, `hasScheduledFrame` is false and a
  1-second pump schedules at most the pump's own frame — the Phase 12
  ticker discipline holds; animations tick only while an effect is
  in flight.
- Startup: `FirebaseBootstrap.initialize()` is `unawaited` and
  `runApp` is called immediately — first paint is never blocked on
  Firebase (code-verified; in the unconfigured case init fails fast
  and locally). Lazy initialization was evaluated and **not**
  implemented: the only saving would be deferring Firebase's share
  of `main.dart.js` parsing, which cannot be isolated without a
  deferred-import refactor of the whole online subtree — Phase
  7/8's `FirebaseStatus` behaviour is built on the startup attempt,
  and no measurement available here condemns it. The owner-run
  Lighthouse pass is the arbiter if that ever changes.
- Web release build (`flutter build web --release`): succeeds;
  `main.dart.js` 2.89 MB; `build/web` totals 42 MB on disk but ships
  six renderer WASM variants (~29 MB) of which a browser downloads
  exactly one (3.6–7.3 MB) plus `.symbols` files that are never
  fetched in normal serving. Assets: one variable font
  `InterVariable.ttf` 843 KB (all weights in a single file — already
  the efficient pattern; no unused weights exist to remove);
  MaterialIcons tree-shaken to 9.7 KB (from ~1.6 MB unshaken);
  audio 137 KB total. Nothing measured as wasteful was found to
  remove; renderer/compile options in this Flutter version were
  checked — the default release build already emits the
  multi-renderer output, and no flag was changed without a measured
  problem.

### Memory and lifecycle (B.2.5/B.2.6)

- `test/perf/phase15_perf_test.dart` lifecycle group: disposing a
  vs-AI controller cancels the pending AI move (no ply lands, no
  throw, past the think delay); five full 5×5 local games play to
  completion through the real controller and dispose cleanly; online
  controllers release their listener on dispose (above). Q-8.6
  (controller disposal from the route) was already resolved in
  Phase 11 via `GameScreen.ownsController`; these tests extend the
  same discipline to the AI timer and the Firestore subscription,
  the two remaining timer/subscription owners.
- Engine hot paths (bench): `legalActions` 0.9 ms (empty 9×9) rising
  to 3.5–5.5 ms (wall-rich 9×9) and 10–17 ms (wall-rich 11×11) —
  the search's dominant cost, reported, and deliberately NOT
  optimized: the engine's behaviour is frozen, its numbers are
  healthy for UI-rate calls (one per human action at most), and the
  only consumer that called it in a hot loop was the AI search,
  whose blocking is fixed by scheduling. Oracle vectors
  byte-identical; spec checker OK; all domain tests pass.

### Owner measurement script (device/browser — not measurable here)

Run on the owner's Windows machine, from a clean clone of `main`:

1. Web profile build + frame chart:
   `flutter run --profile -d chrome` — open DevTools → Performance,
   record while: (a) playing on an 11×11 board with dense walls,
   (b) taking an Expert-AI turn on 9×9 and 11×11, (c) placing walls
   rapidly (animation flurry), (d) dragging the window across the
   768/1024 breakpoints repeatedly. Note the longest frame and any
   dropped frames per scenario; the AI turn should show activity
   spread over many frames, never one ~1.3 s (9×9) block.
2. Web load metrics: `flutter build web --release`, then
   `python -m http.server 8080 --directory build\web`, open
   `http://localhost:8080` in Chrome → DevTools → Lighthouse
   (mobile emulation, Performance) and record FCP, LCP, total
   blocking time and total transfer size.
3. Android: connect a low-end device, `flutter run --profile -d
   <device id>`, enable the performance overlay (DevTools → 
   Performance → frame chart) and repeat scenarios (a)–(c); watch
   the UI-thread (top) chart during the Expert turn specifically.
4. A full online match on two sessions, watching the Firestore
   usage dashboard: expect ≈4 reads + 2 writes per applied action.
Report the numbers back; Phase 15's status upgrades from "complete
except owner-run device/browser checks" when they land.

### Phase 15 gates (real output, 2026-10-30)

`dart format --set-exit-if-changed lib test`: 162 files, 0 changed.
`flutter analyze`: no issues. `flutter test`: **1,717 tests — 1,706
passed, 11 failed**, the 11 being exactly the golden masters awaiting
the owner's reference machine (baseline 1,693/1,682/11; +24 new tests
— 1 real-app resize, 4 defines, 11 AI async/determinism, 8 perf —
all passing). One casualty found and fixed on the way: the Firestore
integration test "a resumed AI match keeps its opponent and
difficulty" waited a fixed `kAiThinkDelay + 50 ms` for the AI reply —
a sleep that encoded the synchronous search's timing; it now polls
for the reply with a 10 s bound (the assertion itself is unchanged)
and passes 5/5 repeat runs. `flutter build web --release`: built.
Spec checker: OK. Oracle: SHA-256 `6f1e3c05…94ba96`, unchanged.
Mojibake scan: clean.
