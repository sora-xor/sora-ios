# Production rollout qualification v3

The staged-rollout validator's no-argument qualification mode is a post-export promotion gate. It
is not itself an Xcode build phase, and the current Jenkins pipeline is not a reviewed release
controller. A missing target is an error, not a successful no-op. Ordinary builds call its
non-promoting template mode:

```sh
/bin/sh SoraPassport/Scripts/verify-production-rollout.sh --lint-templates
```

The modernization build verifier also runs
`SoraPassport/Scripts/test-production-rollout-contract.py`. That hermetic regression uses an
ephemeral synthetic controller and tiny synthetic IPA in `/private/tmp` to execute all four
qualified target paths and 35 fail-closed mutations. The success paths traverse the full dual-controlled
Taira and Minamoto validator; mutations cover missing full funded evidence, preclaimed readiness,
finality below the committed transaction height, a trusted first height above the attested finality,
missing live bounded sequential/stateful successor verification, invalid challenge/finality binding, an invalid
finality-verifier native ABI receipt, retroactively reviewed finality trust or low-value policy,
cross-network canary-run reuse, missing admission, legacy v2 rollout replay, an internally consistent
signed exact legacy PI v2 envelope replay, independently signed false mobile-config-health and
history-height-contract PI receipts, non-newer Taira epochs at canary and rollout admission, and missing/extra historical PI and
cohort evidence; it never installs a key or writes production
evidence. Template mode validates the checked-in blocked templates and exact controller trust-root
schema without claiming release qualification. The real trust root may remain explicitly blocked
or be replaced by a reviewed qualified root; ordinary builds never infer rollout approval from
either state.

Before any rollout receipt or cohort authority is consumed, the no-argument path also calls the
iOS migration post-archive admission with `PRODUCTION_ROLLOUT_IPA_PATH`. That admission first
authenticates the complete schema-8 retained-device qualification, then hashes the exact open
completed IPA and requires it to equal the protected and raw-collected tested-IPA identity. A
migration receipt for a different export, signature, or byte sequence cannot authorize rollout.
The same admission requires `IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH` and streams the fixed,
owner-only sealed package through the download verifier. It must contain that exact primary IPA, an
independently reproduced Release equivalence receipt, both clean build/archive/export manifests and
logs, all six dependency manifests, and the authenticated schema-v8 qualification receipt/signature.
The package check runs first; qualification then authenticates that exact packaged receipt digest.
Both complete before any funded-canary or rollout-cohort authority is consumed.
The dedicated observed-only migration `build-for-testing` wrapper cannot archive or promote and is
not a substitute for this post-export check.

The separate observed-only candidate archive wrapper can create the exact production IPA while
deferring only receipt-dependent migration admission; it still runs every other Release gate and
cannot upload or advance a rollout. Its protected handoff remains explicitly non-authorizing until
the external retained-device authority proves tests ran against the archived executable. The wrapper
snapshots the complete qualification source contract and the no-upload export plist before archive,
uses that private plist snapshot for export, and rechecks both source identities before creating the
handoff. The fixed observed derivation controller then proves the Release test host has the exact
production IPA's versioned signature-insensitive app projection, while retaining its own raw tree,
signature validity, and installed-device equality as separate bindings. That projection decodes and
cross-checks XML/DER entitlement slots, proves every non-signature Mach-O range ends before the
terminal signature, and excludes only recognized signed-bundle material plus the exact scheme-bound
XCTest bundles/runtime roots (which are forbidden in the production IPA). Repository scripts cannot
prevent a credentialed operator from manually uploading outside
the workflow, so
the release controller and operational policy must forbid direct upload and accept only the exact
IPA digest returned by migration post-export admission and revalidated by this rollout gate.

## Current hard blocker

`production-rollout-controller-trust.json` deliberately has `status = blocked`, no controller ID,
and no public-key hash. Production validation cannot pass until the authorized release system
provides a reviewed ECDSA P-256 controller public key and independently protects the SHA-256 of the
updated trust-root JSON. No key, signature, signing identity, or qualification evidence is invented
in this repository. Once that reviewed root is installed, ordinary build qualification accepts its
qualified shape, while the post-export gate still requires the independently protected exact file
hash and matching public key.

Rollout v3 is intentionally wire-incompatible with v2 because its exact identity now requires the
funded Nexus admission receipt plus both exact Taira and Minamoto canary receipt hashes. A protected
controller must be reviewed and deployed with the v3 schema before promotion. No v2 rollout receipt
may be used as a v3 predecessor; the first qualified v3 candidate starts a new chain at 1%.

The existing iOS production-signing fixture is also blocked until the retained distribution
certificate, provisioning profile, entitlements, application identifier, Keychain access groups,
and App Store signing continuity have been matched against the exported application.

## Required controller inputs

A reviewed post-export controller supplies one target plus absolute paths to the actual IPA and
detached ECDSA/SHA-256 signed receipts:

- `PRODUCTION_ROLLOUT_TARGET_PERCENT`: exactly `1`, `5`, `25`, or `100`;
- `PRODUCTION_ROLLOUT_IPA_PATH`;
- `IOS_RELEASE_QUALIFIED_IPA_PACKAGE_PATH`, whose candidate member is byte-for-byte the same primary
  IPA;
- every protected `IOS_MIGRATION_QUALIFICATION_*` pin/path required by
  `ios-migration-qualification-README.md`, including the raw root, run/challenge/sequence,
  collection receipt, trust/key pins, detached signatures, and exact app-build SHA-256;
- `PRODUCTION_CANDIDATE_SOURCE_REVISION`: exact lowercase 40-character release revision;
- `PRODUCTION_ROLLOUT_TRUST_ROOT_SHA256`: trust-root fixture hash pinned outside the source tree;
- `PRODUCTION_KEYCHAIN_ACCESS_GROUPS_SHA256`: canonical retained production Keychain-group digest,
  independently pinned outside the controller receipt;
- `PRODUCTION_ROLLOUT_CONTROLLER_PUBLIC_KEY_PATH`;
- `PRODUCTION_QUALIFICATION_RECEIPT_PATH` and
  `PRODUCTION_QUALIFICATION_RECEIPT_SIGNATURE_PATH`;
- `PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH` and
  `PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_SIGNATURE_PATH`;
- `FUNDED_NEXUS_CANARY_TRUST_ROOT_SHA256`, the pinned independent-reviewer key,
  `FUNDED_NEXUS_CANARY_ADMISSION_RECEIPT_PATH` and signature, and the exact reviewer-signed
  `TAIRA_FUNDED_CANARY_RECEIPT_PATH` / `MINAMOTO_FUNDED_CANARY_RECEIPT_PATH` pairs;
- `PI_PRODUCTION_PROBE_RECEIPT_PATH` and `PI_PRODUCTION_PROBE_SIGNATURE_PATH`;
- `PRODUCTION_ROLLOUT_RECEIPT_PATH` and `PRODUCTION_ROLLOUT_RECEIPT_SIGNATURE_PATH`.

Targets 5, 25, and 100 additionally require the complete prior receipt/signature chain. Target 5
requires `PRODUCTION_ROLLOUT_RECEIPT_1_PATH` and
`PRODUCTION_ROLLOUT_RECEIPT_1_SIGNATURE_PATH`, plus
`PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_1_PATH` and
`PRODUCTION_ROLLOUT_PI_PROBE_RECEIPT_1_SIGNATURE_PATH`; target 25 also requires the corresponding
four names with `1` replaced by `5`; target 100 also requires the same four names with `1` replaced
by `25`. Missing and extra chain inputs both fail. Every later target also requires the current
gate's:

- `PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_PATH` and
  `PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_SIGNATURE_PATH`;
- `PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_PATH` and
  `PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_SIGNATURE_PATH`.

Target 25 additionally supplies the historical gate-5 cohort evidence through
`PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_PATH`,
`PRODUCTION_ROLLOUT_TELEMETRY_ATTESTATION_5_SIGNATURE_PATH`,
`PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_PATH`, and
`PRODUCTION_ROLLOUT_DISTRIBUTION_ATTESTATION_5_SIGNATURE_PATH`. Target 100 supplies that same
gate-5 set plus the same four names with `5` replaced by `25`. A numeric component names the rollout gate whose
`completedCohort` is being revalidated, not the cohort percentage inside that object.

Every JSON object is strict UTF-8 with exact per-object keys. Duplicate keys after JSON escape
decoding, floating-point values, non-finite values, unknown keys, wrong nesting, and overlarge files
are rejected before `plutil` is used for fixed-field extraction. Non-canonical negative-zero
integers and all-zero source/hash placeholders are also rejected. Every bounded
trust/key/receipt/signature input is first copied through
one stable, non-symlink file descriptor into a private read-only snapshot, so semantic parsing,
fixed-field extraction, and signature verification consume the same bytes. Detached signatures
must verify against the externally hash-pinned controller key. The IPA is opened directly through a
stable non-symlink descriptor, checked for mutation and path rebinding, and hashed again at the end.

## Signed evidence contracts

The controller signs these exact contracts:

- `sora-ios-production-qualification-v2` binds the source revision, build-manifest hash, and exact
  qualification-evidence manifest hash; it requires wallet migration, SORA2 runtime 130,
  Minamoto/Taira send implementation, PI,
  Polkamarkt, dependency provenance, native signer/canary, production signing, and privacy telemetry
  to all be qualified. It deliberately contains no pre-artifact funded-canary boolean: the exact
  post-export Taira/Minamoto receipts and admission below are the only funded qualification evidence.
- `sora-ios-production-artifact-identity-v2` binds that qualification receipt to the actual IPA
  SHA-256/size/ZIP inventory, one `Payload/*.app`, Info.plist and executable hashes, app version and
  build, embedded provisioning-profile hash, source revision/build manifest, reviewed runtime,
  distribution certificate/profile, signed entitlements, application identifier, Keychain groups,
  reviewed inspection-tool and code-sign/provisioning evidence digests, nested code-signing
  verification, and App Store signing continuity.
  The application identifier must remain exactly `YLWWUD25VZ.co.jp.soramitsu.sora`, and the signed
  Keychain-group digest must equal the independently protected retained-production value.
- `sora-ios-funded-nexus-canary-admission-v1` is signed by the distinct pinned independent reviewer
  and binds that same IPA/artifact receipt to the exact qualified Taira and Minamoto funded-canary
  receipt bytes. The stable rollout candidate binding includes the admission and both network
  receipt hashes, while the full canary contract separately enforces dual approval, one-use
  append-only consumption, reviewed signer/finality trust, and privacy-redacted ordered stages.
- `sora-pi-production-capability-probe-v3` binds an at-most-five-minute-old production PI response
  to canonical SORA2 genesis/runtime/finalized block hash, zero-lag indexed block hash, a successful
  index timestamp also at most five minutes old, an atomic mobile-config revision, exact true
  `mobileConfigHealthBound` and `historyBlockHeightContractDeployed` proofs, all five enabled release
  capabilities, and canonical nonzero Minamoto/Taira finalized checkpoints.
- `sora-mobile-production-rollout-v3` binds the exact candidate, upstream and artifact receipts,
  exact PI receipt and checkpoint, rollout sequence, current evaluation, and explicit authorization.
- `sora-ios-distribution-cohort-attestation-v1` proves the same App Store build was held at the stated
  cohort and time interval.
- `sora-ios-rollout-telemetry-attestation-v1` supplies the exact privacy-safe aggregate counters and
  dataset hash used by the rollout receipt.

Polkamarkt full-extrinsic qualification deliberately has two source states. Before independent
qualification, `polkamarkt-runtime-v130.json` must have the exact blocked shape:
`reviewedWebAndRuntimeReceiptQualified=false`, `reviewedReceipt=null`, and the exact nonempty
blocker. After reviewed promotion, source tests require the exact v1 receipt shape rather than the
blocked tuple. This keeps the ordinary 198-test modernization build runnable in either state
without treating a promoted boolean as evidence. Release and post-export promotion remain hard
gates: they require the v1 reviewed receipt, exact runtime-130 metadata/genesis identity, five ordered
buy/sell/claim vectors, and reference/Android/iOS parity for full call bytes, signing prehash, valid
sr25519 signatures, signed extrinsic round-trips, and decoded projections. Sr25519 signature bytes
need not be equal across implementations, but every signature must verify over the identical
prehash. No source-only assertion, clean Debug build, or promoted boolean substitutes for the
independently signed composite receipt. Release additionally requires the independently protected
review-key SPKI SHA-256 and exact qualified-fixture SHA-256 through
`POLKAMARKT_EXTRINSIC_REVIEW_KEY_SHA256` and
`POLKAMARKT_EXTRINSIC_QUALIFIED_FIXTURE_SHA256`; neither expected value may be derived from the
checkout being qualified. The exact whole-file pin authenticates the independently reviewed
composite. The iOS Release shell gate does not claim to implement sr25519 verification or runtime
metadata decoding; those facts must be proven in the guarded producer runs bound by the signed
review before that fixture hash is approved.

Android and iOS Release environments must use the same protected qualified-fixture pin. Android
production CI must check out a protected exact iOS source revision, while iOS Release CI must supply
`POLKAMARKT_ANDROID_SOURCE_ROOT`, `POLKAMARKT_ANDROID_SOURCE_REVISION`, and
`POLKAMARKT_ANDROID_FIXTURE_PATH` for a protected exact Android checkout. Both gates compare the
sibling fixture byte-for-byte; missing sibling provenance fails closed.

The controller-signed artifact receipt is the authority for direct `codesign`, provisioning, signed
entitlements, application-identifier, Keychain-group, and nested-code checks. The validator also
independently opens the IPA as a bounded ZIP, rejects duplicate, encrypted, traversal, symlink,
multi-app, and overlarge entries, parses its Info.plist, and compares its bundle ID, version, build,
executable, provisioning-profile, ZIP inventory, size, and hashes with the signed receipt.

## Binding rules

The candidate binding is stable across the 1% -> 5% -> 25% -> 100% sequence. It hashes the following
newline-delimited fields, in this exact order and with no trailing newline:

```text
platform=ios
candidateArtifactSha256=...
artifactIdentityReceiptSha256=...
productionQualificationReceiptSha256=...
fundedNexusCanaryAdmissionReceiptSha256=...
fundedTairaCanaryReceiptSha256=...
fundedMinamotoCanaryReceiptSha256=...
tairaDeploymentManifestSha256=...
tairaDeploymentAdmissionSha256=...
tairaCurrentChainId=...
tairaCurrentGenesisHash=...
sourceRevision=...
candidateBuildManifestSha256=...
bundleIdentifier=co.jp.soramitsu.sora
developmentTeam=YLWWUD25VZ
appVersion=...
buildNumber=...
appStoreBuildIdentifier=...
sora2NetworkRevision=411dcdb70c5c00b21482a44d02334840d5f338c6
runtimeSpecVersion=130
runtimeTransactionVersion=130
runtimeMetadataSha256=2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf
```

Each gate separately hashes the exact signed PI receipt plus SORA2 genesis/finalized height/hash and
Minamoto/Taira finalized heights/hashes. Its evaluation binding combines candidate binding, exact PI
receipt, capability/config revision, finalized-checkpoint binding, sequence/from/target, and current
evaluation epoch. Thus moving checkpoints remain auditable without changing candidate identity.

The capability projection is SHA-256 over these exact newline-delimited fields with no trailing
newline:

```text
schemaVersion=3
configRevision=...
endpoint=https://pi.soramitsu.io/graphql
serviceId=pi.soramitsu.io
ecosystem=sora2
chainId=sora:mainnet
network=mainnet
readOnly=true
workerReady=true
mobileConfigHealthBound=true
historyBlockHeightContractDeployed=true
nexusAvailable=true
nexusSendsAvailable=true
polkamarktVisible=true
polkamarktMutationsAvailable=true
tairaDefaultVisible=true
```

PI `sora-pi-production-capability-probe-v2` receipts are wire-incompatible with v3 and are rejected.
The exact retired v2 envelope and capability projection are constructed only inside the hermetic
negative replay; no operational validator, projection, producer path, or receipt accepts v2.
The protected production PI producer/controller must be upgraded and independently compatibility-
qualified for v3; protected producer compatibility remains a hard release blocker until that review
is complete.

The finalized-checkpoint projection is:

```text
piProbeReceiptSha256=...
sora2GenesisHash=...
sora2FinalizedHeight=...
sora2FinalizedBlockHash=...
minamotoChainId=00000000-0000-0000-0000-000000000753
minamotoGenesisHash=...
minamotoFinalizedHeight=...
minamotoFinalizedBlockHash=...
tairaChainId=<authenticated-manifest currentChainId>
tairaGenesisHash=...
tairaFinalizedHeight=...
tairaFinalizedBlockHash=...
```

The repository never chooses between the two known Taira UUIDs. Before artifact, funded-canary, or
rollout validation, the controller re-verifies one fresh owner-only manifest with distinct operator
and reviewer P-256 signatures, independently pinned public-key digests, and the protected
`IOS_TAIRA_DEPLOYMENT_*` inputs. Either UUID may be designated current; the other is transportless
recovery evidence. The admitted current epoch supplies the exact nonzero genesis and canonical
public HTTPS origin, and only its explicit `/v1/mcp` route is accepted. `taira.sora.org` is a
convenience route and is rejected. The manifest and admission digests are embedded in the signed IPA
and transitively bound above; omission or disagreement blocks rollout.

iOS pending Taira journals add an exact manifest-digest/deployment-epoch/genesis tuple to the chain
UUID. Rows without that tuple—including legacy schema-77 rows—or with another admitted epoch remain
recovery-only even when their UUID equals the newly admitted current UUID. They are never pruned,
resumed, reconciled, or mutated as current evidence.

The evaluation projection is:

```text
candidateBindingSha256=...
piProbeReceiptSha256=...
piCapturedAtEpochSeconds=...
capabilitySnapshotSha256=...
finalizedCheckpointBindingSha256=...
sequenceNumber=...
fromCohortPercent=...
targetCohortPercent=...
evaluatedAtEpochSeconds=...
authorizedAtEpochSeconds=...
```

## Append-only sequencing and telemetry

Target 1 requires sequence 1, transition 0 -> 1, a null prior-receipt hash, and no cohort evidence.
Each later target supplies every signed predecessor back to that null-terminated receipt: 1 -> 5 is
sequence 2, 5 -> 25 is sequence 3, and 25 -> 100 is sequence 4. The validator walks every adjacent
hash link, rechecks every controller signature and exact target schema, recomputes each retained
checkpoint/evaluation binding from the exact historical signed PI receipt, rechecks the historical
worker-success/capture/evaluation chronology, and requires the same candidate and capability
identity. Every historical completed cohort is replayed against its exact signed telemetry and
distribution attestations rather than trusting digest-shaped fields in a prior gate. At every
link it compares all network genesis/finalized heights/hashes, rejects a genesis change or height
regression, and rejects a different hash at an unchanged finalized height. A missing grandparent,
missing historical evidence object, random ancestor hash, rewritten identity, or backdated
self-asserted cohort is not accepted.

Each gate carries `authorizedAtEpochSeconds` inside the signed receipt. Authorization must follow
evaluation by no more than 30 seconds, and each completed cohort starts strictly after the prior
authorization, lasts at least 172800 seconds, and binds an exact signed distribution attestation
plus exact signed telemetry attestation. iOS rollout v3 intentionally uses the one externally
hash-pinned, reviewed controller trust root for both evidence certification and gate authorization;
unlike Android's dual-authority contract it does not claim an independent second authorizer. The
checked-in iOS trust root remains blocked until that single-controller control and key custody are
explicitly reviewed for production. Complete telemetry
requires every eligible device to report, nonzero wallet/account/terminal/eligible observations,
accounts at least wallets, mutually exclusive and exhaustive terminal outcomes, and:

```text
terminal = successes + user cancellations + insufficient funds + eligible failures
eligible = successes + eligible failures
eligible failures * 100 <= eligible
```

Any confirmed missing wallet/account, address mismatch, signature mismatch, or cross-network route
event blocks advancement. All receipts use an exact aggregate-only privacy object that forbids
wallet/account/address/transaction/device/IP identifiers, keys, phrases, payloads, per-wallet rows,
raw responses, and raw errors.

The checked-in candidate and advancement JSON files remain non-qualifying `blocked-template`
examples. Do not infer missing counters, copy old cohort evidence to a new artifact, or fabricate a
controller signature.
