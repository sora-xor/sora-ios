# Sora-iOS
iOS client application to interact with SORA v2 substrate network.
Supported features:
- XOR, VAL, and PSWAP tokens on SORA v2 network are supported in this first release
- Asset management: show, hide and change the order of assets in the app
- Send XOR, VAL, PSWAP to other accounts in the SORA Network

## SORA Nexus

Taira is the live testnet at `https://taira.sora.org` (Torii MCP at `/v1/mcp`).
The wallet uses stateless MCP `2026-07-28`, discovers tool schemas, reads XOR balances,
and loads finalized activity with opaque cursors. Pending-send reconciliation filters by the
exact transaction hash rather than loading an account's entire history.

SORA Nexus production is not deployed. Users can still create or import a wallet and copy
its production address offline. The existing production derivation path and address format
are preserved; production balances, explorer links, and sends are unavailable.

Taira transfers use locally encoded current-protocol Norito transactions and local Ed25519
signing. The exact fee quote comes from authenticated Torii `/v1/fees/quote`; the same
quoted payload and fee limits are signed. Keys remain in the wallet. The signing domain is
the pinned genesis-derived NetworkId, not the legacy deployment UUID.

Taira confirmations trust the canonical HTTPS node. A fresh challenge and the pinned
genesis bind applied-height checks, and the transaction hash, transfer history, and balance
are reconciled without automatic resubmission. This testnet policy does not claim independent
consensus-proof verification and does not enable production sending. Taira remains independent
of production rollout qualification; Nexus visibility and the user's Taira setting still apply.

`VendorPackages/NexusTransferCodec` contains the small current-protocol codec and transport,
with upstream golden vectors and focused tests (`swift test --package-path VendorPackages/NexusTransferCodec`).
A [controlled 2026-10-13 transfer](Fixtures/Modernization/taira-https-transfer-canary-v1.json)
of 0.001 XOR with a 0.01 XOR fee reached Applied at block 74:
`4a48384ad05a8e1669baf4cd0ed83773f006f178e486ad421bcf2abcadd658a1`.
The exact outgoing history and 24999.989 XOR remaining from 25000 faucet XOR were verified.

Live UI testing on 2026-10-13 also completed one 0.001 XOR send in each app,
using fresh simulator/emulator wallets and public faucet funds. iOS reached Applied at
block 78 and Android at block 76, each with a 0.01 XOR fee. Both apps showed the
completed transfer and 24999.989 XOR after relaunch, with no duplicate submission.
Public transaction evidence is in [the UI test results](Fixtures/Modernization/taira-ui-e2e-20261013.json).

Authenticated iOS users can choose a Nexus network while SORA2 services are unavailable.
Recovery-required and account-not-ready states still require wallet verification first.
The UI follow-up passed 15 iOS 27 startup/recovery tests and 36 Android PIN tests.

The app adopts a single UIWindowScene lifecycle, including cold-start links, foreground
recovery, and scene-bound overlay windows, for iOS 27 launch compatibility.
Validation on 2026-10-13 passed the integrated Debug build, 54 focused iOS 27 app/lifecycle
tests, and nine portable codec tests. A normal launch with Xcode-equivalent simulator
entitlements reached account creation/import on a clean iOS 27 simulator.

## Local build and test

Jenkins and GitHub Actions are retired. Run validation on the local build machine
with an installed Xcode 26 or 27 and a matching iOS simulator. Use the same Xcode
version for validation and release archives, and retain the local results.

```sh
xcodebuild -version
/bin/sh SoraPassport/Scripts/verify-modernization-dependencies.sh --lint-ios-migration-release-source-gate
xcodebuild test -project SoraPassport.xcodeproj -scheme SoraPassport \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -only-testing:SoraPassportTests -onlyUsePackageVersionsFromResolvedFile \
  -parallel-testing-enabled NO

```

Choose an available simulator name if yours differs. Debug simulator signing uses
Xcode's local ad-hoc identity so tests can access Keychain.

For the complete Release suite, use the existing local wrapper with fresh output
paths outside the checkout:

```sh
release_test_root="$(mktemp -d /private/tmp/sora-local-release-tests.XXXXXX)"
chmod 700 "${release_test_root}"
/bin/sh SoraPassport/Scripts/run-ios-release-tests.sh --test \
  --destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest,arch=arm64' \
  --derived-data-path "${release_test_root}/DerivedData" \
  --result-bundle-path "${release_test_root}/Release.xcresult"
```

These commands do not upload or publish a release. See [the release checklist](docs/release-3.9.0/RELEASE-CHECKLIST.md)
for archive, signing, and physical-device checks.

The local source dependency audit is available before release review:

```sh
python3 SoraPassport/Scripts/test-swiftpm-advisories.py
python3 SoraPassport/Scripts/audit-swiftpm-advisories.py --output /absolute/path/swiftpm-advisories.json
```

It checks immutable SwiftPM source revisions; vendored source and native binaries
retain their separate qualification requirements. An incomplete scan fails.
