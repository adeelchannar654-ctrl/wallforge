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
