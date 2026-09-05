# iOS funded Nexus canary admission v1

The checked-in Taira and Minamoto JSON files are exact-shape blocked templates. They are not
checklists, live results, or permission to broadcast. Qualification is a post-export operation over
the actual regular non-symlink signed IPA and the controller-signed
`sora-ios-production-artifact-identity-v2` receipt for those same bytes. The ordinary build only
runs `verify-funded-nexus-canary.sh --lint-templates`; only a reviewed release controller may run
the full verifier or produce a rollout admission receipt.

The checked-in `funded-nexus-canary-trust.json` is also deliberately blocked. A qualified revision
must pin four distinct ECDSA P-256 public-key PEM hashes and key IDs for the release operator,
independent approver, independent reviewer, and one-use append-only consumption ledger. The exact
trust-root file hash must additionally be protected outside the checkout. No person name is stored.

## Strict input rules

Every JSON, signature, and public key is supplied as an absolute path, opened without following a
symbolic link, bounded, copied once into a private read-only snapshot, and then parsed, hashed, and
signature-verified from those same bytes. The IPA is too large to copy; it is opened as a stable
regular non-symlink descriptor, validated by the existing bounded IPA/ZIP validator, and hashed
against the signed artifact receipt. Path rebinding or mutation fails.

The JSON parser rejects duplicate keys after escape decoding, trailing data, floats, exponents,
non-finite values, negative zero, integers outside the exact safe range, C0/C1 controls (including
escaped line breaks), overlong strings, overlarge arrays/objects, unknown fields, missing fields,
and wrong nesting. Quantities are positive canonical decimal strings and may not exceed one XOR for
either the transfer or fee, even if a policy claims a larger limit.

Privacy is exact and mandatory: evidence is aggregate and redacted, and it never contains an
account, address, transaction hash, phrase, seed, private key, signed payload, raw response, device
identifier, or operator name. A digest of a transaction hash is still a transaction identifier and
is forbidden. Receipt and evidence schemas contain no extension field in which such data can hide.

## Candidate, signer, and finality binding

Each network has a distinct candidate binding even though both use one IPA. The canonical UTF-8
projection is joined with `\n` and has no final newline:

```text
contractId=sora-ios-funded-nexus-canary-v1
platform=ios
bundleIdentifier=co.jp.soramitsu.sora
developmentTeam=YLWWUD25VZ
appVersion=...
buildNumber=...
appStoreBuildIdentifier=...
sourceRevision=...
ipaSha256=...
ipaBytes=...
artifactIdentityReceiptSha256=...
sora2SourceRevision=411dcdb70c5c00b21482a44d02334840d5f338c6
runtimeSpecVersion=130
runtimeTransactionVersion=130
runtimeGenesisHash=7e4e32d0feafd4f9c9414b0be86373f9a1efa904809b683453a9af6856d38ad5
runtimeMetadataSha256=2b49c3cbf682d8b88985a04a60a958de3ef5de77d282c3622bdae53f7e4fbabf
runtimeTypesSha256=e87760d7a566d1b1b3d21a1e76ad70990fd54e14e6af3ba27dd4440461063601
featureSnapshotObservedAtEpochSeconds=...
featureSnapshotReceiptSha256=...
featureConfigRevision=...
nexusAvailable=true
nexusSendsAvailable=true
polkamarktVisible=true
polkamarktMutationsAvailable=true
tairaDefaultVisible=true
tairaPreferenceIsExplicit=...
tairaEffectiveVisible=...
localNexusSendsQualified=true
signerBindingSha256=...
finalityBindingSha256=...
networkId=...
chainId=...
```

The signed artifact receipt and IPA must preserve bundle ID `co.jp.soramitsu.sora`, team
`YLWWUD25VZ`, version/build/App Store identity, source revision, provisioning and signing identity,
and runtime 130. The checked-in Taira candidate values are inert blocked placeholders, not a choice
of current chain. Only a fresh protected manifest signed by the external release operator and an
independent reviewer may map the two known UUIDs to current and retired roles. Either UUID may be
current; the other is retained only as recovery evidence. The authenticated manifest supplies the
current genesis, deployment epoch, canonical public HTTPS Torii origin, and exact `/v1/mcp` route;
the convenience route `taira.sora.org` is never admission. Taira funded canaries and production
mutation admission remain blocked until that manifest is admitted against independently pinned
public keys. Each new iOS Taira pending row binds the exact admitted manifest digest, deployment
epoch, and genesis as well as the UUID. A missing binding, another digest, or a legacy schema-77 row
remains recovery-only even if its UUID later becomes current. Minamoto is only
`00000000-0000-0000-0000-000000000753`.

Signer and finality are separate bindings. The signer must be a reviewed platform-release Apple
artifact, ABI 21, source-tree clean, backed by the iOS Data Protection Keychain, and matched to the
actual independently reviewed native-canary receipt. A dirty local debug addon is explicitly
forbidden and can never replace `UnavailableNexusTransactionSigner`.

Finality must use a separately reviewed non-placeholder reader and stateful verifier. Its actual
manifest and network trust-context receipts bind the verifier source/artifact, server source,
OpenAPI and route source, canonical signed genesis, genesis signer, expected node/build/protocol,
validator roster/quorum, and trusted first height-context ID. The finality stage must verify a fresh
challenge-bound `BridgeFinalityAttestationV1` and bounded immediate-successor bundle chain through:

- `/v1/bridge/finality/attestation/{height}`;
- `/v1/bridge/finality/bundle/{height}`;
- exact canonical Norito round-trip, node and aggregate signatures, genesis and tip proofs, and one
  StateView; and
- exact wallet network/chain, positive finalized height, and canonical nonzero finalized block
  hash.

The signed trusted first height must not exceed the live attested finalized height. The signed
finality stage must also set `liveBoundedSequentialStatefulSuccessorChainVerified` to true so an
offline successor KAT cannot substitute for bounded sequential verification of the funded run.

The independently reviewer-signed finality-native receipt is not an opaque hash assertion. Its
exact `sora-ios-nexus-finality-native-canary-v1` schema must bind ABI 21, a clean reviewed platform
release artifact, the same verifier source/artifact and finality trust manifest, exact required and
observed export inventories, and distinct known-answer digests for attestation and bundle Norito
round trips, challenge binding, genesis/tip proofs, node/aggregate signatures, stateful successor
verification, and the finalized checkpoint projection. Every corresponding qualification flag must
be true; a repeated KAT identity, ABI mismatch, unknown field, or placeholder fails admission.

`/status/blocks`, a scalar height, a response-declared node key, or a self-claimed chain ID is never
finality evidence. All signer/finality values and actual receipt hashes must match
`iroha-production-send-readiness.json`. Its `finalityAttestationCanaryQualified` prerequisite means
the reviewed platform-native verifier KAT, not the live funded send; the two
`funded*CanaryQualified` result fields must remain false in the bound pre-canary readiness receipt.
Only the two fully validated signed network receipts plus their admission establish those live
results, so no receipt hash is changed after execution and no circular boolean can fabricate them.
The admission also requires distinct Taira and Minamoto receipt hashes, candidate/finality
bindings, canary run IDs, approval nonces, and challenge hashes; a network label cannot be changed
to reuse the other network's live execution or one-use authorization.

## Dual control and exact-once execution

An operator approval receipt is signed over the same bytes by the pinned release-operator and
independent-approver keys. It binds the candidate, network, one-time nonce, reviewed low-value
policy hash, and an interval covering the run. The policy allows exactly one execution; amount and
fee are each capped at one XOR. The policy review must precede the dual-controlled approval, every
network trust context must be reviewed no later than the manifest that binds it, and that manifest
review must precede funded execution; retroactive trust or policy evidence is rejected even when
all hashes and signatures are otherwise internally consistent.

After fee validation and before signing, the ledger authority must atomically reserve that nonce
with zero prior reservations. Its signed consumption receipt binds distinct previous, reservation,
and finalization heads, increasing store versions, one submission handoff, and zero ambiguity. The
versions and heads are append-only within the exact `(ledgerStoreId, networkId)` partition; the
admission separately rejects cross-network run IDs, nonces, and challenges, so a partition cannot
authorize the other chain. The reservation is rechecked before signing and handoff; finalization
occurs only after execution. A
timeout or ambiguous submission fails the canary and is never retried under that approval.

The eleven stages have strictly increasing observation times:

1. network-scoped receive and funded XOR;
2. recipient/amount/balance/fee validation;
3. positive canonical-payload fee and pre-sign revalidation;
4. OS-secured signing after wallet/network/account/deletion/flag/quote revalidation;
5. one exact handoff, durable journal, and local/Torii receipt-hash equality;
6. exact-hash committed terminal status resolved from global state with its positive committed block
   height;
7. attested stateful finality with exact network, chain, height, and block hash, where the finalized
   height covers the committed height;
8. sender/receiver/fee balance reconciliation;
9. network-scoped explorer reconciliation;
10. bounded complete-fanout history reconciliation with the transaction exactly once; and
11. cold-restart exact-hash recovery through a read-only interface with no signing or submission.

Each stage digest is recomputed over its exact assertions, candidate binding, run ID, network, stage
name, status, and observation time. The finality stage projection additionally contains the actual
network ID, chain ID, finalized height/hash, separate attestation and bundle evidence digests,
the nonzero challenge digest and its canonical run/candidate/network/chain/height/attestation
binding, including the finalized block hash, stateful bundle evidence, and reviewed finality
binding; reviewed verifier source/artifact, finality-native canary receipt, trust-manifest receipt,
network-trust-context receipt, and aggregate finality binding. The independently signed evidence
bundle must contain those exact stage objects and the same privacy-redacted attestation and bundle
evidence digests. The independent reviewer signs the evidence bundle, network trust receipts, final network
receipt, and two-network admission receipt. A run lasts at most two hours, is recorded within 24
hours, is no older than seven days at release evaluation, and uses a PI capability snapshot captured
in the five minutes before it starts.

## Release inputs and rollout binding

Funded admission accepts only PI `schemaVersion = 3` receipts with contract
`sora-pi-production-capability-probe-v3`, exact true `mobileConfigHealthBound` and
`historyBlockHeightContractDeployed`, and the existing five exact true release capabilities.
PI v2 receipts are wire-incompatible with v3 and are rejected.
The protected production PI producer and controller must be upgraded and independently
compatibility-qualified for v3; protected producer compatibility remains a hard release blocker
until that review is complete.

The full controller supplies the following common inputs plus the exact `TAIRA_` and `MINAMOTO_`
variants documented by `verify-funded-nexus-canary.sh`:

- actual IPA, signed artifact receipt/signature, rollout trust root pin/key, exact source revision,
  and explicit evaluation epoch;
- independently pinned funded-canary trust root and four authority keys;
- actual reviewed signer and finality-native canary receipts/signatures;
- signed finality trust manifest and per-network trust-context receipts;
- signed PI capability receipts;
- dual-signed approvals that bind exact low-value policies, ledger-signed consumption receipts,
  reviewer-signed evidence,
  final network receipts, and final two-network admission.

`verify-funded-nexus-canary.sh --verify-admission` is the rollout-facing full recheck. It revalidates
the actual IPA/artifact signature, all four authority keys and signatures, both networks' approval,
policy, one-use ledger consumption, evidence, PI, signer, finality and trust inputs, both exact
reviewer-signed network receipt bytes, and the reviewer-signed admission binding. There is no
admission-only shortcut around either per-network `qualified` validation. The controller-signed rollout identity records the
admission SHA-256 plus both exact network receipt SHA-256 values, and the stable candidate-binding
projection includes all three. Every 1% -> 5% -> 25% -> 100% gate therefore remains bound to the
same canaries and IPA without creating a cycle through the pre-export qualification receipt. The
admission must have been evaluated no more than seven days before every cohort gate, so a rollout
that exceeds that safety window must stop instead of silently accepting stale funded evidence. Its
recorded time must follow both bound network receipt recording times and may trail the latest by no
more than 24 hours.

The independently signed Taira deployment admission has the same seven-day live-release ceiling and
is rejected when future-dated. Replaying its immutable original evaluation time can therefore never
extend a retired deployment identity's authority.

The current trust root, signer, finality reader, and evidence are blocked. No receipt or admission
has been fabricated, and no production mutation is enabled by these source changes.
