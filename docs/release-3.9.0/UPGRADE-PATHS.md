# Wallet upgrade and recovery paths

Implemented behavior and evidence status on 12 October 2026. `VERIFICATION.md`
distinguishes passing tests from pending real-app/device qualification. Wallet
funds remain on their chain; the local app must still prove each account's key
before signing. Never erase the app or its retained data as a recovery step.

| Arriving state | First-launch behavior / way forward | Evidence and remaining work |
|---|---|---|
| Healthy 3.8.6 single/multiple accounts | Verify actual rows and independently prove direct signing keys; migrate retained metadata without replacing working key bytes; ask for the existing app PIN. | Normal-app simulator single/multi account, manual PIN, address/phrase/signing and key-byte checks passed; signed old-app upgrade still pending. |
| sr25519 soft/hard/password paths; ed25519/ecdsa; historical double-import auxiliary records | Validate the already-derived direct key independently. Conflicting phrase/seed/path metadata cannot disable a working direct key or silently replace it. A bad present direct key stays read-only. | All 20 baseline original-crypto vectors passed normal-app launch/PIN and exact identity/key/signing verification; includes short, junction and damaged redundant/double-import shapes. |
| 15/18/21-word wallet | Preserve its SORA2 identity and recovery material; do not fabricate a Nexus derivation for unsupported lengths. | All 12 original 15/18/21/24-word vectors across three crypto types passed normal-app simulator launch, phrase reveal and production signing. Signed device qualification remains open. |
| Historical 3/6/9-word wallet | Retained signing works when independently proved. Typed short-phrase import requires the known SORA address and matching derivation before saving. | Retained 3/6/9-word wallets passed normal-app launch and signing for all three crypto types; typed known-address restoration is covered by production-import unit tests. Original SDK cannot reveal phrases for these entropy lengths. |
| Raw seed / encrypted JSON | Prove the supplied result against the intended address. JSON crypto metadata and password must agree; no stale sibling backup source overrides independently valid material. | Three-crypto original raw-seed and encrypted-JSON writers passed real-app PIN, retained identity and signing checks. Actual encrypted Drive transport/device qualification remains open. |
| 1.x `privateKey` + `seedEntropy` | Explicit upgrade, preserving global legacy bytes. Prove scoped copies before adding them. During recovery, independently provable legacy copies may be added without clearing recovery or granting wallet access. | Two original IrohaCrypto 0.2.6 vectors; scoped-copy/downgrade tests. Global-key fixture passed ordinary app upgrade, preserved its original display name, revealed its phrase, and verified exact keys/address/signing. This uses released source, not an installed signed 1.x binary. |
| 2.x `UserDataModel` v1 + selected account | Use retained model migration and the same identity checks; failure keeps evidence and offers recovery. | The original e52beedd 2.3.1 mapper and version-one schema passed normal-app launch, PIN, phrase, address and signing checks. No signed 2.x binary claim. |
| Only retained entropy / no direct secret | Derive and prove an independent fallback; add missing scoped material only where the original evidence matches. | Entropy-only legacy fixture passed ordinary app upgrade, retained its original name/entropy, revealed the phrase, and verified the expected address and production signing. |
| Reinstall: no database, real retained key tags | Welcome back. Bound wallets require each wallet's owner PIN. Unbound older wallets require a phrase or encrypted backup. A saved global PIN alone cannot adopt them. | Actual uninstall/reinstall plus normal Welcome, owner-PIN restore, phrase and signing passed for a bound wallet. Unbound386 Welcome requires phrase/backup. Two actual uninstalls also passed: B’s PIN restores only B, A rejects that PIN and still accepts its original owner PIN. |
| Healthy retained signing rows, no application PIN | Do not offer an unsaveable new-PIN flow or bind a new PIN without ownership proof. Recovery offers supplied backup and explicit set-up-again actions while preserving all existing keys and rows. Exact verified fresh-setup intents still permit PIN setup. | Actual normal-app recovery screen and post-launch key/row/PIN/binding/gate assertions pass. Unit regression also covers a selected read-only row hiding another retained signer. |
| Reinstall: supplied backup matches absent account but retained keys conflict | Explicit repair retains every old byte first. An established installation asks for its current PIN; empty onboarding chooses and confirms a fresh PIN. The normal account journal inserts the proved account. Interrupted absent-row intents never reactivate wallets automatically. | Nine orphan-repair tests including every Keychain mutation interruption and all three crypto types. |
| Restored metadata on a new iPhone, no database and no keys | Preserve stale defaults/snapshot under the lifecycle lease, then normal onboarding. PIN/username tags alone do not count as wallet keys. | Normal-app restored metadata/no-DB/no-keys fixture reached onboarding; unit matrix and race tests also pass. |
| Database exists, keys absent / invalid | Account remains visible with read-only badge, reason and restore action. Missing keys can be restored add-only; failed retained keys need fresh proof, manual PIN and explicit confirmed quarantine/repair. | Capability, 15 repair and actual import-route tests pass. Full simulator erase + application-files-only restore reaches the read-only wallet with missing-key reason/action; signed physical backup qualification remains open. |
| Explicit watch-only | Keep it watch-only; repair/import must not silently convert it into a signing wallet. | Snapshot/settings watch-only and orphan-repair refusal tests. |
| Interrupted writes or migration / pending transfer records unreadable | Preserve authoritative wallet data, recovery copies and journals. Sweep only recognized durable-writer helpers under the lifecycle lock; resume only verified operations. Show recovery with current actionable options. No inferred transaction success or automatic resubmission. | Normal app swept helpers planted in all four wallet folders, and reopened after a 50ms post-launch termination; original bytes/signing remained intact. Unit fault injection covers exact write checkpoints. |
| Set-up-again and earlier preserved generation | Preserve the complete allowlist and settings in a backup-excluded manifest. Empty live state may return verified data only after each retained-key wallet has owner-PIN proof and the user chooses an explicit new app PIN. Metadata-only generations have no retained-key owner to prove. Tampering, competing live data or pending credential repair blocks return. Unbound old wallets use supplied backups. | Unit fault injection proves return at every move plus tamper/live-state/PIN guards. Normal app set-up-again → owner-PIN proof → new PIN → return → wallet/phrase passes; verifier proves original rows/name/keys, rotated ownership, signing, completed manifest and retired return journal. |
| Saved node unreachable / delayed asset service | Local wallet checks route independently of network readiness. Wallet opening offers bounded retry/node recovery; cached balances are not replaced by an empty asset list. | Saved-unreachable-node fixture reached PIN, then a real wallet or bounded retry/node screen; exact keys/signing remained intact. Five consecutive current live catalog/pool/price rounds passed. |
| Downgrade after recovery | Preserve original global/scoped keys and public rows for older startup logic; current app PIN reconciliation requires manual entry on return. | Verbatim 3.8.6 routing and inconsistent-state methods run with explicit adapters over cloned post-launch keys and original-mapper rows. Healthy retained-key clones sign; missing-key clones cannot sign and reproduce the old preferences wipe. The pinless clone follows the old setup route while the new app stays in recovery. This is source qualification, with signed downgrade/device evidence pending. |
| iOS 14 or 15 | 3.9.0 requires a newer supported iOS version. Stay on 3.8.6 until moving to a compatible device/OS. Keep the recovery phrase offline and restore it on that compatible device; do not uninstall the only working wallet first. | Deployment-target/source evidence; support must validate instructions on the released 3.8.6 app. |

A failure to read Keychain is not proof a key was deleted. Recovery details use
fixed diagnostic codes; protected exports exclude phrases, seeds, private keys,
PINs, signed payloads and Keychain contents. Support must never request them.


## Inspected version families

These are inspected source/tag families, not a claim that each signed historical
binary was installed. Exact commits, lockfiles and dependency hashes are in
`Fixtures/Modernization/historical-crypto-provenance/dependency-family-inventory.json`.
Every obtainable active crypto family below was executed independently and its
vectors were fed through current production migration/signing/backup tests.

| Version or tag family | Independent source evidence | Upgrade route |
|---|---|---|
| 1.3.3, 1.4.6, 1.5.1 | Original IrohaCrypto 0.2.6; two original legacy vectors | Global-key/entropy legacy upgrade; normal app confirmation, PIN, name, phrase and signing exercised separately. |
| 2.3.1 | Original e52beedd mapper and version-one account schema | Normal app database migration, existing PIN and retained identity. Other unavailable 2.x signed releases remain unqualified. |
| 3.0.1 | Original FearlessUtils c1d17ccf + IrohaCrypto 0.9.0, 20 vectors | Preserve database and scoped keys; authenticate with existing PIN. |
| 3.1.0, 3.2.0 | Original FearlessUtils e6aaeb17, 20 vectors | Same retained account route; no key re-derivation over a valid direct key. |
| 3.3.0–3.7.1 inspected tags | Original FearlessUtils 26dfc128, 20 vectors | Same retained account route. |
| 3.8.0–3.8.3 | Original active SSFUtils 0.1.31 / SSFModels 0.1.31, 20 vectors | Same retained account route. |
| 3.8.4 | Original active SSFUtils 0.1.31 / SSFModels 0.1.32, 20 vectors | Same retained account route. |
| 3.8.5–3.8.9 inspected tags, including 3.8.6 reference 354f176c | Original shared-features-spm ada44b24, 20 baseline plus 12 long-phrase vectors | Same retained route; verbatim 3.8.6 writer launch cases additionally exercise actual simulator Core Data and Keychain. |

All signed-store upgrades, device-only Keychain behavior, and signed downgrades
remain release gates. A failed read, missing auxiliary backup, or unknown schema
must not be interpreted as permission to delete surviving wallet keys.
