# Authenticated iOS vendored-binary qualification

The six production-reachable XCFramework trees are release inputs. A content manifest proves only
that a tree matches the bytes named by that manifest; a hash copied into another repository file
does not prove that an independent authority reviewed either one. Consequently,
`ios-vendored-binary-readiness.json` remains a blocked inventory record and is never an admission
authority. Its status and review booleans must not be promoted.

`SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh --verify-qualified` is the only
qualified admission path. The Release dependency verifier accepts only the authenticated receipt
SHA-256 printed by that command and then rechecks the same receipt bytes. Debug builds run
`--lint-templates` only; template lint cannot emit a qualifying receipt hash.
`--print-contract-sha256` emits only the current non-authorizing source-contract digest for the
protected release controller to pin; it creates no review evidence, receipt, signature, or key.

## Fixed artifacts

The evidence manifest contains exactly these IDs and paths, in this order:

1. `shared-blake2lib` — `VendorPackages/shared-features-spm/Binaries/blake2lib.xcframework`
2. `shared-libed25519` — `VendorPackages/shared-features-spm/Binaries/libed25519.xcframework`
3. `shared-sr25519lib` — `VendorPackages/shared-features-spm/Binaries/sr25519lib.xcframework`
4. `shared-sorawallet` — `VendorPackages/shared-features-spm/Binaries/sorawallet.xcframework`
5. `shared-mpqr-core-sdk` — `VendorPackages/shared-features-spm/Binaries/MPQRCoreSDK.xcframework`
6. `sora-wallet-binary-sorawallet` —
   `VendorPackages/SoraWalletBinary/Binaries/sorawallet.xcframework`

Each record uses fixed repository-relative content-manifest and provenance paths under
`Fixtures/Modernization/VendoredBinaries`. The validator rejects aliases, symbolic links, special
nodes, duplicate or unsafe manifest paths, missing files, unlisted files, and any whole-tree digest
or file-count mismatch. It opens every regular file without following a final symbolic link,
records a stable identity, and repeats the inventory and digest checks before admission returns.

The two `sorawallet.xcframework` trees must have identical path sets and bytes. Their independently
listed manifests must also be byte-identical. A signed `byteIdentical` assertion is necessary but
does not replace that local comparison.

## Concrete review bindings

Every exact `sora-ios-vendored-binary-provenance-v2` receipt binds the artifact ID and tree path,
whole-tree manifest SHA-256 and file count, plus nonzero SHA-256 identities for:

- source or vendor identity evidence;
- license and notice review evidence;
- an SBOM;
- build provenance;
- artifact attestation.

The signed evidence manifest repeats those values and binds the provenance-receipt SHA-256 and the
locally derived deterministic tree-content SHA-256. Boolean review claims and self-referential
repository hashes are not authorities.

## Authenticated admission

Qualified admission requires fixed regular, non-symbolic repository files named:

- `ios-vendored-binary-qualification.json`;
- `ios-vendored-binary-qualification-evidence.json`;
- `ios-vendored-binary-qualification-trust.json`.

The protected release environment must also supply all of the following, with no repository
fallback values:

- `IOS_VENDORED_BINARY_QUALIFICATION_SOURCE_REVISION`;
- `IOS_VENDORED_BINARY_QUALIFICATION_RUN_ID`;
- `IOS_VENDORED_BINARY_QUALIFICATION_SEQUENCE_NUMBER`;
- `IOS_VENDORED_BINARY_QUALIFICATION_CONTRACT_SHA256`;
- `IOS_VENDORED_BINARY_QUALIFICATION_TRUST_SHA256`;
- `IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PUBLIC_KEY_SHA256`;
- `IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PUBLIC_KEY_SHA256`;
- `IOS_VENDORED_BINARY_QUALIFICATION_ARTIFACT_PRODUCER_PUBLIC_KEY_PATH`;
- `IOS_VENDORED_BINARY_QUALIFICATION_REVIEWER_PUBLIC_KEY_PATH`;
- `IOS_VENDORED_BINARY_QUALIFICATION_RECEIPT_SIGNATURE_PATH`;
- `IOS_VENDORED_BINARY_QUALIFICATION_EVIDENCE_PRODUCER_SIGNATURE_PATH`;
- `IOS_VENDORED_BINARY_QUALIFICATION_EVIDENCE_REVIEWER_SIGNATURE_PATH`.

Every protected path must be canonical, outside the repository, and name exactly one
current-user-owned mode-0600 regular inode with one link. Alias parents, symbolic links, hard
links, public modes, and path rebinding are rejected.

The trust-root digest and both public-key PEM digests are protected release-controller pins;
values inside repository JSON cannot authorize themselves.
The producer and independent reviewer must be
distinct enabled ECDSA P-256 roles with distinct canonical public points. The reviewer signs the
exact qualification-receipt bytes. The producer and reviewer separately sign the exact evidence
manifest bytes. Signatures are detached DER ECDSA values verified with
`openssl dgst -sha256 -verify`. The validator starts Apple Python in isolated, no-site mode and
invokes `/usr/bin/openssl` with a minimal fixed environment; repository-local Python startup hooks
and OpenSSL configuration variables are not admission authorities.

The protected contract SHA-256 binds the ordered path and SHA-256 identity of this document, the
blocked templates, the blocked legacy inventory, both vendored Package.swift files, the Xcode
project, the dependency manifest, the broad Release verifier, and both dedicated validator files.
It also binds the hermetic qualification test file, so a release cannot silently omit or weaken
the admitted-path regression coverage.
The signed receipt and evidence must carry that same digest and the protected source revision, run
UUID, and positive controller sequence. The release controller owns the append-only sequence
high-water mark; the repository does not infer replay state from a checkout.

Runs may last at most 48 hours, review may trail evidence production by at most 24 hours, and a
qualification expires after 30 days. All JSON schemas use exact key sets, reject duplicate keys,
and are parsed from stable snapshots. Qualified receipt, evidence, trust-root, and provenance JSON
must also use canonical bytes. The qualified receipt, evidence, trust root, manifests,
provenance receipts, keys, signatures, and every tree file are rechecked before success is emitted.

`test-ios-vendored-binary-qualification.py` runs ten hermetic Release-gate tests. Its successful
path creates temporary synthetic P-256 producer and reviewer authorities, a six-tree fixture, and
detached signatures solely to exercise the verifier; those ephemeral keys and records are not
production qualification evidence. Mutations cover noncanonical JSON and controller sequences,
wrong-role signatures, changed or symbolic tree content, duplicate-sorawallet drift, and stale
receipt shapes. A separate local comparison confirms that the two checked-in sorawallet trees are
currently byte-identical, but that fact remains non-authorizing without the protected review and
signature inputs described above.

The checked-in `*.blocked.json` templates contain only fixed contract structure and fail-closed
null, zero, false, and blocked values. They contain no keys, signatures, reviewed digests, or
qualified assertions. Never rename or copy a blocked template into a qualified filename.
