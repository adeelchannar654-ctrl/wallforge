# Wallforge — Architecture

## 1. Architecture Overview

Wallforge uses a layered Flutter architecture.

The central principle is:

> **The game engine owns the rules. The UI displays the state. Services handle persistence and networking.**

The UI must never become the source of truth for movement, wall legality, turn changes, or victory.

### High-level architecture

```text
                         WALLFORGE
                              |
             +----------------+----------------+
             |                                 |
         Presentation                      Application
             |                                 |
       Flutter UI/Renderers             Use Cases/Controllers
             |                                 |
             +----------------+----------------+
                              |
                         Game Engine
                              |
              +---------------+---------------+
              |               |               |
          Board State      Rules/Move      Pathfinding
              |            Validation          |
              +---------------+---------------+
                              |
                    Repository Interfaces
                              |
            +-----------------+------------------+
            |                                    |
       Local Storage                         Firebase
            |                                    |
       Offline State              Auth / Firestore / optional
```

---

## 2. Architectural Layers

### 2.1 Presentation Layer

Responsible for:

- Screens.
- Widgets.
- Responsive layouts.
- Visual board rendering.
- Input handling.
- Animations.
- Accessibility.
- UI state presentation.

Must not contain authoritative game rules.

### 2.2 Application Layer

Responsible for coordinating user actions.

Examples:

- Start match.
- Select move.
- Select wall.
- Confirm wall.
- End turn.
- Create online room.
- Join online room.
- Rematch.

The application layer calls the game engine and repositories.

### 2.3 Domain/Game Engine

Pure Dart where practical.

Contains:

- Board model.
- Player model.
- Pawn positions.
- Wall model.
- Turn state.
- Legal move generation.
- Wall validation.
- Pathfinding.
- Win detection.
- Match state transitions.

This layer must have no dependency on Flutter widgets or Firebase.

### 2.4 Data Layer

Contains implementations for:

- Local persistence.
- Firebase Authentication.
- Cloud Firestore.
- Remote match synchronization.

Repositories expose domain-friendly interfaces to the application layer.

---

## 3. Game Engine Design

### Core state

The match state should contain conceptually (see `game_spec.md` section 6 for
the full specification and invariants):

```text
GameState
- boardConfig
- players
- currentPlayer
- pawnPositions
- walls
- remainingWalls
- turnNumber
- status
- winner
```

Use immutable state objects where practical.

### Board coordinates

Use logical coordinates such as:

```text
row
column
```

Never store gameplay state as pixel positions.

Pixel coordinates belong to the presentation layer.

### Walls

Represent walls logically by:

```text
anchorRow
anchorColumn
orientation
owner
```

The renderer converts the logical wall into a visual position.

This prevents resolution/device-size differences from corrupting game state.

---

## 4. Pathfinding

Use BFS initially because movement is on an unweighted grid.

Pathfinding should be able to answer:

- Does a route exist?
- What is the shortest route?
- What route length does each player currently have?

Wall validation:

1. Tentatively add the proposed wall.
2. Build the resulting movement graph.
3. Find a path for Player 1.
4. Find a path for Player 2.
5. Reject the wall if either player has no route.

This must be covered by automated tests.

---

## 5. Movement Validation

The engine should generate legal moves from the current state. See
`game_spec.md` sections 3.4 and 3.5 for the full movement and jumping rules.

A move is legal only if:

- It belongs to the current player.
- The destination is adjacent according to the game's movement rules.
- The destination is inside the board.
- No wall blocks the movement edge.
- Any player-jump rule is satisfied.

The UI should display the result of engine validation rather than implementing its own duplicate rules.

---

## 6. Wall Validation

A proposed wall is validated by the engine. See `game_spec.md` sections 3.6 and
3.7 for the full wall placement and path-preservation rules.

Checks include:

1. Player has a wall remaining.
2. Position is inside valid wall slots.
3. It does not overlap an existing wall of the same orientation.
4. It does not eliminate every path to either goal.
5. The match is still active.
6. It is the requesting player's turn.

Since spec v2.0.0 there is no crossing check: a horizontal and a vertical wall
may share an anchor (a legal "+"), so shape validation only rejects
same-orientation overlap.

---

## 7. Game State Flow

```text
User Input
   |
   v
Application Controller
   |
   v
Game Engine
   |
   +--> Valid? ---- No ---> UI error/feedback
   |
  Yes
   |
   v
New GameState
   |
   +--> Local repository
   |
   +--> Online repository if online
   |
   v
Presentation rebuilds from state
```

---

## 8. Local Mode

Local mode uses the same domain engine.

Flow:

```text
Input
 -> Engine
 -> New State
 -> Local Persistence (optional)
 -> UI
```

No Firebase dependency should be required for local gameplay.

---

## 9. AI Mode

AI must use the same legal-move and legal-wall functions as human players.

Initial AI pipeline:

```text
Current State
     |
Generate legal actions
     |
Evaluate actions
     |
Choose action
     |
Apply through Game Engine
```

Initial evaluation can consider:

- Own shortest path.
- Opponent shortest path.
- Wall cost.
- Immediate win/loss.
- Difficulty-specific randomness.

Do not duplicate game rules inside the AI.

---

## 10. Online Architecture

Firebase services:

### Firebase Authentication

Used to identify users.

### Cloud Firestore

Used for:

- Match rooms.
- Match state.
- Player membership.
- Match metadata.
- Optional player statistics.

### Firebase Crashlytics

Used for crash reporting on supported mobile platforms if enabled for the release.

### Firebase Cloud Messaging

Optional future service for notifications.

The initial design must not depend on Cloud Functions because the project is targeting the Firebase Spark plan.

Firebase's current Spark plan provides no-cost quotas for products such as Authentication and Cloud Firestore; Firestore currently includes a no-cost quota of 1 GiB stored data, 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day and 10 GiB/month outbound transfer. Quotas and product terms can change, so the implementation must verify current limits before release. citeturn0search1turn0search5

---

## 11. Online Match Model

Conceptual Firestore structure:

```text
users/{userId}

matches/{matchId}
  status
  createdAt
  updatedAt
  currentPlayerId
  turnNumber
  version
  winnerId
  boardState
  playerIds
  playerData

matches/{matchId}/moves/{moveId}
  playerId
  turnNumber
  actionType
  actionPayload
  createdAt
```

The final schema must be implemented consistently and documented before online coding.

### State strategy

For the MVP, a match document may contain a compact authoritative snapshot plus a move sequence for audit/recovery.

Avoid repeatedly writing large redundant documents.

---

## 12. Firebase Security Model

The client must never be treated as trusted.

Firestore Security Rules should enforce what is practical within rules, including:

- User must be authenticated where required.
- User must belong to the match.
- Only a participant can submit their action.
- Only the current participant may advance the turn.
- Match state fields have expected types.
- Turn/version progression is constrained.
- A user cannot change the opponent's identity.
- A completed match cannot accept normal moves.

### Important limitation

Firestore Security Rules are not a replacement for a full authoritative game server. Complex pathfinding and all game-rule calculations should not be assumed to be safely enforceable in Security Rules.

The first Spark-plan version therefore prioritizes a consistent shared game engine, constrained writes, immutable/traceable moves where practical, and strong client-side validation.

If competitive cheating resistance becomes a major requirement, introduce an authoritative backend in a later phase and reassess the Firebase billing plan.

---

## 13. Firebase Flutter Integration

Use the official FlutterFire packages.

Initial integration:

```text
firebase_core
firebase_auth
cloud_firestore
```

Optional:

```text
firebase_crashlytics
firebase_messaging
```

Firebase setup should use the FlutterFire CLI and generate `firebase_options.dart`. Official Firebase documentation currently recommends `flutterfire configure` for registering Android, iOS and Web apps and configuring the Flutter project. citeturn0search0

---

## 14. Local Persistence

Use local persistence for:

- Settings.
- Tutorial completion.
- Local statistics.
- Optional unfinished local match.
- Offline AI match state where useful.

Keep persistence behind repository interfaces.

Do not let UI widgets directly read/write storage.

**As built in Phase 6.** The interfaces and the persisted value shapes live in
`lib/domain/repositories/` (pure Dart, no `dart:io`, no Flutter), the device
implementations in `lib/data/local/`, and the application layer depends only on
the interfaces. `LocalGameController` attaches storage through
`attachPersistence(...)` rather than taking a concrete store, so it stays usable
as a plain synchronous object in tests and an online implementation can replace
`lib/data/local/` in Phase 7 without any change above that line.

Two consequences worth keeping:

- The unfinished match reuses the engine's own `GameStateSerializer`, so a saved
  state that violates a spec invariant is rejected by the same code that rejects
  it anywhere else, rather than by a parallel persistence schema.
- Every repository method is total: missing, wrong-typed or corrupt data resolves
  to a documented default. A corrupt store must never stop the app starting.

---

## 15. Folder and File Structure

Recommended structure:

```text
wallforge/
├── android/
├── ios/
├── web/
├── test/
│   ├── domain/
│   ├── application/
│   └── data/
│
├── assets/
│   ├── images/
│   ├── icons/
│   ├── audio/
│   └── fonts/
│
├── lib/
│   ├── main.dart
│   ├── firebase_options.dart
│   │
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme/
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── logging/
│   │   ├── utils/
│   │   └── result/
│   │
│   ├── domain/
│   │   ├── game/
│   │   │   ├── models/
│   │   │   ├── rules/
│   │   │   ├── pathfinding/
│   │   │   └── game_engine.dart
│   │   ├── player/
│   │   └── repositories/
│   │
│   ├── application/
│   │   ├── game/
│   │   ├── online/
│   │   ├── ai/
│   │   └── profile/
│   │
│   ├── data/
│   │   ├── local/
│   │   ├── firebase/
│   │   │   ├── auth/
│   │   │   ├── firestore/
│   │   │   └── models/
│   │   └── repositories/
│   │
│   └── presentation/
│       ├── screens/
│       │   ├── home/
│       │   ├── game/
│       │   ├── modes/
│       │   ├── online/
│       │   ├── ai/
│       │   ├── tutorial/
│       │   ├── profile/
│       │   ├── settings/
│       │   └── result/
│       ├── widgets/
│       ├── game_board/
│       └── animations/
│
├── PRD.md
├── architecture.md
├── rules.md
├── phase.md
├── design.md
├── memory.md
└── README.md
```

---

## 16. Board Rendering Strategy

Because Wallforge's desired board is front-facing rather than isometric, do not introduce a heavy 3D engine unless a later requirement genuinely needs one.

Initial rendering should prefer Flutter-native rendering:

- `CustomPainter` for the grid/board.
- Flutter widgets for UI.
- `Stack`/positioned elements for game pieces where appropriate.
- `Transform` for subtle depth effects.
- Flutter animations for movement and wall placement.
- Shadows/gradients/glows for the 3D appearance.

This creates a 2.5D visual system while keeping Android, iOS and Web behavior consistent.

If performance or advanced 3D effects later require a rendering engine, evaluate the requirement before adding one.

---

## 17. Responsive Layout

Use separate responsive compositions rather than simply scaling one mobile screen.

Mobile:

```text
Top player information
Goal/turn
Board
Bottom player information
Actions
```

Desktop:

```text
Left information
      Board
Right information
```

The game state remains identical across layouts.

---

## 18. Navigation

Use a centralized routing approach.

Recommended routes:

```text
/
 /home
 /modes
 /local
 /ai
 /online
 /online/create
 /online/join
 /game
 /result
 /tutorial
 /profile
 /settings
```

Do not navigate by manually pushing arbitrary widget instances throughout the codebase.

---

## 19. Dependency Direction

Allowed:

```text
Presentation -> Application -> Domain
Data -> Domain interfaces
Application -> Domain
```

Avoid:

```text
Domain -> Flutter
Domain -> Firebase
Domain -> UI
```

The game engine should remain independently testable.

---

## 20. Testing Architecture

Highest test priority:

1. Game engine.
2. Movement.
3. Wall validation.
4. Pathfinding.
5. Win detection.
6. Turn transitions.
7. Serialization/deserialization.
8. Online synchronization behavior.
9. Responsive UI.
10. Animation/UI polish.

The game should have a large set of deterministic domain tests before advanced visual polish.

---

## 21. Scalability

The MVP should scale through:

- Small Firestore documents.
- Low-frequency writes.
- Snapshot listeners only where needed.
- Paginated match history.
- Local caching.
- Repository abstraction.
- Stateless game-engine calculations.

Do not create a Firestore listener for every UI widget.

Use one appropriate match-state stream and derive UI state from it.

---

## 22. Design Reference Policy

The Stitch design system in `stitch_wallforge_ui_design_system/` is the visual source of truth for production. The shipped Flutter app must look like these designs.

Do not:

- Read the Stitch folder at runtime.
- Add Stitch files to `pubspec.yaml` assets.
- Import HTML/Tailwind/CDN code into production.

The app is built natively in Flutter and must build and run fully offline.

`DESIGN.md` and the five screen files inside the Stitch folder provide tokens, measures and layout references. `game_spec.md` controls game rules. `design.md` provides supplementary visual guidance not covered by Stitch.

Approved custom assets may be stored under:

```text
assets/
```

The coding AI should read the MD files and screen references before implementation and inspect the actual project assets.

Owner decision: 2026-09-21.
