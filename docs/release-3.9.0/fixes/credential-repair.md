# Authenticated credential repair

Implemented for integration on 12 October 2026. The existing-row repair suite
passed 15 targeted tests. Root run 3 (`orphan-repair-tests-3.log`) completed
with exit 0: 72 tests, one opt-in visual test skipped, zero failures. It includes
all nine missing-row repair tests, 15 existing-row repair tests, nine owner-PIN
intent tests, five capability tests, 32 UX tests and two actual import-routing
tests. Full-suite and release qualification remain owned by the root audit.

`WalletCredentialRepair` requires freshly supplied phrase, seed or JSON material
that proves the exact existing address, public key, crypto type and network.
Retained-wallet discovery cannot mint this proof. The service reads actual rows
under the lifecycle lease, requires the user's explicitly confirmed action, and
checks the manually entered current app PIN through the durable PIN limiter.
Biometric success and reading the stored PIN cannot authorize a repair.

A working retained direct key remains add-only. Existing secret bytes, including
sr25519 nonce bytes and the redundant ed25519 half, are not replaced. Conflicting
auxiliaries are left untouched on this path. Explicit watch-only markers in
both settings and the durable network snapshot are enforced, including after
settings loss. Repair ignores only its own pending-intent gate: unresolved
database migration and account commit journals continue to block it.

For a failed direct key, the transaction journals the exact account, a digest
of the manually authenticated PIN, and every original/intended scoped item.
It preserves and reads back every replaced original in a unique Keychain
quarantine tag before modifying any live credential. It writes and reads back
the proven replacement and new owner binding, proves a production signature,
preserves a complete receipt, then retires the active intent. Correct existing
backup sources are retained where they still prove the account under the chosen
path. Unreadable originals abort before live replacement because they cannot
yet be safely copied.

Resume verifies the complete intent, exact current identity, unchanged app PIN,
new key proof and owner binding. A live value different from both its recorded
original and intended value blocks the transaction. Ordinary signing/mutation
must reject a pending repair; authentication and startup must resume it under
the proper lifecycle/recovery capability before allowing access. The root
integration owns those hooks and the route from recovery/read-only screens.

If uninstall removed the exact account row, resume does not change credentials
or bindings. It archives and reads back the complete self-contained intent,
including all original and intended bytes, then retires only active metadata.
This leaves unrelated imports available without granting ownership from an old
receipt. Completed and orphaned receipts never drive automatic credential
writes. A same-address row with another public key, type or network still fails
closed. Recovery of an absent wallet continues to require fresh supplied
material/owner proof through the ordinary recovery route.

The supplied-material missing-row forward path is now implemented by
`importMissingAccount`. Its caller chooses an explicit authentication mode:
with current rows, the actual current app PIN must be manually entered; with
no current rows, the user must explicitly choose and repeat a new PIN. An old
Keychain PIN is never adopted as the new install's protection. The service
rechecks the row set, exact identity, watch-only state and complete recovery
gate under one lifecycle lease, and keeps that lease through ordinary journaled
account insertion and model activation.

Fresh supplied material authorizes the single missing identity only. Failed
items and the previous binding are durably quarantined by the same transaction.
The missing-row exception exists only in the active invocation: no journal
field or archived receipt can recreate it. An interruption before insertion
leaves either original or proven replacement bytes and requires a fresh backup
and explicit PIN action on retry. Automatic startup only archives a row-absent
repair intent; it never inserts an account or repairs that account from a
surviving Keychain receipt.

For empty onboarding, an exact-account setup intent precedes credential writes.
Once the new key is proven, the existing PIN rotation journal publishes and
reads back the newly chosen PIN and this wallet's binding. A nonserializable
completion grant suppresses redundant PIN setup during the following account
insertion, after checking the empty row set, exact account identity, unchanged
PIN, matching owner binding and consumed setup intent. Other retained wallets
are neither rebound nor inserted. A crash drops this grant; a later supplied
import performs initial setup again. A working direct key still uses only
add-only writes, preserving all mismatching auxiliary bytes.

`WalletOrphanCredentialRepairTests` covers all three crypto types, current PIN
versus initial PIN modes, stale previous-install PIN refusal, unrelated wallet
bindings, explicit watch-only state, foreign journals, unreadable originals,
working-key add-only behavior, failure before every Keychain mutation through
new-PIN publication, and orphan receipts surviving a second reinstall. The
production UI/import handlers are owned by the root integration and must route
typed and Drive conflicts into the same explicit service API.

The reusable `WalletCredentialRepairViewController` offers phrase/raw-seed/JSON/Drive,
path and JSON password, manual app PIN, an explicit address-bearing confirmation,
and a retry action for an already authorized durable intent. Input fields use
secure entry and clear on background/capture changes. Drive is read only after
an explicit review/confirmation action; opening the controller or choosing a
source does not fetch. Google account selection is followed by a fresh manual
PIN confirmation for the exact address, so a PIN is not retained through the
external sign-in UI. `credential-repair-string-keys.json` lists lookup keys and missing
translations; native review and screenshots remain pending.

`WalletAccountCapability` reuses the existing production key-availability proof
on a background queue under the lifecycle lease. The switcher displays a
read-only/watch-only badge; the selected account header explains missing or
invalid keys and offers “Restore keys for this account.” Explicit watch-only
accounts have no restore action. Send from the wallet, asset details and QR
routes runs a fresh check before opening amount or confirmation screens; a
completion for a changed selected identity is discarded. These UI checks
grant no signing or authentication authority. Normal repair success performs
leased network-model verification before notifying the account graph; a
verification failure reports that keys were repaired and requests startup
recovery, rather than retrying the credential replacement.

`WalletCredentialRepairTests` covers all three crypto types; phrase/seed/JSON
repair and export re-import; every mutation interruption; ambiguous intent,
quarantine, live-key and receipt writes; wrong PIN; missing supplied proof;
watch-only and wrong identity; changed live/quarantine bytes; unreadable originals;
working-key preservation; pending mutation gating; uninstall/orphan archival;
and the production controller's wrong-PIN and input-clearing behavior.
`WalletAccountCapabilityTests` adds all-three-crypto key status checks,
durable watch-only/pending/foreign-journal checks, switcher/header controls,
send preflight and stale-selection refusal, and Drive/prefill secure UI behavior. These
are implementation checks awaiting the integrated simulator run, not a claim
of physical-device or production-IPA execution.
