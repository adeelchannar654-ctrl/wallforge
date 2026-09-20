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

Verified on 2026-09-20. See §13b below for the Phase 1 record.

### Completed (Phase 0 + Phase 1)

- All Phase 0 items (see §13a).
- Frozen game specification in `game_spec.md` (v1.0.0).
- Board size, start positions, goal edges, movement, wall rules, path
  preservation, win condition, turn transition, and pawn-jump behavior all
  formalized with deterministic answers.
- 15 project-specific rules in `rules.md` preserved. New Rule 16 added
  (game_spec.md is single source of truth).
- Documentation cross-references updated (PRD, rules, architecture, phase,
  README, domain README).

### Not yet completed

- Game engine (Phase 2).
- Automated game-rule tests (Phase 2).
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
