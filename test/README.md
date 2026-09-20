# Wallforge tests

Test structure follows `architecture.md` §20 and `rules.md` §17.

```text
test/
└── widget_test.dart        # Phase 0 application shell smoke test
```

## Phase 0

Only a shell smoke test exists. The game engine does not exist yet, so there are
no rule tests to write. Tests here must be real and must pass — never add tests
that exist only to satisfy a checklist.

## Later phases

Add rules and engine tests here as the domain layer is built, for example:

```text
test/
├── domain/
│   ├── game_engine_test.dart
│   ├── movement_test.dart
│   ├── wall_validation_test.dart
│   ├── pathfinding_test.dart
│   └── win_detection_test.dart
├── application/
└── data/
```

Cross-platform integration tests belong in `integration_test/`.
