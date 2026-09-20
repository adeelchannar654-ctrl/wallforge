# Wallforge — Product Requirements Document

## 1. Product Overview

**Product name:** Wallforge  
**Product type:** Cross-platform two-player strategy board game  
**Platforms:** Android, iOS, Web  
**Framework:** Flutter  
**Online backend:** Firebase, initially targeting the no-cost Spark plan

Wallforge is a turn-based strategy game played on a dark, front-facing grid board. Two players race toward the opposite goal area while using a limited supply of colored walls to change the opponent's route.

The player may perform exactly one primary action per turn:

1. Move the pawn one legal step, or
2. Place one legal wall.

The first player to reach their destination wins.

The game is intentionally designed as an original product. The project must not copy another game's name, branding, artwork, exact UI, or proprietary assets.

---

## 2. Product Goal

Build a polished, easy-to-learn, strategically deep board game that works consistently across mobile and web.

The product should provide:

- Fast local matches.
- Offline play against another person on the same device.
- Offline play against an AI opponent.
- Online two-player matches using Firebase.
- A responsive interface for touch and mouse input.
- A distinctive front-facing 2.5D/3D-rendered board.
- Clear game-state feedback without clutter.

### Success criteria

A first-time player should be able to understand the basic objective and make their first legal move without reading a long manual.

A returning player should be able to start a match quickly and understand whose turn it is, how many walls remain, where movement is possible, and how close each player is to the goal.

---

## 3. Core Purpose

Wallforge turns a simple race across a grid into a tactical contest.

Players must balance:

- Advancing their own pawn.
- Preserving limited walls.
- Increasing the opponent's route length.
- Avoiding illegal wall configurations.
- Responding to the opponent's latest move.

The product should reward planning rather than fast tapping.

---

## 4. Target Users

### Primary users

Casual and strategy-game players who want short competitive matches.

Needs:

- Simple rules.
- Fast onboarding.
- Clear controls.
- Short sessions.
- Satisfying feedback.
- Offline availability.

### Secondary users

Players who enjoy deeper tactical competition.

Needs:

- Strong AI.
- Online multiplayer.
- Match statistics.
- Reliable game state.
- Consistent rules.
- Rematch functionality.

### Platform users

Mobile users:

- Touch-first controls.
- Portrait-first gameplay where practical.
- Responsive board sizing.
- Haptics and audio.

Web users:

- Mouse/touch support.
- Larger information panels.
- Keyboard accessibility where practical.
- Responsive desktop and tablet layouts.

---

## 5. Core Game Rules

The authoritative, frozen rulebook is [`game_spec.md`](game_spec.md). All rules
below are summarized from that document. In case of any conflict,
`game_spec.md` controls.

### Board

A configurable NxN movement grid (default 9x9, N must be odd and >= 5). The
board size is set by `BoardConfig` in the game engine, never hard-coded in UI.

### Players

Two players: Blue and Red. Blue starts at the bottom-center; Red starts at the
top-center. Blue moves first.

### Turn

Exactly one primary action per turn: move the pawn or place a wall. No passing.
After every successful action the turn alternates.

### Movement

A pawn may move to any orthogonally adjacent cell that is on the board, not
separated by a wall, and not occupied by the opponent (unless jumping). Pawn
jumping over an adjacent opponent is included — straight jump, or diagonal
side-step when the straight jump is blocked.

### Walls

Each player starts with 10 walls. Walls are horizontal or vertical, 2 cells
long, placed on grid lines between cells. Walls cannot overlap, cannot cross at
the same anchor, and must preserve at least one route for each player to their
goal.

### Win

A player wins immediately upon reaching their goal row. The game stops
accepting actions after a win.

See [`game_spec.md`](game_spec.md) for the complete specification including
rule IDs, error taxonomy, serialization contract, and test catalog.

---

## 6. Key Features

### 6.1 Main Game

- Front-facing dark grid board.
- Blue and red 3D-rendered pawns.
- Blue and red 3D-rendered walls.
- Green goal area.
- Turn indicator.
- Wall inventory.
- Legal movement highlighting.
- Wall-placement preview.
- Invalid-placement feedback.
- Move and wall animations.
- Victory state.

### 6.2 Local Two-Player

Two people can play on the same device.

Requirements:

- No internet dependency.
- Same game engine as online mode.
- Pass-and-play flow.
- Optional privacy/turn handoff screen.

### 6.3 Vs AI

Initial AI:

- Legal move generation.
- Shortest-path evaluation.
- Opponent-path evaluation.
- Wall-placement evaluation.
- Difficulty-specific search depth/heuristics.

Future AI can use stronger search algorithms after the core engine is stable.

### 6.4 Online Multiplayer

Firebase-backed:

- Anonymous or account-based authentication as appropriate.
- Create match.
- Join match.
- Room code.
- Match state synchronization.
- Turn ownership.
- Connection/reconnection state.
- Match completion.
- Rematch.

The online design must stay within the constraints of the Firebase Spark plan during the initial release.

### 6.5 Player Account

A Firebase user can have cloud data associated with their user ID.

Possible data:

- Display name.
- Avatar reference.
- Statistics.
- Match history.
- Preferences.

No private information should be stored unless required.

### 6.6 Settings

- Music.
- Sound effects.
- Haptics.
- Reduced motion.
- Accessibility/color assistance.
- Confirm wall placement.
- UI scale where practical.

### 6.7 Tutorial

Teach:

1. Goal.
2. Movement.
3. Wall placement.
4. Limited wall inventory.
5. Winning.

Tutorial content should use the actual game board.

---

## 7. UX Principles

1. **Board first:** gameplay remains the visual priority.
2. **Immediate feedback:** every tap/click should produce understandable feedback.
3. **Low cognitive load:** only relevant actions are emphasized.
4. **No accidental wall placement:** wall placement should be previewable and optionally confirmable.
5. **Rules are deterministic:** the same game state must produce the same legal actions on every platform.
6. **Responsive:** UI adapts to mobile and desktop without changing game rules.
7. **Accessible:** red/blue color must not be the only player identifier.

---

## 8. Visual Direction

The board is a dark, front-facing digital grid.

It is **not** an isometric tabletop.

The 3D effect comes primarily from:

- Pawn depth.
- Wall depth.
- Bevels.
- Shadows.
- Highlights.
- Glow.
- Lighting.
- Subtle board-edge depth.

The visual language should be original and should not depend on the rejected Stitch output.

The Stitch folder is **not a project dependency and must not be treated as the visual source of truth**.

The implementation source of truth is:

1. This PRD for product requirements.
2. `rules.md` for engineering constraints.
3. `architecture.md` for structure.
4. `design.md` for the visual system.
5. The actual Flutter implementation and approved project assets.

---

## 9. Online/Offline Data Principles

### Offline

The game engine must work without Firebase.

Local game state and local settings should be stored locally.

### Online

Firebase is used for:

- Authentication.
- Match synchronization.
- Cloud player data where required.

The client must not assume that local state is authoritative for another player.

Online security rules must verify, at minimum where feasible:

- Authenticated user identity.
- Match membership.
- Turn ownership.
- Valid state shape.
- Monotonic turn/version values.
- Allowed participant fields.

Complex game-rule validation should remain centralized in the game engine and the online architecture must document the limitations of Firestore Security Rules.

---

## 10. Non-Goals for Initial Release

Do not make these prerequisites for the first playable release:

- Large social network.
- Voice chat.
- Public global chat.
- Spectator mode.
- Tournaments.
- Paid cosmetics.
- Real-money features.
- Complex player trading.
- Large matchmaking infrastructure.
- Custom 3D characters.
- Full free-camera 3D gameplay.

These may be considered after the core game is stable.

---

## 11. MVP Definition

The MVP is complete when:

- The board renders correctly on Android, iOS, and Web.
- Two players can play locally.
- Movement follows the game rules.
- Wall placement follows the game rules.
- Illegal walls are rejected.
- A valid path to each goal is preserved.
- A player wins correctly.
- The game can restart.
- Basic AI can play.
- Online room creation/joining works.
- Online turns synchronize through Firebase.
- Reconnection states are handled.
- Basic settings work.
- Automated game-engine tests pass.

---

## 12. Future Expansion

Potential future features:

- Ranked online matches.
- Matchmaking.
- Leaderboards.
- Player progression.
- Cosmetics.
- Seasonal boards.
- Additional board sizes.
- Advanced AI.
- Replays.
- Spectator mode.
- Tournaments.

Any future feature must preserve the core rule engine and avoid unnecessary coupling to the UI.
