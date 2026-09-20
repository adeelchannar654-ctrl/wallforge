# Domain layer (game engine)

**Phase 0 boundary marker — no implementation yet.**

This directory is the home of the Wallforge game engine. Per
[`architecture.md`](../../architecture.md) §2.3 and [`rules.md`](../../rules.md)
Rule 1, this layer is the authoritative owner of game legality.

The frozen game specification is in [`../../game_spec.md`](../../game_spec.md).
Phase 2 will implement this specification here.

## Responsibility (later phases)

- Board model and board configuration.
- Player and pawn models.
- Wall model (logical `anchorRow`, `anchorColumn`, `orientation`, `owner`).
- `GameState` and turn state.
- Legal move generation.
- Wall validation.
- Pathfinding (BFS).
- Win detection.
- Match state transitions.

## Hard constraints

- **Pure Dart.** No Flutter, no Firebase, no `dart:ui`.
- **Logical coordinates only.** Never store pixel positions as game state.
- **Deterministic.** The same state must yield the same legal actions on every
  platform.

The planned layout is:

```text
lib/domain/
├── game/
│   ├── models/
│   ├── rules/
│   ├── pathfinding/
│   └── game_engine.dart
├── player/
└── repositories/
```

No files are created here in Phase 0 because inventing models before the rules
are frozen (Phase 1) would violate the documented phase order.
