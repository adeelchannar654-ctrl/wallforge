# Data layer

**Phase 0 boundary marker — no implementation yet.**

This directory will contain implementations of the repository interfaces defined
by the domain layer (see [`architecture.md`](../../architecture.md) §2.4).

## Responsibility (later phases)

- Local persistence (settings, tutorial completion, local statistics).
- Firebase Authentication implementation.
- Cloud Firestore match synchronisation.

## Dependency direction

```text
Data -> Domain interfaces
```

The UI must never read or write storage directly; persistence stays behind
repository interfaces.

## Firebase

Firebase is **not** wired up in Phase 0. Firebase belongs to its own later phase
(see [`phase.md`](../../phase.md) Phase 7), and the app must remain runnable
without an active online match.

Planned layout:

```text
lib/data/
├── local/
├── firebase/
│   ├── auth/
│   ├── firestore/
│   └── models/
└── repositories/
```
