# Wallforge

**Forge your path. Block your rival.**

Wallforge is a cross-platform, two-player strategy board game built with Flutter.

Two players (Blue vs Red) race across a grid toward the opposite goal edge,
using a limited supply of walls to reroute the opponent. Each turn allows
exactly one primary action:

1. Move the pawn one legal step, **or**
2. Place one legal wall.

A wall may never remove the last route to either player's goal.

---

## Status

**Phases 0–8 and 8.1 are complete, with one owner-side caveat.** See
[`phase.md`](phase.md) for the full plan and the per-phase results.

- **Phase 0 — Project Foundation.** Flutter project, platform targets, folder
  structure, lint/format standards and test structure in place.
- **Phase 1 — Core Game Specification.** The rules are frozen in
  [`game_spec.md`](game_spec.md) with deterministic answers for every rule, a
  test catalog, an error taxonomy and a decision log. The independent checker
  `tool/spec_verification/check_spec_consistency.py` prints
  `OK: spec is consistent with the reference engine.`
- **Phase 2 — Game Engine.** The pure-Dart engine core in
  [`lib/domain/`](lib/domain/README.md) implements the spec and is verified
  against 114 independently generated oracle games.
- **Phase 3 — Board Rendering.** The native Stitch-aligned board renderer, with
  geometry/engine cross-checks, board widget tests, board goldens, goal-strip
  labels and the visual-conformance checklist.
- **Phase 4 — Interactive Local Game.** A full local pass-and-play match: tap
  movement, wall selection, placement, preview, turn indicator, wall counter,
  invalid-action feedback, victory screen, restart and rematch — including the
  4.1/4.2/4.3 corrections for wall hit-testing, invalid-ghost clarity and
  cross-axis anchor snapping.
- **Phase 5 — Offline AI.** An AI opponent at four difficulties (Easy, Medium,
  Hard, Expert), differing only in search depth and breadth — no randomness. It
  plays through the same engine as a human, so it can never make an illegal move.
- **Phase 6 — Local Persistence.** Settings, match statistics and an unfinished
  match are stored on the device with `shared_preferences`, behind repository
  interfaces in the domain layer so the online backend can replace the
  implementation later. A match in progress can be resumed after closing the app.
- **Phase 7 — Firebase Foundation.** `cloud_firestore`, `firebase_core` and
  `firebase_auth` are wired in, with Firestore-backed implementations of the
  same three repository interfaces behind a narrow storage port, and a
  defensive startup that survives a build with no Firebase configuration.
  The app still defaults to local storage, so nothing about how it plays has
  changed yet — see the note below.
- **Phase 8 — Online Rooms.** Anonymous sign-in and a two-player room:
  create a room, share the six-character code, join by code, ready up, and
  start. The room code is the Firestore document id, so joining is a single
  read with no query or index. Two devices can now reach a shared room with
  an agreed board and seat assignment. **Moves are not synchronised yet** —
  that is Phase 9, and the lobby says so on screen. Local and vs-AI play are
  unchanged.
- **Phase 8.1 — Random Matchmaking.** A Quick Match option alongside Create
  and Join Room: a player is paired with a stranger automatically, with no
  room code. Pairing is atomic — simultaneous requests cannot double-book
  anyone or leave a player stranded — and the resulting room is the same
  Phase 8 room, so ready state, match start and Phase 9 behave identically
  however the two players found each other. Added by owner request after
  Phase 8 shipped; it is recorded in [`phase.md`](phase.md) as its own phase
  rather than folded in silently.

**Firebase still needs owner-side setup in the Console.** The app
code is complete and tested, but this repository ships no Firebase client
configuration on purpose: `.gitignore` excludes `google-services.json`,
`GoogleService-Info.plist` and `firebase_options.dart` and says never to merge
exceptions for them. Until those files are added locally, the app logs
`Firebase unavailable` at startup and runs on local storage. The exact manual
steps — registering the Android/iOS/Web apps, running `flutterfire configure`
for project `wallforge-efdb3`, and creating the Firestore database — are in
[`memory.md`](memory.md) §13o.

**This was confirmed still outstanding during Phase 8**, so the online code is
tested against an in-process Firestore double rather than a live backend. That
means anonymous sign-in actually working, the `matches/{code}` document being
readable, and realtime updates converging between two real devices are all
still unverified.

**Online Play now works without configuration.** A bug found after Phase 8
shipped made tapping "Online Play" silently do nothing, because
`FirebaseAuthGateway` resolved the Firebase SDK in its constructor and threw
before any error handling could run. That is fixed, with a regression test
that builds the real gateway with no Firebase configured. Entering the lobby
now shows a clear "online play is unavailable" state instead of failing
silently. It remains true that the Firebase adapters are barely covered by
tests — `cloud_firestore_client.dart` is at 2.56% and the success paths of
`firebase_auth_gateway.dart` are unverified — because verifying them needs
the live project described above. See [`memory.md`](memory.md) §13p and
§13q for the full list of what is and is not proven.

**The rules changed after Phase 4.** `game_spec.md` is now at **v2.0.0**: a
horizontal and a vertical wall may share an anchor, forming a legal "+". This was
a deliberate owner-approved rule change, not a bug fix. Same-orientation overlap
remains illegal, and path preservation, bounds, inventory, jump rules and the win
condition are unchanged. The initial legal-move counts (3 moves / 128 walls) are
unchanged. One failure reason, `wallCrosses`, became unreachable and is
documented as retired rather than removed.

**Test status:** 968 tests pass, with the spec checker reporting `OK` and the
oracle vectors byte-identical to the reference generator.

---

## Platforms

- Android
- iOS
- Web

## Tech stack

- **Framework:** Flutter (stable) / Dart
- **Backend (later):** Firebase — Authentication and Cloud Firestore, on the
  Spark/no-cost plan

---

## Documentation

Read these before contributing. They are the source of truth.

| Document | Purpose |
| --- | --- |
| [`PRD.md`](PRD.md) | Product requirements |
| [`architecture.md`](architecture.md) | System structure and layer boundaries |
| [`rules.md`](rules.md) | Engineering rules and constraints |
| [`phase.md`](phase.md) | Development phase plan |
| [`design.md`](design.md) | Visual design system |
| [`memory.md`](memory.md) | Project memory / current status |
| [`game_spec.md`](game_spec.md) | Frozen game specification (Phase 1) |

> The Google Stitch design output is **not** a project dependency and must not
> be treated as the visual source of truth. See [`memory.md`](memory.md) §4.

---

## Architecture

```text
Presentation
    ↓
Application
    ↓
Domain / Game Engine
    ↑
Data / Repositories
```

The domain layer is pure Dart and owns all game legality. It must not depend on
Flutter or Firebase.

```text
lib/
├── main.dart
├── app/            # app root, router, theme
├── core/           # constants, logging, errors, utilities
├── domain/         # game engine (Phase 2)
├── application/    # use cases / controllers
├── data/           # local + Firebase repositories
└── presentation/   # screens, widgets, board rendering
```

---

## Getting started

```bash
flutter pub get
flutter run            # choose a connected device or Chrome
```

## Quality checks

```bash
dart format .
flutter analyze
flutter test
```

## Build targets

```bash
flutter build web
flutter build apk        # Android
flutter build ios        # requires macOS + Xcode
```

---

## Contributing

- Follow [`rules.md`](rules.md) for dependencies, error handling, naming and
  testing.
- Never commit secrets, credentials or service-account files.
- Keep the game engine independent of the UI.
