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

See §13b, §13c, §13d, §13e, §13f, §13g, §13h, and §13i below for the Phase records.

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
9. Build interactive local mode. (DONE - Phase 4/4.1)
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
