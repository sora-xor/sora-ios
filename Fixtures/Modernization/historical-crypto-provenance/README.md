# Historical iOS crypto fixtures

Generated on 12 October 2026 from original historical dependencies, using only
public, synthetic zero-entropy mnemonics and literal public test passwords.
The audited app and its patched vendor code do not supply expected values.

The seven baseline fixture JSON files (122 vectors total) are checked in at
`SoraPassportTests/Common/Modernization/HistoricalCrypto/` relative to the
repository root and are included in the test bundle as `HistoricalCrypto`.
`provenance.json` records commits, dependency pins, toolchain, runtime adaptations,
coverage, limitations and fixture SHA-256 checksums.

| Family | Evidence generated | Status |
| --- | --- | --- |
| IrohaCrypto 0.2.6, used by inspected 1.3.3/1.4.6/1.5.1 tags | 2 legacy 15-word identities, original scrypt KDF, original signatures, phrase round trips, upstream KDF known-answer | Executed successfully |
| IrohaCrypto 0.9.0 plus three exact FearlessUtils pins, active in inspected 3.0.1–3.7.1 tags | 20 vectors per pin; original identity, signing and encrypted export/import/sign paths | Executed successfully |
| IrohaCrypto 0.9.0 plus SSFUtils 0.1.31, active in 3.8.0–3.8.4 | 20 vectors for each SSFModels 0.1.31/0.1.32 combination | Executed successfully |
| shared-features-spm ada44b24, pinned by App Store reference 354f176c and inspected 3.8.5–3.8.9 tags | 20 identities, signatures, original encrypted JSON export/import/sign round trips | Executed successfully |

`dependency-family-inventory.json` preserves every inspected tag's commit, Pod
dependencies and checkout options, and Swift package pins. No 2.x tag was present
in this local tag inventory; this is not evidence that no 2.x implementation
existed. The 3.0.1 lock resolves FearlessUtils to
`c1d17ccfbd8217612fdb56e588b1dec9cbe23bf5`; other tags' exact commits are in the
inventory. Every obtainable active key-factory family in this inspected inventory has its own original implementation execution. FearlessUtils remains in the 3.8.0–3.8.4 lock, but those app signing/key-factory sources actually import SSFUtils.

## Fixed vectors and evidence

- `ios-1x-vectors.json`: 2 original legacy Iroha identities. The podspec SHA-1
  matches the app's historical lock exactly. Each vector contains phrase,
  password, scrypt output, public key, challenge, verified original signature and
  phrase round-trip result. The upstream dependency's own known-answer scrypt
  vector also passes. These identities have no SS58 address.
- `ios-386-vectors.json`: 20 vectors produced with the exact historical source
  and native libraries. All contain direct secret, public key, SS58 address,
  entropy, mini-seed, path, parsed chaincodes, challenge, a verified historical
  signature, and an actual encrypted JSON made by the old `KeystoreBuilder`.
  The old `KeystoreExtractor` decrypted each JSON; the extracted key then signed
  and verified successfully. Password is the public literal in `jsonPassword`.
- `ios-fearless-{c1d17ccf,e6aaeb17,26dfc128}-vectors.json`: 60 vectors
  from the exact historical FearlessUtils pins with IrohaCrypto 0.9.0.
- `ios-ssfutils-0.1.31-models-{0.1.31,0.1.32}-vectors.json`: 40 vectors from
  the original active pre-SPM SSFUtils source and both app-pinned model versions.
  Each of these five files has the same 20-case coverage and fields as 3.8.6.
- `pre-spm-source-verification.json`: 2,529 original exported source/library
  files verified against exact Git object digests. `provenance/iroha-0.9-*-section-verification.json`
  records the unchanged native section bytes.
- `pre-spm-family-differences.json` and `pre-spm-comparison.json`: exact source
  differences and successful comparison of identities, seeds, chaincodes and
  scalar halves across all six Substrate fixture sets.
- `cross-family-verification.json`: all six historical implementations read all
  six fixture sets (720 checks), verifying supplied signatures, decrypting fixed
  exports to the exact retained secrets/public keys, and signing/verifying again.
- `integration-contract.json`: proposed production test assertions and stale
  record scenarios; these describe required tests, not executed app results.
- `provenance.json`, `shared-features-source-verification.json`, this README,
  generator/build scripts, `retarget_archive.py`, podspecs and `provenance/`:
  reviewable regeneration evidence. The 321 retained crypto/helper source and
  binary files checked against the upstream Git tree all matched.

Do not copy `runtime/`, recovered Git checkouts, raw build logs, or temporary
binary stdout into test resources. `.gitignore` excludes those local artifacts.

## Substrate coverage and interpretation

The first 12 vectors cover typed 3/6/9/12-word inputs across sr25519, ed25519 and
ECDSA. The original entropy-to-words API rejects fewer than 128 bits, so the
3/6/9-word inputs are explicit checksum-valid phrases passed through the original
words-to-entropy API. This records the historical parsing behavior rather than
relaxing the generator.

Remaining vectors cover sr25519 soft, hard and mixed/password derivation;
ed25519 and ECDSA hard/password derivation; ed25519 64-byte seed-plus-public
secrets, including an intentionally stale redundant half accepted by the old
signing path; and the default sr25519 identity derived from the same 15-word
phrase as the password-free 1.x vector.

The ed25519/ECDSA `childSeedHex` values also re-import through the original
factory without a path to the same public key. This supplies the inputs for the
historical ECDSA phrase-then-child-seed storage sequence. The signing harness
follows the original `SigningWrapperProtocol.swift`: sr25519 uses the direct
secret, ed25519 uses its first 32 seed bytes, and ECDSA hashes the challenge with
BLAKE2b-256 before signing. The primitive implementations and derivation/export
factories are compiled from original retained code.

Legacy Iroha and Substrate identities are different schemes. The 15-word SPM
vector is a reference for a migration's new-chain derivation, not a claim that a
1.x public key equals an SS58 public key. The additional non-empty-password 1.x
vector tests the dependency API; it is not evidence that the old app exposed a
password entry screen.

## Reproduce on Apple Silicon macOS

This uses the installed Xcode command-line compiler, not `xcodebuild`. It needs
the exact historical checkouts with their Git objects and secp256k1 submodule.
All generated files remain under the regeneration directory. Copy this evidence
directory to a temporary directory and copy the seven checked-in test-resource
JSON files into it before running the commands there. Keep the committed vectors
unchanged when comparing new outputs; the cross-verifier reads those fixed files.
The scripts overwrite fixture outputs unless they expose a separate output path;
retain the checked-in fixed vectors and regenerate in a separate copy. Before
running `cross_verify.py`, copy the seven checked-in `ios-*-vectors.json` files
back into that temporary directory so the comparison uses the committed fixtures.

The local harness sources are included: `build_fearless.py` uses
`generate_fearless.swift` and `retarget_archive.py`; `build_ssf_pod.py` uses
`generate_ssf_pod.swift` and the original pod modules produced by the Fearless
build. `cross_verify.py` uses all three Substrate generator sources plus
`cross_verify_tail.swift`. Its three `build-*-commands.json` inputs are generated
by the preceding builds; they are not historical source or required checked-in
artifacts. The external repositories and original native libraries below remain
explicit prerequisites.

```sh
git clone --depth 1 --branch 0.2.6 https://github.com/ERussel/IrohaCrypto.git IrohaCrypto-0.2.6
python3 build_1x.py
python3 build_386.py --ssf /path/to/shared-features-spm-ada44b24 --checkouts /path/to/retained-spm-checkouts --output runtime/reproduced-386.json
git clone --depth 1 --branch 0.9.0 https://github.com/ERussel/IrohaCrypto.git IrohaCrypto-0.9.0
git clone --depth 1 --branch 0.1.2 https://github.com/v57/secp256k1.c.git secp256k1.c-0.1.2
git clone --depth 1 --branch 0.1.1 https://github.com/v57/scrypt.c.git scrypt.c-0.1.1
git clone --filter=blob:none --no-checkout https://github.com/soramitsu/fearless-utils-iOS.git FearlessUtils
python3 build_fearless.py --checkouts /path/to/retained-spm-checkouts
git clone --depth 1 --branch 0.1.31 https://github.com/soramitsu/shared-features-ios.git shared-features-ios-0.1.31
git -C shared-features-ios-0.1.31 fetch --depth 1 origin tag 0.1.32
python3 build_ssf_pod.py
python3 cross_verify.py
```

The 3.8.6 build exports BigInt 5.4.1, secp256k1.swift 0.1.7 plus its exact native
submodule, and TweetNaCl 1.1.0 from pinned Git objects. Source paths and complete
compiler commands are recorded by the build script. The recovered SSF directory
has no Git metadata; `shared-features-source-verification.json` establishes its
contents against the official pinned Git tree. Verify those hashes before
regenerating from a different copy.

Original native arm64 objects are retargeted solely by replacing existing
Mach-O platform/minimum-version load-command metadata. Every file-backed section
is compared by SHA-256 before and after; no native code/data section changes.
Old 1.x libsodium objects are retained LLVM bitcode: host clang compiles that
original IR with a macOS target triple. These are runtime accommodations, not
algorithm replacements. Per-object evidence is in each runtime library's
`section-verification.json`. One small Swift glue file includes the original
`Data.blake2b32` method verbatim and omits unrelated xxHash helpers.

Random salt/nonce, sr25519 signature randomness and any soft-derivation nonce
material can make regenerated JSON or signatures differ. Expected identities,
seeds and scalar halves should agree; every signature and decrypted export must
verify. Check the committed fixture checksum only for accidental edits to that
fixture, not as a deterministic generation assertion.

## Pre-SPM pin differences

The complete FearlessUtils diff from c1d17ccf to e6aaeb17 only exposes existing
scrypt parameter members publicly. The next pin, 26dfc128, changes extrinsic
framing APIs, outside this identity/signature/export harness. Their original key
factories, seed factory and junction algorithms have identical source bytes;
all three pins were nevertheless compiled and executed independently.

SSFUtils 0.1.31 changes the hex initializer name/module, scrypt member visibility,
and keystore information metadata (`isEthereum`). Its actual key factories and
seed derivation are unchanged. The used SSFModels hex helper is byte-identical
between 0.1.31 and 0.1.32; both were independently compiled and executed. All
six Substrate outputs have identical 20 identities, mini-seeds, chaincodes,
child seeds and scalar halves. Full sr25519 secret differences occur only in
the expected randomized nonce halves of the two soft-derivation cases.

Pre-SPM builds use original BigInt 5.2.0, TweetNaCl 1.0.2, secp256k1.c 0.1.2 and
scrypt.c 0.1.1, as required by app locks. Their exact commits and podspec SHA-1s
are in provenance. Original SSFUtils/SSFModels podspec bytes from SSFSpecs match
the historical lock checksums exactly. The historical C `uint` typedef is made
available by a compiler `-include sys/types.h`; the sources are unchanged.
Minimal Swift modules omit unrelated network/UI/xxHash helpers. Import-only
glue supplies IrohaCrypto/SSFModels visibility; the selected original algorithms
remain unchanged.

## Limits

This is historical algorithm execution on the host. It does not exercise the
historical IPA, Keychain/Core Data writers, production startup, device UI, or
interruption recovery. The root audit must feed these fixed vectors through the
production migration/sign/export/repair tests and verify retained bytes before
and after. The original SECSigner context-lifetime defect remains unchanged in
the generator; its recorded calls returned valid signatures, which does not
prove memory safety. The old scrypt source's stray binary printf also remains
unchanged; fixture JSON is written separately and that synthetic-only process's
stdout is discarded. Neither defect exists by virtue of this generator in the
audited application.

No native binary, runtime or credential restriction prevented execution of any
of the dependency families identified here. Full historical application storage,
UI, extrinsic framing and migration integration remain separate app-level tests.

## Additional long-phrase launch vectors

`ios-386-long-phrases.json` adds 12 vectors (15/18/21/24 words across all three
crypto types). `generate_386_long.swift` changes only the public input case list
of the original 3.8.6 generator, reusing its archived original native libraries.
`long-phrases-provenance.json` records hashes and the command. The baseline
122-vector count is unchanged; there are 134 checked-in vectors altogether.

The separate test-target simulator runner uses these values to check real
Core Data, Keychain and normal app launches. Its historical app writer source,
2.3.1 version-one mapper and downgrade-method provenance are under
`Fixtures/Modernization/historical-simulator-writers/`. That source qualification
does not replace installing signed historical releases on a physical iPhone.
