# Release and data hygiene — 12 October 2026

The resumed audit integrates the reviewed keys and network branches at `413d3f4c`.
That merge preserves the startup rule that an empty asset list must not overwrite
cached balances, together with the network branch's balance retry logic.

## Changes

- The chain store, including contacts, custom nodes and pool favourites, is
  preserved beside its original path when its model is unrecognized or SQLite
  identifies corruption. Orphan WAL/SHM/journal files are preserved too. A failed
  move defers startup of that store instead of deleting anything. Unknown errors
  are retryable. Wallet keys and the separate account database are untouched.
- The bundled whitelist is the published `https://whitelist.polkaswap2.io/whitelist.json`
  fetched on 12 October: 277 entries, previously 185. The address diff adds 99 and
  removes seven: SOSHIBA, BAT, AGI, OMG, CHSB, HT and CUSDC. Eighteen existing
  display names change (including XOR's name to `1M XOR`); symbols and decimal
  precision of retained entries do not change. These are the project's existing
  live admission choices. The last-good/bundled fallback remains fail-closed.
- `scripts/archive-app-store.sh` archives only the Release `SoraPassport` scheme,
  pins package resolution, rejects a dirty checkout and detects changes made
  during the build. It rejects the migration evidence harness, prints public
  Google Sign-In identifiers from the built app for continuity checks, and
  exports locally. It refuses export options that would upload automatically.
  Signing settings remain external.
- The Crashlytics phase runs only for archive actions and rejects harness-enabled
  archives even when Xcode is invoked directly. Upload has a 120-second deadline
  and terminates its process group on timeout. Only this build's package paths or
  an explicit `SORA_SOURCE_PACKAGES_PATH` are searched; the DerivedData-wide
  fallback is removed. Upload failure still fails the archive.
- R.swift's build phase uses its checked-in resolved versions and skips remote
  updates. An initially empty package cache still needs dependencies; warm both
  the app and R.swift caches on the release Mac before the release window.
- The `sorawallet` dSYMs were recovered from the historical `ada44b24` package.
  `dwarfdump --uuid` matched every device and simulator slice before copying them
  into both vendored wrappers. `DebugSymbolsPath` now describes the symbols.
- Physical-device evidence tests explicitly skip on a simulator or Debug host.
  Missing evidence on a supported Release device still fails. The scheme explains
  why the legacy pool tests remain excluded: they depend on a historical funded
  account and storage layout. Current-runtime storage coverage is in the opt-in
  mainnet tests.
- The unused destructive `deleteEntropy(for:)` helper is removed. Other deletion
  entry points with callers remain subject to their existing explicit-removal gates.

## Verification

- The integrated Debug test build succeeded with the pinned packages.
- `python3 scripts/test-release-scripts.py`: eight tests pass. These execute the
  real release scripts against an isolated fake Xcode executable; no signing or
  upload occurs. They verify package-pin drift blocks export, dirty and harness
  builds are refused, upload destinations are refused, public identifiers are
  read, and Crashlytics failures propagate.
- Updated production-path storage tests require preservation rather than deletion,
  preserve orphan sidecar bytes, exercise failed moves, and classify unknown errors
  as retryable. The whitelist regression uses an explicit historical subset, so
  refreshing the bundled list does not erase coverage for assets absent from it.
- Targeted storage and whitelist simulator run: 27 tests, zero failures, on
  iOS 27. The physical-device evidence test correctly skipped this unsupported
  host. Raw results: `audit-2026-10-12/ios/hygiene-targeted.log` in the audit
  workspace. Release compile and full-suite qualification remain in progress.
  No signed archive or physical-device upgrade is claimed by this change.

## Release checks still required

Use absolute, new paths outside the checkout for `SORA_ARCHIVE_PATH` and
`SORA_EXPORT_PATH`. Set `SORA_SOURCE_PACKAGES_PATH` when using an external package
cache; optional signing overrides are `SORA_DEVELOPMENT_TEAM` and
`SORA_PROVISIONING_PROFILE_SPECIFIER`. Run the script only from the reviewed,
committed release tree. Compare the printed Google identifiers with the actual
App Store 3.8.6 binary before upload.

After the remaining safety fixes and upgrade qualification pass, use a phased
release. Halt expansion for any confirmed key-loss report, wrong identity,
PIN bypass, new upgrade lockout, or regression in signing; investigate startup
and recovery failures before resuming. There is no qualified rollback build:
fix forward, and do not instruct users to reinstall or clear their data.

Close unsafe public TestFlight access before distribution if the retained-wallet
PIN audit confirms older builds can bypass the new protection. Replace build
2026091402 before its reported 13 December expiry, confirm the actual expiry in
App Store Connect, and provide a tested upgrade path for testers. Confirm current
age-rating answers, review notes, screenshots and last-compatible-version settings.
Export-compliance declarations remain the publisher's legal determination.
