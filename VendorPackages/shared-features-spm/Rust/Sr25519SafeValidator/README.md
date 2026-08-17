# Sr25519SafeValidator

This static library validates a serialized sr25519 secret/public pair before
the legacy signer receives the secret. Malformed encodings and mismatched pairs
return `false`; a Rust panic is caught before it can cross the C ABI boundary.

The application already links a Rust sr25519 signer built with
`rustc 1.46.0-nightly (7750c3d46 2020-06-26)`. This validator intentionally uses
the exact same compiler and the dependency versions pinned in `Cargo.lock`, so
the final executable contains one compatible Rust unwind runtime.

Install the historical x86_64 toolchain and its iOS targets once:

```sh
rustup toolchain install nightly-2020-06-27-x86_64-apple-darwin \
  --profile minimal --force-non-host
rustup target add aarch64-apple-ios x86_64-apple-ios \
  --toolchain nightly-2020-06-27-x86_64-apple-darwin
rustup toolchain install 1.95.0-aarch64-apple-darwin --profile minimal
```

Then rebuild and verify the checked-in XCFramework:

```sh
./build-xcframework.sh
```

The script vendors the locked graph into a temporary directory, runs the Rust
tests (including forced-panic containment), builds the arm64 device and x86_64
simulator slices, and replaces the XCFramework libraries. Rust 1.46 predates the
arm64 iOS simulator target, so Apple-silicon simulator validation must run as
x86_64 under Rosetta. The Xcode 26 linker compatibility wrapper edits only
temporary copies of historical `.rlib` files; the installed Rust toolchain and
source dependencies remain unchanged. Temporary source paths are remapped and
inherited Cargo profile/Rust flag overrides are cleared so repeat builds produce
the same checked-in archive bytes.
