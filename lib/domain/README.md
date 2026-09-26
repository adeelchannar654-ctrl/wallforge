# Domain layer (game engine)

**Complete.** Pure-Dart game engine implementing
[`game_spec.md`](../../game_spec.md) v2.0.0 (9x9 board, 10 walls per player).

> Status note: Phase 2's exit criteria are met and were re-verified since — the
> spec checker reports `OK`, the 114 oracle games are byte-identical to the
> reference generator, and the engine is exercised by the full suite. Nothing in
> this file is claimed as "clean" unless a command was run and its output quoted.
>
> `game_spec.md` is now **v2.0.0** after the owner-approved crossing-wall rule
> change: a horizontal and a vertical wall may share an anchor. The domain
> enforces it (`MoveGenerator` and `ActionValidator` no longer reject that shape),
> same-orientation overlap is still rejected, and `ActionFailure.wallCrosses` is
> retained but unreachable — see `memory.md` §13l.

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
│   └── action_failure.dart          — failure taxonomy: 12 declared, 11 reachable (spec §5.1)
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

## Spec conformance (source of truth: `game_spec.md` v2.0.0)

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
| Failure reasons (12 declared, 11 reachable — `wallCrosses` is retired) | §5.1 | [`ActionFailure`](models/action_failure.dart) |
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
├── worked_examples_test.dart — §8 worked examples, one per example
├── scripted_game_test.dart   — §15 scripted game replay
├── traceability_test.dart    — rule ID → test ID traceability
├── cross_checks_test.dart    — independent naive re-implementation vs the engine
└── oracle_vectors_test.dart  — cross-check against the independent oracle
```

All of the above are implemented, not planned. Phase 2.1's scope ("one test per
catalog row, worked examples, scripted game, traceability, independent
cross-checks, structure test") was completed; the later phases added
`crossing_walls_test.dart` for the v2.0.0 rule change.

## Quality gates

Run (do not claim) before declaring any phase done:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
python tool/spec_verification/check_spec_consistency.py game_spec.md
python tool/spec_verification/gen_engine_vectors.py   # must be byte-identical to
                                                      # test/fixtures/engine_vectors.json
```

History, kept for traceability: at the start of Phase 2.1 (2026-09-20) `dart format`
reported 11 files changed, `flutter analyze` reported 165 issues, `flutter test`
reported `+69: All tests passed!`, and the spec checker printed `OK`. Those
baselines were superseded. The most recent full run (2026-09-26, end of Phase 5)
is `Formatted 67 files (0 changed)`, `No issues found!`, `936: All tests passed!`,
checker `OK`, oracle vectors byte-identical.
