# Privacy Notes — Wallforge Accounts (Phase 16.6)

What the accounts feature collects, where it lives, and what
deletion does and does not do. Written for the owner (store
listings and the privacy policy will draw on this) and for
anyone auditing the code. Every claim below is checkable in the
repository.

## What exists where

### Firebase Authentication (Google's servers, project `wallforge-efdb3`)

* The account itself: sign-in provider (`google.com` or
  `password`), the email address **for email accounts**, whether
  the email is verified, and the uid.
* Anonymous (guest) accounts: a uid and nothing else — no email,
  no name, no profile data.
* Passwords are held by Firebase Auth as salted hashes; the app
  never sees or stores a hash, and never stores the password
  itself anywhere.

### Firestore

* `users/{uid}/profile` — the cloud profile (Part E): the
  generated display name (e.g. "Calm Falcon 42"), its generation
  number, unlocked achievement ids with unlock times, a compact
  statistics snapshot and the ids of the matches it covers.
  Written only for real accounts, only on sign-in (merged) and
  after finished matches (debounced).
* `leaderboard/{week}/entries/{uid}` — the weekly board entry:
  the generated display name, wins/losses/points, the per-match
  id list and the opponent list the double-count guards need.
* Match and room documents — the two players' uids, the board
  position, move deadlines. Shared game state, not profiles.
* **No email address is stored in Firestore anywhere.** No
  Google profile name or photo is read or stored; the public
  identity is always the generated display name.

### The device only (SharedPreferences, never uploaded)

* Match history (the full record list — deliberately **not**
  synced; the UI says so), local statistics, achievements,
  settings, the unfinished match, display-name generations.
* A second person using the same device sees this device-local
  game data, but never the first person's email: the address
  exists only inside Firebase Auth's own session (which sign-out
  ends) and in the account controller's memory. It is excluded
  from `AuthState.toString`, never logged, and never persisted
  by app code.

### Logs

* No tokens, credentials, email addresses or passwords are
  logged anywhere in the app. The auth gateway logs only fixed
  strings ("signed in anonymously", "password reset requested").

## Account deletion (in-app, Part F)

Settings → Account → **Delete account**. The flow
re-authenticates first (password for email accounts, Google
sign-in for Google accounts), then:

1. Deletes `users/{uid}/profile`.
2. Deletes the Firebase Auth user.

**Removed:** the Auth account (sign-in is gone, the email can be
registered again), and the cloud profile.

**Not removed, deliberately:**

* Leaderboard entries. They keep counting under the generated
  display name, because removing them would corrupt the weekly
  results and reopen the double-count guards other players'
  entries rely on. An entry carries no personal data — a
  generated name and match counts.
* Match documents the account played in. The opponent's record
  of the game remains; the deleted uid becomes a dangling
  reference that names nobody.
* Device-local data. Deletion is about the account, not the
  phone; "Clear this device's progress" is a separate, explicit
  action in the same place.

If step 1 fails, deletion **aborts** — the account still exists
and the profile will re-sync from the device at the next
sign-in, rather than leaving personal data behind under an
unrecoverable uid. If step 2 fails after re-authentication
(e.g. the session expired), the account also still exists and
the player can retry.

## Store requirements (from the official sources, read 2026-10-31)

* **Apple App Store Review Guideline 5.1.1(v):** "If your app
  supports account creation, you must also offer account
  deletion within the app." — Shipped (above). Apple Guideline
  **4.8** additionally requires Sign in with Apple when a
  third-party login is offered; that is deferred with Phase 17's
  iOS decision (see `memory.md` §13ab, D16.6-1) — iOS is not
  shipped in this phase.
* **Google Play (account deletion requirements, Play Console
  Help):** apps that enable account creation must provide both
  an in-app deletion path — shipped — **and** a web link
  resource where users can request deletion, plus answering the
  Data safety section's data-deletion questions. The web path is
  an **owner action outstanding**: publish a deletion-request
  page/form and enter its URL in Play Console when the listing
  is created (Phase 17). This gap is recorded here, not hidden.

## Console settings that protect accounts (owner, Part H script)

* **Email enumeration protection** — enable in Firebase Console
  → Authentication → Settings. Without it, sign-in error
  responses can reveal whether an email is registered; the app
  already maps every credential failure to one neutral message,
  and this setting closes the server side of the same leak.
* **Sign-up quota / abuse protections** — review the per-IP
  account-creation quota (default 100/hour per IP) in the same
  place.
* Verification and password-reset emails use Firebase's default
  templates unless customised under Authentication → Templates;
  template text never contains app-collected data.
