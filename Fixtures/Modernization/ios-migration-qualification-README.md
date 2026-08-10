# iOS wallet-migration qualification receipt

`ios-migration-qualification.json` is release evidence, not a configuration file or a unit-test
fixture. Do not create it from source inspection, inferred results, or a partially passing test run.
Publish it only from an independently reviewed qualification run over every retained production
Core Data snapshot and the current source tree.

The receipt uses schema version 8 and contains aggregate evidence only. Its root, privacy,
release identity, Core Data hash, and qualification-check objects use exact reviewed key sets;
unknown fields are rejected so nested data cannot bypass the privacy contract. Schema 8 retains
the cohort matrix and binds the exact production IPA to the installed archive-derived clone,
protected raw-input/challenge pins, the observed v3 collection receipt, all four schema-v4 collector
artifacts, and exact retained-device test outcomes. Schema-7 and older receipts, evidence-manifest
v3 and older shapes, and any mixed-version family are wire-incompatible and cannot qualify this contract. It
must never contain a
wallet or account identifier, address, phrase, seed, private key, signature, signed payload, or
per-wallet row.
The qualified receipt, evidence manifest, trust root, and every nested contract object use
code-defined exact key sets; a changed blocked template cannot extend or redefine a qualified wire
schema. Template linting also rejects any non-reviewed non-null hash or identity, positive count or
timestamp, enabled flag, true qualification result, populated device/build list, or altered fixed
artifact path.

Required identity and aggregate fields:

- `contractId`: `sora-ios-wallet-migration-qualification-v8`; `platform`: `ios`; `status`:
  `qualified`; an empty `blockingReasons`; canonical protected `runId`, positive monotonic
  `qualificationSequenceNumber`, exact protected 40-hex `sourceRevision`, and positive,
  non-future `reviewedAtEpochSeconds` and `qualifiedAtEpochSeconds`.
- Exact protected `runChallengeSha256`, `rawInputSetSha256`, `collectionReceiptSha256`,
  `trustRootSha256`, and `evidenceManifestSha256`; direct hashes for all four aggregate outputs;
  distinct
  `deviceEvidenceProducerKeyId` and `independentReviewerKeyId`; and an aggregate release identity
  containing the exact production IPA digest, installed-clone raw-tree digest/count, installed
  executable digest/count, equal production/installed canonical-projection digests, canonical
  projection-receipt digest, canonical-projector source digest, and
  nonempty generic device-class and OS-build lists.
  Device serial numbers, UDIDs, addresses, account IDs, public keys, and raw Keychain values are
  forbidden.
- `sourceModelVersions`: exactly `UserDataModel`, `UserDataModel 2`; `targetModelVersion`:
  `UserDataModel 2`.
- `retainedCoreDataModelCount`: 2; `retainedCoreDataCohortCount`: 4;
  `singleAccountCohortCount`: 2; `multiAccountCohortCount`: 2.
- `successfulSecretSourceCohortCount`: 6 (12-word, retained 15-word SORA2-only,
  24-word, raw seed, retained keystore-import/secret-only, watch-only). The
  secret-only cohort must prove the exact retained private/public key and SORA2
  address/signing result remain unchanged, no Minamoto or Taira child is created,
  explicit deletion revalidates the protected identity, and corrupt material is
  preserved in the recovery route. The retained-15 cohort must prove the original
  unsuffixed entropy is unchanged, no address-scoped secret/entropy/seed is
  created, the original SORA2 public key/address/signing result is unchanged,
  Nexus derivation remains unavailable, explicit deletion revalidates the exact
  protected identity before removal, and corrupt material is retained in the
  recovery route;
  `secretFailureCohortCount`: 2; `currentSchemaSafetySnapshotCohortCount`: 2;
  `interruptionPointCohortCount`: 5.
- The focused source suite must exercise the actual asynchronous unsuffixed-entropy
  activation route for 12-, retained 15-, and 24-word wallets:
  `RootInteractor` -> `AccountImportInteractor` -> in-memory Core Data insert ->
  ordered `WalletAccountCommitJournalStore` activation -> copy-on-write
  `WalletNetworkStore`. Each case must compare the complete Keychain identifier
  set and every retained value byte-for-byte, the SORA2 address/public/signing-key
  identity, selected Core Data row, terminal journal, network snapshot, and
  deletion preflight. A post-secret-retention interruption must leave the Core
  Data row and non-terminal journal as recovery evidence, activate no network
  snapshot, and preserve the original Keychain values. Raw-seed-only,
  secret-only, and explicit watch-only paths must separately prove no rewrite and
  no Nexus promotion. Once any secret-source class is present in the active
  wallet-network snapshot, startup reconciliation must require that exact class;
  missing material, stale watch-only markers, or newly visible material cannot
  implicitly cross-classify mnemonic, retained-15, raw-seed, secret-only, or
  watch-only wallets. A mismatch enters recovery before publication and leaves
  every active snapshot byte-for-byte unchanged. These isolated unit cases are
  source qualification only; they cannot set `status: qualified` or produce this
  receipt.
- Durable wallet records must preserve a concrete, reviewed `FileProtectionType`
  across staged replacement and atomic rename. Both the retained source class and
  destination class are re-read as typed Foundation metadata; a missing, malformed,
  or unknown protection value rejects publication rather than allowing absent
  optionals to compare equal. Recovery archives are assigned `.complete` while
  hidden, then—after private-tree cleanup—archive-validity is bracketed by exact
  inode and typed `.complete` checks immediately before exclusive same-directory publication.
  Published archive validity is likewise bracketed by exact identity/protection,
  file/directory-chain synchronized, and bracketed again as the final throwing
  admission before the URL is returned. The focused
  exporter tests independently open the published archive attributes and require
  the exact `.complete` class. A missing or mismatched final attribute atomically
  withdraws the exact published inode to its unique hidden archive-staging name,
  repairs that same hidden inode to `.complete`, rechecks identity and typed
  protection around file/directory synchronization, and only then attempts
  deletion. If protection repair cannot be proved, only the exact withdrawn inode
  is eligible for removal and its absence must be proved; it is never deliberately
  retained without `.complete`. If later hidden deletion fails, no visible artifact
  remains and the identity-verified `.complete` archive is retained as support
  evidence. If exact withdrawal or safe cleanup cannot be proved, a distinct
  withdrawal failure is surfaced; neither a concurrent final entry nor unrelated
  hidden evidence is overwritten or deleted. The focused exporter case weakens
  the actual published inode to `.none` (rather than merely spoofing a provider)
  and requires withdrawal to leave neither a visible nor hidden artifact.
- Replacing an existing durable record first creates a random exclusive
  `.durable-rollback-*.anchor` hard link to the exact old inode and verifies its
  typed protection metadata. Immediately before either publication syscall, the
  exact random prepared inode and intended protection are re-read. Existing-target
  publication uses an atomic name swap and verifies the displaced inode; an initially
  absent target uses an exclusive rename so a concurrent creation cannot be overwritten. Before rollback consumes
  the first old-inode name, a second random exclusive hard-link safety anchor is
  identity/protection verified and its directory chain synchronized. Rollback uses
  another atomic swap: an unexpected displaced inode is swapped back when that can
  be proved, while both it and an old-inode anchor remain named if reversal is
  uncertain. The safety anchor remains until the restored destination has been
  identity/protection checked and synchronized. A hidden failed-new inode is
  reprotected to the intended retained class, identity/protection checked around
  file and directory-chain synchronization, and retained only after that proof. If
  reprotection cannot be proved, only that exact inode is eligible for removal and
  its absence must be proved. All later old-inode cleanup is exact-identity and
  non-throwing; an uncertain cleanup deliberately retains a protected hidden anchor
  or failed-new-file withdrawal as support evidence. Private wallet, commit,
  transaction, and migration-safety namespace admission treats every such hidden
  entry as unresolved before accepting active state or another mutation; it is
  never auto-cleaned. None is automatically included in or exposed by the recovery
  exporter, which continues to export only independently verified database and
  settings artifacts for support. Existing-target rollback and absent-target
  withdrawal are both exercised by weakening the actual published inode to `.none`
  inside the existing 198-method source suite.
- A positive `retainedReleaseSnapshotCount`, the reviewed
  `retainedReleaseSnapshotManifestSha256`, both checked-in Core Data model SHA-256 values, the
  exact executed `WalletModernizationTests`, `WalletRecoveryCapabilityGateTests`, and
  `WalletRecoveryExporterTests` method counts, zero failure counts, and a reviewed
  `testResultBundleSha256` covering all four suite inventories (198 + 11 + 12 + 3 = 224).
- True parity for account count, selected wallet, preferences, Keychain identity and accessibility,
  legacy dual-read retention, existing SORA2 identity/signatures, and zero lost accounts.
- Missing-store qualification must separately retain and exercise raw selected-account settings,
  the pre-account-model `userName` key in Keychain and settings, the activated wallet-network
  schema-version marker, legacy decentralized-ID/public-key-ID/completed-migration settings,
  PIN/watch-only markers, SQLite sidecars, safety backups, and a corrupt or missing active snapshot.
  Every unexplained case must enter recovery; only the explicitly confirmed final-wallet-deletion
  cohort may return to clean onboarding.
- Unsuffixed legacy activation must preserve the exact display name from its retained source.
  A Settings-only or valid UTF-8 Keychain-only name is accepted unchanged; equal dual-source
  evidence is accepted, while malformed, oversized, or conflicting evidence enters recovery.
  Neither source may be normalized, moved, or deleted during activation.
- Every named `qualificationChecks` gate enforced by
  `SoraPassport/Scripts/verify-modernization-dependencies.sh`.
  This includes `legacySecretQualified` and
  `retainedFifteenWordMnemonicQualified`; neither can be inferred from another
  cohort or source inspection.

Ordinary SORA2 ambiguous-submission recovery is part of the release wallet-safety
contract. Qualification must interrupt a mortal transaction after RPC handoff,
restart and foreground the app, and prove that recovery starts only after both the
wallet-network snapshot and SORA2 chain/runtime are ready. The recovery path must
perform status reads only: it may not build, sign, submit, or resubmit. A terminal
inclusion requires the exact wallet/account/hash, reviewed mainnet genesis and
runtime-130 metadata identity, canonical finalized block inclusion, and exactly one
`System.ExtrinsicSuccess` or `System.ExtrinsicFailed` event. Absence before the
versioned mortal-era death block stays ambiguous. Expired absence is terminal only
after every canonical block in the validated era was read successfully and the
exclusive death height finalized. For a versioned witness, an RPC submission success
alone is not prunable and must continue to block wallet deletion and journal-capacity
eviction until that authoritative terminal resolution is durable. Legacy ambiguous
entries without the complete versioned era
identity, and unreadable or corrupt journals, remain non-prunable and continue to
block wallet deletion. Record only aggregate pass/fail counts; never include a hash,
address, account ID, signed payload, or per-wallet result in the qualification
receipt.

The first SORA2 history page must also read the protected signed-submission
journal. If a crash interrupts the richer Core Data overlay write, an
account-bound generic pending row still appears from the durable exact hash and
creation time. A richer local row for that hash wins, and a PI row suppresses it
only after an exact decoded hash match; pagination age is never evidence that an
ambiguous submission did not happen. Authoritative finalized success/failure or
full-era expired-absence proofs may update that fallback row's status, but the
projection must never invent a call, amount, fee, receiver, or resubmit action.
Ordinary SORA2 send qualification must use the actual transfer destination, asset, and amount:
the exact signed bytes are fee-queried after one signing operation, both asset and XOR balances
are refreshed before handoff, and the same bytes are fee-queried again immediately before
transport. Any difference from the reviewed raw fee is definitive pre-transport rejection.

Every newly prepared generic SORA2 mutation must carry that complete recovery identity;
qualification must prove a caller-created prepared value without it is rejected before transport.
Before any generic SORA2 or Polkamarkt signer may read a secret, the exact live RPC engine that
supplies nonce, finalized head, fees, and submission must return canonical block zero matching the
reviewed SORA2 mainnet genesis. An address-derived/static genesis, matching runtime versions, or
matching metadata alone is not sufficient; missing, malformed, non-canonical, or foreign genesis
responses must fail closed before signing.
All canonical block, runtime, and execution-status RPC reads must use the reviewed finite timeout
and cancellation boundary so a disconnected foreground recovery cannot remain live indefinitely.
The bounded one-shot HTTPS JSON-RPC route must cover nonce, finalized head, canonical block-zero,
fees, ordinary `author_submitExtrinsic`, Polkamarkt authoritative reads, and recovery status reads,
with no reconnect resend or WebSocket fallback. The remaining legacy subscription and runtime-
factory WebSocket stack's finite operation timeout does not itself prove a bound on inbound
frame/message aggregation. SORA mainnet metadata fetched or hot-booted into a signing factory must
be at most 4 MiB and match the exact reviewed runtime-130 spec, transaction version, and metadata
SHA-256 before SCALE decoding; a stale or corrupt same-version cache is replaced only after the
bounded live bytes pass that identity check. Reviewed SORA2 must force the checked-in
`runtime-sora.json` override mode and admit both bundled type-registry resources by exact byte count
and SHA-256 before JSON or SCALE construction; remote chain configuration and stale cache files may
not change those bytes or select common/mixed resolution. The legacy Iroha migration mutation must
use the same one-shot bounded submission path, persist a purpose-tagged exact hash before handoff,
re-derive its Iroha identity from the currently selected account immediately before preparing the
call, and resume only status reads after interruption. An already running exact-hash recovery must
accept the claim screen as an observer instead of signing again, and its task lifecycle must clear
atomically on every terminal or local-recovery exit; a watched subscription, stale cached identity,
reconnect resend, or missing/ambiguous purpose must never expose an unsafe retry action. Concurrent
`needsMigration` checks must be account-tokenized, and a late response after account change, claim
submission, or terminal success must not present a second claim screen. The retained app-wide
`hasMigrated` setting is dual-read upgrade evidence only, never authority to skip that query. A
versioned per-account completion marker may preserve public recovery evidence, but both the initial
check and every requested migration must still obtain an authoritative `needsMigration` result for
the same selected account before signing; the request token remains exclusive through the exact
signing boundary and durable pending-row handoff so a repeated tap cannot enter the pre-journal gap.
An authoritative `false` completes locally without submission. Production SORA2/Polkamarkt mutation
qualification still requires oversized-response and single-handoff tests in the release receipt.
Nexus committed instruction history is authoritative only when the MCP
`structuredContent.headers` object carries the complete bounded fanout count family with every
attempted route successful; a missing family, routed-by-only proof, partial family, or declared
route failure must fail closed without replacing the local pending overlay.

The legacy Jenkins job remains a build/test driver and is not a rollout or funded-canary
controller. Its `jenkins-library` dependency must resolve the exact authenticated Soramitsu
commit `65079bbe356bca4a3d5a1964e360498735afa1f0`; a branch, tag, default version, or a different
40-hex value is rejected. On 2026-08-09, authenticated GitHub GraphQL and Git object inspection
resolved that private repository's unprotected `master` head to this GitHub-valid signed commit,
tree `d48928bf7706be3fd7d6bb37aae43593c3ba5100`, and the reviewed iOS pipeline, parameters,
Fastfile, Gemfile, and base-pipeline blobs and SHA-256 values recorded in
`SoraPassport/Configs/ModernizationDependencies.conf`. The source review confirmed the current
Jenkinsfile interface, mandatory application tests, SORA Release bundle/team/profile parameters,
and the Release build handoff that executes this repository's strict build phase. This immutable
dependency pin does not qualify migration evidence, signing material, canaries, rollout authority,
or production mutations.

`qualificationContractSha256` binds the ordered relative path and SHA-256 identity of every
migration, recovery, lifecycle, deletion-preflight, pending-journal, project, test, checklist, and
verifier input listed by the release verifier, including both shared test schemes, the Jenkins
pipeline definition and dependency-provenance manifest, the SORA2 extrinsic builder/service,
application/chain-readiness wiring, the
retained settings-key definitions and per-account completion record, signing wrappers, and seed
signer used for backward-compatibility parity. Re-run the complete qualification whenever any
bound file changes. Never copy a prior receipt forward.

## Raw-bound observed collection (non-authorizing)

`SoraPassportMigrationEvidence.xcscheme` is the dedicated Release/physical-device evidence
scheme. Its exact test inventory is 198 `WalletModernizationTests`, 11
`WalletRecoveryCapabilityGateTests`, 12 `WalletRecoveryExporterTests`, and three
`WalletMigrationRetainedDeviceEvidenceTests`. The last three tests bind their schema-v3 attachments
to the installed production bundle identifier, the exact production IPA, the canonical projection
receipt and projector source, the raw installed-clone tree, equal production/installed canonical
projections, the installed executable, the run
UUID/challenge/source revision, and an owner-only, complete-protection schema-v3 observation ledger
at the fixed Application Support path. XCTest independently inventories every installed app file,
byte count, content hash, POSIX executable mode class, and normalized relative path using the same
versioned raw-tree record as the projector. It rejects extra, missing, aliased, symbolic, special,
empty, unsafe, casefold-colliding, NFC-colliding, or changing nodes. Equality with the collector's
independently rederived raw installed-clone record binds the installed canonical projection
without claiming that XCTest contains a second Mach-O parser. Successful attachment production also
proves a physical-device Release launch under the reviewed bundle ID. The owner-only ledger directory
must contain exactly `retained-device-observation-ledger-v3.json`; a stale v2 filename, stale schema,
or any unreviewed sidecar fails closed. The tests do not create that ledger and do not turn an external
scenario assertion into qualification authority: the retained-device controller must derive the
ledger from the actual Keychain and device-scenario run and retain the underlying restricted raw
evidence for independent review.

Before schema-8 evidence exists, the retained-device controller may invoke only the narrowly
scoped observed-only build capability:

```sh
/bin/sh SoraPassport/Scripts/build-ios-migration-evidence-candidate.sh \
  --build-ui-for-testing \
  --destination 'platform=iOS,id=RETAINED_DEVICE' \
  --derived-data-path /absolute/private/new-derived-data
```

The source-side Release closure can also be run without protected signing or device input:

```sh
/bin/sh SoraPassport/Scripts/verify-modernization-dependencies.sh \
  --lint-ios-migration-release-source-gate
```

That gate requires exactly 93 passing migration tests across the projector (30), installable clone
(3), exact-IPA controller (24), `.xctestrun` sanitizer (6), collector (15), and Release boundary
(15), plus 16 Release-reproduction/package mutation tests. It executes the eleven
projector/clone/controller/sanitizer/collector/qualification/build/reproduction-package
and non-promoting Release-test contract or template lints, parses every qualification-bound shell
entry point, parses the retained
harness, XCTest attachment producer, and UI runner with the Xcode Swift frontend, and checks the
fixed 26-key authorization, nonarchivable Release schemes, archive-derived clone reinstall,
`test-without-building`, deep-signature/provisioning inspection, and no-rebuilt-host invariants.
An absent suite, changed test count, stale authorization shape, symbolic source, malformed script,
or missing hook fails this gate closed.

Every simulator-eligible application XCTest can be executed with Release optimization on an arm64
simulator through the exact non-promoting wrapper:

```sh
release_test_root="$(mktemp -d /private/tmp/sora-ios-release-tests.XXXXXX)"
/bin/sh SoraPassport/Scripts/run-ios-release-tests.sh \
  --test \
  --destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4,arch=arm64' \
  --derived-data-path "${release_test_root}/DerivedData" \
  --result-bundle-path "${release_test_root}/SoraPassport-Release.xcresult"
```

The wrapper accepts only fresh outputs beneath an existing current-user-owned mode-0700 directory
outside the repository. Its build phase capability requires the exact Release main target, simulator
SDK/platform, disabled signing, enabled testability, and active arm64 architecture. It exits before
protected signing, archive, migration-evidence, funded-canary, and rollout admission. Consequently,
a passing simulator result is useful Release-regression evidence but cannot authorize a device build,
IPA, TestFlight upload, migration receipt, or production promotion.

The wrapper excludes exactly the three retained-device attachment methods and the one retained-device
UI method. Those methods require the registered physical device, exact-IPA installable clone, fixed
evidence environment, and signed authorization; they remain mandatory in the dedicated Release
evidence schemes and cannot be satisfied, skipped, or replaced by this simulator run.

The wrapper fixes the project, scheme, Release configuration, physical-device destination, and
`build-for-testing` action, and enables Swift testability only for these non-archivable XCTest
products. The three migration evidence producer/harness/runner sources carry targeted
`-warnings-as-errors` compiler flags; a global override is not used because reviewed package targets
may intentionally suppress their own warnings. Its build setting is accepted only when Xcode reports `ACTION=build`,
`DEPLOYMENT_LOCATION=NO`, the physical `iphoneos` SDK/platform, and the exact preserved production
target identity. The evidence scheme has three exact build entries and every one has
`buildForArchiving=NO`; the wrapper has no arbitrary Xcode arguments and cannot invoke `archive`,
`install`, `exportArchive`, collection, qualification, rollout, or upload. Its products and later
test output are candidate inputs only. This exception does not weaken an ordinary Release build,
production archive, or rollout gate: without the exact opt-in capability all Release builds still
take the strict modernization admission path.

That nonarchivable XCTest runner build is not the completed production IPA and must never be described
or hashed as if it were. The exact candidate bytes are created separately by the observed-only
production archive/export route:

```sh
/bin/sh SoraPassport/Scripts/archive-ios-migration-candidate.sh \
  --archive-and-export \
  --archive-path /private/owner-only/new-candidate.xcarchive \
  --export-path /private/owner-only/new-candidate-export
```

Both parents must already be current-user-owned mode-0700 directories outside the repository and
both output paths must be fresh. The wrapper creates a fresh mode-0700
`new-candidate.xcarchive.observed-control` sidecar beside the archive. Before Xcode starts, that
sidecar exclusively captures the complete qualification source-contract inventory and the exact
checked-in export-options bytes. Xcode export consumes that private plist snapshot, and the wrapper
rechecks the snapshot, its checked-in source, and the complete source contract after export before
it can publish the handoff. The wrapper fixes the production `SoraPassport` scheme, `Release`
configuration, generic physical-iOS destination, development team, bundle identity, archive action,
and checked-in `destination=export` App Store Connect export options. The archive compilation also
sets both Swift and C-family warnings-as-errors. It invokes only Xcode archive
and export; it has no upload or rollout action. During that archive, the main target still runs the
complete production modernization verifier. The exact candidate capability requires Xcode's
`ACTION=install`, `DEPLOYMENT_LOCATION=YES`, `iphoneos` platform/SDK, signing enabled, and the
preserved target identity. Only the receipt-dependent migration qualification section is deferred;
the source-contract/test inventory is still snapshotted and rechecked. Funded-canary and rollout
receipt admission are also deferred because they must bind the exported IPA. Dependency,
distribution-signing, runtime, provenance, static canary/rollout contract, and source-readiness gates
remain active during the archive; no candidate-bound receipt is inferred before the IPA exists.

After export, `create-ios-migration-candidate-handoff.py` opens the private export namespace and
requires exactly one bounded unique regular IPA and no symbolic, linked, special, or nested export
entry. It verifies the fixed bundle identifier, hashes the exact IPA and declared executable twice
through a stable descriptor, and exclusively writes
`ios-migration-candidate-handoff.json`. That handoff is always `status: observed`,
`releaseAuthorized: false`, `promotionAuthorized: false`, and carries an explicit blocker. Its
`exactAppTestHandoff.status` remains `pending` and `rebuiltTestHostAccepted` remains false. Raw
executable equality after different signing is neither required nor accepted as a substitute for
the canonical derivation proof.

The five-argument archive form above remains an observed-only input route. A candidate cannot reach
post-export admission until the primary export and one independent reproduction have instead been
created from two physically distinct, completely clean checkouts with distinct DerivedData,
archive, and export inodes:

```sh
# Run in clean checkout A. This export remains the immutable production candidate.
/bin/sh SoraPassport/Scripts/archive-ios-migration-candidate.sh \
  --archive-and-export-reproducible \
  --role primary \
  --derived-data-path /private/release-a/primary-DerivedData \
  --archive-path /private/release-a/primary.xcarchive \
  --export-path /private/release-a/primary-export

# Run the same revision in physically distinct clean checkout B.
/bin/sh SoraPassport/Scripts/archive-ios-migration-candidate.sh \
  --archive-and-export-reproducible \
  --role reproduction \
  --derived-data-path /private/release-b/reproduction-DerivedData \
  --archive-path /private/release-b/reproduction.xcarchive \
  --export-path /private/release-b/reproduction-export
```

Each command retains warnings-as-errors archive/export logs, canonical archive and export content
manifests, the source revision, six exact dependency manifests (four reviewed SwiftPM manifests plus
the IrohaSwift and NoritoBridge whole-tree manifests), the authenticated signing-continuity receipt,
and the raw IPA
digest in its private control directory. The second run may never replace the primary candidate.
Compare the two printed build-manifest paths with:

```sh
/usr/bin/python3 -B -I -S \
  SoraPassport/Scripts/verify-ios-release-reproducibility-package.py \
  --compare \
  --primary-ipa /private/release-a/primary-export/Sora.ipa \
  --reproduction-ipa /private/release-b/reproduction-export/Sora.ipa \
  --primary-build-manifest /private/release-a/primary.xcarchive.observed-control/primary-build-manifest.json \
  --reproduction-build-manifest /private/release-b/reproduction.xcarchive.observed-control/reproduction-build-manifest.json \
  --output /private/release-package/equivalence-receipt.json
```

The receipt uses `exact-ipa-bytes-v1` and records
`deterministicProductionExportDemonstrated: true` only when both raw IPA SHA-256 values are equal.
If Apple
signing/container metadata legitimately changes the outer bytes, it explicitly records
`exactIpaByteEquality: false` and uses `canonical-signed-application-equivalence-v1` only after the
complete canonical installed-app tree, executable and resources, Info.plist identity, entitlement
projection, full SHA-256 CodeDirectory identities, embedded profile bytes/projection/UUID/name,
signed entitlements, application leaf signing-certificate digest, and all embedded
developer-certificate digests are exactly equal and match the authenticated retained pins. Any mismatch blocks;
the policy never describes unequal IPA containers as byte-identical.

After the external schema-v8 qualification receipt and detached reviewer signature really exist,
seal the untouched primary IPA with both builds, logs, manifests, dependencies, equivalence receipt,
authenticated signing-continuity and vendored-binary receipts, and qualification receipt/signature:

```sh
/usr/bin/python3 -B -I -S \
  SoraPassport/Scripts/verify-ios-release-reproducibility-package.py \
  --seal \
  --package /private/release-package/sora-qualified-ipa.zip \
  --primary-ipa /private/release-a/primary-export/Sora.ipa \
  --equivalence-receipt /private/release-package/equivalence-receipt.json \
  --primary-build-manifest /private/release-a/primary.xcarchive.observed-control/primary-build-manifest.json \
  --reproduction-build-manifest /private/release-b/reproduction.xcarchive.observed-control/reproduction-build-manifest.json \
  --qualification-receipt /absolute/ios-migration-qualification.json \
  --qualification-signature /private/reviewer/qualification.sig
```

The package is exclusively created mode 0600 beneath a current-user-owned mode-0700 parent. Its
`sora-ios-qualified-ipa-package-v3` fixed ZIP inventory contains only mode-0600 regular members and
binds both `signingIdentityReceiptSha256` and `vendoredBinaryReceiptSha256`; symbolic links, hard links, unexpected
members, changed logs/manifests, or a changed candidate fail closed. The download verifier streams
and byte-compares the packaged candidate to the primary IPA. Post-archive migration admission
requires `IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH`, authenticates both protected dependency/signing
receipts, verifies the package, reauthenticates both receipts against the packaged digests, then
authenticates the real v8 receipt and requires its digest to equal the packaged receipt before any
canary or cohort authority is consumed. It also requires the package verifier's IPA SHA-256 to equal
the migration verifier's IPA SHA-256, then repeats the descriptor-safe package/candidate verification
immediately before returning so a path rebind cannot join evidence from two different IPAs.

Archive/export completion alone is not signing or migration qualification. The exact-IPA controller
must still extract the exported IPA through its bounded ZIP reader, run
`codesign --verify --deep --strict`, decode and compare the embedded provisioning profile and signed
entitlements, and bind those results to the installed archive-derived clone before XCTest. The
collector repeats the tested-IPA signature/profile/entitlement verification, and post-archive
promotion rehashes the completed IPA against the signed schema-v8 receipt. Distribution credentials,
the retained profile and registered device, the physical 8-Keychain/10-device run, producer and
reviewer signatures, sequence authority, and final receipt remain protected external blockers; the
source gate neither supplies nor fabricates any of them.

After the exact IPA is exported, the retained-device owner creates the fixed non-authorizing,
registered-device-signed clone directly from those archive bytes:

```sh
/bin/sh SoraPassport/Scripts/create-ios-migration-installable-clone.sh \
  --create \
  --ipa /private/owner-only/candidate-export/Sora.ipa \
  --provisioning-profile /private/owner-only/registered.mobileprovision \
  --signing-identity-sha1 40-lowercase-hex \
  --registered-device-udid RETAINED_DEVICE \
  --output-root /private/owner-only/fresh-installable-clone \
  --qualification-contract-sha 64-lowercase-hex
```

The bound projector strictly opens the exact IPA ZIP and complete installed-clone app tree; rejects unsafe,
duplicate, colliding, linked, special, empty, or changing inputs; preserves production bundle, team,
application-identifier, and Keychain-access-group identity; and recognizes only reviewed public
Mach-O/fat/load-command shapes. Its versioned canonical projection includes the main executable,
every nested Mach-O/framework/helper, and every resource. The only exclusions are parsed terminal
`LC_CODE_SIGNATURE` payloads and validated signature-derived `__LINKEDIT` fields; direct-child
`_CodeSignature/**` and `embedded.mobileprovision` material at recognized signed-bundle roots; the
two exact scheme-bound `PlugIns/SoraPassport{,Integration}Tests.xctest/**` roots; and the fixed,
enumerated XCTest runtime framework/dylib roots present in a build-for-testing host. Production IPAs
must contain none of that XCTest-only material. Every Mach-O's XML and DER entitlement slots are
decoded, required to be semantically identical, and retained per relative path; the fixed root-owned
`/usr/bin/derq` decoder identity is receipt-bound. Only `aps-environment`, `beta-reports-active`, and
`get-task-allow` may differ, while nested identity/capability drift fails closed. Unknown commands,
nonterminal or overlapping signatures, any non-signature file range reaching signing material,
invalid page-rounded `__LINKEDIT` mappings, fat padding, or an unreviewed exclusion is rejected.

The resulting canonical-projection receipt v2 is canonical `status: observed` and
`releaseAuthorized: false`. Its projector-internal `releaseTestHost` label identifies the supplied
archive-derived clone, not an XCTest-built host. It binds the exact production IPA SHA-256, raw
installed-clone tree and executable hashes/counts, identical production/installed canonical projection records, every per-path
entitlement record/delta, exact exclusion list, and the projector plus qualification source
contract. It does not authorize release or claim signing validity. The collector re-executes the
captured contract-bound projector against protected raw bytes, validates the non-authorizing
installable-clone receipt, runs `codesign --verify --deep --strict` on both the extracted production app and installed clone, and requires the installed
physical-device raw-tree equality/launch proof described above.

The retained-device authority must then run the complete physical-device suite against that exact
installed clone. An operator with release credentials
could still manually upload any exported file outside this repository, so operational policy and
the protected release controller must forbid direct upload. Supported promotion always requires
the schema-8 qualification and post-export gate to re-hash this same admitted IPA digest.

`collect-ios-migration-evidence.sh --collect` accepts only a protected absolute input root outside
the repository with this fixed layout:

- `request.json` using `sora-ios-wallet-migration-collection-request-v3` and the exact production
  IPA, installed tree/executable, equal canonical projections, projection receipt, and projector-source identities;
- `application/Sora.ipa`, the exact signed production app;
- `application/SoraPassport.app`, the exact archive-derived installable clone;
- `application/canonical-projection-receipt-v2.json`, the canonical observed projection receipt;
- `application/installable-clone-receipt-v1.json`, the protected non-authorizing clone receipt;
- `tests/Migration.xcresult`, containing the exact 224 passing test identifiers and three
  test-associated reserved JSON attachments;
- `snapshots/index.json` and `snapshots/data/<snapshotId>/{source,migrated}`, containing the
  retained Core Data/settings bundles.

The collector opens that tree through descriptor-anchored, no-follow snapshots, rejects aliases,
hard links, special nodes, path-normalization collisions, malformed IPA/xcresult inputs, simulator
runs, mismatched executable identity, unexpected/skipped/retried tests, unreviewed attachments,
Core Data schema drift, duplicate wallet identities, selection/settings drift, and unconsumed WAL
state. It rechecks the raw tree and shared source-contract snapshot immediately before exclusive
no-replace publication. Its public output is exactly one observed-only collection receipt plus
four privacy-safe schema-v4 aggregate containers. Every output carries `status: observed`,
`releaseAuthorized: false`, and the exact non-authorizing blocker. Raw xcresult, retained stores,
Keychain values/identifiers, device identifiers, and free-form device logs remain in the protected
handoff and are never copied into the public output.
Every reviewed device-event projection hashes the event outcome plus its start/finish timestamps;
each event, the aggregate event span, and the xcresult start/finish must fit the same ordered
48-hour retained-device controller window.

The collector saves the full source-contract entry inventory before raw processing. Every
point-of-use read of `SettingsExtension.swift` and the four authoritative test/producer sources is
descriptor-anchored and must match that saved entry's exact byte count and SHA-256; a transient
change restored before the final whole-contract recheck is still rejected.

`Jenkinsfile.migration-evidence` is a separate non-promoting collection entry point. It accepts a
completed protected raw namespace, runs the collector twice into fresh owner-only external
namespaces, byte-compares all five outputs, and archives only the observed public artifacts. It
rejects qualification sequence/signature/private-key, funded-canary, rollout-controller, and
production-mutation authority in its environment. It neither builds the raw run nor creates the
protected observation ledger; those remain responsibilities of the separately controlled
retained-device runner. It never calls `--verify-qualified`, writes a qualification receipt/trust
root/signature, assigns an append-only sequence, or promotes a build.

Observed collection output remains non-authorizing by itself. Schema-8 admission accepts it only
when the signed v4 evidence manifest and signed v8 receipt bind the protected raw-input digest,
challenge, collection receipt, and all four aggregate bytes, and the validator independently
reproduces the complete five-file output from the same protected raw root.

## Authenticated evidence admission

`SoraPassport/Scripts/verify-ios-migration-qualification.sh --verify-qualified` is the only
admission path for a schema-8 receipt. The Release verifier consumes its authenticated receipt
SHA-256 and then evaluates all aggregate matrix assertions against an immutable copy of those
same bytes. Template linting is hermetic and can never emit a qualifying receipt hash.

Promotion has an additional post-archive boundary. The rollout controller invokes
`verify-ios-migration-promotion-ipa.sh --verify-qualified-ipa /absolute/completed.ipa` only after
the final IPA exists. The underlying validator authenticates the complete schema-8/v4 evidence
and its protected pins first; only then does it open the supplied IPA without following a symbolic
link, retain that exact descriptor, hash its bounded bytes, and compare the digest with the
protected app-build identity and raw collection's tested-IPA identity. It re-hashes the same open
descriptor and rejects any metadata/path rebinding before returning the one authenticated receipt
hash together with the admitted IPA SHA-256. The rollout controller strictly parses both values,
requires its own first candidate hash to equal the admitted digest, and requires its final candidate
rehash to equal both that digest and its first hash. The wrapper itself never builds, exports,
uploads, advances a cohort, or grants rollout
authority. `verify-production-rollout.sh` requires this successful exact-IPA admission before it
consumes any rollout-chain authority, so a separately rebuilt, re-signed, or re-exported IPA cannot
reuse migration evidence from another byte sequence.

The admission path requires fixed regular, non-symbolic files named
`ios-migration-qualification.json`, `ios-migration-qualification-evidence.json`, and
`ios-migration-qualification-trust.json`. It also requires detached signatures and public-key
files supplied by the protected release environment. The trust-root SHA-256 and both public-key
PEM SHA-256 values must be independently protected environment pins; values carried only by the
trust JSON never authorize themselves. The device-evidence producer and independent reviewer
must be distinct enabled ECDSA P-256 roles. The reviewer signs the exact receipt bytes; both roles
sign the exact evidence-manifest bytes. Detached signatures use the DER ECDSA form accepted by
`openssl dgst -sha256 -verify`; textual/base64 wrappers are not accepted.
Different PEM encodings are not sufficient separation: the verifier canonicalizes both public keys
to named-curve, uncompressed-point SPKI DER and rejects the same P-256 public point under two role
labels, including compressed/uncompressed input-encoding aliases.
Role IDs are non-secret controller labels and must use the
`ios-migration-device-producer-…` and `ios-migration-independent-reviewer-…` prefixes; raw
hashes, UUIDs, addresses, or key material are not accepted as IDs.

The protected release environment supplies `IOS_MIGRATION_QUALIFICATION_SOURCE_REVISION`,
`IOS_MIGRATION_QUALIFICATION_RUN_ID`, `IOS_MIGRATION_QUALIFICATION_SEQUENCE_NUMBER`,
`IOS_MIGRATION_QUALIFICATION_APP_BUILD_IDENTITY_SHA256`,
`IOS_MIGRATION_QUALIFICATION_TRUST_SHA256`,
`IOS_MIGRATION_QUALIFICATION_RAW_INPUT_ROOT`,
`IOS_MIGRATION_QUALIFICATION_RAW_INPUT_SET_SHA256`,
`IOS_MIGRATION_QUALIFICATION_RUN_CHALLENGE_SHA256`, and
`IOS_MIGRATION_QUALIFICATION_COLLECTION_RECEIPT_SHA256`, both role-specific public-key SHA-256 pins and
absolute PEM paths, and the three absolute detached-signature paths. Their absence is a release
blocker; the repository does not provide fallback values. The protected run UUID and app-build
identity must both be nonzero; all-zero sentinels cannot identify or authorize a qualification run
or release build.
The protected sequence value is the controller's append-only high-water mark: a run may consume it
once, and a value at or below the last consumed sequence must be rejected before publication. This
repository deliberately does not synthesize that external ledger or infer monotonicity from a
clean checkout.

The evidence manifest is exact `sora-ios-wallet-migration-evidence-v4`. It binds the same run,
challenge, raw-input set, sequence, source revision, app build, generic device classes, OS builds,
qualification-contract digest, trust root, roles, five fixed paths, byte counts, hashes, and
chronology as the receipt and collection. The run may last at most 48 hours, independent review
evidence production must follow the observed run finish by at most 24 hours, independent review
must follow evidence production by at most 24 hours, qualification must follow review by at most
24 hours, and the receipt expires after seven days. The protected run ID, sequence, source
revision, app-build digest, trust digest, and key digests must all match external release inputs.

Only after all three detached signatures verify, the validator opens and snapshots these fixed
collector outputs rather than trusting copied hash strings:

- `ios-migration-collection-receipt.json` using exact observed collection-receipt v3 and raw-input-set v3;
- `ios-migration-retained-snapshot-manifest.json` using contract
  `sora-ios-wallet-migration-retained-snapshot-manifest-v4`;
- `ios-migration-tests.xcresult.zip`, which must be a bounded valid ZIP with no unsafe, duplicate,
  or symbolic-link entries and must contain the exact aggregate
  `ios-migration-test-summary.json` v4 record;
- `ios-migration-keychain-evidence.json` using contract
  `sora-ios-wallet-migration-keychain-evidence-v4`;
- `ios-migration-device-execution-evidence.json` using contract
  `sora-ios-wallet-migration-device-execution-evidence-v4`.

The validator independently inventories the owner-only, non-symbolic raw root using the collector's
canonical raw-input projection, checks the protected digest and collection counts, executes the
exact descriptor-opened collector source into a fresh private temporary namespace, and
byte-compares every one of the five outputs. It compares the recomputed start/finish chronology,
run, challenge, source, app identity, qualification contract, raw digest, and collection receipt
hash, then inventories the original raw root again and rechecks every signed/source/artifact input.
The collector deliberately writes each deterministic artifact `producedAtEpochSeconds` and the
collection `collectedAtEpochSeconds` as the xcresult's observed run-finish epoch, not as the later
filesystem creation time; schema-8 therefore bounds signed evidence production directly to that
recomputed finish time so a stale raw run cannot be recollected and newly authorized.
The temporary recomputation remains observed and is deleted; the validator never creates a
qualified receipt, evidence manifest, signature, trust root, or repository artifact.

Every repository-owned component from the canonical project root to each fixed file is opened
without following symbolic links. The release verifier applies the same no-alias rule to every
qualification-contract input, including both authoritative Core Data model contents, and rechecks
their exact hashes after aggregate receipt evaluation.

Each JSON artifact is strict aggregate-only observed v4 evidence bound to the same run, challenge,
raw input set, source, release identity, and signed chronology. Unknown root fields, duplicate JSON keys, unbounded data,
or recursively embedded account/address/device-identifier/secret/key/payload fields reject the
qualification. The checked-in `*.blocked.json` files contain only immutable contract labels and
fixed paths plus null/zero/false/empty evidence state (apart from the explicit aggregate-only
privacy marker). They are not authorities, do not contain keys or signatures, and cannot be renamed
or promoted into qualified evidence.

The retained-snapshot aggregate must exactly match the receipt's snapshot count and source-model
list and carry assertions for regular files, verified hashes, and read-only store opens. The
Keychain aggregate must exactly match successful/failing source counts and the receipt's
identity/accessibility assertions, with no credential rewrite or raw values. The device aggregate
must exactly match Core Data and interruption counts plus reinstall/upgrade, rollback, low-storage,
recovery-export, and process-death/restart assertions. The ZIP summary must exactly match all four
declared suite counts (198 + 11 + 12 + 3 = 224) and zero failure, unexpected-failure, skipped, and
expected-failure counters. Independent byte reproduction proves that these public aggregates are
the collector's derivation from the pinned raw namespace; producer and reviewer signatures remain
necessary authentication and do not replace review of the restricted scenario material.

The focused WalletModernization and recovery-exporter unit suites are necessary but
not sufficient. CoreSimulator does not surface `NSFileProtectionKey`, so simulator
builds compile a namespaced inode-xattr emulator solely to exercise the exact
rename/hard-link/rollback and mismatch state machine. Physical-device builds do not
compile that fallback and still reject missing Foundation protection metadata. A
simulator pass is therefore not evidence that an installed device's Keychain,
release Core Data snapshots,
filesystem protection classes, process-death restart, or rollback behavior passed.
Qualification also requires retained release-produced
database/settings snapshots, immutable encrypted Keychain identity evidence,
interruption/restart execution, reinstall/upgrade and rollback execution, low
storage execution, and recovery archive validation on the release simulator/device
contract. The aggregate receipt remains absent until that independently reviewed
run publishes it; never synthesize or copy it from the unit harness.
