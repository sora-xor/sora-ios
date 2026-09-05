# Authenticated iOS production-signing continuity

`ios-production-signing-identity.json` is the configured, public identity inventory for the
current release selection. It records no private key or credential and is not release authority.
The two `*.blocked.json` files are exact non-authorizing schema examples. Editing its nulls and
booleans cannot qualify a signing selection, existing-app lineage, or release.

This is the first Taira-enabled release, but it updates the existing App Store application with
Adam ID `1457566711`. The durable identity therefore remains the App Store record, bundle ID,
development team, application identifier, and Keychain access groups. Apple distribution
certificates and provisioning profiles can rotate over the application's lifetime; this release
nonetheless pins the exact retained certificate and profile selected for its independently
reproduced archives.

The only pre-archive admission path is
`SoraPassport/Scripts/verify-ios-production-signing-identity.sh --verify-qualified`. The protected
release controller supplies canonical, absolute paths outside the repository through
`IOS_SIGNING_IDENTITY_RECEIPT_PATH` and `IOS_SIGNING_IDENTITY_TRUST_PATH`. Both files must be
owner-owned regular files with mode `0600`. The controller supplies the producer and reviewer
public keys and detached signatures under the same path rules. Qualified receipts, trust roots,
keys, and signatures must never be copied into source control.

The verifier accepts a canonical v2 receipt only when distinct protected release-evidence
producer and independent-reviewer P-256 authorities both sign its exact bytes. Protected
environment values pin the source revision, run UUID, append-only sequence, contract digest,
trust-root digest, both public-key digests, and all six external file paths. Repository values
cannot bootstrap those pins. `--print-contract-sha256` emits the current non-authorizing source
contract digest for the protected controller to pin before either authority signs; it does not
create a receipt, trust root, key, or signature.

The receipt binds the existing-app lineage and the manual release selection: certificate SHA-1
and SHA-256, profile UUID and name, raw and canonical profile SHA-256, application and team
identifiers, source and signed entitlement SHA-256 values, and the canonical Keychain-access-group
SHA-256. Qualifications expire after 30 days; review must finish within 24 hours of assessment,
and the external controller owns sequence replay protection.

Pre-archive authentication is necessary but not sufficient. The archive entry point verifies the
installed private identity and exact profile, selects both explicitly with manual signing, and
copies the authenticated receipt into its owner-only release-control directory. The independently
reproduced IPA package gate derives the application signer certificate, embedded profile, signed
entitlements, application/team identity, and Keychain identity from both exported IPAs. It
requires both exports to match one another and every retained pin before emitting an equivalence
receipt. The immutable package carries the exact protected receipt snapshot and its digest.

The contract digest binds this document, both blocked templates, the public inventory, the project
and Release configuration, source entitlements and Info.plist, the signing verifier and its
ten-test hermetic suite, the Release package verifier and suite, and the broad dependency gate.
The hermetic success path creates temporary synthetic P-256 authorities only to test admission;
those test keys and receipts are never production evidence.
