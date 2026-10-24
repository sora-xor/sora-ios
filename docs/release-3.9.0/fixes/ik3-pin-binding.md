# Per-wallet PIN ownership — integration in progress

Resumed from the interrupted safety audit on 12 October 2026. This is not a
release verdict. The active changes are on `codex/upgrade-safety-20261012`.

## Implementation

- A wallet's `<address>-ownerPin` is a versioned salted scrypt verifier (random
  16-byte salt, N=32768, r=8, p=1, 32-byte output). It uses the production
  `kSecClassKey` / `WhenUnlockedThisDeviceOnly` Keychain implementation.
- Neither `pincode` nor `earlierInstallPin-*` grants ownership of retained
  wallets. Old copies are untouched and no new copies are created. A wallet
  left by 3.8.6 without a binding needs its phrase or encrypted Drive backup.
- Restore and recovery phrase reveal return only the wallets whose own binding
  matches the entered PIN. Their per-wallet Keychain counters reserve an
  attempt before verification. One wallet's success never clears another's
  failures. Waits use uptime and boot identity; changing wall time cannot
  shorten a wait, and a new boot restarts the current wait step.
- First onboarding marks PIN setup pending before the first account insert.
  The existing launch/foreground gates stay in force. Setup reports success
  only after the app PIN and bindings read back successfully.
- Manual app PIN entry can reconcile proven accounts actually present as rows
  after a 3.8.6 downgrade changed the app PIN. Startup and biometrics do not
  create bindings from a stored PIN. New/imported material supplies its own
  ownership proof; retained discovery does not acquire that import grant.
- Both PIN writers use a durable Keychain rotation journal. Its exact affected
  wallet set and the new app PIN complete before another authentication,
  including biometric authentication. Failed saves do not report success.
- Restoring into an existing installation asks for its current PIN and clearly
  says the restored wallets will use that PIN. A per-wallet rebind intent is
  written before insertion and settled from committed account rows. No row
  leaves the old binding intact; a committed row gets the new binding before
  authentication can proceed.
- Explicit removal revokes the binding/counter even if unverified signing
  bytes must be kept. Import can establish a fresh binding from supplied proof.

## Evidence so far

`audit-2026-10-12/ios/owner-pin-second.log` records passing tests for interrupted
rotation at each write, per-wallet lockout across reinstall/clock changes,
separate owners, manual-only downgrade reconciliation, mixed-PIN restore,
and the two-reinstall attack against the production simulator Keychain.
That run had two obsolete expectation failures elsewhere, since corrected.

`owner-pin-third.log` records 30 passing Activity pagination/refresh tests,
a passing recovery-screen foreground authentication test, passing independent
auxiliary-source startup tests, and a passing recovery phrase/path round trip.
One existing read-only inventory test exposed a global-entropy mismatch being
classified as an I/O error; that distinction is corrected for the next run.

The strengthened real-Keychain test deletes a temporary account database and a
dedicated UserDefaults suite between installs. It and interrupted PIN publication
cases pass in the full Debug suites on iOS 17.5, 18.4, 26.5 and 27 (838 tests,
8 opt-in skips each; exit 0). Independent review follow-ups are integrated.
The separate normal-app two-uninstall UI sequence and optimized Release results
are recorded in `../VERIFICATION.md`. Physical/store qualification remains open.

## Last public TestFlight source

Commit `7176228c` (build 2026091402) has no generic retained-wallet PIN restoration
or earlier-install PIN copies. `RootInteractor.decideModuleSynchroniously`
routes missing selection with protected Keychain material to recovery, except
for the separate explicit 1.x upgrade. With a selected row it asks for the app
PIN. Its recovery screen restores missing keys from an entered phrase or a
password-verified Drive backup. The stored `pincode` item is not a generic
retained-wallet adoption credential in that source. This is source evidence,
not a claim that a distributed binary or every downgrade path was device-tested.
Closing public TestFlight links remains part of the release operations checklist.

## Independent review follow-up: durable setup and committed restores

The independent review in `audit-2026-10-12/ios/pin-independent-review.json`
identified two interruption paths. The first was the use of an unchecked
preferences Boolean as PIN setup authority. The second lost the committed
restore result when owner-binding publication failed after the account row
had already committed.

The follow-up replaces the Boolean's authority with a device-only Keychain
setup intent containing the exact account identity and account-commit operation
UUID. The journaled insert saves and reads it back before secret persistence.
Only supplied import/create material or a sealed, address-scoped owner-PIN
restore grant can create that intent. Retained discovery explicitly drops the
factory's supplied-material grant before insertion. The initial rotation names
and consumes the exact intent UUIDs; it cannot consume a newer import claim for
the same address. A lost `pending=true` preference no longer enables the earlier
app PIN, and a stale `pending=true` preference after success no longer permits
another unauthenticated PIN change. Unmatched retained intents remain untouched.

Normal manual authentication now reads the current rows and reconciles ownership
under one lifecycle lease. The lock order is lifecycle lease, then owner-PIN
lock. The secret resolver called from ownership proof does not acquire another
lifecycle lease. Biometric preparation also refuses a current-row setup intent.
Launch routing checks the selected account's durable intent rather than the
preferences hint.

The restore flow reconciles the actual committed rows against the matched owner
address grant after publication recovery. A transient post-commit failure can
finish PIN setup in the same session. A persistent failure with committed rows
reports that the wallets were saved and provides the PIN setup continuation;
it does not claim that nothing changed. Existing-install failures explain that
PIN protection is incomplete and require retry before use.

`WalletOwnerPINIntentTests` adds nine focused checks, including a real
`SelectedWalletSettings`/Core Data insertion that commits and then receives a
one-shot Keychain publication failure. The other checks cover preferences
rollback, exact claim scope across reinstall, claim-write failure before key
persistence, each initial-rotation mutation, journal/binding/PIN readback
failures, and retained discovery without an ownership grant. Swift syntax
parsing and project-file lint pass. The completed simulator run
`pin-review-short-import-4.log` passed all 106 tests: 67 key-safety, nine durable
PIN-intent and 30 UX cases.

A further integration check covers an orphan setup intent from an import that
never committed a row. After another wallet completes setup, a later authorized
import of that abandoned account journals consumption of the orphan intent's
exact UUID alongside rebinding to the current app PIN. A failed/no-row insertion
keeps the orphan intent untouched. Setup state is derived from current rows,
so an unrelated retained intent cannot strand a completed installation.

Integration testing caught a preflight-ordering regression: an import rejected
for conflicting retained material had already created PIN setup metadata. The
insert now validates all retained items under the same lifecycle lease before
creating its intent; the intent still precedes new secret writes. The original
no-write conflict test passes unchanged. Successful-import tests explicitly
allow only the exact setup tag and continue comparing every retained key byte.
