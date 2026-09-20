# Application layer

**Phase 0 boundary marker — no implementation yet.**

This directory coordinates user actions. It calls the game engine and the
repository interfaces, and it is the only layer the presentation layer talks to
for state changes (see [`architecture.md`](../../architecture.md) §2.2).

## Responsibility (later phases)

- Start match, select move, select wall, confirm wall, end turn.
- Create online room, join online room, rematch.
- Mode orchestration (local, AI, online).

## Dependency direction

```text
Presentation -> Application -> Domain
```

The application layer must not contain authoritative game rules; it delegates
those to the domain layer.

Planned layout:

```text
lib/application/
├── game/
├── online/
├── ai/
└── profile/
```
