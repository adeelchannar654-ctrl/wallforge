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

**Phases 0–14 are complete; Phase 15 (Performance) is complete except
owner-run device/browser checks.** See [`phase.md`](phase.md) for the
full plan and the per-phase results.

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
- **Phase 9 - Online Game Synchronization.** Two clients can now play a
  synchronised match. Each action is validated against the authoritative
  snapshot inside a single transaction that writes the match document and its
  move record together, so a listener never sees half a move; the client cache is
  never trusted for legality. Snapshots are verified before they are shown, a
  lost acknowledgement is retried idempotently, and a finished match is a
  record that cannot be erased or played into. The schema as built is in
  [`architecture.md`](architecture.md) §11, and the reasoning, the two real
  defects that random full-game testing exposed, and an owner acceptance script
  are in [`memory.md`](memory.md) §13q.

  **The Phase 9 live verification was completed on 2026-10-26**: two real
  browser sessions played against the live Firebase project
  `wallforge-efdb3` — moves and a wall placement were recorded server-side
  in `matches/{code}/moves` and rendered identically on both clients
  (matches `6QH974` and `H3NQY2`; see [`memory.md`](memory.md) §13q). A
  full match played to a winner across two devices has not been run yet.
- **Phase 10 — Online Reliability and Security.** Multiplayer is now
  hardened. [`firestore.rules`](firestore.rules) enforces match
  authorization, turn ownership, version/turn progression and document
  shape on every write, with the matchmaking queue covered as well; the
  security model — including the demonstrated limit of Firestore-only
  enforcement (the rules accept a pawn teleport and a board-sealing wall:
  they check authorization and structure, not game legality) — is
  documented in [`security_model.md`](security_model.md) and proven by 33
  emulator tests in [`tool/rules_tests/`](tool/rules_tests/). A waiting
  player now sees an opponent-disconnect notice after 120 seconds and can
  claim the match as abandoned; a player can hold only one open room at a
  time. Rematch was deferred to Phase 11 by recorded decision (Q-9.2) and
  shipped there (below).
- **Phase 11 — Full UI/UX.** Every product screen now exists and is
  reachable without dead ends: Splash, Home, Game Modes, a dedicated AI
  difficulty screen (Q-5.2), the online lobby (Create / Join / Quick
  Match), the shared Result screen, a five-step Tutorial played on the
  real board and engine, Profile (the device's recorded statistics —
  online matches are not recorded and the screen says so), and Settings.
  Settings is honest about what exists: gameplay options (confirm wall
  placement, the new movement-assistance route display) are real and
  persisted; the Audio/Haptics groups were built visibly inert, to be
  made real in Phase 12 (below), and the Accessibility group in
  Phase 13. The online rematch
  (Q-9.2) is a new room with fresh seats and explicit consent from both
  players, built on the shipped matchmaking claim; a rules-emulator test
  proves the claim shape for this use (34 rules tests in total). The
  developer board-preview screen that used to be the app's entry point
  is retired.
- **Phase 12 — Audio, Haptics and Animation.** The game now feeds back
  without distracting from strategy. A single feedback layer
  ([`lib/core/feedback/`](lib/core/feedback)) owns every sound cue
  (move, wall placement, invalid action, turn change, victory, button
  press), the background music loop, and the haptics, all triggered from
  the game controllers at the moment an action resolves — in online
  play, when the verified snapshot adopts it, so nothing ever cues
  twice. Animations follow `design.md` §24's timing bands: pawns slide
  with a landing bounce, walls scale and fade into place, the goal
  strips pulse only on proximity and victory, and screens transition in
  240 ms. The Settings Audio (Music / Sound effects / Volume), Haptics
  and Reduced motion controls are live; Reduced motion — from the
  device's own setting or the in-app toggle — resolves every animation
  to its end state instantly, while Color assistance, High contrast and
  UI scale remain honestly inert until Phase 13. All audio assets are
  synthesized in-project and CC0-licensed; see
  [`memory.md`](memory.md) §13t for the full record, including the
  Reduced Motion correction and the performance profile.
- **Phase 13 — Accessibility.** The game no longer relies on colour
  alone anywhere: pawns carry their B/R letters, and every player
  mention in the UI is text as well as colour (proven by automated
  identity tests). Color assistance swaps the player colours to the
  Okabe–Ito colour-blind-safe pair (verified by colour-vision
  simulation); High contrast applies a token set whose text pairs
  are computed to meet WCAG AA (main text 21:1); UI scale (100–150%)
  enlarges the whole app through Flutter's `TextScaler` and is
  layout-verified at the largest factor. All three are real,
  persisted Settings controls, as is Reduced motion from Phase 12.
  Every screen has screen-reader semantics (headers, live regions),
  non-board screens are fully keyboard-operable with a visible focus
  indicator, and error messages are plain-language, icon-plus-text,
  and announced. See [`memory.md`](memory.md) §13v for the full
  record, including the contrast measurements and the keyboard
  scope decision.
- **Phase 14 — Responsive Web.** The web version adapts through one
  centralized breakpoint definition (`AppBreakpoints`): phone,
  tablet and desktop tiers replace the old binary 768px split.
  Tablets get a genuine hybrid layout — the game screens keep a
  single, centered column under a width cap so the board grows
  without inheriting desktop's side rails — and every other screen
  uses its wide space deliberately (card grids, two-column Settings
  and Lobby entry, a side-by-side Tutorial) instead of stretching a
  phone column. Landscape phones borrow the side-panel layout with
  compact rails. Mouse players get hover ghost previews on the
  board, verified alongside touch; resizing never recomputes game
  state. Every screen is render-tested at five viewport sizes, and
  Phase 13's UI scale is tested composed with every tier. See
  [`memory.md`](memory.md) §13w for the full record, including the
  per-screen tablet decisions and the landscape bug the tests
  caught (board size floors overflowing short slots).

**Firebase still needs owner-side setup in the Console for Android/iOS.**
The web app is registered and live-verified (above). Android and iOS
client configuration is still absent: this repository ships no Firebase
client configuration on purpose — `.gitignore` excludes
`google-services.json`, `GoogleService-Info.plist` and
`firebase_options.dart` and says never to merge exceptions for them.
Until those files are added locally, the app logs `Firebase unavailable`
at startup on those platforms and runs on local storage. The exact manual
steps — registering the apps and running `flutterfire configure` for
project `wallforge-efdb3` — are in [`memory.md`](memory.md) §13o.

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
| [`security_model.md`](security_model.md) | Online security model: what the Firestore rules enforce, the demonstrated limits, and the deliberate exceptions (Phase 10) |
| [`firestore.rules`](firestore.rules) | Firestore Security Rules — the online authorization boundary (Phase 10) |

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

## Running with online play from a clean `git clone`

Local play (pass-and-play and vs AI) works from a fresh clone with no
setup. Online play needs Firebase client configuration, which this
repository deliberately does **not** commit (see `.gitignore` and
`rules.md` §14). How the options reach the app depends on the
platform:

- **Android / iOS** — the Firebase SDK reads the platform config file
  at startup. Place your project's `google-services.json` in
  `android/app/` (or `GoogleService-Info.plist` in `ios/Runner/`).
  Both paths are git-ignored; never commit them.
- **Web** — there is no config file. Pass the project's web config as
  build-time defines (values are in the Firebase console under
  Project settings → Your apps → Web app):

  ```bash
  flutter run -d chrome \
    --dart-define=FIREBASE_API_KEY=<apiKey> \
    --dart-define=FIREBASE_APP_ID=<appId> \
    --dart-define=FIREBASE_PROJECT_ID=<projectId> \
    --dart-define=FIREBASE_MESSAGING_SENDER_ID=<messagingSenderId> \
    --dart-define=FIREBASE_AUTH_DOMAIN=<authDomain> \
    --dart-define=FIREBASE_STORAGE_BUCKET=<storageBucket>
  ```

  The last two are optional. `lib/main.dart` hands these to
  `FirebaseBootstrap` via `FirebaseOptionsFromDefines`; if the
  required values are absent the app starts with Firebase
  unavailable and online play stays off — local play is unaffected.

- **Alternative (FlutterFire CLI)** — `flutterfire configure`
  generates `lib/firebase_options.dart` locally. That file is also
  git-ignored in this project; the committed `main.dart` does not
  import it, so prefer the `--dart-define` path above unless you are
  maintaining a local variant.

Deploying the security rules to a live project is separate:
`firebase deploy --only firestore:rules` from a machine signed in to
the project's Firebase account.

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
