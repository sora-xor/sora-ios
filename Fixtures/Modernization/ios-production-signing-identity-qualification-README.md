# Authenticated iOS production-signing continuity

`ios-production-signing-identity.json` is a blocked inventory record, not a release authority.
Editing its nulls and booleans cannot qualify a certificate, provisioning profile, application
identifier, entitlement set, or Keychain access group.

The only pre-archive admission path is
`SoraPassport/Scripts/verify-ios-production-signing-identity.sh --verify-qualified`. It accepts a
canonical `ios-production-signing-identity-qualification.json` only when distinct protected
release-evidence producer and independent-reviewer P-256 authorities both sign its exact bytes.
The protected controller supplies the source revision, run UUID, append-only sequence, contract
digest, trust-root digest, both public-key digests and paths, and both detached-signature paths.
Repository values cannot bootstrap those pins, and public keys or signatures under the repository
root are rejected.
`--print-contract-sha256` emits the current non-authorizing source-contract digest for the protected
controller to pin before the producer and reviewer sign; it does not create a receipt or key.

The receipt pins the retained distribution-certificate SHA-256, profile UUID and name, canonical
profile SHA-256, application and team identifiers, source and signed entitlement SHA-256 values,
and canonical Keychain-access-group SHA-256. It records no private key, credential, raw Keychain
item, seed, address, or signature payload. Qualifications expire after 30 days; review must finish
within 24 hours of assessment, and the external controller owns sequence replay protection.

Pre-archive authentication is necessary but not sufficient. The independently reproduced IPA
package gate derives the application signer certificate, embedded profile identity, signed
entitlements, application/team identity, and Keychain-group identity from both exported IPAs. It
requires both exports to match one another and every retained pin before it emits an equivalence
receipt. The immutable package carries the exact authenticated signing receipt and its digest.

The contract digest binds this document, both blocked templates, the blocked legacy inventory,
the project and Release configuration, source entitlements and Info.plist, the signing verifier and
its ten-test hermetic suite, the Release package verifier and suite, and the broad dependency gate.
The hermetic success path uses temporary synthetic P-256 authorities only to test admission; those
keys and receipts are not production evidence.

Qualified files are deliberately absent from source control until protected evidence exists:

- `ios-production-signing-identity-qualification.json`;
- `ios-production-signing-identity-qualification-trust.json`.

Never rename either `*.blocked.json` template into a qualified path.
