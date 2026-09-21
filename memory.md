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

Google Stitch was explored for UI design.

The generated Stitch design did not match the desired board direction.

Decision:

**Do not use the Stitch folder as a design dependency or required reference.**

Do not build the application around Stitch output.

Use:

- `design.md`
- Custom approved assets.
- Product requirements.
- Actual Flutter implementation.

The Stitch output can be ignored unless the user later explicitly changes this decision.

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
## Phase 2 — Game Engine Implementation: IN PROGRESS (Phase 2.1)

The engine core is implemented (commit `d6c7af2`), but Phase 2 is **not** complete.
Phase 2.1 is finishing docs, structured serialization, complete per-rule tests and
quality gates. See §13g below for the Phase 2 record and its outstanding items.

See §13b, §13c, §13d, §13e, §13f, and §13g below for the Phase records.

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

- Board renderer.
- Pawn renderer.
- Wall renderer.
- Local multiplayer.
- AI.
- Firebase integration.
- Online rooms.
- Online synchronization.
- Complete UI screens.
- Audio.
- Haptics.
- Production QA.

---

# 11. Immediate Next Work

The recommended next implementation order is:

1. Finalize detailed game rules.
2. Create Flutter project. (DONE - Phase 0 complete and verified)
3. Create domain models.
4. Implement game engine.
5. Implement BFS/pathfinding.
6. Implement wall validation.
7. Write engine tests.
8. Build board renderer.
9. Build interactive local mode.
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

- Stitch is the final design.
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

Status: **in progress — Phase 2.1.** (Commit `d6c7af2` "Phase 2 redo" replaced an
incorrect 10x10 engine with one matching `game_spec.md` v1.0.4. The core is
correct, but Phase 2 exit criteria are not yet met.)

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
