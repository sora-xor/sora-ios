# SORA Wallet iOS 3.9.0: changes

Each section covers one release task: what changed, why, and what users see.

## i1: UIScene life cycle, build-phase gates retired, lean CI

### Why

- Apps built with the iOS 26+ SDKs must use the UIScene life cycle. The
  previous code crashed at launch on iOS 27
  (`_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`).
  App Store Connect only accepts builds made with the iOS 26 SDK or later.
- The first build phase of every build ran
  `verify-modernization-dependencies.sh` (7,268 lines of exact-string,
  exact-count and Python checks). Its Release path rejected every plain
  archive, so no 3.9.0 IPA could be produced, and it made every source change
  a script change.

### What changed

**UIScene adoption** (`SoraPassport` and `SoraPassportDev` targets)

- New `SoraPassport/SceneDelegate.swift`. `Info.plist` declares
  `UIApplicationSceneManifest` with one scene and no multiple-window support.
  `AppDelegate` uses `@main` and returns the scene configuration.
- The root window and the Splash flow are still created once per process.
  Splash starts wallet storage migration. If the system disconnects the scene
  and connects a new one, the existing windows (wallet, PIN lock, loading,
  toasts) move to the new scene. Nothing is created again, so a migration can
  never start twice.
- URL handling moved to the scene: IrohaConnect links and the Google Sign-In
  callback (`scene(_:openURLContexts:)`), universal links
  (`scene(_:continue:)`), and cold-launch URLs (`connectionOptions`). A
  cold-launch URL is now handled once; before, it could be handled twice.
  External links are ignored while the migration-evidence screen is shown.
- Life cycle: "resume pending transaction status checks" still runs when the
  app returns from the background, and not at first launch. IrohaConnect
  still learns when the app goes to the background. The PIN timeout and
  security overlay are unchanged: they observe the `UIApplication`
  notifications, which UIKit still posts.
- Windows: the loading spinner shown while a send, swap or liquidity
  transaction is confirmed, the general loading window and toasts are now
  attached to the window scene. Without this they would be invisible.
  The status bar height comes from the scene's status bar manager. The
  network status banner falls back to the wallet window when a loading or PIN
  window is key.
- External displays: only the iPhone's own application scene gets
  `SceneDelegate`. An AirPlay Screen Mirroring or USB-C/HDMI display scene
  gets no delegate, so the system simply mirrors the phone. The wallet's
  windows never move to the external screen, and connecting or
  disconnecting a display does not end an IrohaConnect session or leave the
  phone blank. `SceneDelegate` and `AppDelegate` also ignore life-cycle and
  URL events from any scene that is not the application scene (fix round).
- `RetainedMigrationEvidenceHarness`: `bootstrap()` is still the first call at
  launch. Its evidence-only and authorized screens are created in the scene.
- Tests: two `WalletUXTests` cases that need view-appearance callbacks now
  attach their window to the test host's scene (a window without a scene is
  never shown in a scene-based app).

**Qualification machinery retired**

- Both "Verify production modernization dependencies" build phases are
  removed from the project.
- Deleted: 45 promotion, controller, receipt, evidence-collection,
  internal-TestFlight and signing-identity scripts with their Python tests;
  `Fixtures/Modernization/*.blocked.json`, trust, canary and readiness
  records; `ModernizationDependencies.conf`; the two qualification
  export-option plists; `Jenkinsfile.production-promotion`;
  `Jenkinsfile.migration-evidence`; `.github/workflows/ios_modernization.yml`.
- Kept: every XCTest, the wallet test fixtures
  (`wallet-derivation-v1.json`, `polkamarkt-runtime-v130.json`), the
  localization notes, the build scripts the app needs
  (`inject-google-signin-info-plist.sh`, `run-crashlytics.sh`), and the
  `SoraPassportMigrationEvidence*` schemes. One assertion in
  `WalletModernizationTests` that read the deleted gate script was removed.

**Lean CI**: `.github/workflows/ios_ci.yml`

- Runs on `macos-26` with Xcode pinned through `DEVELOPER_DIR`
  (`/Applications/Xcode_27.0.app`, the newest Xcode, matching local release
  builds).
- Job 1 builds the Debug app and tests, checks the scene manifest, and runs
  `SoraPassportTests` on a new iPhone 17 Pro simulator with the newest iOS
  runtime.
- Job 2 builds the same tests in the Release configuration
  (`ENABLE_TESTABILITY=YES`, unsigned), checks that the build carries
  `-DF_RELEASE`, and runs `SoraPassportTests` on a new simulator. Code that
  exists only under `#if F_RELEASE` (genesis pinning, production config and
  node URLs, the production-only feature policy) is tested on every change,
  as the retired "Full Release XCTest Closure" did (fix round).
- Job 3 compiles an unsigned Release app for devices and checks arm64, the
  bundle ID `co.jp.soramitsu.sora`, the scene manifest, and that no static
  `.a` archives are embedded under `Frameworks/`.
- Every CI build passes `-onlyUsePackageVersionsFromResolvedFile`, so it uses
  exactly the Swift package versions pinned in the committed
  `Package.resolved`. Without it, a build with fresh DerivedData re-resolved
  and moved some pins to newer releases (seen locally: nanopb, swift-http-types,
  swift-nio-http2), so CI would not test what ships (fix round).

### User-visible effects

- The app launches on iOS 26 and 27. Before, it crashed at launch when built
  with the current SDK.
- No change to wallets, keys, addresses or stored data. Key material is not
  read or written by this change.
- Spinners and toasts are visible on scene-based builds.

### Verification (Xcode 27.0)

- Builds: `SoraPassport` Debug (simulator), `SoraPassportDev` (simulator) and
  unsigned `SoraPassport` Release for `generic/platform=iOS` all succeed.
  The Release app is arm64, `co.jp.soramitsu.sora`, has the scene manifest,
  and embeds only dynamic frameworks.
- Simulator SORA-Release-A (iPhone 17 Pro, iOS 27): Splash, then onboarding,
  no crash. Background and foreground keep the same process and screen.
  A warm `irohaconnect://` link and a cold-launch link are each routed once.
  The `SoraPassportDev` app also launches. Launching with the evidence
  enrollment argument shows the evidence-only screen; a normal launch after
  removing that test namespace shows onboarding.
- `SoraPassportTests` on iOS 27: 326 tests, 0 failures
  (`WalletModernizationTests` 236, `WalletUXTests` 29,
  `WalletRecoveryExporterTests` 12, `WalletRecoveryCapabilityGateTests` 11,
  others 38). The first run found 2 `WalletUXTests` cases failing because
  their windows had no scene; they pass after the fix above.

### Fix round (review findings)

- External displays (major): fixed as described above. New test
  `WalletUXTests.testOnlyTheApplicationSceneHostsTheWallet` checks that only
  the application role gets `SceneDelegate` and that an external-display
  role gets no delegate.
- Release-configuration tests in CI (minor): added as CI job 2 above.
- Pinned package versions in CI (minor): every CI `xcodebuild` call passes
  `-onlyUsePackageVersionsFromResolvedFile`, as described above.
- Verification (Xcode 27.0, SORA-Release-A, iOS 27):
  - Debug, `SoraPassportDev` and unsigned Release device builds succeed.
  - The app launches to Splash, then onboarding, with no crash.
  - `SoraPassportTests`, Debug: 327 tests, 0 failures.
  - `SoraPassportTests`, Release configuration (built exactly as the new CI
    job does, with pinned package versions): 327 tests, 0 failures.
  - In one of two full Debug runs,
    `WalletModernizationTests.testCancelledLifecycleAcquireOperationDoesNotLeakLease`
    hit its 2-second timeout. It passed in the other full run, in the
    Release run, and 50 of 50 times when run alone. This test predates this
    change and does not touch scenes. RELEASE-CHECKLIST.md lists it as a
    possible CI flake.
  - Checked again on a clean copy of branch commit `7520a9f6`, which
    includes the later SORA Card and package-removal commits: the Debug app
    launches to Splash, then onboarding, on SORA-Release-A with no crash.
    `SoraPassportTests` passes in Debug (327 tests, 0 failures) and in the
    Release configuration, built as CI job 2 does (327 tests, 0 failures).

## i2: SORA Card residue and dead code removed

### Why

- SORA Card (PayWings / Sumsub KYC / X1 on-ramp) is discontinued. Its code
  was removed before this release, but strings, images, a KYC microphone
  permission text, a config flag and the two vendored packages it brought
  in (reCAPTCHA, JOSESwift) were still in the repository, and some of them
  still shipped in the app.
- The app also carried code and resources from the retired SORA v1 backend
  and fully commented-out files. Less code means a smaller app, fewer
  proprietary binaries and less to review.
- Rule for this task: nothing that touches key storage, migration or
  recovery was changed. Wallet keys, addresses and stored data are not read
  or written by any of these changes.

### What changed

**SORA Card, KYC and fiat on-ramp residue** (`52a17f05`)

- `Info.plist`: removed `NSMicrophoneUsageDescription` ("…to pass KYC").
  Nothing in the app or its vendored binaries records audio.
- PI indexer `mobileConfig`: the query no longer selects `soracard` and
  `PIMobileConfig` no longer decodes it. The KMM `SoraConfig` initializer
  still requires the argument, so the app passes `false`.
- Deleted the SORA Card asset folder (KYC status art and card front,
  9.1 MB) and the old More-menu card icon.
- Deleted 40 unused SORA Card and X1 fiat on-ramp strings from all 33
  `Localizable.strings` catalogs (including `ja`), and their entries in the
  Middle Egyptian generator script. No new strings were added.

**Vendored packages**

- `VendorPackages/RecaptchaEnterprise` (Google binary, 9.5 MB, referenced
  by nothing) deleted (`77f9d603`).
- `JOSESwift` (the PayWings JWT/JWE dependency, statically linked into
  `SoraPassport` and `SoraPassportDev` but imported by nothing) unlinked
  and deleted (`7520a9f6`). Its only harness had already been retired
  with the qualification scripts in i1.
- `MPQRCoreSDK` (Mastercard EMV-QR dynamic framework with armv7/i386
  slices and no dSYM) is no longer embedded in the app (`8c65fd97`). The
  app linked `SSFQRService` only for two QR wire-format constants; it now
  declares `SubstrateQRConstants` itself in `ScanQR/QRCommon.swift` with
  the same values (`"substrate"`, `":"`) and links `SSFUtils` directly
  instead. The vendored shared-features tree is unchanged. New
  `AddressQRCodecTests` pins the address and receive QR formats, so QR
  codes shown by 3.8.x and 3.9.0 stay readable by each other.
- `SoraDocuments` (SORA v1 DID document helpers, a static SwiftPM
  library) unlinked from all four targets and deleted, together with the
  SORA v1 API error layer that was its only user (`2e901e32`). It was
  never an embedded framework, so this removes compiled code, not a file
  in `Frameworks/`. `Package.resolved` is unchanged by all of
  these removals.
- Kept on purpose: `SoraWalletBinary` (the embedded `sorawallet`
  framework; `IrohaCrypto` links it by name), FLEX (already Dev-only) and
  the `MPQRCoreSDK.xcframework` file in the vendored tree (no longer linked).

**Dead code and files**

- `dfc05f90`: nine compiled files that were 100 % commented out; files in no
  target (a stale `AssetModel` duplicate, `VerificationState`, 171 KB of
  stale Cuckoo mocks, four dead tests, a `.textClipping`, a copied test
  `Info.plist`, the unreferenced `SoraPassport/de.lproj`, Generamba
  templates). `GoogleService-Info-Staging.plist` is no longer copied into
  the production app as a resource (the Staging configuration still
  installs it through the Firebase setup phase, like every configuration).
- `eb94ba48`: the SORA v1 FireMock network mock tree (49 Swift files,
  Dev-only) and its 51 JSON fixtures, which were bundled into the
  production app. FireMock is unlinked from `SoraPassportDev`; the test
  targets still use it.
- `e84dd362`: 33 unreferenced SORA v1-era types and six closed clusters
  with no outside users (modal input presentation, staking-era
  subscriptions, compact bar, skeleton cells, call-path table, Messages
  toast module), plus twelve test files whose classes were empty. Every
  file was checked for outside references (comments stripped) and all
  targets compile without it.
- `2e901e32`: the SORA v1 response envelope and request-error layer
  (17 files) and `SoraDocuments`, as above.
- Review fix: the unused test helper `DummyNetworkMock` is deleted. Its
  default fixture, `emptyResponse.json`, went away with the mock JSON
  above, so any future use would have failed. `NetworkMockManager` still
  uses FireMock in the test targets.

In total about 63,500 lines were removed across 484 files (436 of them
deleted): about 19,400 of those lines are vendored package code (211
files), the rest SORA Card PDFs, strings, mock fixtures and dead app code.

### User-visible effects

- None in the UI. The app no longer declares a microphone permission, and
  the download is smaller: the SORA Card PDFs, the mock JSON and the
  embedded `MPQRCoreSDK` dynamic framework are gone, and the
  `SoraDocuments` static code is no longer linked.
- QR codes: unchanged format. Receive QR codes made by 3.9.0 scan in 3.8.x
  and vice versa.
- No change to wallets, keys, addresses, balances or stored data.

### Verification (Xcode 27.0, SORA-Release-A, iOS 27)

- After each commit: `SoraPassport` Debug with all test targets
  (`build-for-testing`, pinned package versions) and `SoraPassportDev`
  build successfully.
- `AddressQRCodecTests`: 4 tests, 0 failures.
- Final tree (`2e901e32`):
  - `SoraPassportTests`, Debug: 331 tests, 0 failures (327 before plus the
    4 new QR tests).
  - `SoraPassportTests`, Release configuration, built as CI job 2 does:
    331 tests, 0 failures.
  - Unsigned Release build for `generic/platform=iOS` succeeds. Its
    `Frameworks/` holds only FirebaseAnalytics, GoogleAdsOnDeviceConversion,
    GoogleAppMeasurement(+IdentitySupport), blake2lib, libed25519,
    sorawallet and sr25519lib: no `MPQRCoreSDK`. The
    bundle has no mock JSON, one `GoogleService-Info.plist`, and no
    `NSMicrophoneUsageDescription`.
  - The Debug app and the `SoraPassportDev` app launch on SORA-Release-A to
    the onboarding screen with no crash.
  - `Package.resolved` is unchanged.
- Review fix round (`DummyNetworkMock` removal, doc wording): the
  `SoraPassport` scheme with all test targets and `SoraPassportDev` build;
  `SoraPassportTests` Debug: 331 tests, 0 failures; the unsigned Release
  device build succeeds with the same eight frameworks; the Debug app
  launches to onboarding with no crash.
- Not run here: a manual QR round trip on devices (needs a wallet and a
  camera). It is in RELEASE-CHECKLIST.md.

## i3: Live-runtime signing, indexer tolerance, flags, version, privacy

### Why

- Every SORA2 transaction failed on mainnet. The app accepted only runtime
  130 (spec and transaction version 130 plus one pinned metadata hash) in
  six places. Mainnet moved to 132 on about 28 September and to 133 (transaction
  version 131) on about 7 October. Fee estimates, transfers, swaps, referral
  and claim calls all stopped, the new runtime metadata was never stored, and
  the runtime snapshot was never rebuilt.
- The deployed PI indexer (`pi.soramitsu.io`) can lag behind the schema the
  app expects. It may reject the whole `mobileConfig` query when it does not
  know the feature-flag fields, and its public query plan rejects referrer
  rewards ordered by timestamp.
- Taira testnet, Polkamarkt and the Nexus portfolio were visible by default
  in production. IrohaConnect (a new pairing and signing deep link) was
  enabled.
- Version 3.8.7 already has TestFlight builds. Two tester-only locales
  (Old Akkadian, Middle Egyptian) were in the production language picker,
  and `egy-Egyp` triggered ITMS-90176.
- The QA migration-evidence harness, which can read every wallet key item,
  was compiled into App Store builds. The privacy manifest left out
  required-reason APIs that the app uses. A photo-library permission string
  was missing.
- Release builds could silently switch to a different Google Sign-In client,
  which would hide existing Google Drive backups.

### What changed

**Signing against the live chain runtime** (`2535b6a3`)

- Runtime admission (`ReviewedSoraRuntimeSnapshotAdmission.validate`, used
  by the runtime sync service, the snapshot factory and the hot-boot factory)
  accepts any SORA2 mainnet runtime at or above the reviewed floor (spec
  130). The metadata bytes must declare, in their own `System.Version`
  constant, the spec name `sora-substrate` and exactly the spec and
  transaction versions they are stored under. The chain is still pinned by
  genesis hash, and the type-registry pins are unchanged. Metadata for
  runtime 133 is now stored and the snapshot is rebuilt.
- Before encoding any SORA2 extrinsic (fee estimate, prepare, submit), the
  extrinsic service reads `chain_getRuntimeVersion` and the node's metadata
  from the same live engine that supplies the nonce, era and genesis and
  receives the signed bytes. The metadata hash is stored only after its
  `System.Version` matches the reported version (since the fix round it is
  kept across launches and also recorded by the runtime sync service; see
  "Fix round" below). `Sora2LiveRuntimeValidator` (modelled on
  Android's `requireMutationRuntimeIdentity`, without its runtime-130 block)
  requires the local runtime to match the live spec version, transaction
  version and metadata hash.
  - If the app's metadata is behind a runtime upgrade, nothing is signed.
    The error is `runtimeUpgradeInProgress`, and the runtime sync service is
    asked to fetch the live runtime. If the metadata differs for the same
    version, the stored copy is replaced only after the new download passes
    admission; it is never deleted first.
  - Send screens show a calm message in English or Japanese: "The SORA
    network was just upgraded. The app is updating its network data. Please
    try again in a few seconds."
- Pending-transaction recovery: recovery contexts accept any runtime from
  the floor up, so contexts written at runtime 130 stay valid. The status
  reconciler no longer uses the Polkamarkt runtime pin. It decodes events
  with the runtime that produced the inclusion block: the current snapshot
  when it is that exact, proven runtime, otherwise that block's own
  metadata. One entry that cannot be resolved yet no longer blocks the
  others.
- The runtime-130 pins remain only for Polkamarkt, whose mutations stay
  compiled off.
- `runtime-sora.json` gains `"Index": "u32"`. Runtime 133 renamed the nonce
  type to `Nonce`, and the encoder failed with `unresolvedType("Index")`.
  The compact encoding of a nonce does not depend on its integer width, so
  bytes for earlier runtimes are unchanged. The reviewed size and SHA-256
  pins for this bundled file are updated (136,971 bytes, `7a96f47a…`).
- Wallet keys, addresses and derivation are not touched. sr25519, SS58
  prefix 69, genesis pinning and the production signing path are unchanged.

**PI indexer tolerance** (`2ac54ecc`, `b46970e7`)

- `mobileConfig`: when the deployed schema rejects the feature-flag query
  (GraphQL errors with HTTP 200, or HTTP 400), the app reads the base fields
  (`blockExplorerUrl`, `substrateTypesUrl`, `nodes`) with a
  schema-compatible query and turns every optional feature off. Network and
  server failures are not hidden: the app quietly keeps the bundled nodes
  and types, as before. No error is shown.
- Referrer rewards: if ordering by timestamp is rejected, the app reloads
  them ordered by ID. Rewards are summed per referral, so the order does not
  matter.
- The live indexer was checked on 2026-10-10. It now serves the full
  `mobileConfig`, but it also returns `polkamarktVisible`, `nexusAvailable`
  and `tairaDefaultVisible` as `true`. The production surface policy below
  keeps those features hidden in App Store builds anyway.

**Chain sync on a fresh install** (`ec6a2cbf`)

- On a fresh install, every chain sync in the first session failed with Core
  Data error 133021 (uniqueness constraint conflict). PI lists
  `wss://mof2.sora.org` as "Sora", the bundled list has the same URL as
  "SORA Ministry of Finance 2", and the node store allows one row per URL.
  With no chain saved, the runtime was not synced in that session.
- The chain now keeps one node per URL, and the bundled name wins.
  `ConfigService` keeps the bundled nodes and type registry; PI can only add
  nodes at URLs that are not already bundled.

**Production defaults and surfaces** (`2c9c1ad0`)

- When nothing is stored, Taira, Nexus and Polkamarkt are now off until PI
  publishes them. Before, all three were on, which applied to every App
  Store 3.8.6 user.
- `ProductSurfacePolicy` (compile-time, `F_RELEASE`): App Store builds never
  show the Taira testnet switch, Polkamarkt (Explore button, tab push and
  More menu route) or the Nexus portfolio (account network button, wallet
  route and More menu route). It applies only at these UI entry points.
  `NexusNetworkAdmissionPolicy`, derivation, migration and
  pending-transaction reconciliation are unchanged.
- IrohaConnect: `canHandle` returns false in App Store builds, so links and
  QR codes are ignored. The `iroha`/`irohaconnect` URL schemes are no longer
  in `Info.plist`. The new script `register-irohaconnect-url-schemes.sh`
  adds them to the built Info.plist for non-Release configurations only.
  The Google Sign-In URL type stays at index 0.

**Locales** (`55516b6a`)

- `akk.lproj`, `egy-Egyp.lproj`, the Noto Sans Egyptian Hieroglyphs font and
  its licence, the font's `UIAppFonts` entry, project references, the
  picker's special titles, the generator script and the two localization
  notes are removed. SoraUIKit no longer adds the hieroglyph font to every
  font's cascade list.
- A tester whose stored language is a removed locale gets the best shipped
  device language at startup, or English.

**Version** (`f04967eb`)

- `MARKETING_VERSION = 3.9.0` in all five xcconfigs.
- `CURRENT_PROJECT_VERSION = $(SORA_IOS_BUILD_NUMBER:default=2026101001)`
  in each xcconfig. CI passes `SORA_IOS_BUILD_NUMBER` as an environment
  variable or build setting. The ten target-level `CURRENT_PROJECT_VERSION
  = 4` overrides are removed.

**Migration-evidence harness** (`15510df2`)

- The harness is compiled only under `SORA_MIGRATION_EVIDENCE_HARNESS`.
  Debug, Dev, Test and Staging set it through
  `SORA_EVIDENCE_HARNESS_CONDITION`; Release does not.
- Release builds get an inert stub: `bootstrap()` is always `.inactive`, and
  every hook does nothing. Call sites are unchanged.

**Privacy** (`e6584e45`)

- `PrivacyInfo.xcprivacy` declares FileTimestamp `C617.1`, DiskSpace
  `E174.1` and SystemBootTime `35F9.1`, in addition to UserDefaults
  `CA92.1`. Collected data now lists crash and diagnostic data (Crashlytics)
  and product interaction and device ID (Firebase Analytics automatic
  collection). None of it is linked to the user or used for tracking.
- The embedded `sorawallet.framework` has its own manifest (UserDefaults,
  SystemBootTime).
- `Info.plist` adds `NSPhotoLibraryAddUsageDescription`, which the share
  sheet's Save Image needs. The camera, Face ID and photo-library strings are
  clearer; Face ID unlocks the wallet and is not only for IrohaConnect. The
  English and Japanese `InfoPlist.strings`, which override Info.plist, use
  the same text. Other locales keep their existing translations. The
  microphone string had already been removed in i2.

**Google Sign-In continuity** (`1d9eaf13`)

- For Release, `inject-google-signin-info-plist.sh` takes `GIDClientID` and
  the callback scheme only from `SORA_GOOGLE_TOKEN_DEV` and
  `SORA_GOOGLE_URL_SCHEME_DEV`, the build settings that App Store 3.8.6
  used. It fails if another Google setting holds a different client, fails
  an archive when those settings are missing, and checks that the scheme is
  the reversed client ID. A plain Release build without them (the CI compile
  check) warns and must not be distributed.

**CI** (`.github/workflows/ios_ci.yml`)

- The live-network test class is skipped in both test jobs.
- The Release bundle check now also requires version 3.9.0, a numeric build
  number above 2026091402, no harness code, no IrohaConnect URL scheme, no
  removed locale, the four required-reason categories, the sorawallet
  manifest, the photo-library add string and no microphone string.

### User-visible effects

- Sending, swapping and every other SORA2 transaction work again on the
  current mainnet runtime, and keep working across future runtime upgrades
  without an app update. Right after an upgrade, a send can briefly show
  "The SORA network was just upgraded…"; trying again a few seconds later
  works.
- Prediction markets, the Taira testnet switch and the network portfolio
  are not shown in the App Store app. IrohaConnect links do not open it.
- The language list no longer offers Old Akkadian or Middle Egyptian.
  Testers who had chosen one see their device language, or English.
- Clearer permission prompts for camera, Face ID and photos. Saving a QR
  code image from the share sheet now asks for permission instead of
  failing.
- Referral rewards load again on the Friends screen.
- A fresh install connects to the chain and loads the network runtime in its
  first session, without a restart.
- No change to wallets, keys, addresses or stored account data.

### Verification (Xcode 27.0, SORA-Release-A, iOS 27)

- New tests:
  - `Sora2LiveRuntimeTests` (11) use real mainnet runtime 133 metadata
    (`Fixtures/Modernization/sora2-metadata-spec133.scale`, SHA-256
    `e7b2459c…`, the hash the audit reported). They cover admission,
    version binding, the metadata round trip (the re-encoded metadata hash
    equals the node's), live validation, the recovery-context floor,
    transfer encoding and the translated message.
  - `PIMobileConfigFallbackTests` (6) drive the PI client through a stubbed
    URL protocol: old schema, HTTP 400, current schema, unavailable PI, and
    the referrer-reward order fallback.
  - `ProductSurfacePolicyTests`, `ShippedLocalizationTests` and
    `PrivacyDeclarationTests` run in Debug and in the Release configuration.
- Live-network test `Sora2MainnetLiveSigningTests`, run on the simulator on
  2026-10-10 against `wss://ws.mof.sora.org` with
  `TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1`. It uses the app's admission,
  snapshot and bundled types, live-runtime validator, extrinsic assembly and
  sr25519 signer, with a throwaway in-memory key, never a user key. Result:
  live runtime spec 133, transaction version 131, metadata
  `ab22a2d4…` (hex form) matching the app's computation;
  `payment_queryInfo` decoded (partial fee 100018412589707326, about 0.1
  XOR), `payment_queryFeeDetails` decoded into the app's model with the
  same fee; `author_submitExtrinsic` rejected with exactly 1010 "Invalid
  Transaction: Inability to pay some fees (e.g. account balance too low)".
  This means the signature, genesis, era and runtime versions were all
  accepted. The test also runs the extrinsic service's own live-runtime
  operations twice (the second time from the cache) and checks that they
  agree. It is skipped unless the variable is set, and CI skips the class.
- In the app (Debug build, fresh install on SORA-Release-B): first launch
  stores the chain with both bundled nodes once each, stores runtime 133/131
  metadata (623,616 bytes) and logs "Did complete snapshot". Before the
  chain-sync fix, the first session failed every chain sync with error
  133021 and stored no runtime. Screenshot of the onboarding screen:
  `scratchpad/screens/ios/i3-release-correctness/03-fresh-install-simB.png`.
  A fee estimate in the UI was not exercised: it needs a wallet, and
  simulator UI control was not available in this session. RELEASE-CHECKLIST
  "Device QA" covers a real send.
- Full suites (`SoraPassportTests`, live class skipped): Debug 357 tests, 0
  failures. Release configuration (built as CI job 2 builds it): 357 tests.
  The only failure in the first run was `testRemovedLocalesAreNotPackaged`,
  because the reused DerivedData still held `akk.lproj`/`egy-Egyp.lproj`
  from older builds. It passes after those stale folders are removed. CI
  builds into fresh DerivedData.
- Builds: `SoraPassport` Debug (simulator), `SoraPassportDev` (simulator) and
  unsigned `SoraPassport` Release for `generic/platform=iOS` all succeed.
  The Release app passes every "Check Release app bundle" step of
  `ios_ci.yml`, run locally: 3.9.0 (2026101001), arm64, no harness, no
  IrohaConnect scheme, no removed locale, privacy declarations present.
  Without the Google secret, the Release build warns as designed.

### Fix round (review findings)

**Activity history on the deployed PI (major)** (`32fd6850`)

- Why: the deployed PI's public query plan accepts history filters only
  with an exact signer `address` outside any OR (checked on the live
  indexer on 2026-10-10: the app's `address OR dataFrom OR dataTo` filter
  gets HTTP 200 with `BAD_USER_INPUT`; `address` alone with the same type
  filter and timestamp order is accepted). Every Activity page failed, and
  Activity showed "could not load" with a Refresh that could never work.
- When PI rejects the all-roles filter as an unsupported query (GraphQL
  errors, or HTTP 400), the history walk restarts from page one with the
  accepted signer-only filter. Outages and other errors are not treated as
  a schema rejection. The choice is remembered for 30 minutes per app run,
  then the full filter is tried again, so a fixed indexer is picked up
  without an app update.
- A signer-only page may contain only rows the account signed. Lookups of
  pending transaction hashes keep the all-roles filter, which PI accepts
  with an `id` filter.
- Activity shows a calm note above the list, in English and Japanese:
  "Incoming transfers from other accounts may not appear in Activity right
  now. Your balances are not affected." The validated offline history cache
  remembers which kind of page it holds (older entries count as complete).

**Signing error messages** (`ddf3dc7e`)

- The wallet-binding check (missing or mismatched SORA2 account row,
  read-only account) now throws `signingAccountUnavailable`. Its message
  offers Try again and restoring the account with its recovery phrase,
  instead of "could not confirm the SORA network version". Other accounts
  are not affected.
- A node whose block zero is not SORA2 mainnet throws `unexpectedNetwork`.
  A runtime that is not `sora-substrate`, is below the reviewed floor or has
  no `System.Version` throws `unsupportedRuntime` instead of
  `runtimeUpgradeInProgress`. Both show "The connected node does not match
  the SORA network this app uses, so nothing was signed. Choose another node
  and try again." and do not ask the runtime sync to refresh.

**Live-runtime proofs and metadata replacement** (`84fb787c`)

- The proven metadata hash per runtime version is kept across launches
  (UserDefaults, SORA2 mainnet only, at most 16 versions; it is not wallet
  data). Concurrent operations share one metadata download. The runtime
  sync service records the proof when it saves metadata it downloaded from
  the connected node and admitted for that version. After that, each fee
  estimate, prepare and submit reads only `chain_getRuntimeVersion`, not
  about 1.25 MB of metadata per launch.
- A metadata replacement (stored copy differs from the node's for the same
  version) is remembered per chain and version. Automatic retries keep
  re-downloading instead of skipping the cached copy, and repeated requests
  from signing while the replacement runs or waits for its retry no longer
  cancel it and reset the backoff. The stored copy is still replaced only
  after the download passes admission.

**Node choices from older releases** (`fc336c65`)

- Node rows have a store-wide unique URL. A custom node at a URL that 3.9.0
  bundles (for example `wss://ws.mof.sora.org` added when PI listed only
  mof2) stays the user's custom node and is not saved again as a default
  node. The selected node is saved under the name of the default or custom
  node with its URL, so saving no longer renames it back to PI's "Sora" and
  the next sync sees no change (before, every sync rewrote the chain and
  restarted its connection). The mapper reuses a row with the same URL that
  an older release saved for a selected node on its own.

**Smaller fixes**

- Language: a stored localization this build does not ship falls back to
  the same language without its region first (`es-CO` from 1.5.1 keeps
  Spanish), then the device language, then English (`2bc2919f`).
- The Info.plist script phase that injects the Google Sign-In client and
  registers the IrohaConnect schemes now starts with `set -e`, so a failure
  of the Google script fails the build even when it prints no `error:`
  line (`60ebe419`).
- New tests run the pending-transaction reconciler's decoder choice through
  the bounded HTTPS transport: a block included under another runtime is
  decoded with that block's metadata, mismatched metadata is refused, and
  the current snapshot is reused only with a matching proof (`891a3959`).
  The reconciler's full pass (one entry deferred while the others resolve)
  still has no unit test: it reads the global wallet network store and
  needs hand-encoded SORA2 event records. It is listed in
  RELEASE-CHECKLIST.md.

**User-visible effects**

- Activity lists the account's own transactions again on the live indexer,
  with a calm note that incoming transfers from other accounts may be
  missing. Balances are read from the chain and are not affected.
- Clearer messages when an account cannot sign on this device or the
  selected node is not SORA2 mainnet.
- Fewer downloads: after the first proof, sending no longer downloads the
  network metadata on each launch.
- Users who added a custom node in an older release keep it, and the chain
  is no longer rewritten on every sync.
- A Spanish (Colombia) choice from an old release stays Spanish.

**Verification (Xcode 27.0, SORA-Release-A, iOS 27)**

- New or extended tests: `ApplicationConfigTests` (node choices from older
  releases, on a SQLite store that enforces the URL constraint),
  `ShippedLocalizationTests` (regional variant), `Sora2LiveRuntimeTests`
  (signing messages, proof persistence, one shared download, failed proof,
  metadata replacement through `RuntimeSyncService`, recovery decoding),
  `PIMobileConfigFallbackTests` (history fallback, accepted all-roles
  filter, foreign rows refused, outage not mistaken for a schema change,
  the Activity operation's coverage, translated note).
- `SoraPassportTests`, Debug, live class skipped: 372 tests, 0 failures;
  the history-operation test added afterwards passes in its class run (12
  tests, 0 failures).
- `SoraPassportTests`, Release configuration built as CI job 2 builds it:
  372 tests, 0 failures.
- Live-network test against `wss://ws.mof.sora.org` (2026-10-10, finalized
  block 27,975,755): spec 133, transaction version 131, metadata
  `ab22a2d4…`, `payment_queryInfo` partial fee 100018412589707326, submission
  rejected only with 1010 "Inability to pay some fees". The extrinsic
  service's operations downloaded and proved the metadata once (fresh
  in-memory proof cache) and used the stored proof the second time.
- Live PI checks (2026-10-10): `address OR dataFrom OR dataTo` with the type
  filter and timestamp order is rejected (`BAD_USER_INPUT`); `address`
  alone is accepted; the transaction-hash lookup (`id in` with the OR) is
  accepted.
- Builds: `SoraPassport` Debug (simulator), `SoraPassportDev` (simulator) and
  unsigned `SoraPassport` Release for `generic/platform=iOS` succeed. The
  Release build still warns that `SORA_GOOGLE_TOKEN_DEV` is not set, as
  designed.

## i4: Key safety, lockouts and recovery (core)

### Why

The audit found that the candidate never lost keys, but locked many users
out of them, and that one rollback path could lose a key:

- **Reinstall** (I-L1): iOS keeps Keychain items when the app is deleted.
  Any retained PIN or wallet key made startup latch `(missing_wallet_store)`
  and Root latch `(unexpected_failure)`. The recovery screen hid every
  restore action, offered no way forward and told users not to reinstall.
  Importing the phrase then failed as "already imported".
- **New iPhone** (I-L2): the database comes back from iCloud, the
  `ThisDeviceOnly` keys do not. The `(missing_wallet_secret)` marker was
  never retried, and the restore check accepted only `(unexpected_failure)`.
- **One account** without keys, with keys that do not match, or a stale 2.x
  selection, zero or several selected rows, or 3/6/9-word wallets locked
  every account (I-L5). Soft-path sr25519 accounts (`//hard/soft`) could
  never be proven (I-L4), and new soft-path imports failed.
- **Transient errors** (locked device, I/O, a full disk during the backup
  copy) were recorded permanently.
- **Interrupted create or import**: a killed import left a journal that
  only the 1.x upgrade resolver understood, so every later launch failed.
- **Google Drive backups made by App Store 3.8.6** have no key verifier and
  were all rejected as "incorrect password". The onboarding restore also
  did not check the backup address and reported an error after JSON
  imports.
- **Downgrade risk**: a 1.x-origin account upgraded by the candidate keeps
  its secret only in `seedEntropy`. App Store 3.8.6 code (a rollback build,
  or a tester returning to the App Store build when TestFlight expires)
  wipes settings when the selected account has no `-secretKey` and deletes
  `seedEntropy` on every launch.
- Phrase import accepted only 12 or 24 words, so 15-word 1.x wallets (and
  18/21-word ones) could not be restored after a reinstall.

### What changed

**Retryable startup failures** (`1408ede4`, `76c62f3f`)

- Every fixed startup code (`missing_wallet_store`, `missing_wallet_secret`,
  `backup_verification_failed`, `selected_account_mismatch`, …) and the two
  journal-read latches are retryable. `interrupted_migration`, the
  account-commit marker and an unreadable marker record keep their own
  resolvers. A retry only re-runs read-only verification; only a full
  proof clears the marker, by compare-and-set.
- Startup retries a retryable failure automatically, up to three runs in
  total (0.3 s and 0.6 s apart), before the recovery screen is shown.
- A failed migration attempt whose backup copy was never verified (the
  live store was never replaced) is moved, not deleted, to
  `Documents/CoreData/WalletMigrationSuperseded/<id>/`, and a fresh attempt
  runs. A failed attempt with a verified backup is re-proved for every
  retryable code.
- Before the first unlock, startup waits for protected data instead of
  recording a failure.

**Identity proofs** (`8a322950`)

- sr25519: a stored 64-byte secret matches when its 32-byte scalar equals
  the re-derived one (constant time); the stored bytes are then proven with
  the signature challenge against the account public key. Soft junctions
  randomize the other 32 bytes. ed25519 and ecdsa are compared in full.
- 3/6/9-word wallets (4/8/12-byte entropy, imported by App Store 3.8.6) are
  proven and signed through their stored seed or secret; the entropy is
  left untouched. Such phrases are still not accepted for new imports.

**One account never blocks the others** (`edff7f53`)

- An account with no key material on this device, or with material that
  does not prove its address, is read-only. The migration manifest records
  it (`signingUnavailable`, optional), the network model keeps the
  recorded source and Nexus children of a known wallet, and a wallet seen
  for the first time without keys gets the new `signingUnavailable`
  source. Keychain read errors still propagate and are retried.
- Signing a read-only account fails with `keysNotOnThisDevice` (keys
  missing) or, since the fix round, `keysNotVerified` (keys present but not
  matching) before any secret is used. See the fix round for the messages.
- `restoreKeysForReadOnlyAccount` (phrase, seed or secret) adds the missing
  keys while the app is in normal use: add-only, proven first, and the
  network model is rebuilt (the placeholder becomes the proven source and
  Nexus children are added). This is the domain API for the Safe Mode UI.
- A read-only account can be removed on the user's confirmed request. Since
  the fix round this removes only its account row and network entries; its
  Keychain items stay (see "Fix round").
- Watch-only contradictions (a watch-only marker beside signing keys or a
  signing source) stay fail-closed.

**Selection** (`ecbfb037`, `34c9e4f9`)

- Zero or several selected rows, or a stale or absent 2.x `selectedAccount`
  setting, resolve deterministically: the single selected row; otherwise
  the account the 2.x setting names; otherwise the lowest order, then
  address. No accounts: a stale setting is ignored. Only duplicate
  identifiers throw.
- Startup writes the resolved selection back when Core Data holds zero or
  several selected rows, because App Store 3.8.6 reads only that row.

**Google Drive backups** (`f0b4f6c8`)

- With a key verifier, it must decrypt to the backup address. Without one
  (App Store 3.8.6), at least one secret must be present and every
  non-empty encrypted field must decrypt (authenticated encryption, so a
  wrong password fails). The recovery-screen restore still proves the
  address before any write.
- Onboarding Drive restore refuses a phrase, seed or JSON whose account is
  not the backup's address before any Keychain write
  (`backupIdentityMismatch`), and no longer reports an error after a JSON
  import.
- Phrase import and Drive restore accept 12, 15, 18, 21 and 24 words for
  SORA2. Nexus derivation stays 12/24 only, so 15/18/21-word wallets are
  SORA2-only.

**Reinstall and welcome back** (`dcda8416`)

- Retained evidence is classified as none, Keychain-only (the reinstall
  signature) or durable (database sidecars, migration backup, wallet
  settings, watch-only marker, network snapshot). Keychain-only no longer
  blocks startup and writes nothing. Startup verification clears markers
  that earlier 3.9.0 candidates latched for this state.
- Root routes a Keychain-only install to a new **Welcome back** screen:
  - "Restore wallets found on this iPhone", after the PIN used on this
    iPhone before (wrong PINs lead to short waits, never a permanent lock;
    see the fix round). Only wallets whose own items
    prove their tagged SORA address are restored (phrase, seed or JSON
    secret; sr25519, ed25519, ecdsa), through the normal journaled insert.
    Their items are adopted as they are; only absent scoped copies are
    added. They are named "Restored wallet", "Restored wallet 2", …
  - "Restore with recovery phrase" and "Restore from Google Drive" open
    onboarding.
  - "Show my recovery phrase", after the PIN, for wallets whose phrase
    entropy is on this iPhone and proves the address.
  - "Set up this iPhone again" (two confirmations) opens onboarding. The
    Keychain items stay; this screen is offered until a wallet exists.
- Importing a phrase, seed or JSON whose address already has items in the
  Keychain adopts them when they hold the same key (sr25519: same scalar)
  and writes only the absent ones. Any item that differs stops the import
  before any write ("This iPhone already has different saved keys for this
  wallet. Nothing was changed. Contact SORA support.").

**Recovery screen** (`dcda8416`)

- Restore actions are shown from facts (accounts in the database whose keys
  are missing), whatever cause the latest check recorded.
- New "Show my recovery phrase" (after the PIN) and "Set up this iPhone
  again". The latter, after two confirmations, moves this install's wallet
  database, migration backups, network model and commit journals into
  `Documents/WalletSetAside/<time>-<id>/` with a copy of the wallet
  settings (`wallet-settings.plist`), removes those settings and clears the
  marker. Nothing is deleted; the Keychain is never touched. The next
  launch is a welcome back, so wallets whose keys are on the iPhone can be
  restored with the PIN.
- "Do not delete or reinstall the app" is replaced by "SORA stopped before
  changing anything and did not delete or replace any wallet data. Try
  again, restore with your recovery phrase or Google Drive backup, or
  contact SORA support…".
- `WalletRecoveryOptions` exposes the Safe Mode flags `canRetry`,
  `canRestoreFromPhrase`, `canRestoreFromDrive`, `canRestoreExistingKeys`,
  `canShowPhraseAfterPin`, `canReadOnly`, `canExport` and
  `canSetUpDeviceAgain` per state (`WalletRecoveryState.welcomeBack` /
  `.recovery`). Every state has a forward action besides Try again.
  `canReadOnly` is false while a recovery marker is set: outside recovery,
  read-only is automatic per account.

**Interrupted create or import** (`dc94149c`)

- Only a real 1.x first activation keeps the legacy resolver. Any other
  unresolved journal is resolved from Core Data: the account row is there,
  so the network model is rebuilt, the selection written and the journal
  activated; or it never got there, so the journal becomes `abandoned`.
  Items the abandoned import saved stay and are adopted by the next import
  of the same phrase.

**Downgrade safety: scoped copies** (`34c9e4f9`)

- SORA2 accounts backed only by the global `seedEntropy` get
  `<address>-entropy`, `-seed` and `-secretKey` copies at every startup
  after the network model is active, and right after the explicit 1.x
  upgrade: add-only, proven before writing, read back after, in the order
  entropy, seed, secret (an interrupted run resumes from the scoped
  entropy), stopping at any item that differs. `seedEntropy`, `privateKey`
  and `userName` are never touched. Failures are logged and retried at the
  next launch; recovery is never latched.
- Removing such an account removes the global entropy with it only when
  the entropy derives exactly that account (fix round; before the fix round
  equal bytes under another path or crypto type also counted).

### Key-safety invariants (how each is kept)

- No code path in this change updates or deletes a Keychain item. Writes
  are `addKey` of absent items only (adoption, scoped copies, restore),
  each proven against the account first. The only deletions are the
  existing rollback of items a failed import itself just wrote, and the
  existing explicit account removal.
- Addresses, public keys and derivation (sr25519, SS58 prefix 69,
  mini-seed, junction parsing) are unchanged; the soft-junction rule only
  changes how a stored secret is compared.
- Files are moved, never deleted, by "Set up this iPhone again". Superseded
  attempts are moved; since the fix round only the newest three are kept
  (older unverified failed attempts, which never replaced the live store,
  are pruned).
- The Core Data model is unchanged, so App Store 3.8.6 can still open the
  store; the selection repair keeps exactly one selected row for it.
- Production signing, genesis pinning and address-prefix checks are
  unchanged.

### User-visible effects

- After deleting and reinstalling SORA, users see "Welcome back" instead of
  a recovery dead end, and can restore their wallets with the old PIN, the
  phrase or Google Drive, or start fresh. Keys are never deleted.
- On a new iPhone restored from iCloud, the wallet opens; accounts whose
  keys did not move are read-only until restored. Other accounts work.
- Google Drive backups made by App Store 3.8.6 restore again.
- 15/18/21-word phrases (including SORA 1.x wallets) can be imported.
- Soft-path and 3/6/9-word wallets open and sign.
- Short-lived problems (locked device, I/O) are retried before any
  recovery screen; that screen always offers a way forward.
- A killed import no longer locks the app.

### Verification (Xcode 27.0, SORA-Release-A, iOS 27)

- New `WalletKeySafetyTests` (28 tests). Fixtures are written by code
  copied from released writers: SORA 1.5.1 `IdentityCreationOperation`
  (`privateKey` + `seedEntropy`), 2.x `e52beedd` / App Store 3.8.6
  `354f176c` `AccountOperationFactory` (phrase, seed and JSON imports), 2.x
  version-1 rows with the UserDefaults selection, and 3.8.6 account
  removal (`-entropy` only deleted). The App Store 3.8.6 launch
  (`SelectedWalletSettings.performSetup`, `InconsistentStateMigrator`,
  `RootInteractor.decideModuleSynchroniously`) is reproduced to show that a
  global-only account loses its key without the scoped copies and keeps it
  with them. A recording Keychain fails on duplicate adds (like the real
  one) and every test asserts that no existing item is updated or deleted.
  Covered: every marker code; automatic retries; 3.8.6 Drive backups
  (recovery screen and onboarding, wrong password, other wallet, foreign
  verifier); reinstall to welcome back with adoption; conflicting retained
  items; latched reinstall markers; removed-account leftovers; Keychain
  discovery with the PIN gate and lockout; phrase reveal; set up again;
  forward actions for every state; new iPhone (with and without the old
  marker) and per-account restore; one keyless account; soft junctions;
  superseded attempts; 2.x selection states; several selected rows and
  their repair; scoped copies, conflicts and resume; downgrade to 3.8.6;
  15/18/21-word imports; 3/6/9-word wallets; interrupted imports before and
  after the Core Data commit.
- Existing tests that asserted the old blocking behaviour were rewritten
  to the new behaviour (not deleted): reinstall cases in
  `WalletModernizationTests` (scoped secret, PIN only, empty store with a
  PIN) and `WalletUXTests` (pristine store, empty bootstrap); the missing
  secret now activates read-only; selection fallbacks; the missing-key
  phrase recovery (now startup opens read-only and the keys are restored in
  the app); failed attempts with typed codes and a changed key; generic
  startup recovery with a mismatched key or an abandoned import journal;
  legacy activation with missing or changed entropy; global-entropy
  conflicts (degraded vs. fail-closed); explicit removal of read-only
  accounts; the full legacy upgrade now also checks the scoped copies; the
  recovery screen's restore buttons follow facts. Durable-evidence cases
  (settings, sidecars, safety backup, watch-only, snapshot conflicts) still
  fail closed.
- `SoraPassportTests`, Debug, live class skipped: 401 tests, 0 failures.
  After the restart fix below, `WalletKeySafetyTests` and `WalletUXTests`
  were run again: 58 tests, 0 failures.
- Simulator (SORA-Release-B, Debug build, Japanese locale): a hosted test
  wrote a 3.8.6-shaped wallet (phrase import, `-secretKey`/`-entropy`/`-seed`)
  and PIN into the simulator Keychain; the app was then uninstalled and
  installed again. Launch showed "Welcome back" (おかえりなさい) with every
  action; "Restore wallets found on this iPhone" with the old PIN restored
  the wallet as "復元したウォレット" and the PIN screen led to the wallet
  home. Screenshots: `scratchpad/screens/ios/i4-key-safety-core/`.
  This found one bug, fixed in `d9fb0d47`: the in-process restart after the
  restore hung on the splash screen (the first migration backup waited for
  the app's own open Core Data connection). The startup restart now closes
  that stack first; a cold launch was not affected.
- Builds: `SoraPassport` Debug (simulator), `SoraPassportDev` (simulator)
  and unsigned `SoraPassport` Release for `generic/platform=iOS` succeed.

### Commits

`1408ede4` retryable markers, `8a322950` identity proofs, `edff7f53`
read-only accounts, `ecbfb037` selection, `f0b4f6c8` Google Drive
backups, `dcda8416` welcome back / adoption / set aside / recovery options,
`dc94149c` interrupted imports, `34c9e4f9` scoped copies and selection
repair, `76c62f3f` transient retries, `d65fb6e8` tests, `d9fb0d47` restart
fix.

### Fix round (review findings)

Reviewers checked every line against the key-safety invariants. Each
finding was verified against the code; all were real and are fixed.

**Blocker: an abandoned import journal blocked database recovery**

- `LegacyWalletAccountCommitRecovery` counted `abandoned` journals as
  unresolved. Every later startup took the ordinary-recovery branch, which
  refuses while a database attempt is unfinished. So a later launch killed
  during its first safety backup latched `(interrupted_migration)` for good:
  the automatic retries and Try again repeated the same refusal. Abandoned
  journals are now terminal there too (and are never re-bound to a marker).
  Test: abandoned and activated journals plus a killed backup copy now
  start `.ready`, twice.

**Account removal never deletes keys it did not prove** (major)

- Removal used to delete a read-only account's own `<address>-*` items, and
  for the last account the PIN, `seedEntropy` and `userName` too, even when
  none of them proved the account. Now `WalletExplicitRemovalPlan` decides:
  - the account's own items go only when they proved it;
  - the PIN goes only with the last account, and only when that account's
    keys proved it (as before this release);
  - `seedEntropy` and `userName` go only when the global entropy derives
    exactly this account: sr25519, default path, no `-deriv` item, address
    and signature proven. Equal bytes under another path or crypto type
    (the same phrase imported again) are not ownership, so removing that
    second account no longer deletes the 1.x wallet's only key.
  - A read-only account is removed as a row and network entries only; its
    items stay quarantined in the Keychain. After removing the last
    read-only account, the next launch is a Welcome back.

**Restoring a read-only account in the app** (major)

- On a new iPhone (files from iCloud, keys not), importing the phrase,
  seed or Google Drive backup of an account that is already in the wallet
  used to fail with "Account already imported". When none of that
  account's keys are on the iPhone, the import now restores them in place:
  add-only, after the material proved the address, then the network model
  is rebuilt and the account selected. An account that has keys, or is
  watch-only, is still a duplicate.
- `WalletAccountKeyAvailability` reports per account, from the keys:
  available, watch-only, keys missing, or keys present but not verified.
- Signing messages: missing keys: "This account's keys are not on this
  iPhone, so it can't send. Your funds are not affected. To send from it,
  import this account again with its recovery phrase or Google Drive
  backup." Keys that do not match: "The keys saved for this account on this
  iPhone could not be verified, so it can't send. They have not been
  changed, and your funds are not affected. Contact SORA support."

**Every signing account gets `-secretKey` (downgrade safety)** (major)

- A restore (recovery screen, Drive, or in the app) now writes every
  supplied item and then the derived `-seed` and `-secretKey` (add-only, in
  the order phrase, seed, secret, read back), for any crypto type and path.
  The startup backfill now also completes accounts with a scoped phrase or
  seed but no `-secretKey` (for example restored by an earlier candidate,
  or interrupted). App Store 3.8.6 signs only with `-secretKey` and wipes
  its settings when the selected account has none.

**Welcome back and leaving it**

- A 1.x wallet backed only by `seedEntropy` is now found on Welcome back
  (proven like the explicit upgrade, including the Iroha `privateKey`), and
  restoring it adds its scoped copies.
- 1.x items that do not prove themselves (for example a `privateKey` that
  `seedEntropy` does not derive) are "not a 1.x upgrade" instead of an
  error, so Splash and Root go to Welcome back, not to a recovery screen
  that "Set up this iPhone again" could not leave. Nothing is changed.
- "Restore wallets found on this iPhone" restores each wallet on its own,
  skips wallets already in the wallet, and reports a partial result
  accurately ("Some wallets were restored"); the wallets restored stay and
  the app continues to them.
- Onboarding ends by setting a new PIN over the earlier install's PIN.
  Before leaving Welcome back (phrase, Drive, set up again, or restoring
  found wallets), the app now keeps a copy of the earlier PIN
  (`earlierInstallPin-N`, add-only, read back) and, while found wallets are
  not restored, asks first ("Restore the wallets found on this iPhone
  first?"). Afterwards, Add account offers "Restore wallets found on this
  iPhone" when such wallets remain; only the earlier PIN unlocks them, never
  this install's new PIN alone.
- Wrong PINs lead to waits of 1, 5, 15 and then 30 minutes after the third
  failure, as on the normal PIN screen, instead of a permanent lock.
- The confirmation texts now say exactly what happens on each screen.

**Recovery screen and set aside**

- "Set up this iPhone again" undoes its moves if one move fails ("Nothing
  was changed"). If a move cannot be undone, the folder is marked
  `INCOMPLETE`, the message says so, and Try again continues in the same
  folder.
- Recovery phrases are shown on a dedicated screen instead of an alert: the
  standard screenshot warning, words hidden while the app is inactive (app
  switcher) or the screen is recorded or mirrored.
- "SORA never deletes wallet keys from this iPhone's Keychain" now reads
  "Recovery never deletes wallet keys from this iPhone's Keychain" (account
  removal does delete proven keys).

**Other fixes**

- A key conflict (or any key-write failure) during an import now closes
  the import's journal as `abandoned` before Core Data is touched, so the
  calm "Nothing was changed" no longer latches recovery for the rest of the
  session.
- A JSON import over retained items that carry a path (a wallet created
  with `//0`, then reinstalled) is adopted when the retained phrase or seed,
  read with that path, and the JSON secret all prove the account.
- 3/6/9-word phrases (App Store 3.8.6) are accepted to restore a known
  address only (Drive backup in onboarding or on the recovery screen, or a
  phrase on the recovery screen), after proof; the short entropy is stored
  with the seed and secret, as 3.8.6 did. New imports still refuse them.
- An interrupted database migration is retried automatically too (3 runs
  in total, proof-gated).
- Superseded migration attempts are capped at the newest 3.

**Tests**: 14 new tests in `WalletKeySafetyTests` (one per finding,
including the abandoned-journal blocker, removal with the same phrase
under //1 and as ed25519, read-only removal keeping every item,
restore-then-3.8.6 signing, in-place restore on a new iPhone, Welcome back
with a global-only 1.x wallet, unproven 1.x items, superseded pruning,
partial restores, set-aside rollback and reuse, JSON over a path, the
earlier PIN after onboarding, a 6-word 3.8.6 Drive backup, signing
messages); updated tests for the PIN waits, the restore result, the
conflict journal, and restore expectations that now include the derived
seed and secret.

**Verification (fix round)**: `SoraPassportTests` on SORA-Release-A
(Debug, live mainnet class skipped): 415 tests, 0 failures. `SoraPassport`
Debug, `SoraPassportDev` and unsigned `SoraPassport` Release for
`generic/platform=iOS` build. On SORA-Release-B the new build opened an
existing wallet (left by the i4 simulator check) straight to the PIN
screen: no recovery screen, no crash.

### Fix round 2 (review findings)

Six findings: three blockers and three majors. Each one was checked
against the code, all six were real, and all six are fixed. Two of them
corrected statements made in the first fix round; those corrections are
noted below.

**Blocker: Welcome back's actions did nothing; the 1.x upgrade never ran**

- `SplashWireframe.showRoot` created the Root module as a local, and
  `RootInteractor.presenter` is weak. Once launch routing returned, the
  presenter, wireframe and interactor were released. Two things broke:
  - Welcome back's "Restore with recovery phrase", "Restore from Google
    Drive", "Set up this iPhone again" and "Continue without them" did
    nothing, because they captured the wireframe weakly.
  - The 1.x "Continue protected upgrade" button started its spinner but
    never called the upgrade, because it captured the presenter weakly.
  This was in place since 1c2f46fc.
- The fix: `RootPresenterFactory` now keeps the module on the window
  (`SoraWindow.rootModule`) until the next startup replaces it. The Welcome
  back closures also capture the wireframe strongly. The wireframe holds no
  state and does not own the controller, so this creates no cycle.

**Blocker: a stop between the import and PIN setup asked for the forgotten earlier PIN**

- Onboarding saves the account before it shows PIN setup. After Welcome
  back, `pincode` is still the earlier install's PIN. If the app stopped
  between those two steps, the next launch asked for that PIN, and the PIN
  screen has no "forgot PIN" option.
- Leaving Welcome back now records `wallet.pinSetupPendingAfterWelcomeBack`
  in settings. While it is set and an account exists, Root opens PIN setup
  instead of PIN entry. PIN setup clears the flag only after the new PIN
  has been saved.
- The same applies when "Restore wallets found on this iPhone" on Welcome
  back succeeds with a PIN that matched only a copy kept from an earlier
  install. The app would otherwise ask for a `pincode` the user never
  proved, so it asks for a new PIN instead.
- Returning from the background no longer asks for the earlier install's
  PIN in two places, where a user who does not remember it would be stuck:
  - while the new PIN is pending;
  - on Welcome back, which has its own PIN-gated actions.

**Major: the earlier PIN could be overwritten without a copy**

- Before, leaving Welcome back only logged a failure to save the copy, and
  stopped adding copies once 4 existed. Onboarding then overwrote
  `pincode`.
- Keeping the copy is now a precondition, enforced by
  `WalletRetainedPinGate.keepEarlierInstallPin`:
  - The copy is add-only, read back, and compared.
  - Every distinct PIN gets its own copy; the limit is gone.
  - If the copy cannot be kept, Welcome back stays open. It shows "Your
    earlier PIN was not saved" with Try again, Restore them now, Contact
    support and Cancel.
- `PinSetupInteractor` applies the same check before it saves a PIN over
  an existing `pincode` during setup. Changing the PIN after entering it is
  not affected. If the check fails, it stops and the earlier PIN stays
  unchanged.
- Correction to the first fix round: the earlier PIN copies are not capped
  at 4.

**Major: a briefly unreadable migration folder could still lock the wallet**

- The shared gate's namespace probe treats any read error as "unfinished
  or unverifiable" and latches a database-interruption marker. Startup then
  found no unfinished attempt and threw `interrupted_migration` on every
  run, so the automatic retries and Try again could not clear it.
- Now, when the marker is a database interruption and nothing is left to
  resume, the marker is cleared by compare-and-set. "Nothing left to
  resume" means there is no attempt, or every attempt re-verifies as
  activated and is not bound to this marker. Before clearing, startup
  proves the following:
  - the live store is the current schema;
  - its inventory can be read;
  - every key it names is present, except for accounts that are already
    read-only.
  An older store goes through the ordinary journaled migration.
- An attempt whose backup verification hit a read error records
  `interrupted_migration` and has no verified artifacts, so it never
  replaced the live store. Under that marker it is now moved to
  `WalletMigrationSuperseded` and a fresh attempt runs, as already happened
  for retryable codes.

**Major: Add account could not restore a read-only account's keys**

- `AddAccountImportInteractor` rejected every address that already had a
  row before the import ran, so the in-place restore from the first fix
  round could not be reached from the app.
- The rule now lives in one place,
  `WalletReadOnlyAccountKeyRestore.applies`, and validation and insert both
  use it (`SelectedWalletSettingsProtocol.restoresKeysInPlace`). An
  existing account counts as restorable only when all of these hold:
  - it is not watch-only;
  - it has the same public key and type as the imported material;
  - none of its keys are on this iPhone.
  Any other existing account is still a duplicate.
- The Google Drive lists in onboarding, Add account, and the "other
  backups" sheet hid every address recorded in `backupedAccountAddresses`.
  That record comes back with an iCloud restore, but the keys do not. The
  lists now hide an address only when its keys are on this iPhone
  (`WalletDriveBackupList`).
- Correction to the first fix round: "Restoring a read-only account in the
  app" now works from Add account → Import and from Google Drive. Before,
  only the domain path worked.

**User-visible effects**

- Welcome back's phrase, Google Drive and set-up actions open onboarding.
  The 1.x upgrade confirmation runs the upgrade.
- If the app stops after a phrase import that started from Welcome back,
  the next launch asks the user to set a PIN, not to enter the earlier one.
- In the rare case that the earlier PIN cannot be saved, Welcome back
  explains it and offers Try again, instead of continuing.
- On a new iPhone restored from iCloud, Add account → Import, or the Google
  Drive list, restores a read-only account's keys.

**New strings** (English and Japanese):
- "Your earlier PIN was not saved"
- the explanation shown under it
- "SORA could not save a copy of the PIN you used before. Nothing was
  changed. Try again."

**Tests**: 9 new tests in `WalletKeySafetyTests`:
- Welcome back actions through `RootPresenterFactory` reach onboarding
  after launch routing returns.
- The 1.x confirm button and the import completion reach the module. This
  test fails without the `rootModule` retention.
- Welcome back → import → stop → PIN setup → new PIN, with the other found
  wallet still restorable with the earlier PIN.
- PIN copies are kept with no limit, and a failing Keychain stops both
  Welcome back and PIN setup.
- There is no resume PIN prompt while the new PIN is pending or on Welcome
  back.
- A marker latched by the gate on a verified namespace, and the same
  marker with no attempt, both reach `.ready`.
- An attempt interrupted during backup verification is set aside and
  retried.
- Add account → Import with the real `AccountImportPresenter` and
  `AddAccountImportInteractor` restores a read-only account. Importing the
  same phrase again is a duplicate.
- The Drive list filter.

**Verification (fix round 2)**:
- `SoraPassportTests` on SORA-Release-A, Debug, with
  `Sora2MainnetLiveSigningTests` skipped: 424 tests, 0 failures.
- With `rootModule` retention removed, the new 1.x-confirmation test fails.
- These builds succeed: `SoraPassport` Debug, `SoraPassportDev`, and
  unsigned `SoraPassport` Release for `generic/platform=iOS`.
- On SORA-Release-B, a real reinstall over Keychain items from an earlier
  install showed Welcome back. Tapping "Restore with recovery phrase", then
  "Continue without them", opened onboarding. Screenshots are in
  `scratchpad/screens/ios/i4-fix2/`.

## i5: Port of the App Store 3.8.6 commits

### Why

App Store 3.8.6 (`354f176c`) has 13 commits that the 3.9.0 candidate did
not have (`git log 4bf5209b..354f176c`). Five of them change behaviour that
users depend on:

- **Chain store wiped on upgrade.** 3.8.6 added `CDConfig`,
  `CDMetadataVersion` and `CDNode` to `SubstrateDataModel`. The candidate
  had the older 10-entity model and opened the store with RobinHood's
  `.removeStore`, so updating from 3.8.6 deleted the user's contacts,
  custom and selected nodes, pool favourites and caches. `.removeStore` also
  deleted the store whenever its metadata could not be read, for example on
  a launch before the first unlock.
- **Asset whitelist failed open.** Until `whitelist.polkaswap2.io`
  answered (and whenever it failed), every on-chain asset was listed with
  its on-chain name and symbol, and such assets stayed in the stored chain.
  Anyone can register a SORA asset with any name, so spoofed tokens could
  appear. 3.8.6 listed only whitelisted assets.
- **DEX ids hard-coded to 0 and 1.** Mainnet `DEXManager.DEXInfos` has
  0 (XOR), 1 (XSTUSD), 2 (KUSD) and 3 (base `0x006a2718…`). Pairs that only
  exist on DEX 2 or 3 were reported as unavailable, and liquidity sent DEX
  "1" for every non-XOR base.
- **KXOR offered as a liquidity base.** KXOR is not a DEX base on chain; a
  supply with it fails after the fee is charged.
- **A damaged chain row crashed every launch** (`preconditionFailure` in
  `ChainModelMapper`).

### What changed

**Versioned chain store** (`45e6c338`)

- `SubstrateDataModel.xcdatamodeld` has two versions: `SubstrateDataModel`
  (v1, unchanged, the candidate's model) and `SubstrateDataModel 2` (v2,
  current), a byte-for-byte copy of the 3.8.6 model.
- Before the store is opened, `SubstrateStoreMigrator` reads its metadata:
  - no store, or a v2 store (every 3.8.6 store): opened as is;
  - a v1 store (2.x to 3.8.5 and the 3.9.0 TestFlight builds): migrated in
    place with lightweight migration;
  - a store that matches no known version, or a file that is not a SQLite
    database: removed together with its `-wal` and `-shm` files (the same
    end state as `.removeStore`; the store holds no key material);
  - a store that cannot be read or migrated now (locked before the first
    unlock, disk full, I/O, busy): left untouched, and this session uses a
    temporary in-memory store. The next launch tries again.
- The store is then opened with `.ignore` and the migration options.
- After the migration the store is in the 3.8.6 schema, so App Store 3.8.6
  opens it after a downgrade without wiping it. A downgrade to a 3.9.0
  TestFlight build from before this change still wipes it (that build has
  `.removeStore`).

**Fail-closed asset whitelist** (`89e49a12`)

- Every chain-sync pass applies a whitelist: the fresh remote list, else
  the last remote list that decoded (saved in
  `Application Support/AssetWhitelist/whitelist.json`), else the bundled
  `whitelist.json`. Assets kept from the stored chain are filtered too.
  Listed assets take the list's name, symbol and icon.
- A downloaded list is used and saved only if it decodes and lists XOR; an
  empty, truncated or HTML response keeps the last good list. Entries that
  do not decode are skipped.
- The bundled list dates from 2.3.1 and lacks XST, TBCD and KUSD (XST and
  TBCD are shown by default). When the bundled list is the source (or no
  list is readable), the protocol's predefined assets
  (`0x02` + 16-bit code + zeros, which no account can register) stay listed
  with their on-chain names. With a remote or last-good list the rule is
  strict.
- The saved list is public data and uses
  `completeUntilFirstUserAuthentication` protection, so a background launch
  can read it.
- The unused `WhitelistOperationFactory` is removed.

**DEX ids from the chain** (`5d8bfbc1`)

- New `DexInfoService` reads `DEXManager.DEXInfos` (`state_getKeysPaged`,
  then `state_queryStorageAt`) and decodes the DEX id from the key and the
  base asset from the value. Compared with 3.8.6's `DexInfoServiceDefault`:
  - an unknown base asset costs at most one chain read and is reported as
    unknown (3.8.6 called itself without end);
  - callers share one read; after a failure the next read waits 30 s;
  - DEX 0 (XOR) and 1 (XSTUSD) are always known, so a failed read never
    blocks XOR or XSTUSD pools;
  - completions are set before operations are enqueued.
- Swaps: the path check, the market sources and the quote cover every DEX.
  The best quote's DEX id is the one the swap is signed with (already
  plumbed through `TransactionContextKeys.dex`).
- Liquidity: the DEX id comes from the base asset's DEX. An unknown base is
  refused (`LiquidityTransferInfoFactoryError.unknownDex`) instead of
  guessed, and a missing DEX id in the context is an error instead of 0.
  The pools service reads the DEX list at start.
- Unused pair checks in `AccountPoolsService` are removed.

**KXOR is no longer a supply base** (`7d9d4cf9`)

- The base picker offers XOR, and XSTUSD unless the target is XST. It no
  longer fails to open when KXOR or XSTUSD is not listed, and the target
  picker no longer needs ETH to be listed.

**Chain store crash guard** (`af3b65a0`)

- Incomplete asset and node rows are skipped; a chain row without an id or
  name is reported as an error. Pruning node rows no longer force-unwraps
  their URL.

**Alerts on the main thread** (`39189a1c`)

- `AlertPresentable` and `UIAlertController.present` move to the main
  thread when called from a background queue, as the 3.8.x line did after
  3.8.6 (`b890dd5c`). Calls on the main thread are unchanged.

**Already done or not ported**

- Photo-library permission string (`354f176c`): done in i3 (`e6584e45`)
  with clearer text and Japanese.
- Shared-features pins, the build-phase removal of static libraries and
  the SORA Card pod (`2b17f41d`, `ea1691fb`, `879f43c8`, `5bf6c40c`,
  `e50c7ca4`, `42361874`, `52872616`, `fa4c910f`): not needed. Shared
  features are vendored; SORA Card is removed. The archive check for
  static libraries is in the i1 checklist.
- `fe184e06` offline config cache and runtime-version cache, and
  `7eaba9b8` (bundled metadata with spec 102, `try? saveBackup` before
  marking a backup done): not ported. 3.9.0 has its own node list and
  live-runtime path, and its backup flow is stricter.
- Tags 3.8.7 to 3.8.9 (`9759b8ae`, `b890dd5c`, `fe9016cd`) follow 3.8.6
  and keep its `SubstrateDataModel`, so v2 covers them. Only the alert
  main-thread change from `b890dd5c` is ported.

### User-visible effects

- Updating from App Store 3.8.6 keeps contacts, the chosen and custom
  nodes, and pool favourites. Updating from a 3.9.0 TestFlight build keeps
  them too.
- The wallet lists only whitelisted assets, with their vetted names and
  icons. Tokens that are not on the whitelist (for example a token someone
  registered with a well-known name) are not shown, as in 3.8.6. Testers of
  earlier 3.9.0 builds may see such tokens disappear.
- Swaps between assets that trade on the KUSD or the fourth DEX are now
  offered and quoted; the best price across all DEXes is used.
- KXOR is no longer offered as the first asset when adding liquidity.
- No change to wallets, keys, addresses or account data. No new strings.

### Verification (Xcode 27.0, SORA-Release-A, iOS 27)

- `SubstrateStoreMigrationTests` (9): a store written with the 3.8.6 model
  (compiled independently from `354f176c` with `momc`, embedded in the
  test) keeps its contact, custom and selected node, pool favourite and
  3.8.6-only rows, needs no migration, and still opens with the 3.8.6
  model; a v1 store is migrated and then opens with the 3.8.6 model; a
  store from an unknown model and a non-database file are removed while
  `UserDataModel.sqlite` beside them is untouched; an unreadable store is
  left byte-for-byte unchanged, the session uses memory, and the next
  launch migrates it; v2 equals 3.8.6 (entity version hashes); transient
  error classification; incomplete rows do not crash the mapper.
- `AssetWhitelistTests` (7): with the remote list failing and no saved
  list, a spoofed asset is not listed, VAL takes the bundled name, symbol
  and icon, and XST (predefined) stays; with a saved list the rule is
  strict; a fresh list decides and is saved; unusable downloads keep the
  saved list; assets kept from the stored chain are filtered.
- `DexInfoServiceTests` (9): decoding mainnet-shaped `DEXInfos` (and
  skipping malformed entries); the loader's two RPC calls over a fake node;
  one read shared by 20 concurrent callers; an unknown base (KXOR) after
  one read and no more; fallback to DEX 0/1 and a retry after 30 s; the
  swap interactor reports a path that exists only on DEX 2, merges market
  sources, quotes DEX 0 to 3 and picks DEX 2 (desired input) or DEX 0
  (desired output); liquidity uses DEX 1 for XSTUSD and refuses KXOR.
- `ApplicationConfigTests` chain-sync tests were updated to pass a
  whitelist (bundled or empty) instead of `nil` data.
- Full `SoraPassportTests` (Debug, `Sora2MainnetLiveSigningTests`
  skipped): 449 tests, 0 failures (424 before this task, 25 new).
- Simulator upgrade (SORA-Release-B): the earlier i4 Debug build's v1
  store was given a contact, an unmarked pool favourite and a selected
  node (`ws.mof.sora.org`), then the new build was installed over it and
  launched. The store gained the `CDConfig`, `CDMetadataVersion` and
  `CDNode` tables and kept the contact, the favourite flag, the node
  choice and all other rows. The app launched normally (to the existing
  Welcome back state of that simulator); no crash report. Screenshot:
  `scratchpad/screens/ios/i5-port-386/upgrade-launch.png`.
- Builds: `SoraPassport` Debug (simulator, with tests), `SoraPassportDev`
  (simulator) and unsigned `SoraPassport` Release for `generic/platform=iOS`
  succeed; both app bundles contain `SubstrateDataModel.mom` and
  `SubstrateDataModel 2.mom`.

### Commits

`45e6c338` versioned chain store, `89e49a12` fail-closed whitelist,
`7d9d4cf9` KXOR, `5d8bfbc1` DEX ids from the chain, `af3b65a0` mapper crash
guard, `39189a1c` alerts on the main thread.
