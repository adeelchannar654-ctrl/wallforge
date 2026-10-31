# Owner steps & tests — Phase 16.6 (Accounts and Sign-in)

Everything in this file needs either your Firebase Console, a
real device, or a machine where the Firestore emulator can
boot (Java networking is blocked in the build VM, so the rules
suite and native Google sign-in are **written, not verified**
there). Work top to bottom: the Console setup comes first
because the manual tests depend on it.

Build with the feature on (it already is by default in debug;
release needs the define):

```sh
flutter run --dart-define=FEATURE_ACCOUNTS=true
flutter build apk --release --dart-define=FEATURE_ACCOUNTS=true
```

## 1. Firebase Console — enable the providers (5 minutes)

Project `wallforge-efdb3` → **Authentication → Sign-in method**:

1. Enable **Anonymous** (should already be on — guest mode).
2. Enable **Google**. Then, so Android sign-in works:
   - Project settings → your Android app → add the **SHA-1**
     and **SHA-256** fingerprints of your signing key. For the
     debug key:
     `keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore`
     (password `android`). Add the release key's fingerprints
     too when you sign a release build.
   - **Download the updated `google-services.json`** and
     replace `android/app/google-services.json` in your local
     copy (the file is git-ignored — never commit it). Without
     this step Google sign-in fails on Android with a
     configuration error.
3. Enable **Email/Password**.
4. **Authentication → Settings → Authorized domains**: make
   sure `wallforge-efdb3.firebaseapp.com` and
   `wallforge-efdb3.web.app` are listed (they are by default)
   — the web sign-in popup needs them; add your custom domain
   if you ever ship one.
5. **Authentication → Templates**: the verification and
   password-reset emails work out of the box; customise the
   sender name/text if you want them to read as Wallforge.

## 2. Firebase Console — abuse & privacy settings

Authentication → Settings:

1. **Enable "Email enumeration protection"** (under "User
   actions" / advanced, depending on console version). The app
   already answers every bad credential with one neutral
   message; this closes the server side of the same leak.
2. Review the **sign-up quota** (default 100 new accounts per
   hour per IP) — the default is fine.
3. (Optional but recommended) Set the **OAuth consent screen**
   (Google Cloud Console → APIs & Services → OAuth consent
   screen) to your app name so the Google sign-in sheet says
   "Wallforge", and set the support email to yours.

## 3. Deploy the rules and run the rules suite

The 16.6 rules (account-gated leaderboard writes, validated
profile document) deploy **together with** the still-pending
Phase 10/16.5 rules — one command:

```sh
firebase deploy --only firestore:rules --project wallforge-efdb3
```

Then the emulator suite (needs JDK 17+; `JAVA_HOME` set):

```sh
cd tool/rules_tests && npm install   # once
cd ../..
tool/rules_tests/node_modules/.bin/firebase emulators:exec \
  --only firestore --project demo-wallforge \
  "node --test tool/rules_tests/test/"
```

Expected: the Phase 10/16.5 suite (`rules.test.mjs`) passes
unchanged, and `rules_phase166.test.mjs` passes — including:
a guest token denied a leaderboard create with a valid
payload; Google and verified-email creates succeeding;
unverified email denied; claim-less contexts still passing;
profile shape refusals (incl. an `email` field); the wildcard
carve-out case; linking keeping ownership.

## 4. Manual device tests (Android; two devices if you can)

Sign-in state is visible in **Firebase Console →
Authentication → Users** throughout.

1. **Guest first**: fresh install → the game opens instantly
   as a guest. Play a local game and a vs-AI game: no sign-in
   is ever requested.
2. **Link Google**: Settings → Account → Continue with
   Google → pick your Google account. In the Console, the
   SAME uid row gains the Google provider (no second row).
   The Account screen shows "Signed in with Google" — and
   your Google name/photo appear **nowhere** in the app.
3. **Online as an account**: play an online match to a
   decisive finish (10+ plies) → it counts on the weekly
   leaderboard under your generated name.
4. **Reinstall**: delete the app, reinstall, open the
   leaderboard → your entry from step 3 is still there.
   Sign in with the same Google account → same uid in the
   Console; your profile (name, achievements, statistics) is
   back — match history is not (it never leaves a device; the
   UI says so).
5. **Conflict**: on a second device (or after reinstall with
   a DIFFERENT Google account linked first), sign in from
   guest with the Google account from step 2 → the conflict
   card offers "sign in to that account" or "keep this
   guest". Choose each once across two runs: switching lands
   on the step-2 identity; cancelling changes nothing.
6. **Email flow**: create an email account from guest →
   verification email arrives → verify via the link → the
   Account screen's verify card clears after "I've verified —
   refresh". Before verifying, finish an online match: it
   must NOT count (unverified email). After verifying, the
   next one counts.
7. **Password reset**: sign out → Account → sign-in mode →
   Forgot password → the reset email arrives; the on-screen
   message never confirms whether the address is registered.
   Reset, sign in with the new password.
8. **Sign out**: Settings → Account → Sign out → you land as
   a NEW guest (new uid in the Console). Your device-local
   history/achievements are still on the device; your email
   is shown nowhere.
9. **Guest leaderboard block**: as that fresh guest, finish
   an online match → it does NOT appear on the board (the
   client doesn't even spend the write; with the rules
   deployed, a forced write would also be denied — case 3
   in the rules suite proves the server side).
10. **Mid-match refusal**: start an online match, and while
    it is live try to sign in / sign out / delete from
    Settings → Account (second device or by navigating —
    where reachable) → the app refuses with "Finish or leave
    your current match first". The match itself is
    undisturbed.
11. **Delete account**: sign in (email account) → Delete
    account → re-enter the password → the account row
    disappears from the Console, the profile document
    (`users/{uid}/profile`) is gone in Firestore, and you
    land as a fresh guest. The deleted account's leaderboard
    entries REMAIN under the generated name (deliberate — see
    `privacy_notes.md`). The same email can register again.
12. **Web**: `flutter run -d chrome
    --dart-define=FEATURE_ACCOUNTS=true` → Google sign-in
    opens the Firebase popup and completes (the native
    package cannot do web sign-in; the app uses the popup
    path there by design).

## 5. What remains unverified after this file

* **Android Google sign-in end-to-end** — verified only by
  step 4 above on your device; the build VM cannot run it.
* **iOS** — not built in this phase. When iOS ships, Apple
  Guideline 4.8 requires Sign in with Apple alongside
  Google; the provider model already supports adding it
  (see `memory.md` §13ab, D16.6-1).
* **Play Console web-deletion URL** — Google Play also
  requires a web-reachable account-deletion path; publishing
  that page and entering its URL belongs to the Phase 17
  listing work (`privacy_notes.md` records the gap).
