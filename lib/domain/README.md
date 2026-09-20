# Domain layer (game engine)

**Phase 2 complete.** Pure-Dart game engine implementing `game_spec.md` v1.0.4.

## Structure

```text
lib/domain/
├── wallforge_domain.dart        — barrel export
├── models/
│   ├── models.dart              — model barrel
│   ├── board_config.dart        — board geometry (10x10, 10 walls)
│   ├── cell.dart                — immutable grid coordinate
│   ├── player_id.dart           — Blue/Red enum with opponent
│   ├── wall_orientation.dart    — horizontal/vertical enum
│   ├── wall.dart                — wall model with footprint and blocked edges
│   ├── game_action.dart         — MoveAction, JumpAction, PlaceWallAction
│   ├── game_status.dart         — waitingForPlayers, active, blueWins, redWins, draw
│   ├── game_state.dart          — immutable game snapshot with copyWith
│   └── action_failure.dart      — sealed error taxonomy (14 failure types)
├── engine/
│   ├── engine.dart              — engine barrel
│   ├── pathfinder.dart          — BFS reachability check
│   ├── move_generator.dart      — generates all legal actions for active player
│   ├── action_validator.dart    — validates a single action against state
│   ├── game_engine.dart         — validates + applies actions, switches turns
│   └── board_edge.dart          — edge utility type
└── serialization/
    ├── serialization.dart       — serialization barrel
    ├── game_state_json.dart     — JSON round-trip (spec §16)
    └── action_notation.dart     — action notation parse/serialize
```

## Responsibility

- Board model and board configuration.
- Player and pawn models.
- Wall model.
- `GameState` and turn state.
- Legal move generation.
- Wall validation.
- Pathfinding (BFS).
- Win detection.
- Match state transitions.

## Hard constraints

- **Pure Dart.** No Flutter, no Firebase, no `dart:ui`.
- **Logical coordinates only.** Never store pixel positions as game state.
- **Deterministic.** The same state yields the same legal actions on every platform.
- **Invalid actions return structured failures.** Never throw exceptions for game-rule violations.

## Tests

```text
test/domain/
├── models_test.dart          — model unit tests
├── engine_test.dart          — engine unit tests
├── spec_catalog_test.dart    — spec catalog traceability (T-* IDs)
└── property_test.dart        — property/cross-check tests
```

79 tests, all passing. Spec checker passes OK.
