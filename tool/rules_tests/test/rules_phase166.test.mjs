// Wallforge Firestore Security Rules tests — Phase 16.6 (accounts).
//
// Covers what 16.6 changes in firestore.rules:
//   * leaderboard writes require a real account (D16.6-10): an
//     anonymous (guest) token is denied even with a perfectly
//     valid payload; Google and verified-email tokens pass;
//     unverified email is denied; the claim-less contexts the
//     Phase 10/16.5 suites use still pass (deny-only-anonymous).
//   * the cloud profile document (users/{uid}/profile): owner
//     only, shape-validated, and the Phase 6/7 users wildcard no
//     longer grants it (the carve-out is itself tested: an
//     invalid profile write must fail, which it could not if
//     the wildcard still allowed it).
//   * linking does not change ownership: the same uid keeps its
//     documents across a provider change (anonymous -> google).
//
// WRITTEN, NOT RUN in the build VM (the Firestore emulator
// cannot boot there — Java networking is blocked; see
// owner_tests_16_6.md). Run from the repository root, together
// with the existing suite:
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
  deleteDoc,
  Timestamp,
} from 'firebase/firestore';

const NOW = Date.now();
const CODE = 'ABC234';

let testEnv;
let claimless; // alice with no provider claims (the 16.5 suites' shape)
let guestAlice; // alice, anonymous provider
let googleAlice; // alice, google.com provider
let verifiedAlice; // alice, password provider, verified email
let unverifiedAlice; // alice, password provider, unverified email
let googleBob; // bob, google.com provider (a stranger to alice's docs)

// --- document factories (mirroring the Dart writers, as in rules.test.mjs) ---

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
    finishReason: null,
    timeControlSeconds: 0,
    turnDeadline: null,
    rematchOf: null,
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

function currentWeekStartMs() {
  const dayMs = 86400000;
  const weekMs = 604800000;
  const mondayResidue = 345600000;
  const nowMs = Date.now();
  const dayStart = nowMs - (nowMs % dayMs);
  const residue = dayStart % weekMs;
  const sinceMonday = residue >= mondayResidue
    ? residue - mondayResidue
    : residue + (weekMs - mondayResidue);
  return dayStart - sinceMonday;
}

const WEEK = currentWeekStartMs();
const entryRef = (db, uid, week = WEEK) =>
  doc(db, `leaderboards/${week}/entries/${uid}`);
const profileRef = (db, uid) => doc(db, `users/${uid}/profile`);

// A finished match: alice (Blue) beat bob in 14 plies, server
// stamped inside the current week (the 16.5 fixture).
function finishedMatchDoc(overrides = {}) {
  return roomDoc({
    code: 'FIN123',
    status: 'finished',
    blue: { playerId: 'alice', ready: true },
    red: { playerId: 'bob', ready: true },
    boardState: boardState({ turnNumber: 14, status: 'finished', winner: 'blue' }),
    turnNumber: 14,
    currentPlayerId: null,
    winnerId: 'alice',
    finishReason: 'goal',
    version: 20,
    serverUpdatedAt: Timestamp.fromMillis(Date.now()),
    ...overrides,
  });
}

// Alice's entry after counting FIN123 (her win).
function entryDoc(overrides = {}) {
  return {
    uid: 'alice',
    displayName: 'Swift Falcon 42',
    points: 3,
    wins: 1,
    losses: 0,
    countedMatches: { FIN123: 'bob' },
    opponentCounts: { bob: 1 },
    weekStartMs: WEEK,
    lastCountedMatch: 'FIN123',
    ...overrides,
  };
}

// The cloud profile, exactly as CloudProfile.toJson writes it.
function profileDoc(overrides = {}) {
  return {
    schemaVersion: 1,
    displayName: 'Swift Falcon 42',
    nameGeneration: 0,
    achievements: { 'first-steps': NOW },
    statistics: {
      matchesPlayed: 3,
      humanWins: 2,
      humanLosses: 1,
      byBoardSize: {},
      byDifficulty: {},
    },
    statisticsRecordIds: ['m1', 'm2', 'm3'],
    updatedAtMs: NOW,
    ...overrides,
  };
}

async function seed(path, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-wallforge',
    firestore: {
      rules: readFileSync(new URL('../../../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
  claimless = testEnv.authenticatedContext('alice').firestore();
  guestAlice = testEnv.authenticatedContext('alice', {
    firebase: { sign_in_provider: 'anonymous' },
  }).firestore();
  googleAlice = testEnv.authenticatedContext('alice', {
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
  verifiedAlice = testEnv.authenticatedContext('alice', {
    firebase: { sign_in_provider: 'password' },
    email_verified: true,
  }).firestore();
  unverifiedAlice = testEnv.authenticatedContext('alice', {
    firebase: { sign_in_provider: 'password' },
    email_verified: false,
  }).firestore();
  googleBob = testEnv.authenticatedContext('bob', {
    firebase: { sign_in_provider: 'google.com' },
  }).firestore();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

// --- leaderboard: the account gate (D16.6-10) --------------------------------

test('leaderboard: a guest (anonymous) cannot write, even with a valid payload', async () => {
  await seed('matches/FIN123', finishedMatchDoc());
  await assertFails(setDoc(entryRef(guestAlice, 'alice'), entryDoc()));
});

test('leaderboard: Google and verified-email accounts can write', async () => {
  await seed('matches/FIN123', finishedMatchDoc());
  await assertSucceeds(setDoc(entryRef(googleAlice, 'alice'), entryDoc()));
  await testEnv.clearFirestore();
  await seed('matches/FIN123', finishedMatchDoc());
  await assertSucceeds(setDoc(entryRef(verifiedAlice, 'alice'), entryDoc()));
});

test('leaderboard: an unverified email account cannot write', async () => {
  await seed('matches/FIN123', finishedMatchDoc());
  await assertFails(setDoc(entryRef(unverifiedAlice, 'alice'), entryDoc()));
});

test('leaderboard: claim-less contexts (the older suites) still pass the gate', async () => {
  await seed('matches/FIN123', finishedMatchDoc());
  await assertSucceeds(setDoc(entryRef(claimless, 'alice'), entryDoc()));
});

test('leaderboard: a guest cannot rename an existing entry either', async () => {
  await seed(`leaderboards/${WEEK}/entries/alice`, entryDoc());
  const renamed = entryDoc({ displayName: 'Iron Raven 07' });
  await assertFails(setDoc(entryRef(guestAlice, 'alice'), renamed));
  await assertSucceeds(setDoc(entryRef(googleAlice, 'alice'), renamed));
});

test('leaderboard: guests may still read the board', async () => {
  await seed(`leaderboards/${WEEK}/entries/alice`, entryDoc());
  await assertSucceeds(getDoc(entryRef(guestAlice, 'alice')));
});

// --- the cloud profile ---------------------------------------------------------

test('profile: the owner writes and reads a valid profile', async () => {
  await assertSucceeds(setDoc(profileRef(googleAlice, 'alice'), profileDoc()));
  await assertSucceeds(getDoc(profileRef(googleAlice, 'alice')));
  // Update (the post-match sync) and delete (account deletion).
  await assertSucceeds(
    setDoc(profileRef(googleAlice, 'alice'),
      profileDoc({ statistics: { ...profileDoc().statistics, matchesPlayed: 4 } })),
  );
  await assertSucceeds(deleteDoc(profileRef(googleAlice, 'alice')));
});

test('profile: a stranger can neither read nor write nor delete it', async () => {
  await seed('users/alice/profile', profileDoc());
  await assertFails(getDoc(profileRef(googleBob, 'alice')));
  await assertFails(setDoc(profileRef(googleBob, 'alice'), profileDoc()));
  await assertFails(deleteDoc(profileRef(googleBob, 'alice')));
});

test('profile: malformed or oversized documents are refused', async () => {
  const ref = (db) => profileRef(db, 'alice');
  // An email field — the document must never carry one.
  await assertFails(setDoc(ref(googleAlice), profileDoc({ email: 'a@b.c' })));
  // A real-looking name is not the generated pattern (no digits).
  await assertFails(
    setDoc(ref(googleAlice), profileDoc({ displayName: 'Alice Smith' })));
  // A newer schema this build must not bless.
  await assertFails(
    setDoc(ref(googleAlice), profileDoc({ schemaVersion: 2 })));
  // Over the client's own caps.
  const manyAchievements = {};
  for (let i = 0; i < 65; i++) manyAchievements[`a${i}`] = NOW;
  await assertFails(
    setDoc(ref(googleAlice), profileDoc({ achievements: manyAchievements })));
  const manyIds = Array.from({ length: 101 }, (_, i) => `m${i}`);
  await assertFails(
    setDoc(ref(googleAlice), profileDoc({ statisticsRecordIds: manyIds })));
  // A write stamped far in the future.
  await assertFails(
    setDoc(ref(googleAlice), profileDoc({ updatedAtMs: NOW + 3600000 })));
  // Negative counters.
  await assertFails(setDoc(ref(googleAlice), profileDoc({
    statistics: { ...profileDoc().statistics, matchesPlayed: -1 },
  })));
});

test('profile: the users wildcard no longer grants the profile document', async () => {
  // If the Phase 6/7 wildcard still covered `profile`, this
  // unvalidated write would be allowed by it; the carve-out
  // means only the validated match governs the document.
  await assertFails(
    setDoc(profileRef(googleAlice, 'alice'), profileDoc({ schemaVersion: 7 })));
  // Nested settings keep their owner-only behaviour (the
  // existing suite's case, unchanged).
  const settings = (db, uid) => doc(db, `users/${uid}/settings/current`);
  await assertSucceeds(setDoc(settings(googleAlice, 'alice'), { schemaVersion: 1 }));
  await assertFails(setDoc(settings(googleBob, 'alice'), { schemaVersion: 1 }));
  await assertFails(getDoc(settings(googleBob, 'alice')));
});

test('profile: linking keeps ownership — same uid, new provider', async () => {
  // Written while the uid was a guest…
  await assertSucceeds(setDoc(profileRef(guestAlice, 'alice'), profileDoc()));
  // …still alice's after the credential is linked (Google),
  // because linking preserves the uid.
  await assertSucceeds(getDoc(profileRef(googleAlice, 'alice')));
  await assertSucceeds(
    setDoc(profileRef(googleAlice, 'alice'), profileDoc({ nameGeneration: 1 })));
  // And still nobody else's.
  await assertFails(getDoc(profileRef(googleBob, 'alice')));
});
