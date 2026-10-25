# Wallforge security model

Phase 10 gave Wallforge its first server-side enforcement. Before this
phase, every write to `matches/{code}` and the matchmaking documents was
protected only by the client's own code — which `architecture.md` §12
already said must never be trusted. This document records what the
Firestore Security Rules in `firestore.rules` actually enforce, what they
provably cannot enforce, what compensates for that gap today, and the
deliberate exceptions a reader of the rules file will otherwise trip over.

Everything claimed here is backed by the emulator test suite in
`tool/rules_tests/` (33 tests, all passing against the real Firestore
emulator — see "Running the rules tests" below). Where a limit is stated,
it is demonstrated by a test, not asserted.

## Document shapes covered

| Collection | Shape (as implemented, `architecture.md` §11) |
|---|---|
| `matches/{code}` | Room + match state: seats (`blue`/`red` with `playerId`, `ready`), `status`, `boardState` (serialised `GameState` or `null` before start), `turnNumber`, `currentPlayerId`, `winnerId`, `version`, `updatedAt`, config (`boardSize`, `wallsPerPlayer`), `schemaVersion`, Phase 10's `abandonedById` |
| `matches/{code}/moves/{NNNNNN}` | One record per ply, id is the zero-padded turn number: `turnNumber`, `playerId`, `action`, `notation`, `createdAt`, `resultingVersion` |
| `matchmaking/{boardKey}/waiting/{uid}` | Queue entry: `uid`, `queuedAt` (document id is the uid) |
| `matchmaking/{boardKey}/matched/{uid}` | The full room document, written for both players by a successful quick-match claim |
| `users/{uid}/{document}` | Private per-user documents (`settings`, `statistics`, `unfinishedMatch`) |
| `playerRooms/{uid}` | Phase 10 open-room pointer: `openRoomCode` (string or `null`), `updatedAt` |

## What the rules enforce

Each item traces to `architecture.md` §12's required list (PRD §9 adds the
monotonic-progression and valid-shape requirements). Every rule has at
least one passing allow-test and one passing deny-test in the emulator
suite.

1. **Authenticated access only.** A request with no `request.auth` is
   denied on every path the rules govern. (Test: "create: unauthenticated
   is denied", and the unauthenticated cases throughout.)
2. **Membership.** A user may write a `matches/{code}` document, and may
   read or write its `moves` log, only if their uid is one of the two
   seated players. (Tests: "move record: only the two players may read the
   log", the stranger cases in "claim: … or as a stranger is denied".)
   The one read exception is documented below.
3. **Participant-only actions.** Joining fills only an empty seat, with
   the joiner's own uid, unready; a member may toggle only their own
   seat's `ready` flag or vacate their own seat; the stored `status` must
   always be the status the seats derive. (Tests: "join: a guest fills the
   empty seat", "join: taking the host seat or readying on arrival is
   denied", "ready: a member toggles only their own seat…", "ready: status
   must be the status the seats derive".)
4. **Turn ownership.** A move write may be made only by the player whose
   uid is the document's stored `currentPlayerId`. (Test: "move: the
   opponent cannot submit on your turn".)
5. **Monotonic turn/version progression.** Every shared-state write
   advances `version` by exactly one; a move advances `turnNumber` by
   exactly one. Skips, rewinds and replays with a lower value are denied.
   (Tests: "move: skipping or rewinding turn/version is denied", "ready: a
   member toggles only their own seat, version advancing by one".)
6. **Type and shape constraints.** Writes must match the implemented
   document shape: field types are checked, identity fields (`code`,
   `hostId`, both seats' `playerId`s once set, `createdAt`, config) cannot
   change, and the denormalised fields must agree with `boardState`
   (turn parity, `boardState.turnNumber`, `currentPlayerId`, `winnerId`,
   pawn distinctness, remaining-wall ranges). (Tests: "create: wrong
   version, started status and extra fields are denied", "update: identity
   fields are immutable", "move: a state whose denormalised fields
   disagree is denied".)
7. **Match start integrity.** Only the host may start, only when both
   seats are ready, and the starting `boardState` must be exactly the
   `GameState.initial` for the room's configuration — start cells, full
   wall counts, no walls placed. (Tests: "start: the host starts a ready
   room with the true initial state", "start: a non-host, an unready room,
   or a forged initial state is denied".)
8. **Finished matches are locked.** A match whose `status` is `finished`
   (or `abandoned`, see §"Timeout and abandonment") rejects further move
   writes. (Test: "move: a finished match accepts no further moves".)
9. **Move records are immutable, with one exception.** A `moves/{turn}`
   document may be created only by the player whose turn it is, only for
   the parent match's current turn, with the id equal to the turn number
   and `resultingVersion` equal to the parent's next version — and only
   while the parent match is started. It can never be deleted, and can be
   overwritten only with byte-identical content by its own player: the
   idempotent retry Phase 9's submission flow depends on. (Tests: "move
   record: shape, turn and version are enforced", "move record: immutable
   except the identical retry by its own player".)
10. **Matchmaking ownership.** A user may create or update only their own
    `waiting` entry and may delete it at any time; a fresh, well-formed
    entry belonging to someone else cannot be deleted. The quick-match
    claim is validated as one transaction: the room document and both
    `matched` documents must agree, and the queue entries are consumed.
    (Tests: "queue: you own your entry…", "queue: a fresh entry cannot be
    deleted by another player", "quick match: the claim transaction
    writes room, matched pair, consumes queue", "quick match: a matched
    document without its room is denied".)
11. **Private documents stay private.** `users/{uid}/…` and
    `playerRooms/{uid}` are readable and writable only by their owner;
    the pointer document is shape-checked. (Tests: "users: private
    documents belong to their owner only", "playerRooms: the open-room
    pointer is owner-only and shape-checked".)
12. **Room deletion is narrow.** Only the host may delete a room, and
    only before the match starts (`waiting`/`ready`). (Test: "delete:
    only the host, and only before the match starts".)

## The demonstrated limit of Firestore-only enforcement

Security Rules can check structure, identity, turn order and progression.
They cannot run the game's legality checks — above all the pathfinding
check that a wall placement leaves both players a path to their goal
(`architecture.md` §12 says this in prose; Phase 10 proved it in the
emulator).

The rules test "LIMIT: rules accept a structurally valid but
game-illegal state" submits two writes that are correctly authenticated,
correctly turn-owned, correctly versioned and shape-valid — and illegal
under the game rules:

- **A pawn teleport.** Blue's pawn moves from (8,4) to (5,4) — not an
  adjacent cell, so `GameEngine` would reject it outright. The rules
  accept the write (`assertSucceeds`).
- **A path-sealing wall.** Blue places the five horizontal walls that
  close row 4 end to end (anchors at columns 0, 2, 4, 6, 7), sealing
  Red's path to the goal row, with `remainingWalls.blue` honestly
  decremented to 5. The rules accept this write too.

Both writes are in the suite permanently, so the gap is regression-
visible: if a future rules change ever starts rejecting them, that is a
behaviour change to be noticed, not a silent improvement.

### What compensates today — and its honest caveat

Every client write passes through the client's own `GameEngine`
validation before submission, and every client validates what it receives
before adopting it. In honest play between two unmodified clients, an
illegal state is therefore caught twice.

The caveat is the one `architecture.md` §12 already states: that
validation lives in the client, and a modified or malicious client can
skip it. Rules are the only real server-side authority, and they cannot
tell a legal wall from a sealing one. What rules *do* bound is the blast
radius: a cheating client can only corrupt matches it is seated in, only
on its own turns, only one version step at a time, and it cannot rewrite
history (the move log is immutable), touch anyone else's matches, or
forge a winner into a state whose stored fields disagree. Opponents who
receive a state their own engine rejects treat it through the existing
sync-failure path rather than adopting it.

Phase 10's instruction, carried forward verbatim from `phase.md`: **if
stronger authoritative validation is required later, reassess backend
architecture and Firebase billing.** That means an authoritative backend
(Cloud Functions or equivalent), which the Spark plan does not include —
explicitly out of scope here.

## Timeout and abandonment

Phase 9 handled *your own* dropped connection. Phase 10 covers the other
side: what the waiting player sees when the opponent goes quiet.

- **Threshold.** No project document specified a duration, so Phase 10
  chose **120 seconds** of opponent inactivity as a reasoned default,
  recorded as a decision in `memory.md`. It lives in one named constant,
  `opponentInactivityThreshold` in `lib/domain/repositories/match.dart`;
  the rules encode the same 120 000 ms.
- **Detection.** While it is the opponent's turn in a started match, the
  client derives `OpponentPresence` from the document's `updatedAt`: the
  opponent is `active` inside the threshold and `stalled` past it — a
  signal deliberately separate from the Phase 9 connection-state chip,
  which describes *your* connection, not theirs. The UI shows a distinct
  notice ("Your opponent seems to have disconnected.") with a claim
  action, behind a confirmation dialog.
- **The claim.** Claiming writes a new terminal status, `abandoned`
  (Phase 10 decision: not `cancelled`, which is pre-start, and not
  `finished`, which means played to a conclusion), records the claimant
  in `abandonedById`, and leaves `winnerId` null — the engine alone
  declares winners. Rules allow the write only to a member who is *not*
  the player to move, only on a started match, and only once server time
  minus the stored `updatedAt` reaches the threshold. (Tests: "claim: the
  waiting player ends a stalled match", "claim: too early, on your own
  turn, or as a stranger is denied".)
- **The reconnect race.** The claim and a late move are both single
  Firestore transactions against the same document, so exactly one of
  them lands first and the other re-reads the result: if the opponent's
  move lands first, the claim's transaction sees a fresh `updatedAt` and
  a flipped turn and refuses (`opponentStillActive` / `notOpponentTurn`);
  if the claim lands first, the move refuses because the match is over.
  There is no interleaving in which both succeed. This is covered by
  repository tests as well as the rules tests.
- **A clock caveat, stated plainly.** `updatedAt` is written from the
  acting player's device clock; the rules measure elapsed time as server
  time (`request.time`) minus that stored value. A device clock running
  ahead therefore delays when a claim becomes legal, and one running
  behind hastens it. The threshold is an abandonment heuristic, not a
  precision timer, and both the client UX and the rule use the same
  stored value, so they agree with each other even when they disagree
  with a wall clock.

## Abuse resistance, as defined for v1

No project document defined "abuse" for this system, so Phase 10 defined
it narrowly and cheaply, in ways the Spark plan can actually enforce:

- **One open room per player (code rooms).** Creating or joining a code
  room while you already hold an open (`waiting`/`ready`) room is refused
  with `RoomFailureReason.alreadyHasOpenRoom`. Enforcement is client-side
  via the `playerRooms/{uid}` pointer, because rules cannot run queries —
  there is no way in rules to ask "does this uid already have an open
  room?". The pointer is never trusted blindly: the named room is
  re-read, and a pointer to a room that is gone, started or finished does
  not block. A modified client can bypass the limit; the consequence is
  bounded, because every room it creates still obeys the per-room
  membership and turn rules. Quick-match rooms are not pointer-guarded:
  they are bounded structurally instead — one `waiting` entry per uid per
  board configuration, one `matched` document per uid per board.
- **Queue hygiene.** A `waiting` entry older than 60 seconds, or
  malformed, may be deleted by any signed-in client (the reaping Phase
  8.1 already designed); a fresh, well-formed entry may be deleted only
  by its owner or by the claim that consumed it. (Tests: "queue: a stale
  or malformed entry may be reaped by anyone signed in", "queue: a fresh
  entry cannot be deleted by another player".)
- **Stale rooms.** A scheduled cleanup would need Cloud Functions, which
  Spark does not have — so there is no server-side reaper for pre-start
  rooms, and this document does not pretend otherwise. The client-side
  mitigations are the ones Phase 8 already built: the host leaving
  deletes the room, a guest leaving reopens it, and the one-open-room
  pointer means an abandoned room blocks its owner's next room until
  they leave it — an incentive pointed the right way.

One residual worth naming: `BoardConfig` places no upper bound on
`wallsPerPlayer` (any value ≥ 0 is legal to the engine), so the rules
mirror that and a host can create a room with an absurd wall count. That
is a configuration nuisance for the two consenting players, not an
integrity hole, and changing it would mean changing the engine — which
Phase 10 does not do.

## Deliberate exceptions a reader must know

- **Single-document reads of a room are open to any signed-in user.**
  `matches/{code}` allows `get` (never `list`) without membership, and
  `matched/{uid}` likewise. This is forced by the Spark constraint: the
  join flow must read a room before the joiner is a member, room creation
  must check for a code collision, and the quick-match claim must check
  for its pair document — and there is no Cloud Function to broker any of
  it. The practical consequence: **the room code is a capability.**
  Anyone signed in who learns a code can read that room's current state.
  They still cannot write it, read its move log, or enumerate rooms, and
  codes are not listed anywhere. Treat codes accordingly.
- **The waiting queue is listable by signed-in users.** Queue discovery
  is how Phase 8.1 matchmaking works; entries carry only a uid and a
  timestamp.
- **Legacy documents.** Rooms written before Phase 10 (schema 1) are
  read tolerantly by the rules (fields are read with defaults), and a
  schema 1 → 2 migration write is permitted.

## No indexes required

There is deliberately no `firestore.indexes.json`. No client queries the
`matches` collection (the lobby watches single documents; recovery orders
only the `moves` subcollection, a single-field ordering that needs no
composite index), and the `FirestoreClient` port has no filter parameter
by design. If a future phase adds a filtered query, that phase adds the
index and records it here.

## Running the rules tests

```sh
cd tool/rules_tests && npm install   # once
cd ../..
firebase emulators:exec --only firestore --project demo-wallforge \
  "node --test tool/rules_tests/test/rules.test.mjs"
```

The suite runs against the Firestore emulator with the repository's real
`firestore.rules` and needs a Java runtime for the emulator. Recorded
result for Phase 10: **33 tests, 33 passed, 0 failed.**

Two environment notes from the Phase 10 verification environment (a
sandboxed Linux VM), recorded because both cost real debugging time and
neither is a property of the rules:

- The emulator JVM's internal loopback channels fail when the JVM prefers
  IPv6 (`http2 exception` on every API call, rules upload included). Run
  with `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true` in such an
  environment.
- That sandbox's emulator build evaluated rule paths as absolute paths,
  which is one reason `firestore.rules` uses the canonical full form
  (`match /databases/{database}/documents { … }`, the `firebase init`
  template structure) instead of the shorthand: the composed paths are
  identical in production, and the intent is explicit either way.
