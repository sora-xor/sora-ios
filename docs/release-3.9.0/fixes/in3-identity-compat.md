# Historical signing and backup compatibility — work in progress

Resumed from the credit-interrupted audit on 12 October 2026. The work below is
being integrated on `codex/upgrade-safety-20261012`; it is not a release verdict.

## Implemented

- Signing proves the retained, already-derived direct secret independently of
  entropy, parent seed and derivation records. Lengths are checked before native
  calls. Sr25519 scalar encoding is checked, then a production signature must
  verify. Ed25519 accepts a 32-byte seed or a 64-byte historical JSON secret and
  proves its seed half. ECDSA uses the child scalar without replaying a stored
  path and retains BLAKE2b-256 preprocessing.
- The identity rule is applied to signing, account availability, retained-wallet
  discovery, network-model migration, startup inventory and saved-manifest
  validation. A present but invalid secret stays read-only; it is never hidden
  by an auxiliary fallback. When the direct secret is absent, independently
  verified entropy/seed remain available as in-memory fallbacks.
- Optional backup sources are assessed separately as absent, unreadable,
  mismatching or matching. Drive creation includes only matching phrase/seed
  material plus a verified JSON. Profile descriptors use the account's actual
  crypto type. JSON export reconstructs the redundant ed25519 public half in
  memory and leaves retained bytes unchanged.
- Both recovery-screen Drive restoration and ordinary Drive import can use a
  proven source when another source is stale. Older default-crypto metadata is
  not allowed to override the JSON's real encoding and the expected address.
- Matching imports can add missing backup items alongside a working retained
  key, without overwriting conflicting auxiliaries. If a retained path differs,
  new auxiliary writes that would depend on another path are withheld.
- Phrase and raw-seed screens only display proven sources. Where a derivation
  path is needed, it is displayed with a separate copy action. The raw-seed
  screen offers JSON export when no matching seed exists. English and Japanese
  messages are in string tables.
- The native ECDSA signer retains its context until serialization finishes and
  destroys it on failure. It also checks the private-key length before signing.

## Evidence so far

- Targeted simulator run: 61 tests, zero failures, on iOS 27. Log:
  `audit-2026-10-12/ios/identity-fourth.log` in the parent audit workspace.
- New cases include full startup plus signing and JSON round trips for sr25519
  soft/hard/password paths, ed25519 historical JSON with a damaged redundant
  half, ECDSA phrase-then-child-seed double import, stale paths, unreadable
  auxiliary records, malformed direct-secret lengths, and Drive JSON recovery
  despite stale sources and incorrect outer crypto metadata.
- All tests use synthetic/public fixture material. Retained bytes are compared
  before and after; no real wallet keys or funds are involved.
- The full Debug unit suite is running after the backup-screen additions.

## Required before this task is complete

- Authenticated, explicitly confirmed quarantine-and-repair when the retained
  signing key does not prove the account. Preserve originals and journal
  interruption recovery; coordinate with per-wallet PIN binding.
- Typed 3/6/9-word import for an explicitly known address on a fresh install.
- Checked-in vectors generated with historical dependency families, including
  obtainable 1.x implementations, beyond the copied historical storage writers.
- Full-suite results, independent review, backup-screen screenshots and the
  final device/upgrade matrix. Re-run unsigned Release after all changes.

## Independent review follow-up (12 October)

The read-only review of commit `95a6dabb` found three remaining gaps, recorded in
`audit-2026-10-12/ios/identity-independent-review.json`. Current integration
changes make availability and both startup-manifest paths independently prove
surviving sources when no direct key exists. An unreadable sibling cannot block
a valid source, and saved auxiliary-only manifests now recheck identity and a
signature rather than mere presence. Recovery phrase reveal includes the
verified path/password with its own copy action and the same capture/background
protection as the phrase. Tests across all three crypto types, stale/unreadable
siblings and full Core Data migration passed in `owner-pin-third.log`, as did
the phrase/path round trip. One unrelated global-entropy mismatch classification
was corrected after that run and is being rechecked. The earlier remaining-work
list still applies; quarantine repair and historical dependency vectors are
not completed by these changes.

## Typed historical phrases

Typed 3/6/9-word restore now asks for the wallet's known SORA address. Both the
validation operation and the final name-screen import require that exact address
before any secret persistence. The address travels through both onboarding and
Add account. A missing/empty address, another wallet's address, or a missing
required derivation path is rejected without writes. The new regression cases
exercise all three short lengths across sr25519, ed25519 and ECDSA and verify the
retained writer's exact signing key and production signature. These cases passed in the 106-test targeted run
`pin-review-short-import-4.log`; they are not included in the older full-suite
result below.

The pre-follow-up Debug unit run (`owner-pin-full-debug.log`) completed 781 tests,
with five skips and zero failures. Its separate physical-IPA migration evidence
UI test was incorrectly runnable on a simulator; it now explicitly skips there.
The long legacy activation interruption test was sampled while running and was
actively deriving/verifying keys; it completed successfully. This result predates
the final independent PIN corrections and typed short-phrase changes.

The import screen now exposes crypto type and optional derivation path under
Advanced options, and an encrypted JSON import accepts its backup password.
Previously those setter hooks were empty and the selected controls could not
reach the request. Controller-to-input-model and typed-address presenter tests
pass in the same targeted run. Screenshot review and all production locales
remain pending.
