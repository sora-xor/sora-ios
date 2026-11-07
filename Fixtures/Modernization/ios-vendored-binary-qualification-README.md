# iOS vendored binaries: none

The app links no prebuilt or closed-source binary. Until 2026-11-07 six XCFramework
trees were vendored and never qualified: blake2lib, libed25519, sr25519lib, two
copies of the Kotlin/Native sorawallet framework, and Mastercard's MPQRCoreSDK.
Firebase was linked as well, and its Analytics product ships Google's closed
GoogleAppMeasurement binary. Since then:

- blake2lib, libed25519 and sr25519lib are C targets built from vendored source in
  `VendorPackages/shared-features-spm/Sources/<name>`. Each README there names its
  upstream commit and license.
- `VendorPackages/shared-features-spm/Tests/CryptoCompatibility/run.sh` checks them
  against the recorded outputs of the binaries they replaced.
- The sorawallet indexer models are Swift source in `VendorPackages/SoraWalletBinary`.
- MPQRCoreSDK, XNetworking and Firebase are not used.

`SoraPassport/Scripts/verify-ios-vendored-binary-qualification.sh --scan-repository`
fails if Git tracks any of the items below. The dependency gate runs it on every build.
`--lint-templates` only checks the template, because the release scripts call it many
times in one run. The scan rejects:

- an `.xcframework` or `.framework`;
- a static or dynamic library or an object file;
- any Mach-O, ELF or ar image;
- a SwiftPM binary target;
- a closed-source or binary-only package pin (Firebase, GoogleAppMeasurement, the Google
  ads conversion SDK, the abseil/gRPC binary packages, XNetworking).

`ios-vendored-binary-qualification.blocked.json` is the fixed template the tool checks.
Production promotion (`--verify-qualified`) still fails closed:
values inside repository JSON cannot authorize themselves,
and no reviewed promotion receipt for the binary-free tree has been produced.
Boolean review claims and self-referential repository hashes are not authorities.
