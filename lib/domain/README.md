# Domain layer (game engine)

**Phase 2.1 in progress.** Pure-Dart game engine implementing
[`game_spec.md`](../../game_spec.md) v1.0.4 (9x9 board, 10 walls per player).

> Status note: the engine core is implemented and the spec checker and oracle
> vectors pass, but Phase 2 exit criteria are **not** yet met. Docs, structured
> serialization, complete per-rule tests and quality gates are being finished in
> Phase 2.1. Nothing in this file is claimed as "clean" unless a command was run
> and its output quoted.

## Structure

```text
lib/domain/
├── wallforge_domain.dart            — barrel export
├── models/
│   ├── models.dart                  — model barrel
│   ├── board_config.dart            — board geometry (default 9x9, 10 walls/player)
│   ├── cell.dart                    — immutable (row, column) coordinate
│   ├── player_id.dart               — blue/red enum with opponent
│   ├── wall_orientation.dart        — h/v enum
│   ├── wall.dart                    — wall model (anchor + orientation + owner)
│   ├── game_action.dart             — sealed GameAction: move | wall
│   ├── game_status.dart             — inProgress | finished
│   ├── game_state.dart              — game snapshot (turn-parity current player)
│   └── action_failure.dart          — 12-reason failure taxonomy (spec §5.1)
├── engine/
│   ├── engine.dart                  — engine barrel
│   ├── pathfinder.dart              — BFS route-preservation check
│   ├── move_generator.dart          — enumerates legal actions for current player
│   ├── action_validator.dart        — validates one action against a state
│   └── game_engine.dart             — validate + apply, turn transitions
└── serialization/
    ├── serialization.dart           — serialization barrel
    └── game_state_serializer.dart   — GameState JSON (spec §7.1 / §16)
```

## Spec conformance (source of truth: `game_spec.md` v1.0.4)

| Concern | Spec | Dart symbol |
| --- | --- | --- |
| Board size / config | §2 (odd, ≥5; default 9) | [`BoardConfig`](models/board_config.dart) |
| Walls per player | §2 (default 10) | [`BoardConfig.wallsPerPlayer`](models/board_config.dart) |
| Start cells (Blue bottom, Red top) | §3 R-BOARD-03 | [`BoardConfig.blueStart`](models/board_config.dart), [`BoardConfig.redStart`](models/board_config.dart) |
| Goal rows | §3 R-BOARD-04 | [`BoardConfig.blueGoalRow`](models/board_config.dart), [`BoardConfig.redGoalRow`](models/board_config.dart) |
| Coordinate order `(row, column)` | §3 R-BOARD-01 | [`Cell`](models/cell.dart) |
| Wall identity (anchor + orientation + owner) | §3 R-WALL-01 | [`Wall`](models/wall.dart) |
| Single action type (move \| wall) | §4 / §5 | [`GameAction`](models/game_action.dart) |
| Current player from turn parity | §3 R-TURN-01 | [`GameState.currentPlayer`](models/game_state.dart) |
| Match status | §3 R-WIN-01 | [`GameStatus`](models/game_status.dart) |
| State JSON shape | §7.1 / §16 | [`GameStateSerializer`](serialization/game_state_serializer.dart) |
| Failure reasons (12) | §5.1 | [`ActionFailure`](models/action_failure.dart) |
| Failure precedence | §5.2 | [`ActionValidator`](engine/action_validator.dart) |
| Canonical action order | §3 R-ORDER-01 | [`MoveGenerator`](engine/move_generator.dart) |

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
├── spec_catalog_test.dart    — spec catalog (T-* IDs) coverage
└── oracle_vectors_test.dart  — cross-check against the independent oracle
```

Phase 2.1 is expanding this to one test per catalog row, worked examples (§8), the
scripted game (§15), a traceability test, independent cross-checks and a
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
