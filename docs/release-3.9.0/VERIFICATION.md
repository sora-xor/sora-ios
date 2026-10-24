# Recovery integration verification — 12 October 2026

This is an evidence ledger for `codex/upgrade-safety-20261012`, not a release
approval. Historical task notes retain their original dates and results. The
current continuation's raw logs and screenshots are in the sibling workspace
`audit-2026-10-12/ios/`; test fixtures and regeneration provenance are checked
into `Fixtures/Modernization/historical-crypto-provenance/`.

| Check | Result and scope | Evidence |
|---|---|---|
| Full Debug, iOS 17.5 / 18.4 / 26.5 | Each **838 tests, 8 opt-in skips, 0 failures; xcodebuild exit 0**. Later changes have focused checks and final iOS 27 full-suite validation separately. | `final-debug-ios17.5-2.log`, `final-debug-ios18.4-2.log`, `final-debug-ios26.5-2.log` |
| Full Debug, iOS 27 | **843 tests, 8 opt-in skips, 0 failures; xcodebuild exit 0.** Includes final missing-PIN routing and corrected legacy-intent fixture. Earlier focused PIN checks: 17 tests, zero failures on iOS 17.5. | `final-debug-ios27-4.log`, `final-pin-routing-debug.log` |
| Optimized Release test host | **843 tests, 8 opt-in skips, 0 failures; xcodebuild exit 0.** Production `F_RELEASE` and optimization remain active; test-only durable checkpoint observation is explicitly enabled. | `final-release-testable-build-8.log`, `final-release-ios27-4.log` |
| Integration suite | **21 tests, 3 physical-device skips, 0 failures; exit 0.** The scheme's pre-existing exclusion of 6 legacy funded-account/layout-specific `JSONRPCPoolXYKTests` remains. Current storage/pool reads are also covered by live production-client tests. | `final-integration-ios27.log` |
| Current live production behavior | **5 tests, no skips/failures; exit 0.** Five consecutive assets/pools/fiat/market-cap/cache reads all succeeded. Other reads/history passed; finalized pruned-state reconciliation passed; live account storage decoding passed. A new random, unfunded key signed a self-transfer and the node rejected it only for inability to pay fees. | `final-live-mainnet-5-rounds.log` |
| Historical crypto | 120 original Substrate vectors across every migration restart checkpoint, 2 original Iroha vectors, plus 12 original long-phrase vectors. Tests check retained bytes, expected public identity, production signing and backup round trips. | `HistoricalCrypto/`, provenance; full unit logs; real-app launch matrix |
| Repair/authentication | Full suites include all 9 orphan-repair cases, 15 existing-row repair cases, 9 owner-intent cases, capability and actual import-routing tests. Earlier focused run: 72 tests, 1 visual skip, 0 failures, exit 0. | Full logs; `orphan-repair-tests-3.log`; independent auth review |
| Unsigned generic-device Release | Final ordinary Release generic-device compile **passed, exit 0**, including PIN routing, header, legacy-name and node fixes. No test-only compilation condition, signed IPA or upload. | `final-unsigned-release-device-3.log` |
| Release helper scripts | 8 tests passed. | `final-release-script-tests.log` |
| Recovery layout | 176 English/Japanese light/dark normal/maximum-text captures from production controllers. These use synthetic UI state; they do not prove launch routing. Reviewed captures identified switcher and real-table restore-button sizing corrections. Final constrained multiline label, capped at 26pt using the actual trait collection, passes real UITableView sizing assertions in Debug and Release. Reviewed final maximum-text captures are legible. | `recovery-visual-final-4/`, `recent-ui-independent-review.json`, `final-regressions-and-visual-4.log` |
| Localization | **28 shipped locales × 235 keys = 6,580 entries**, complete and placeholder-valid, including four tuple/conditional wallet-opening keys added after `e0d90d04`. Native review remains open. | Checked-in [manifest](recovery-translations.json), [validation](recovery-translations-validation.json) |
| Real app with historical writers | Single/multi 3.8.6, all 20 base vectors (short phrases and derivation/double-import forms), 2.3.1 v1 database, all 12 long-phrase cases, and three-crypto raw seed/JSON cases passed. Actual bound reinstall restored with the owner PIN, revealed the phrase and retained/sign-verified keys; unbound reinstall correctly requires a supplied backup. Missing DB, new-phone metadata, helper leftovers, first-launch termination and saved-unreachable-node/PIN cases passed. Erased-simulator filesystem restore reaches read-only. Original global-key and entropy-only cases preserve legacy names and pass all stages. All **56 distinct cases** have complete passing prepare/UI/verify sequences (two-reinstall uses five stages). Two actual uninstalls demonstrate that B’s PIN restores only B and cannot claim A; A’s own PIN still proves A. Missing app PIN with retained keys reaches recovery without creating a PIN or binding. Normal-app set-up-again and return of a preserved generation passes manual owner proof, new-PIN confirmation, exact original keys/row/name, phrase and production signing. Failed attempts remain in the JSON ledger. | `SIMULATOR-MATRIX.md`, `simulator-matrix-summary.json`, original per-stage ledgers and xcresult screenshots/accessibility |
| Signed physical/store behavior | Not qualified by simulator or source tests; external release gate. | `RELEASE-CHECKLIST.md` |

## Reproducible build settings

Use the checked-in `Package.resolved` and pass
`-onlyUsePackageVersionsFromResolvedFile` to every Xcode command. This
continuation uses Xcode's `SoraPassport` scheme, explicit derived-data directory
`build/safety-audit`, and an explicit existing cloned package directory. The
isolated iOS 27 simulator ID is `07581E47-6973-4028-A34A-6ECB6F499F3E`.

Full units use `-only-testing:SoraPassportTests -parallel-testing-enabled NO`
and `-collect-test-diagnostics never`. The latter avoids Xcode's verbose
post-failure diagnostic collection hang without suppressing XCTest failures.
Simulator apps retain local ad-hoc signing; `CODE_SIGNING_ALLOWED=NO` removes the
Keychain entitlement and is reserved for the generic-device compile.

Optimized Release tests also pass `ONLY_ACTIVE_ARCH=YES ARCHS=arm64
ENABLE_TESTABILITY=YES 'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited)
WALLET_TESTING'`. Only the durable-writer fault observer uses `WALLET_TESTING`;
ordinary Release compilation does not include it. Production `F_RELEASE`
conditions and optimization remain enabled.
Targeted recovery uses `WalletCredentialRepairTests`,
`WalletOrphanCredentialRepairTests`, `WalletOwnerPINIntentTests`,
`WalletAccountCapabilityTests`, `WalletUXTests` and the two import validation
cases in `WalletKeySafetyTests`. No live balances, funds or personal recovery
material are needed. All fixture keys are synthetic/public.

Set `SORA_CAPTURE_RECOVERY_UI=1` and
`TEST_RUNNER_SORA_CAPTURE_RECOVERY_UI=1` only for the opt-in visual test. Pull
`Documents/RecoveryVisualEvidence` from the test host's current simulator data
container after the run; Xcode may replace the container between runs.

## Evidence limits

The native historical fixture generators use original dependency source and
pinned versions. The provenance records source hashes and host-only platform
adaptations. They do not establish the memory safety of historical binaries,
cover every unavailable historical binary, or prove application-signing continuity. The obtainable 2.3.1 source mapper and version-one schema are exercised separately. Native
translation review, full state/RTL layout checks, device-provider behavior and
store eligibility remain explicit release gates.

## Normal application screenshots and commands

Fresh public phrase import passed through the normal Debug app on iOS 17.5,
18.4 and 26.5; optimized Release also passed on 26.5. Each imports the public
12-word abandon/about phrase, chooses/confirms a PIN, visits Activity and Wallet,
and reveals the phrase. The Debug host verifies the expected address and
production signatures afterward. The Release case is UI-only and checks the
address in account details. Exported images and accessibility text are under
`fresh-ui-exported/` with their xcresult attachment manifests. The four overview
PNGs were manually inspected. Some Activity captures show initial loading;
26.5 and Release show the empty-history state. Thirty separate unit regressions
cover pagination/refresh behavior.

The complete distinct-case index is `SIMULATOR-MATRIX.md` in the evidence folder,
with machine-readable `simulator-matrix-summary.json`. The 56-case result spans
recorded builds, not one rerun of all cases on the final binary; final changes
have the focused and full-suite checks above.

The simulator runner records exact Xcode commands in each stage log and retains
all outcomes in `matrix-results.json`. Example (owned simulator only):

```sh
python3 scripts/run-simulator-upgrade-matrix.py \
  --udid OWNED_SIMULATOR_UUID \
  --xctestrun build/simulator-matrix-products-17/SoraPassport_iphonesimulator27.0-arm64.xctestrun \
  --output ../audit-2026-10-12/ios/real-app-matrix \
  --cases vector-9 multi model-v1
```

Use an available device named exactly `SORA-Codex-SimulatorMatrix`; the marker,
UUID, development bundle and opt-in test environment are all checked before
fixture writes. `--cases two-reinstalls` performs two actual simulator uninstalls.
`erase-restore` erases the owned simulator and restores only saved public-fixture
application files, never Keychain. The production bundle option is restricted
to `--stage ui --cases fresh-import` and performs no fixture writes.

The iOS 16 source/compiler review is in `fixes/in5-older-ios.md`; no iOS 16
runtime was available. Complete availability-site inventory and review notes are
in the evidence directory.


## Corrected failed validation attempts

The retained Release run `final-release-ios27-2.log` executed 840 tests and
reported two assertions in the synthetic custom-node case: its fake URL reached
the real Release-only genesis probe. The test now injects an expected genesis
operation, while production keeps the real probe and identity policy.

`final-release-ios27-3.log` executed 843 tests with four assertions in one
legacy-upgrade fixture. Its `SelectedWalletSettings` omitted the fixture
keystore, bypassing creation of the exact durable initial-PIN intent. The
production singleton supplies its Keychain. The fixture now supplies the same
isolated keychain as its importer/root and checks account/public-key identity,
the actual import journal ID, no premature PIN/binding, and the exact permitted
new tags. Focused Debug and Release regressions both pass, followed by full
843-test Debug and optimized Release passes. These failures and their result bundles are retained.

The only intentional `git diff --check` exceptions are trailing spaces in the
two verbatim historical 3.8.6 mapper copies. Their original source hash and
declared compilation adaptations are retained; all other changed files pass.


## Evidence preservation and cleanup

Final full Debug/Release, integration, live and focused XCTest result bundles
are copied under `audit-2026-10-12/ios/final-unit-results/`, alongside their
manifest. Case-specific normal-app result bundles, public fixture receipts,
screenshots and accessibility exports remain in their original matrix folders.
`owned-simulator-cleanup.json` records deletion of all six explicitly owned audit
simulators after evidence export. Build products remain available in the local
audit checkout for review; these are not signed distribution artifacts.
