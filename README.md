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

**Phase 1 — Core Game Specification** is complete: the game rules are frozen
in [`game_spec.md`](game_spec.md) with deterministic answers for every rule,
a test catalog, and an error taxonomy.

**Phase 0 — Project Foundation** is also complete: the Flutter project, platform
targets, folder structure, lint/format standards, test structure and a minimal
application shell are in place.

The game engine, board rendering and online multiplayer are **not** implemented
yet. See [`phase.md`](phase.md) for the full phase plan.

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
