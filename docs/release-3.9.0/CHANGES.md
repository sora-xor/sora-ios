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
  receives the signed bytes. The metadata is fetched once per runtime
  version per process, and it is cached only after its `System.Version`
  matches the reported version. `Sora2LiveRuntimeValidator` (modelled on
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
  accepted. The test is skipped unless the variable is set, and CI skips
  the class.
