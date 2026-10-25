// Wallforge Firestore Security Rules tests (Phase 10).
//
// Runs against the Firestore emulator via @firebase/rules-unit-testing.
// Every rule in firestore.rules gets an allow case and at least one deny
// case. Document factories mirror Room.toJson / MatchMove.toJson exactly.
//
// Run from the repository root:
//   tool/rules_tests/node_modules/.bin/firebase emulators:exec \
//     --only firestore --project demo-wallforge \
//     "node --test tool/rules_tests/test/"
// (JAVA_HOME must point at a JRE 17+ for the emulator.)

import { readFileSync } from 'node:fs';
import { test, before, beforeEach, after } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  setDoc,
  getDoc,
  getDocs,
  deleteDoc,
  collection,
  runTransaction,
} from 'firebase/firestore';

const NOW = Date.now();
const CODE = 'ABC234';
const BOARD_KEY = 's9w10';

let testEnv;
let alice; // host, Blue
let bob; // guest, Red
let carol; // third party
let anon;

// --- document factories (mirror the Dart writers) ---------------------------

function roomDoc(overrides = {}) {
  return {
    code: CODE,
    status: 'waiting',
    boardSize: 9,
    wallsPerPlayer: 10,
    hostId: 'alice',
    blue: { playerId: 'alice', ready: false },
    red: { playerId: null, ready: false },
    createdAt: NOW,
    updatedAt: NOW,
    version: 1,
    schemaVersion: 2,
    boardState: null,
    turnNumber: 0,
    currentPlayerId: null,
    winnerId: null,
    abandonedById: null,
    ...overrides,
  };
}

function boardState(overrides = {}) {
  return {
    schemaVersion: 1,
    boardConfig: { size: 9, wallsPerPlayer: 10 },
    players: ['blue', 'red'],
    currentPlayer: 'blue',
    pawnPositions: {
      blue: { row: 8, column: 4 },
      red: { row: 0, column: 4 },
    },
    walls: [],
    remainingWalls: { blue: 10, red: 10 },
    turnNumber: 0,
    status: 'inProgress',
    winner: null,
    ...overrides,
  };
}

// A started room at version 3, Blue (alice) to move, nothing played yet.
function startedRoom(overrides = {}) {
  return roomDoc({
    status: 'started',
    blue: { playerId: 'alice', ready: true },
    red: { playerId: 'bob', ready: true },
    boardState: boardState(),
    currentPlayerId: 'alice',
    version: 3,
    ...overrides,
  });
}

// The room document after Alice's first move e1->e2.
function afterFirstMove(overrides = {}) {
  return startedRoom({
    boardState: boardState({
      currentPlayer: 'red',
      pawnPositions: {
        blue: { row: 7, column: 4 },
        red: { row: 0, column: 4 },
      },
      turnNumber: 1,
    }),
    turnNumber: 1,
    currentPlayerId: 'bob',
    version: 4,
    updatedAt: NOW,
    ...overrides,
  });
}

function moveDoc(overrides = {}) {
  return {
    turnNumber: 0,
    playerId: 'alice',
    action: { type: 'move', destination: { row: 7, column: 4 } },
    notation: 'M 7,4',
    createdAt: NOW,
    resultingVersion: 4,
    ...overrides,
  };
}

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

const matchRef = (db) => doc(db, `matches/${CODE}`);
const moveRef = (db, id) => doc(db, `matches/${CODE}/moves/${id}`);

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-wallforge',
    firestore: {
      rules: readFileSync(new URL('../../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
  alice = testEnv.authenticatedContext('alice').firestore();
  bob = testEnv.authenticatedContext('bob').firestore();
  carol = testEnv.authenticatedContext('carol').firestore();
  anon = testEnv.unauthenticatedContext().firestore();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

// --- matches: creation -------------------------------------------------------

test('create: host creates a code room', async () => {
  await assertSucceeds(setDoc(matchRef(alice), roomDoc()));
});

test('create: unauthenticated is denied', async () => {
  await assertFails(setDoc(matchRef(anon), roomDoc()));
});

test('create: a stranger pre-seated as Red is denied', async () => {
  await assertFails(
    setDoc(matchRef(alice), roomDoc({ red: { playerId: 'carol', ready: false } })),
  );
});

test('create: wrong version, started status and extra fields are denied', async () => {
  await assertFails(setDoc(matchRef(alice), roomDoc({ version: 2 })));
  await assertFails(setDoc(matchRef(alice), roomDoc({ status: 'started' })));
  await assertFails(setDoc(matchRef(alice), roomDoc({ admin: true })));
});

test('create: host must be Blue, and the board must be a legal config', async () => {
  await assertFails(setDoc(matchRef(alice), roomDoc({ hostId: 'bob' })));
  await assertFails(setDoc(matchRef(alice), roomDoc({ boardSize: 8 })));
  await assertFails(setDoc(matchRef(alice), roomDoc({ wallsPerPlayer: -1 })));
});

// --- matches: reads ----------------------------------------------------------

test('read: a non-member may get one room (join capability), never list', async () => {
  await seed(`matches/${CODE}`, roomDoc());
  await assertSucceeds(getDoc(matchRef(carol)));
  await assertFails(getDocs(collection(carol, 'matches')));
  await assertFails(getDoc(matchRef(anon)));
});

// --- matches: pre-start updates ----------------------------------------------

test('join: a guest fills the empty seat', async () => {
  await seed(`matches/${CODE}`, roomDoc());
  await assertSucceeds(
    setDoc(matchRef(bob), roomDoc({
      red: { playerId: 'bob', ready: false },
      version: 2,
      updatedAt: NOW,
    })),
  );
});

test('join: taking the host seat or readying on arrival is denied', async () => {
  await seed(`matches/${CODE}`, roomDoc());
  await assertFails(
    setDoc(matchRef(bob), roomDoc({
      blue: { playerId: 'bob', ready: false },
      version: 2,
    })),
  );
  await assertFails(
    setDoc(matchRef(bob), roomDoc({
      red: { playerId: 'bob', ready: true },
      version: 2,
    })),
  );
});

test('ready: a member toggles only their own seat, version advancing by one', async () => {
  await seed(`matches/${CODE}`, roomDoc({
    red: { playerId: 'bob', ready: false },
    version: 2,
  }));
  await assertSucceeds(
    setDoc(matchRef(alice), roomDoc({
      red: { playerId: 'bob', ready: false },
      blue: { playerId: 'alice', ready: true },
      version: 3,
    })),
  );
  // The opponent's ready flag is not yours to change.
  await assertFails(
    setDoc(matchRef(alice), roomDoc({
      red: { playerId: 'bob', ready: true },
      blue: { playerId: 'alice', ready: true },
      version: 3,
    })),
  );
  // Version may not skip, stall (with changes), or rewind.
  await assertFails(
    setDoc(matchRef(alice), roomDoc({
      red: { playerId: 'bob', ready: false },
      blue: { playerId: 'alice', ready: true },
      version: 4,
    })),
  );
  // A non-member cannot touch a seat at all.
  await assertFails(
    setDoc(matchRef(carol), roomDoc({
      red: { playerId: 'bob', ready: false },
      version: 3,
    })),
  );
});

test('ready: status must be the status the seats derive', async () => {
  await seed(`matches/${CODE}`, roomDoc({
    red: { playerId: 'bob', ready: false },
    version: 2,
  }));
  // Claiming "ready" while Red has not readied is a forged lifecycle state.
  await assertFails(
    setDoc(matchRef(alice), roomDoc({
      red: { playerId: 'bob', ready: false },
      blue: { playerId: 'alice', ready: true },
      status: 'ready',
      version: 3,
    })),
  );
});

test('update: identity fields are immutable', async () => {
  await seed(`matches/${CODE}`, roomDoc({
    red: { playerId: 'bob', ready: false },
    version: 2,
  }));
  await assertFails(
    setDoc(matchRef(alice), roomDoc({
      red: { playerId: 'bob', ready: false },
      hostId: 'bob',
      version: 3,
    })),
  );
  await assertFails(
    setDoc(matchRef(alice), roomDoc({
      red: { playerId: 'carol', ready: false },
      version: 3,
    })),
  );
});

test('update: an identical rewrite by a member is allowed (idempotent)', async () => {
  const seeded = roomDoc({ red: { playerId: 'bob', ready: false }, version: 2 });
  await seed(`matches/${CODE}`, seeded);
  await assertSucceeds(setDoc(matchRef(bob), seeded));
});

// --- matches: start ------------------------------------------------------------

const readyRoom = () => roomDoc({
  blue: { playerId: 'alice', ready: true },
  red: { playerId: 'bob', ready: true },
  status: 'ready',
  version: 5,
});

test('start: the host starts a ready room with the true initial state', async () => {
  await seed(`matches/${CODE}`, readyRoom());
  await assertSucceeds(
    setDoc(matchRef(alice), startedRoom({ version: 6 })),
  );
});

test('start: a non-host, an unready room, or a forged initial state is denied', async () => {
  await seed(`matches/${CODE}`, readyRoom());
  await assertFails(setDoc(matchRef(bob), startedRoom({ version: 6 })));
  // Blue's pawn already advanced: not GameState.initial.
  await assertFails(
    setDoc(matchRef(alice), startedRoom({
      version: 6,
      boardState: boardState({
        pawnPositions: {
          blue: { row: 7, column: 4 },
          red: { row: 0, column: 4 },
        },
      }),
    })),
  );
  await seed(`matches/${CODE}`, roomDoc({
    blue: { playerId: 'alice', ready: true },
    red: { playerId: 'bob', ready: false },
    version: 5,
  }));
  await assertFails(setDoc(matchRef(alice), startedRoom({ version: 6 })));
});

// --- matches: moves ------------------------------------------------------------

test('move: the current player advances the turn and writes the move record', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  await assertSucceeds(
    runTransaction(alice, async (txn) => {
      txn.set(matchRef(alice), afterFirstMove());
      txn.set(moveRef(alice, '000000'), moveDoc());
    }),
  );
});

test('move: the opponent cannot submit on your turn', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  await assertFails(
    runTransaction(bob, async (txn) => {
      txn.set(matchRef(bob), afterFirstMove());
      txn.set(moveRef(bob, '000000'), moveDoc({ playerId: 'bob' }));
    }),
  );
  // A third party cannot either.
  await assertFails(setDoc(matchRef(carol), afterFirstMove()));
});

test('move: skipping or rewinding turn/version is denied', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  await assertFails(
    setDoc(matchRef(alice), afterFirstMove({ turnNumber: 2, version: 5 })),
  );
  await assertFails(
    setDoc(matchRef(alice), afterFirstMove({ version: 5 })),
  );
  await assertFails(
    setDoc(matchRef(alice), afterFirstMove({ version: 3 })),
  );
});

test('move: a state whose denormalised fields disagree is denied', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  // boardState says turn 1, the document says turn 1, but the snapshot's
  // own turnNumber was left at 0: the pair no longer agrees.
  const bad = afterFirstMove();
  bad.boardState = boardState({ currentPlayer: 'red', turnNumber: 0 });
  bad.boardState.pawnPositions.blue = { row: 7, column: 4 };
  await assertFails(setDoc(matchRef(alice), bad));
  // Winner declared without the game being finished.
  await assertFails(
    setDoc(matchRef(alice), afterFirstMove({ winnerId: 'alice' })),
  );
});

test('move: a finished match accepts no further moves', async () => {
  await seed(`matches/${CODE}`, startedRoom({
    status: 'finished',
    boardState: boardState({
      currentPlayer: 'red',
      pawnPositions: {
        blue: { row: 0, column: 4 },
        red: { row: 1, column: 4 },
      },
      turnNumber: 9,
      status: 'finished',
      winner: 'blue',
    }),
    turnNumber: 9,
    currentPlayerId: null,
    winnerId: 'alice',
    version: 12,
  }));
  await assertFails(setDoc(matchRef(bob), afterFirstMove({ version: 13 })));
  await assertFails(setDoc(moveRef(bob, '000009'), moveDoc({
    turnNumber: 9,
    playerId: 'bob',
    resultingVersion: 13,
  })));
});

// --- moves subcollection -------------------------------------------------------

test('move record: shape, turn and version are enforced', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  await assertFails(setDoc(moveRef(alice, '000001'), moveDoc())); // id != turn
  await assertFails(setDoc(moveRef(alice, '000000'), moveDoc({ resultingVersion: 9 })));
  await assertFails(setDoc(moveRef(alice, '000000'), moveDoc({ playerId: 'bob' })));
  await assertFails(
    setDoc(moveRef(alice, '000000'), moveDoc({
      action: { type: 'wall', orientation: 'X', anchor: { row: 1, column: 1 } },
    })),
  );
});

test('move record: immutable except the identical retry by its own player', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  await seed(`matches/${CODE}/moves/000000`, moveDoc());
  // Identical re-presentation (Phase 9's lost-acknowledgement retry).
  await assertSucceeds(setDoc(moveRef(alice, '000000'), moveDoc()));
  // Different content for the same turn.
  await assertFails(
    setDoc(moveRef(alice, '000000'), moveDoc({ notation: 'M 7,3' })),
  );
  // The opponent cannot rewrite it even identically; nobody can delete it.
  await assertFails(setDoc(moveRef(bob, '000000'), moveDoc()));
  await assertFails(deleteDoc(moveRef(alice, '000000')));
});

test('move record: only the two players may read the log', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  await seed(`matches/${CODE}/moves/000000`, moveDoc());
  await assertSucceeds(getDoc(moveRef(bob, '000000')));
  await assertFails(getDoc(moveRef(carol, '000000')));
  await assertFails(getDocs(collection(carol, `matches/${CODE}/moves`)));
});

// --- the demonstrated limitation (security_model.md) ---------------------------

test('LIMIT: rules accept a structurally valid but game-illegal state', async () => {
  await seed(`matches/${CODE}`, startedRoom());
  // Blue's pawn teleports from (8,4) to (5,4): not an adjacent cell, so
  // GameEngine would refuse it — but every check rules *can* express
  // (membership, turn ownership, +1 turn, +1 version, shape, parity,
  // cross-field agreement) passes. This passing write is the empirical
  // proof that rules are not a game-rules engine.
  const teleported = afterFirstMove({
    boardState: boardState({
      currentPlayer: 'red',
      pawnPositions: {
        blue: { row: 5, column: 4 },
        red: { row: 0, column: 4 },
      },
      turnNumber: 1,
    }),
  });
  await assertSucceeds(setDoc(matchRef(alice), teleported));

  // And a wall that seals Red's only route (a full barrier on row 4):
  // path preservation is a pathfinding question rules cannot ask.
  await seed(`matches/${CODE}`, startedRoom());
  const sealing = afterFirstMove({
    boardState: boardState({
      currentPlayer: 'red',
      turnNumber: 1,
      walls: [0, 2, 4, 6, 7].map((column) => ({
        owner: 'blue',
        orientation: 'H',
        anchor: { row: 4, column },
      })),
      remainingWalls: { blue: 5, red: 10 },
    }),
  });
  await assertSucceeds(setDoc(matchRef(alice), sealing));
});

// --- abandonment claim ---------------------------------------------------------

const staleStartedRoom = (overrides = {}) => startedRoom({
  boardState: boardState({
    currentPlayer: 'red',
    pawnPositions: {
      blue: { row: 7, column: 4 },
      red: { row: 0, column: 4 },
    },
    turnNumber: 1,
  }),
  turnNumber: 1,
  currentPlayerId: 'bob',
  updatedAt: NOW - 121000,
  version: 4,
  ...overrides,
});

test('claim: the waiting player ends a stalled match', async () => {
  await seed(`matches/${CODE}`, staleStartedRoom());
  await assertSucceeds(
    setDoc(matchRef(alice), staleStartedRoom({
      status: 'abandoned',
      abandonedById: 'alice',
      updatedAt: NOW,
      version: 5,
    })),
  );
});

test('claim: too early, on your own turn, or as a stranger is denied', async () => {
  // Too early: the document advanced seconds ago.
  await seed(`matches/${CODE}`, staleStartedRoom({ updatedAt: NOW }));
  await assertFails(
    setDoc(matchRef(alice), staleStartedRoom({
      status: 'abandoned',
      abandonedById: 'alice',
      updatedAt: NOW,
      version: 5,
    })),
  );
  // Bob cannot claim: it is Bob's own turn.
  await seed(`matches/${CODE}`, staleStartedRoom());
  await assertFails(
    setDoc(matchRef(bob), staleStartedRoom({
      status: 'abandoned',
      abandonedById: 'bob',
      updatedAt: NOW,
      version: 5,
    })),
  );
  // Carol is not in the match.
  await assertFails(
    setDoc(matchRef(carol), staleStartedRoom({
      status: 'abandoned',
      abandonedById: 'carol',
      updatedAt: NOW,
      version: 5,
    })),
  );
  // A claim may not move the board or name a winner while it lands.
  await assertFails(
    setDoc(matchRef(alice), staleStartedRoom({
      status: 'abandoned',
      abandonedById: 'alice',
      winnerId: 'alice',
      updatedAt: NOW,
      version: 5,
    })),
  );
});

// --- deletion ------------------------------------------------------------------

test('delete: only the host, and only before the match starts', async () => {
  await seed(`matches/${CODE}`, roomDoc());
  await assertFails(deleteDoc(matchRef(bob)));
  await assertSucceeds(deleteDoc(matchRef(alice)));
  await seed(`matches/${CODE}`, startedRoom());
  await assertFails(deleteDoc(matchRef(alice)));
});

// --- matchmaking -----------------------------------------------------------------

const waitingRef = (db, uid) => doc(db, `matchmaking/${BOARD_KEY}/waiting/${uid}`);
const matchedRef = (db, uid) => doc(db, `matchmaking/${BOARD_KEY}/matched/${uid}`);

test('queue: you own your entry; the queue is listable by design', async () => {
  await assertSucceeds(setDoc(waitingRef(alice, 'alice'), { uid: 'alice', queuedAt: NOW }));
  await assertFails(setDoc(waitingRef(bob, 'alice'), { uid: 'alice', queuedAt: NOW }));
  await assertFails(setDoc(waitingRef(alice, 'alice'), { uid: 'alice', queuedAt: NOW, extra: 1 }));
  await assertSucceeds(getDocs(collection(bob, `matchmaking/${BOARD_KEY}/waiting`)));
  await assertSucceeds(deleteDoc(waitingRef(alice, 'alice')));
});

test('queue: a fresh entry cannot be deleted by another player', async () => {
  await seed(`matchmaking/${BOARD_KEY}/waiting/alice`, { uid: 'alice', queuedAt: NOW });
  await assertFails(deleteDoc(waitingRef(bob, 'alice')));
});

test('queue: a stale or malformed entry may be reaped by anyone signed in', async () => {
  await seed(`matchmaking/${BOARD_KEY}/waiting/alice`, { uid: 'alice', queuedAt: NOW - 61000 });
  await assertSucceeds(deleteDoc(waitingRef(bob, 'alice')));
  await seed(`matchmaking/${BOARD_KEY}/waiting/alice`, { queuedAt: 'not-a-time' });
  await assertSucceeds(deleteDoc(waitingRef(bob, 'alice')));
});

test('quick match: the claim transaction writes room, matched pair, consumes queue', async () => {
  await seed(`matchmaking/${BOARD_KEY}/waiting/alice`, { uid: 'alice', queuedAt: NOW });
  const payload = roomDoc({
    code: 'QCK123',
    red: { playerId: 'bob', ready: false },
  });
  await assertSucceeds(
    runTransaction(bob, async (txn) => {
      txn.delete(waitingRef(bob, 'alice'));
      txn.set(doc(bob, 'matches/QCK123'), payload);
      txn.set(matchedRef(bob, 'alice'), payload);
      txn.set(matchedRef(bob, 'bob'), payload);
    }),
  );
});

test('quick match: a matched document without its room is denied', async () => {
  const payload = roomDoc({
    code: 'QCK123',
    red: { playerId: 'bob', ready: false },
  });
  await assertFails(setDoc(matchedRef(bob, 'alice'), payload));
  // And a matched document is never deletable by a client.
  await seed(`matchmaking/${BOARD_KEY}/matched/alice`, payload);
  await assertFails(deleteDoc(matchedRef(alice, 'alice')));
  await assertFails(getDocs(collection(alice, `matchmaking/${BOARD_KEY}/matched`)));
});

// --- per-player documents --------------------------------------------------------

test('playerRooms: the open-room pointer is owner-only and shape-checked', async () => {
  const ref = (db, uid) => doc(db, `playerRooms/${uid}`);
  await assertSucceeds(setDoc(ref(alice, 'alice'), { openRoomCode: CODE, updatedAt: NOW }));
  await assertSucceeds(setDoc(ref(alice, 'alice'), { openRoomCode: null, updatedAt: NOW }));
  await assertFails(setDoc(ref(bob, 'alice'), { openRoomCode: CODE, updatedAt: NOW }));
  await assertFails(getDoc(ref(bob, 'alice')));
  await assertFails(setDoc(ref(alice, 'alice'), { openRoomCode: CODE, updatedAt: NOW, rooms: [] }));
});

test('users: private documents belong to their owner only', async () => {
  // The Dart storage port names the settings document `users/{uid}/settings`
  // (Phase 7). Firestore document paths need an even segment count, so the
  // addressable form of that document is a document inside the `settings`
  // subcollection — the rule guards the whole `users/{uid}` subtree, so the
  // authorization property is the same either way. (The port's 3-segment
  // path is a Phase 7 latent issue recorded in memory.md's Phase 10 entry;
  // the real cloud client would reject it as a document path.)
  const settings = (db, uid) => doc(db, `users/${uid}/settings/current`);
  await assertSucceeds(setDoc(settings(alice, 'alice'), { schemaVersion: 1 }));
  await assertFails(setDoc(settings(bob, 'alice'), { schemaVersion: 1 }));
  await assertFails(getDoc(settings(bob, 'alice')));
});
