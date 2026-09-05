# iOS production promotion controller

`Jenkinsfile.production-promotion` is the only checked-in pipeline authorized to compose the
protected iOS production release systems. The legacy `Jenkinsfile` and
`Jenkinsfile.migration-evidence` remain non-authorizing. Repository code owns no App Store
credential, retained-device identity, funded account, private key, signature, trust decision,
sequence allocation, qualification receipt, or rollout receipt.

The Jenkins job must run on the dedicated `mac-sora-production-controller` label with a pre-existing
current-user-owned mode-0700 `IOS_PRODUCTION_WORK_ROOT`. It accepts only one exact source revision,
one explicit build number, one fixed Release-test destination, and one phase:

- `candidate` creates two physically distinct clean checkouts of the exact revision, authenticates
  every external controller, queries the current App Store Connect build-number lower bound, runs
  the source gate and complete Release suite in both checkouts, creates the primary archive exactly
  once and the independent reproduction exactly once, then compares them. The explicit build number
  must be strictly greater than the fresh controller observation.
- `qualify` invokes the protected retained-device authority on the unchanged primary IPA, requires
  the existing verifier to authenticate the real schema-v8 receipt against those exact bytes, seals
  the independently reproduced package, and repeats post-archive admission.
- `upload` repeats package and post-archive admission, passes only the admitted IPA and its digest to
  the pinned App Store controller, then authenticates the returned artifact receipt/signature against
  the independently pinned rollout trust root and the actual IPA.
- `rollout-1`, `rollout-5`, `rollout-25`, and `rollout-100` must run in that exact order. Each phase
  re-hashes the same IPA, build manifests, equivalence receipt, sealed package, artifact receipt, and
  signature before and after `verify-production-rollout.sh`. Only after that strict gate succeeds may
  the pinned distribution controller apply the cohort. Targets after 1% therefore inherit the
  existing validator's complete signed predecessor replay, fresh PI receipt/checkpoints, external
  telemetry/distribution attestations, and minimum 172800-second dwell checks without rebuilding.

## Protected executable contract

The job configuration—not source parameters—must provide all six values:

```text
IOS_PRODUCTION_APP_STORE_CONTROLLER_PATH
IOS_PRODUCTION_APP_STORE_CONTROLLER_SHA256
IOS_PRODUCTION_RETAINED_DEVICE_CONTROLLER_PATH
IOS_PRODUCTION_RETAINED_DEVICE_CONTROLLER_SHA256
IOS_PRODUCTION_DISTRIBUTION_CONTROLLER_PATH
IOS_PRODUCTION_DISTRIBUTION_CONTROLLER_SHA256
```

Every path must be canonical, absolute, external to this repository, a unique regular executable,
owned by the job user or root, and not group/world writable. Each SHA-256 is independently protected.
The controller records device/inode/size/mtime/digest at initialization and rejects missing pins,
symlinks, path rebinding, content drift, or pin drift before and after every external invocation. It
executes fixed argv arrays directly; arbitrary command strings, shell evaluation, and plugin-provided
upload commands are not accepted.

The App Store executable supports exactly these operations:

```text
query-build-lower-bound --bundle-identifier co.jp.soramitsu.sora --source-revision REV --output-receipt PATH
upload-exact-ipa --ipa PATH --ipa-sha256 SHA --qualified-package PATH --source-revision REV --build-number N --idempotency-key SHA --artifact-receipt PATH --artifact-signature PATH
```

The query writes canonical `sora-ios-app-store-build-lower-bound-v1` JSON no more than five minutes
old and bound to its own executable pin. Upload outputs must be fresh owner-only paths named by
`PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_RECEIPT_PATH` and
`PRODUCTION_ROLLOUT_ARTIFACT_IDENTITY_SIGNATURE_PATH`. The repository verifies the artifact's
controller signature and strict `sora-ios-production-artifact-identity-v2` projection; it never
creates or modifies either output.

`upload-exact-ipa` must be idempotent for the SHA-256 key derived from the exact bundle identifier,
build number, and IPA digest. If App Store Connect accepted the build but Jenkins was interrupted
before its local state write, a retry with fresh artifact-output paths must query and authenticate
that already-present identical build and emit fresh signed artifact outputs. It must never upload
different bytes under that build, increment/reuse another build implicitly, or trigger a rebuild.

The retained-device executable supports only `qualify-exact-ipa` with the fixed IPA/digest,
revision/build, equivalence receipt, and both build manifests supplied as separate argv fields. Its
protected environment must install the real raw evidence and schema-v8 producer/reviewer artifacts
required by `verify-ios-migration-qualification.sh`; the executable may not substitute simulator or
self-signed evidence.

The distribution executable supports only `advance-immutable-cohort` with the target, exact
IPA/package, authenticated artifact pair, and current signed rollout pair. It writes a fresh
canonical `sora-ios-app-store-distribution-mutation-v1` record to
`IOS_DISTRIBUTION_MUTATION_RECEIPT_PATH`. That directly observed output must bind the immutable IPA,
artifact/rollout receipt digests, build, target, execution pin, and fresh application time. The
external mutation must be idempotent for that signed rollout receipt so interruption cannot widen a
cohort beyond its one authorized target.

## Durable fail-closed state

`controller-state.json` is mode 0600 beneath the release's mode-0700 namespace. It is operational
ordering state, not release evidence. It records the fresh ASC query, controller identities,
checkout physical identities, SHA-256/physical identities for every script the job can execute,
Release-test outputs, the two one-shot builds, immutable artifact
digests, and ordered cohort receipts. Existing state makes `candidate` fail; a role cannot be tested
or archived twice; qualification cannot precede comparison; upload cannot precede v8 qualification;
and a cohort cannot skip or repeat a predecessor. Qualification may add only the three authenticated
`ios-migration-qualification{,-evidence,-trust}.json` files; their bytes are recorded, while any
other tracked/untracked checkout change or executed-script drift blocks upload and rollout. Failed candidate work is quarantined and a new
build number/state namespace is required—operators must not delete state to retry the same release.

All existing protected migration, signing, vendored-binary, Taira, funded-canary, PI, Polkamarkt,
rollout trust, prior-chain, telemetry, and distribution-attestation inputs remain mandatory. This
controller deliberately has no blocked-template promotion fallback and never infers a legal export-
compliance answer or TestFlight tester assignment.
