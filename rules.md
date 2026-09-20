# Wallforge — Project Rules

## 1. Purpose

These rules define how Wallforge must be built, tested, maintained and extended.

The project targets:

- Android
- iOS
- Web

Framework:

- Flutter
- Dart

Backend:

- Firebase, initially targeting the Spark plan.

---

# 2. What to Use

## 2.1 Required technologies

Use:

- Flutter stable channel.
- Dart version compatible with the selected stable Flutter release.
- Flutter's standard Material/Cupertino capabilities where appropriate.
- Firebase Flutter plugins through FlutterFire.
- Cloud Firestore for online match synchronization.
- Firebase Authentication for identity.
- Local persistence for offline settings/game state.
- Flutter testing tools.
- Git for version control.

Flutter is intended to support Android, iOS and Web from a shared codebase, making it appropriate for this project. citeturn0search3

---

## 2.2 Architecture pattern

Use a layered architecture:

```text
Presentation
    ↓
Application
    ↓
Domain/Game Engine
    ↑
Data/Repositories
```

The domain layer must remain independent of Flutter and Firebase wherever practical.

---

## 2.3 State management

Use one consistent state-management approach across the application.

Do not mix several state-management frameworks without a documented reason.

The selected solution must support:

- Reactive UI updates.
- Clear ownership of state.
- Testability.
- Separation between game state and presentation state.

The game engine itself should remain framework-independent.

---

## 2.4 Board rendering

Use Flutter-native rendering initially:

- CustomPainter.
- Widgets.
- Stack.
- Transform.
- AnimationController/implicit animations.
- Gradients/shadows.

Do not introduce a full 3D engine simply because the game is described as 3D.

The desired board is front-facing with subtle 3D rendering.

---

# 3. What to Avoid

## 3.1 Avoid copied game identity

Do not copy:

- Another game's name.
- Logo.
- Artwork.
- Exact UI.
- Proprietary assets.
- Exact typography.
- Exact branding.

The game is Wallforge.

The project may use common strategy-game mechanics, but its presentation and implementation must be original.

---

## 3.2 Avoid Stitch dependency

Do not require Google Stitch exports to build or run the application.

The user explicitly decided not to use the Stitch folder because it did not match the desired design.

Do not:

- Import Stitch-generated code into production by default.
- Treat Stitch screenshots as the source of truth.
- Build the application around a Stitch folder.
- Create a dependency on Stitch being installed.

Use `design.md` and approved project assets instead.

---

## 3.3 Avoid unnecessary packages

Do not add packages for problems Flutter already solves.

Every package must have:

- A clear purpose.
- A maintained release.
- Platform compatibility.
- A reason that justifies its maintenance cost.

Before adding a package, verify Android, iOS and Web compatibility.

---

## 3.4 Avoid business logic in widgets

Do not write:

```text
if wall is valid...
```

or complex movement rules directly inside UI widgets.

Widgets request actions.

The game engine decides whether actions are legal.

---

## 3.5 Avoid pixel-based game state

Never store:

```text
pawnX = 174.5
pawnY = 283.2
```

as the authoritative game state.

Use logical coordinates:

```text
row = 4
column = 3
```

The renderer calculates pixels.

---

## 3.6 Avoid client-trusted online state

Never assume a Firebase client is honest.

Do not expose a design where a client can freely declare:

```text
winner = true
wallsRemaining = 10
```

without validation.

Firestore rules must constrain writes as much as possible.

---

# 4. Libraries and Dependencies

Use the smallest practical dependency set.

## Required/approved

### Flutter SDK

Purpose:

- UI.
- Rendering.
- Animation.
- Cross-platform application.

Version guideline:

- Use a current stable Flutter release.
- Keep Flutter/Dart versions consistent across the team.
- Upgrade intentionally and test all platforms after upgrades.

### firebase_core

Purpose:

- Initialize Firebase.

### firebase_auth

Purpose:

- User authentication and identity.

### cloud_firestore

Purpose:

- Online matches.
- User cloud data.
- Match metadata.

### shared_preferences

Purpose:

- Small local settings.
- Tutorial completion.
- Simple local preferences.

For larger local game storage, select a maintained local database only when requirements justify it.

### flutter_test

Purpose:

- Unit/widget tests.

### integration_test

Purpose:

- Cross-platform integration testing where needed.

---

## Optional/approved after justification

### firebase_crashlytics

Use for supported mobile crash reporting.

### firebase_messaging

Use only when push notifications become an actual product requirement.

### Connectivity/network-status package

May be used if platform-independent network status is required and Flutter's built-in capabilities are insufficient.

### Animation package

May be added only if the required animation cannot be implemented cleanly with Flutter's built-in animation APIs.

---

## Dependency version policy

Do not copy arbitrary package versions from old tutorials.

Use versions compatible with the current stable Flutter/Dart release.

Before adding/upgrading dependencies:

1. Check package maintenance.
2. Check Android compatibility.
3. Check iOS compatibility.
4. Check Web compatibility.
5. Check licensing.
6. Run tests.
7. Run `flutter analyze`.
8. Test a release build on supported targets.

---

# 5. Firebase Rules

Firebase is initially restricted to the no-cost Spark plan.

Current Firebase documentation lists no-cost quotas for Cloud Firestore and most Authentication options. Firestore's current no-cost quota includes 1 GiB storage, 50,000 reads/day, 20,000 writes/day, 20,000 deletes/day and 10 GiB/month outbound data transfer. These limits must be rechecked before production release because quotas can change. citeturn0search1turn0search5

Do not assume the Spark plan provides unlimited usage.

The application should be designed to remain efficient:

- Avoid excessive writes.
- Do not write every animation frame.
- Do not write every pointer movement.
- Write only meaningful game-state changes.
- Keep documents compact.
- Use one appropriate match listener.
- Paginate historical data.

---

# 6. Firebase Authentication

Authentication can initially use an appropriate low-friction method such as anonymous authentication.

If the product later needs durable cross-device identity, introduce account linking/sign-in methods.

Important:

Anonymous identity is not equivalent to a durable user account unless the account is linked/persisted according to the selected authentication strategy.

The account system must be designed before promising cross-device data restoration.

---

# 7. Error Handling

Errors must be handled at the correct layer.

## Domain errors

Examples:

- Illegal move.
- Illegal wall.
- No walls remaining.
- Match already finished.
- Wrong turn.

These should return structured domain failures.

Do not throw generic exceptions for expected invalid game actions.

---

## Data errors

Examples:

- Firebase unavailable.
- Permission denied.
- Timeout.
- Serialization failure.

Map these to application-level errors.

---

## UI errors

Show clear messages.

Bad:

> Exception: FirebaseException code permission-denied...

Good:

> We couldn't join this match. Check the room code and try again.

---

# 8. Logging

Use structured logging.

Logs should include:

- Event type.
- Screen/service.
- Match ID when safe.
- Turn number when useful.
- Error category.

Do not log:

- Passwords.
- Authentication tokens.
- Private user data.
- Full sensitive documents.

Avoid excessive logs in release builds.

---

# 9. Error Recovery

### Offline

If the game is local:

- Continue playing.

If an online match loses connection:

- Preserve the current local state.
- Show "Reconnecting".
- Avoid applying duplicate moves.
- Resume synchronization when possible.

### Failed move submission

Do not immediately apply a second attempt blindly.

Use a version/turn identifier to prevent duplicate submissions.

---

# 10. AI Boundaries

AI coding assistants may:

- Generate boilerplate.
- Create Flutter widgets.
- Create tests.
- Refactor code.
- Explain code.
- Suggest architecture.
- Generate documentation.

AI coding assistants must NOT:

- Invent game rules.
- Change core rules without updating `PRD.md` and `rules.md`.
- Invent Firebase security behavior.
- Claim online security is stronger than the implementation.
- Add packages without justification.
- Delete tests to make the project pass.
- Replace working architecture without explaining why.
- Generate fake Firebase credentials.
- Store secrets in source code.
- Assume a design from an image is an exact specification.
- Treat unverified assumptions as requirements.

Before implementation, AI must read:

```text
PRD.md
architecture.md
rules.md
phase.md
design.md
memory.md
```

Then inspect the existing code before changing it.

---

# 11. Code Style

Use standard Dart formatting.

Run:

```bash
dart format .
flutter analyze
flutter test
```

before considering a meaningful implementation task complete.

Prefer:

- Small functions.
- Clear types.
- Immutable models where practical.
- Explicit interfaces.
- Dependency injection where useful.
- Descriptive names.

Avoid:

- Giant widgets.
- Giant service classes.
- Deep nesting.
- Global mutable state.
- Hidden side effects.

---

# 12. Naming

Classes:

```text
PascalCase
GameEngine
MatchRepository
WallPreview
```

Variables/functions:

```text
camelCase
currentPlayer
validateWall()
```

Files:

```text
snake_case.dart
game_engine.dart
wall_preview.dart
```

Constants:

Use Dart's standard lowerCamelCase for const identifiers unless a project-wide convention establishes another style.

---

# 13. Git Commit Messages

Use:

```text
type(scope): description
```

Examples:

```text
feat(game): add wall validation
fix(game): prevent blocked goal paths
feat(online): add room joining
fix(ui): correct board scaling on web
test(game): add pathfinding cases
docs(rules): document firebase constraints
refactor(domain): separate move validation
```

Avoid:

```text
update
changes
final
done
new code
```

---

# 14. Security

Never commit:

- API secrets.
- Private keys.
- Service account JSON.
- Passwords.
- OAuth secrets.
- User tokens.

Firebase client configuration values that are designed for client apps are not equivalent to server secrets, but Firestore Security Rules and authentication controls must still be configured correctly.

Never rely on hiding a client configuration value as the primary security mechanism.

---

# 15. Privacy

Collect only information needed for the product.

Do not store unnecessary personal information.

Player IDs should use Firebase user IDs rather than exposing private account information.

Match documents should contain only necessary data.

---

# 16. Performance

Do not:

- Repaint the entire application unnecessarily.
- Run pathfinding every animation frame.
- Recalculate legal moves on unrelated UI rebuilds.
- Send Firestore writes for pointer movement.
- Load large assets unnecessarily.

Do:

- Cache derived game calculations where useful.
- Keep board rendering lightweight.
- Use logical state.
- Animate only visual properties.
- Dispose controllers/listeners correctly.
- Profile before optimizing complex areas.

---

# 17. Testing Rules

Every important game rule must have automated tests.

Required tests include:

### Movement

- Valid move.
- Edge of board.
- Wall blocked.
- Wrong turn.
- Completed match.

### Walls

- Valid wall.
- Overlap.
- Illegal crossing.
- No walls remaining.
- Outside board.
- Wall that blocks a goal route.

### Pathfinding

- Open board.
- Single wall.
- Multiple walls.
- Forced detour.
- No-path detection.

### Win

- Correct goal detection.
- Opponent does not win accidentally.
- Match locks after victory.

### Serialization

- Game state to/from JSON.
- Match state persistence.
- Version compatibility.

---

# 18. Documentation Rules

Update documentation when behavior changes.

If a game rule changes:

Update:

- PRD.md
- rules.md
- phase.md if relevant
- tests

If architecture changes:

Update:

- architecture.md

If visual behavior changes:

Update:

- design.md

If implementation progress changes:

Update:

- memory.md

---

# 19. Project-Specific Rules

### Rule 1

The game engine is authoritative for local game legality.

### Rule 2

The same engine must be used by local, AI and online modes.

### Rule 3

The UI must not duplicate game rules.

### Rule 4

Board state is logical, not pixel-based.

### Rule 5

Walls must be represented by grid coordinates and orientation.

### Rule 6

Every legal wall placement must preserve at least one route for each player.

### Rule 7

One turn equals one primary action.

### Rule 8

No normal actions are accepted after the game ends.

### Rule 9

The board must remain front-facing and grid-focused.

### Rule 10

Do not turn Wallforge into an isometric tabletop game.

### Rule 11

Stitch is not a project dependency.

### Rule 12

Never sacrifice game-rule correctness for visual effects.

### Rule 13

Never sacrifice data/security correctness for development convenience.

### Rule 14

Do not introduce online features before the offline game engine is stable.

### Rule 15

Any change to the core game rules requires tests and documentation updates.
