# Domain layer (game engine)

**Phase 2.1 in progress.** Pure-Dart game engine implementing
[`game_spec.md`](../../game_spec.md) v2.0.0 (9x9 board, 10 walls per player).

> Status note: the engine core is implemented and the spec checker and oracle
> vectors pass, but Phase 2 exit criteria are **not** yet met. Docs, structured
> serialization, complete per-rule tests and quality gates are being finished in
> Phase 2.1. Nothing in this file is claimed as "clean" unless a command was run
> and its output quoted.

## Structure

```text
lib/domain/
â”œâ”€â”€ wallforge_domain.dart            â€” barrel export
â”œâ”€â”€ models/
â”‚   â”œâ”€â”€ models.dart                  â€” model barrel
â”‚   â”œâ”€â”€ board_config.dart            â€” board geometry (default 9x9, 10 walls/player)
â”‚   â”œâ”€â”€ cell.dart                    â€” immutable (row, column) coordinate
â”‚   â”œâ”€â”€ player_id.dart               â€” blue/red enum with opponent
â”‚   â”œâ”€â”€ wall_orientation.dart        â€” h/v enum
â”‚   â”œâ”€â”€ wall.dart                    â€” wall model (anchor + orientation + owner)
â”‚   â”œâ”€â”€ game_action.dart             â€” sealed GameAction: move | wall
â”‚   â”œâ”€â”€ game_status.dart             â€” inProgress | finished
â”‚   â”œâ”€â”€ game_state.dart              â€” game snapshot (turn-parity current player)
â”‚   â””â”€â”€ action_failure.dart          â€” 12-reason failure taxonomy (spec Â§5.1)
â”œâ”€â”€ engine/
â”‚   â”œâ”€â”€ engine.dart                  â€” engine barrel
â”‚   â”œâ”€â”€ pathfinder.dart              â€” BFS route-preservation check
â”‚   â”œâ”€â”€ move_generator.dart          â€” enumerates legal actions for current player
â”‚   â”œâ”€â”€ action_validator.dart        â€” validates one action against a state
â”‚   â””â”€â”€ game_engine.dart             â€” validate + apply, turn transitions
â””â”€â”€ serialization/
    â”œâ”€â”€ serialization.dart           â€” serialization barrel
    â””â”€â”€ game_state_serializer.dart   â€” GameState JSON (spec Â§7.1 / Â§16)
```

## Spec conformance (source of truth: `game_spec.md` v2.0.0)

| Concern | Spec | Dart symbol |
| --- | --- | --- |
| Board size / config | Â§2 (odd, â‰¥5; default 9) | [`BoardConfig`](models/board_config.dart) |
| Walls per player | Â§2 (default 10) | [`BoardConfig.wallsPerPlayer`](models/board_config.dart) |
| Start cells (Blue bottom, Red top) | Â§3 R-BOARD-03 | [`BoardConfig.blueStart`](models/board_config.dart), [`BoardConfig.redStart`](models/board_config.dart) |
| Goal rows | Â§3 R-BOARD-04 | [`BoardConfig.blueGoalRow`](models/board_config.dart), [`BoardConfig.redGoalRow`](models/board_config.dart) |
| Coordinate order `(row, column)` | Â§3 R-BOARD-01 | [`Cell`](models/cell.dart) |
| Wall identity (anchor + orientation + owner) | Â§3 R-WALL-01 | [`Wall`](models/wall.dart) |
| Single action type (move \| wall) | Â§4 / Â§5 | [`GameAction`](models/game_action.dart) |
| Current player from turn parity | Â§3 R-TURN-01 | [`GameState.currentPlayer`](models/game_state.dart) |
| Match status | Â§3 R-WIN-01 | [`GameStatus`](models/game_status.dart) |
| State JSON shape | Â§7.1 / Â§16 | [`GameStateSerializer`](serialization/game_state_serializer.dart) |
| Failure reasons (12) | Â§5.1 | [`ActionFailure`](models/action_failure.dart) |
| Failure precedence | Â§5.2 | [`ActionValidator`](engine/action_validator.dart) |
| Canonical action order | Â§3 R-ORDER-01 | [`MoveGenerator`](engine/move_generator.dart) |

## Responsibility

- Board model and board configuration.
- Player and pawn models.
- Wall model.
- `GameState` and turn state.
- Legal action enumeration.
- Wall validation.
- Pathfinding (BFS route preservation).
- Win detection.
- Match state transitions.

## Hard constraints

- **Pure Dart.** No Flutter, no `dart:ui`, no Firebase, no `dart:io` in `lib/domain/`.
- **Logical coordinates only.** Never store pixel positions as game state.
- **Deterministic.** The same state yields the same legal actions on every platform.
- **Invalid input returns structured failures.** Never throw for game-rule violations.

## Tests

```text
test/domain/
â”œâ”€â”€ spec_catalog_test.dart    â€” spec catalog (T-* IDs) coverage
â””â”€â”€ oracle_vectors_test.dart  â€” cross-check against the independent oracle
```

Phase 2.1 is expanding this to one test per catalog row, worked examples (Â§8), the
scripted game (Â§15), a traceability test, independent cross-checks and a
structure test.

## Quality gates

Run (do not claim) before declaring any phase done:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
python tool/spec_verification/check_spec_consistency.py game_spec.md
```

Baseline measured at the start of Phase 2.1 (2026-09-20): `dart format` reported
11 files changed; `flutter analyze` reported 165 issues (mostly
`prefer_const_constructors` infos plus one `unused_element_parameter` warning);
`flutter test` reported `+69: All tests passed!`; the spec checker printed
`OK: spec is consistent with the reference engine.`; the oracle generator output
was byte-identical to the committed fixture. Phase 2.1 must drive format and
analyze to zero and add the missing tests before Phase 2 can be called complete.
