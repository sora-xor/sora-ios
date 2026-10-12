# SORA Wallet iOS 3.9.0: changes

## Release completion: Neon screens and private backups

The production PIN keypad now uses the Neon controls with four- and six-digit
support, accessible digit counts, and a long-press clear action. Existing PIN,
biometric and cooldown presenters remain in control. Settings exposes System,
Dark and Light appearance plus Reduce Effects. Only an otherwise empty install
gets the new dark default; retained preferences, files or Keychain entries keep
the existing appearance choice. Existing installs receive no new preference marker
before migration, preserving interrupted-upgrade settings comparisons.

Inter Regular, SemiBold and Bold 4.1 are bundled with their SIL Open Font License.
The wallet balance owns a full-width line. Receive uses a white, unfiltered QR
plate and the full address. Settings, backup and raw-seed screens support the
largest Dynamic Type sizes without clipping their controls. The account recovery
header measures localized text at its actual wrapping width and collapses hidden
actions when changing accounts.

Ordinary backup, raw-seed export and recovery phrases require an explicit reveal.
They hide after sixty seconds, when leaving the screen, on capture changes and
when the app becomes inactive. Revealing again is always explicit. Secret copies
stay on the local device and expire after 45 seconds. Import and confirmation
screens receive an opaque capture/inactive cover; credential repair keeps its
existing input-clearing policy. The app-switcher cover is now opaque and is laid
out synchronously before a snapshot.

Focused controller/privacy checks passed (65 tests), as did eight archive-script
checks. The final set of 168 English, Japanese and Arabic captures covers
light/dark, four/six-digit PIN, settings, the recovery account header and
hidden/revealed backups at normal and AX5 text sizes. Full
Debug/Release qualification and the final signed archive are recorded separately
in the release evidence; store submission and physical-device gates remain open
until verified.


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
  (`ENABLE_TESTABILITY=YES`, locally ad-hoc signed), checks that the build carries
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

### Fix round 2 (same review findings, rechecked on the current branch)

- External displays (major): rechecked against the code. Only interactive
  application scenes get `SceneDelegate`; an external-display scene
  (`windowExternalDisplayNonInteractive`) gets a configuration with no
  delegate, so the system mirrors the phone. `SceneDelegate`,
  `attachRootWindow(to:)`, both `sceneDidDisconnect` handlers and
  `soraWindowScene` ignore any scene that is not an application scene.
- New in this round: the Assistive Access application role
  (`windowAssistiveAccessApplication`, iOS 26+) is now treated as an
  application scene too, as the review suggested. If iOS ever connects the
  app in that role, the wallet appears instead of a blank screen with no
  way forward. External displays are unchanged.
  `WalletUXTests.testOnlyTheApplicationSceneHostsTheWallet` covers it.
- Release-configuration tests in CI (minor): rechecked. CI job 2
  ("Unit tests, Release configuration (simulator)") builds with
  `-configuration Release ENABLE_TESTABILITY=YES CODE_SIGNING_ALLOWED=NO`,
  checks `-DF_RELEASE`, and runs `SoraPassportTests`. No change needed.
- Verification on a clean copy of branch commit `1d33a4d6` (all of i1 to i6
  plus this fix), Xcode 27.0, SORA-Release-A (iOS 27):
  - Debug, `SoraPassportDev` and unsigned Release device builds succeed.
  - The Debug app launches with no crash (this simulator already has a
    wallet, so it opens at PIN entry) and survives going to the background
    and back.
  - `SoraPassportTests`, Debug: 466 tests, 0 failures (`WalletUXTests` 30).
  - `SoraPassportTests`, Release configuration, built exactly as CI job 2
    does (`OTHER_SWIFT_FLAGS = -DF_RELEASE`): 466 tests, 0 failures.
  - `Sora2MainnetLiveSigningTests` needs the live network and is skipped
    in both runs, as in CI.

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
- Recheck after i3-i6 landed (clean export of `188e0b9c`, nothing else in
  the build): no SORA Card, KYC, microphone, `soracard` query field,
  reCAPTCHA, JOSESwift, SoraDocuments, SSFQRService or mock-fixture
  residue came back. `SoraPassport` Debug with all test targets,
  `SoraPassportDev` Debug and the unsigned Release device build succeed;
  `SoraPassportTests` Debug: 476 tests, 0 failures (the 4
  `AddressQRCodecTests` included). The Release app still embeds only the
  same eight frameworks (no `MPQRCoreSDK`), and the Debug app opens to the
  PIN screen over an existing wallet with no crash. No code change was
  needed.
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

### Recheck on the current branch (second run, 2026-10-10)

The workflow was run again. The i3 changes were already on the branch, so
this round checked them against everything that landed afterwards (i4 to
i6 and the two kana fixes) on a clean copy of the branch, and drove the app
on a simulator for the first time. It found and fixed two defects.

**XOR balances read as zero (critical)** (`b68ad974`, `3b3ff988`)

- Why: runtime 124 (6 May 2026, block 26,009,453) changed the balances
  pallet's account data from `free, reserved, misc_frozen, fee_frozen` to
  `free, reserved, frozen, flags`. An archive node shows the old layout up
  to runtime 119 and the new one from 124 to 133. The app decodes
  `System.Account` with the live metadata into `AccountData`, which
  required `miscFrozen` and `feeFrozen`, so decoding failed for every
  account. On runtime 133 the app log showed
  `keyNotFound 'miscFrozen'` right after the asset list loaded. The wallet
  reads the XOR balance only from `System.Account`
  (`fetchBalanceInfoForAssets`), so every XOR balance showed as 0. Send
  then reported an insufficient balance, and its recipient read
  (`transferMetadataOperation`) failed. The earlier rounds tested signing
  and fees, which do not read this storage.
- What changed: `AccountData` and `DyAccountData` decode both layouts. In
  the new layout, only the part of `frozen` that the reserved balance does
  not cover locks free balance, and never more than `free`. The app
  therefore never shows more XOR as transferable than the chain allows.
  `available` now stops at zero instead of trapping when a lock is larger
  than the free balance. Mainnet has such an account: 1.29 XOR free and 100
  XOR frozen. Encoding keeps the earlier keys. Other tokens are read
  through `assets_usableBalance` and were not affected.
- App Store 3.8.6 has the same `AccountData` model but an older version of
  the decoding library (the remote `shared-features-spm` package). Whether
  it reads XOR balances correctly on the current network was not checked;
  see RELEASE-CHECKLIST.md.

**Pending-transfer recovery: one account no longer holds back the others
(major)** (`a8856103`)

- Why: the recovery pass checked every pending entry's wallet binding
  first and stopped the whole pass when one failed. That happens, for
  example, when an account is removed while its transfer is pending. The
  other accounts' pending transfers then stayed unresolved, and so did a
  pending legacy migration, which waits for this pass.
- What changed: an entry that cannot be bound stays pending and protected
  and is skipped. The others are resolved from the chain, and the pass
  still reports that something was deferred. The wallet store read can be
  injected, so the full pass now has the unit test that the fix round
  listed as missing.

**Live storage check** (`1495f99b`)

- `Sora2MainnetLiveSigningTests.testWalletStorageDecodesWithTheLiveMainnetRuntime`
  is a live-network test. Like the signing test it is gated, and CI skips
  its class. It reads a page of live `System.Account`, Demeter farming
  (`UserInfos`, `Pools`, `TokenInfos`) and `PoolXYK.AccountPools` values at
  the finalized head. It decodes them with the app's models and the live
  metadata, so a runtime upgrade that renames a field the wallet reads
  fails here before users see it.

**Rechecked, no change needed**

- No SORA2 path pins runtime 130: admission, the live-runtime validator,
  recovery contexts, runtime sync and the reconciler all check against the
  live runtime. The 130 pins are left only in `PolkamarktRuntime.swift`,
  where mutations stay compiled off. `runtime-sora.json` matches its pins
  (136,971 bytes, `7a96f47a…`). Mainnet is still on spec 133, transaction
  version 131.
- PI on 2026-10-10: `mobileConfig` serves the full schema. History still
  rejects the all-roles filter (`BAD_USER_INPUT`) and accepts `address`
  alone, so the signer-only fallback is still needed.
- Unchanged since i3 and as described above: the production surfaces, the
  IrohaConnect gate and URL schemes, the locales (31, no `akk` or
  `egy-Egyp`), version 3.9.0 (2026101001), the harness compile condition,
  the privacy manifest (i4 to i6 use no new required-reason API), the
  Info.plist strings and the Google Sign-In script.

**User-visible effects**

- XOR balances show the real amount again on the current SORA network, and
  frozen XOR is not counted as transferable. Send no longer reports an
  insufficient balance for funded accounts and can read the recipient's
  account again.
- Pending transfers of other accounts are resolved even when one account's
  transfer cannot be.

**Verification (Xcode 27.0, iOS 27, clean copy of branch commit `1495f99b`)**

- New tests in `Sora2LiveRuntimeTests`:
  `testSystemAccountDecodesTheRuntime133BalancesLayout` (runtime 133
  fixture; with the previous model it fails with `keyNotFound
  'miscFrozen'`), `testAccountDataKeepsTheEarlierBalancesLayout`, and
  `testPendingRecoveryPassResolvesOtherAccountsWhenOneEntryHasNoWallet`
  (full pass over a stubbed node; with the previous pass the bound entry
  stays unresolved).
- `SoraPassportTests`, Debug, live class skipped: 482 tests, 0 failures.
- `SoraPassportTests`, Release configuration built as CI job 2 builds it:
  482 tests, 0 failures.
- Live network, SORA-Release-A, `wss://ws.mof.sora.org`:
  - Signing test (finalized block 27,983,611): spec 133, transaction
    version 131, metadata `ab22a2d4…`, `payment_queryInfo` partial fee
    100018412589707326, submission rejected only with 1010 "Inability to
    pay some fees".
  - Storage test: 300 accounts (13 funded, 1 with frozen XOR), 50
    `UserInfos`, 31 `Pools`, 12 `TokenInfos` and 50 `AccountPools` values,
    all decoded.
- In the app (Debug build, SORA-Release-B, over an earlier test install):
  - "Welcome back" appeared. "Continue without restoring" was chosen, then
    a throwaway phrase was imported with a test PIN. The phrase was typed
    with the English keyboard.
  - Before the fix, the log showed the `miscFrozen` decoding failure; with
    the fix it is gone, the runtime snapshot completes, and the wallet
    loads.
  - With this unfunded account, Send shows "残高不足" (insufficient
    balance) and no fee. A real send needs funds and stays in Device QA.
  - Screenshots: `scratchpad/screens/ios/i3-release-correctness-retry/`.
- Builds: `SoraPassport` Debug (simulator, all test targets),
  `SoraPassportDev` (simulator) and unsigned `SoraPassport` Release for
  `generic/platform=iOS` succeed. The Release app passes every "Check
  Release app bundle" step of `ios_ci.yml`, run locally: 3.9.0
  (2026101001), arm64, no harness, no IrohaConnect scheme, no removed
  locale. Without the Google secret the Release build warns, as designed.
- The full runs used `1495f99b`. After the comment-only commit `3b3ff988`,
  the Debug and Release device builds were repeated and the i3 test classes
  were run again (53 tests, 0 failures).

**Commits**

- `a8856103` Resolve other accounts' pending transfers when one cannot be
  bound
- `b68ad974` Read XOR balances in the runtime 132+ balances layout (the
  runtime number in this message is wrong; see `3b3ff988`)
- `1495f99b` Check live mainnet storage against the app's models
- `3b3ff988` Name runtime 124 as the start of the new balances layout

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

- `SubstrateDataModel.xcdatamodeld` has three versions (v0 was added in
  the fix round below): `SubstrateDataModel 0` (v0, App Store 3.0.1 to
  3.8.4), `SubstrateDataModel` (v1, unchanged, the model of 3.8.5 and the
  candidate) and `SubstrateDataModel 2` (v2, current), a byte-for-byte copy
  of the 3.8.6 model.
- Before the store is opened, `SubstrateStoreMigrator` reads its metadata:
  - no store, or a v2 store (every 3.8.6 store): opened as is;
  - a v0 store (3.0.1 to 3.8.4) or a v1 store (3.8.5 and the 3.9.0
    TestFlight builds): migrated in place with lightweight migration;
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

- Incomplete asset and node rows are skipped. Pruning node rows no longer
  force-unwraps their URL. (Chain rows: see the fix round below.)

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

### Fix round (review findings)

Every finding was checked against the code and the tags. All were real
except the mechanism in the chain-row finding (see below); all are fixed.

**Stores from App Store 3.0.1 to 3.8.4 were still wiped** (two majors and
one minor, the same finding)

- The code comment and the notes above said v1 covered "2.x to 3.8.5". It
  covers 3.8.5 and the TestFlight builds only. Tags 3.0.1 to 3.8.4 all
  ship one 11-entity model: v1 plus `CDSingleValue`, which `db5d2dcd`
  removed in 3.8.5. Such a store matched no known version and was removed,
  so a user updating straight from 3.8.4 or older lost contacts, nodes and
  pool favourites.
- `SubstrateDataModel 0` is now an exact copy of that model
  (`git show 3.8.4:` and `git show 3.0.1:` of the model are identical) and
  is part of the version group in `project.pbxproj`. Lightweight migration
  to v2 drops `CDSingleValue` (an unused cache) and adds the three 3.8.6
  entities; every other entity is unchanged. The migrated store is in the
  3.8.6 schema.
- Stores from 2.x (before 3.0.1) are still reset, as 3.0.1 already did.
  Their layout differs (no chain tables, optional asset ids that are
  required now, no uniqueness constraints), so an in-place migration could
  fail or carry rows the 3.x code does not expect. Their only user data
  would be contacts from 2021–22.
- Comments, the notes above and the checklist are corrected.

**Side files are removed before the database** (minor)

- Removal used to delete `SubstrateDataModel.sqlite` first. If deleting
  `-wal` then failed, the next launch found no database and created a new
  one beside the old WAL. Now `-wal`, `-shm` and `-journal` go first and
  the database last, and side files found without their database are
  removed before a new store is created. If one cannot be removed, the
  launch uses the temporary store and the next launch tries again.

**A corrupt store behind a generic Cocoa error** (minor)

- Errors are now classified by the SQLite result code when Core Data
  reports one, before the generic Cocoa codes (Core Data wraps read
  failures in 256). SQLITE_CORRUPT and SQLITE_NOTADB are permanent, so
  such a store is replaced as `.removeStore` did instead of running on a
  temporary store forever. SQLITE_FULL (and ENOSPC, EDQUOT, out of space)
  is its own class.

**Deferred sessions are bounded** (minor)

- A store whose file is readable but that fails with a temporary-looking
  error (busy, I/O) is retried twice within the launch (0.25 s, then
  0.5 s). If it still fails, the launch is counted. On the third launch in
  a row the store is renamed aside to
  `SubstrateDataModel-unreadable-<UTC date>.sqlite` (with its side files;
  nothing is deleted) and a new store is used. Any launch that opens the
  store resets the count.
- Not counted, so never moved aside: a file that cannot be opened at all
  (before the first unlock) and a full disk. Both pass by themselves, and
  freeing space loses nothing.
- A store from a known version that cannot be migrated for a permanent
  reason is renamed aside the same way instead of being deleted.
- Not done: switching a running session from the temporary store to the
  real one. Repositories and the chain observer hold the Core Data
  context; replacing it mid-session would leave the chain registry
  watching the old context, so node changes would stop taking effect
  until restart. The app has no background modes, so it is not launched
  before the first unlock; a deferred session now needs a full disk or a
  repeated I/O error, and edits in such a session could not be saved to
  the real store either. Each deferred launch is logged with its reason.

**Damaged chain rows** (minor; different mechanism, same dead end)

- The finding said `fetchAll` fails for a chain row without a name. It
  does not: Core Data never returns a stored row that lacks required text
  (it logs "missing mandatory text data" and skips the row), so the fetch
  succeeds without it. A test showed the real problem: the hidden SORA row
  keeps its unique chain id, so the chain sync can neither read it nor
  insert the chain again, the save leaves the row as it was, and the chain
  never loads.
- New `ChainStoreRepair` runs before each chain sync. It gives chain rows
  that have an id but no name an empty name with a batch update (below
  Core Data's validation), so the next fetch returns them and the sync
  writes the real name. It only runs on SQLite stores. A row without an
  id is left in place; it is never returned and does not block the chain.
- The mapper reads a chain without a name with an empty name instead of
  throwing.

**The first chain sync no longer erases the user's token choices** (major
and minor, the same finding)

- On the first launch after the update there is no saved last-good
  whitelist. If the whitelist server has not answered yet, the old bundled
  list decides, and it lacks newer tokens such as VXOR. `AssetManager`
  then rebuilt the saved order and visible list from that shorter list and
  saved it, so such a token came back hidden and at the end of the list.
- `AssetManager` now keeps saved ids that are missing from the current
  list: each keeps its place after the id it followed, and stays visible
  if it was. A missing token is hidden only while it is missing. This also
  stops a save before the chain is loaded (empty list) from erasing the
  whole order.
- When the chain's set of listed assets changes after setup (the live
  whitelist arrives), `AssetManager` rebuilds its list on the main queue,
  so screens that read the list again show the token in the same session.
- Refreshing the bundled `whitelist.json` is now a release blocker in the
  checklist (no downloads were allowed here).

### User-visible effects (fix round)

- Updating straight from App Store 3.0.1 to 3.8.4 keeps contacts, the
  chosen and custom nodes and pool favourites.
- A token that is missing from the bundled whitelist on a first offline
  launch is hidden only until the live list arrives. It comes back in its
  place and visible; the user does not have to turn it on again.
- A chain store that keeps failing no longer leaves the app on a temporary
  store forever; after three launches it is set aside and a new one is
  used. Contacts and node choices in it are not deleted, but the app no
  longer shows them.
- No change to wallets, keys, addresses or account data. No new strings.

### Verification (fix round, Xcode 27.0, SORA-Release-A, iOS 27)

- `SubstrateStoreMigrationTests` (18): new tests for a 3.8.4 store (v0
  hashes checked against an independent `momc` compile of
  `git show 3.8.4:`, store migrated, contact, nodes and favourite kept,
  3.8.6 opens it afterwards); side files without a database; a database
  kept until its `-wal` can be removed; SQLITE_CORRUPT inside Cocoa 256
  removed; a failing readable store deferred twice and moved aside on the
  third launch with its bytes intact; a successful launch resets the
  count; a full disk never moves the store aside; a known store that
  cannot be migrated is moved aside; a nameless SORA row and an id-less
  row in a real SQLite store, then the production chain sync with
  `ChainStoreRepair` restores the chain and leaves the id-less row.
- `AssetWhitelistTests` (9): a bundled-only first pass without VXOR,
  then a pass with the live list, keeps VXOR's place and visibility
  through `AssetManager`'s arrange and save steps; saving with no listed
  assets keeps the saved choice.
- Full `SoraPassportTests` (Debug, `Sora2MainnetLiveSigningTests`
  skipped): 460 tests, 0 failures (449 before, 11 new).
- Simulator upgrade (SORA-Release-B): a store written with the
  independently compiled 3.8.4 model (a contact, an unmarked pool
  favourite, a selected custom node, a `CDSingleValue` row) replaced the
  app's chain store; the new build was installed over it and launched. The
  store gained the 3.8.6 tables, lost `CDSingleValue`, and kept the
  contact, the favourite flag and the selected custom node; the chain sync
  rewrote the chain row. No crash report. The app opened to that
  simulator's existing Welcome back screen; the network banner is expected
  because the fixture's custom node is a made-up address. Screenshot:
  `scratchpad/screens/ios/i5-port-386/upgrade-384-launch.png`.
- Builds: `SoraPassport` Debug (simulator, with tests), `SoraPassportDev`
  (simulator) and unsigned `SoraPassport` Release for `generic/platform=iOS`
  succeed; both app bundles contain `SubstrateDataModel 0.mom`,
  `SubstrateDataModel.mom` and `SubstrateDataModel 2.mom`.

### Commits (fix round)

`388648d5` 3.0.1–3.8.4 stores, side-file order, error classes, bounded
deferral; `002141e8` chain row repair; `d7bab53b` token order and
visibility kept.


## i6: SORA Neon UI foundation (SoraUIKit, fonts, components)

### Why

- The design owner chose "SORA Neon" (design spec `SORA-NEON-DESIGN.md`
  §2–§7): a near-black canvas with faint aurora washes, calm glass cards,
  neon reserved for the one action that matters, neumorphism only for
  thumb-pressed controls, and a calm "Safe Mode" for recovery and upgrade
  screens.
- The audit and the UI map found real bugs in the old UI layer:
  - The bundled Sora font never loaded. `FontData` built the name from the
    enum case names (`"headline-one"`), so every SoraUIKit text style fell
    back to the system font.
  - In dark mode, warning, success, error and info containers were light
    pastels behind light text (fgPrimary on the warning container was
    1.09:1, success text on its container 1.39:1).
  - Modal backdrops (59 flows) were always a light blur, also in dark mode.
  - The in-app Dark switch did not reach system UI (alerts, keyboards,
    sheets, Liquid Glass): no window had `overrideUserInterfaceStyle`.
  - The launch screen and splash were light only, so dark-mode users saw a
    light flash at every launch.
  - The recovery, Welcome back, phrase-reveal and 1.x upgrade screens used
    raw system colours and ignored the app theme; the upgrade screen had
    hard-coded English and told users "Do not delete the app".
  - A theme change or an enable toggle reset a button's chosen background
    and image tint.
  - Every Soramitsu view allocated an unused `UIVisualEffectView`; card
    shadows had no `shadowPath` (an offscreen pass per card while
    scrolling); bleached buttons rasterised an animating layer.
  - The global bar-button appearance made every text bar button invisible.

### What changed

`SUK/` below is `VendorPackages/SoraUIKit/SoraUIKit/SoraUIKit/Sources/`
(the vendored SoraUIKit package).

**Typography** (`SUK/Core/FontData.swift`, `SUK/Codegen/Fonts.swift`)

- Font names come from the raw values: headlines, buttons and display
  numbers now render in the bundled Sora (`Sora-Regular`, `Sora-SemiBold`,
  `Sora-Bold`). The body face of the spec (Inter) is not in the repository,
  so body text uses the system font, as the spec's fallback allows. No font
  was added.
- The SORA Neon type scale (§5.3): SemiBold weight, tracking and line
  heights; new tokens `displayHero`, `eyebrow`, `amountM`, `amountS`
  (tabular figures), `mono` (platform monospace for addresses and codes),
  `phraseWord` and `pinDigit`. Fonts are cached (`NSCache`).
- The never-called `TypographyConstants.registerFonts` is removed; fonts
  load through `UIAppFonts` as before.

**Tokens** (`SUK/Neon/NeonTokens.swift`, `SUK/Codegen/*Palette.swift`)

- `NeonTokens.dark` / `.light` hold every value of §2.1/§2.2 (surfaces,
  aurora, glass, gradient hairlines, text, accents, CTA gradients, status,
  glow specs, neumorphic shadows, skeleton) plus motion tokens.
- `DarkPalette` and `LightPalette` map every `SoramitsuColor` slot onto
  the tokens (§2.3), so all existing `sora.*Color` call sites restyle. The
  switch is exhaustive: the old `default: return .black` is gone. Dark
  containers are now dark (warning `#241B12`, success `#0B221D`, error
  `#2A1119`, info `#0B2128`); contrast checked with `cc.py` (≥ 4.5:1 for
  text and container pairs in both themes; see the new unit test).
- The Figma token generator (`Scripts/main.swift`, `Config.json`) is
  removed: it could not express SemiBold, alpha tokens or tabular
  figures, and running it would have silently reverted the palettes. The
  `Codegen` files are now maintained by hand. The unused legacy foundation
  colours are removed (`Colors.white100`/`black100` stay).
- `FxPolicy` (§4.0): FULL / REDUCED / MINIMAL tiers from Reduce
  Transparency, Low Power Mode, thermal state and a new in-app
  `neon.reduceEffects` key (no UI yet); Increase Contrast turns glows off
  and glass opaque. `NeonFxCenter` reposts the system notifications as one
  `.neonFxChanged`, and the theme manager re-resolves every surface.

**Components** (`SUK/Neon/`)

- `GradientBorderLayer`: the 135° gradient hairline and glass sheen, drawn
  with Core Graphics once per size or theme (no mask, so no offscreen pass).
- `GlassView` (card glass with fill, sheen, gradient hairline and the light
  card shadow; opaque under reduced transparency), `GlowHostView` (glow
  behind a control, ring fallback, finite pulse), `NeumorphicControl`
  (dual outer shadows, inset pressed state, cyan ring, paths everywhere),
  `AuroraView` (static radial washes, optional grid texture, Safe Mode
  variant without red), `NeonChrome` (chrome material: `UIGlassEffect` on
  iOS 26+ inside `#if compiler(>=6.2)` / `#available(iOS 26.0, *)`,
  ultra-thin material with tint below; tab and navigation bar
  appearances), `NeonScrimView` (theme-aware modal backdrop) and
  `NeonInputStyle`.
- Every effect has a cheaper fallback (Reduce Transparency, Increase
  Contrast, Reduce Motion, Low Power Mode) and every shadow has a path.

**SoraUIKit core** (`SoramitsuViewConfiguration`, buttons, inputs)

- Cards: the legacy card idiom (`.bgSurface`, card radius, all corners)
  keeps an opaque Neon surface and gets a 1 pt hairline drawn above its
  content (one outline per card: cards nested in cards get none), soft
  ink shadows in light and none in dark (§4.3.1). Translucent glass is
  opt-in (`sora.material = .glass` or `GlassView`): many cards contain
  `.bgSurface` subviews that a translucent card would show as patches.
- Shadows are theme-aware and always get a `shadowPath` when the view has
  a fill; corners are continuous; the card radius is 24 (was 32).
- The unused per-view blur decorator and `CustomVisualEffectView` (a paused
  `UIViewPropertyAnimator` hack) are deleted; their users get
  `NeonScrimView` and a small glass card.
- A theme change no longer re-assigns `shadow` (which also reset
  `clipsToBounds` and clipped content such as the Welcome logo).
- `SoramitsuButton`: the primary CTA (filled primary, or an explicit
  `.accentPrimary` background) is the `cta.primary` gradient with ink text
  in dark and white in light plus `glow.primary`; `.additionalPolkaswap`
  becomes the `cta.swap` gradient. A caller's background and image tint
  survive theme changes and enable toggles; filled buttons on surface or
  container colours get a readable label; disabled buttons use
  `cta.disabled` with `text.disabled`; press scales to 0.98 (not under
  Reduce Motion); bleached buttons no longer rasterise.
- Text fields (`InputField`, `InputTextView`, `InputAssetField`): opaque
  input fill, `border.input` at rest, cyan border and focus glow when
  focused (dark, full effects), status borders for success and errors,
  radius 16 (the amount card keeps the card radius).
- `BlurViewController` (59 modal flows) uses `NeonScrimView`: a dark blur
  and page tint in dark mode, a light one in light mode, updated while the
  modal is open. An opaque root (the PIN screen) shows no backdrop.

**Theme and chrome**

- `ThemeManager` applies `overrideUserInterfaceStyle` to the app's windows
  in every connected scene on each theme change (unspecified when the
  stored choice is "System"); new windows (root, lock, loading, toasts)
  get it when created. System UI now follows the in-app Dark switch. The
  device appearance is read from the screen, which overrides do not
  affect, at scene connection and whenever the root window's trait changes
  (for example the automatic sunset switch). The stored choice
  (`SoramitsuThemeType`) is never rewritten.
- Tab bar on iOS 26/27 Liquid Glass: the notch fill is no longer drawn
  (it painted over the system glass); the system selection is the
  indicator; inactive items `text.secondary`, active `text.primary`. The
  centre button is the neon swap disc (`cta.swap` gradient, Polkaswap mark
  in ink/white, static `glow.swap`) instead of a white button with a grey
  shadow. iOS 16–25 keep the notch with the chrome colour and a hairline.
- The KVC tab-bar swap (`setValue(_:forKey: "tabBar")`) was verified on
  iOS 27: the custom bar installs, tabs switch and the disc renders and
  responds. It now runs only when `UITabBarController` still has the
  `_tabBar` storage; otherwise the disc is added to the system bar
  instead of raising an Objective-C exception.
- One static aurora sits behind all tabs; the four tab roots are clear.
- Navigation bars: SORA Neon title fonts and colours, cyan tint, default
  Liquid Glass on iOS 26+, ultra-thin material with tint below. Back
  titles stay hidden through the bar appearance; the global clear
  `UIBarButtonItem` title is removed, so text bar buttons are visible
  again. Open bars are re-styled on a theme change.
- Settings toggles use the Neon cyan. Toggles, settings arrows and the
  Welcome terms text are re-coloured when the theme changes while they
  are on screen.

**Launch, splash and Safe Mode screens**

- Launch screen: system background (black in dark, white in light) and a
  default (adaptive) status bar style instead of always-light content; no
  more light flash for dark-mode users. A named colour with a dark variant
  was tried first, but the iOS 27 launch-screen renderer drew its light
  variant.
- Splash: page colour from the theme; the Lottie rings and mark are
  recoloured per theme; the slow-start label uses `textS`
  `text.secondary`, the spinner cyan.
- `WalletUX`: `button(primary:)` is the neon CTA or a glass secondary
  button (`WalletNeonButton`, `UIButton.Configuration`, theme reactive);
  new `.tertiary` and `.safe` styles; table destinations get the aurora,
  glass rows (no blur in cells) and Neon dividers.
- `WalletSafeMode` kit: safe aurora (cyan and mint, no red), shield
  emblem with a static mint glow, calm title/body/detail/technical styles
  and Safe Mode buttons.
- Recovery, Welcome back, the phrase reveal, the 1.x upgrade
  confirmation and the low-storage panel follow the app theme in both
  modes: one Safe action ("Try again", "Restore wallets found on this
  iPhone", "Upgrade wallet", "Check again"), restore options as glass
  buttons, the rest as text buttons, technical details in a monospace
  card, recovery words on an opaque card (no aurora, blur or glow behind
  secrets). Accessibility identifiers, actions, availability rules and
  titles read by tests are unchanged.
- Copy (English and Japanese, new keys only): the 1.x upgrade screen now
  says "Upgrade your wallet" with the two assurances that hold for this
  flow ("Your original keys are not deleted or replaced", "If a check
  fails, SORA stops safely and shows your options"); the earlier
  technical text moved behind "What happens during the upgrade?"; the
  progress line is "Updating your wallet. Keep SORA open until this
  finishes." (no "Do not delete the app"). The recovery title is "We
  paused to keep your wallet safe"; its last English-only buttons are
  localised. The low-storage panel is "Free up some space" with "Check
  again".
- PIN dots: empty dots are a ring and filled dots cyan (the dark fill was
  invisible on the dark backdrop). The Welcome artwork is dimmed in dark
  mode so light titles on it stay readable.

**Simplification**

- Deleted dead UI code: `SoraButton`/`GrayCopyButton` (only their
  appearance proxies remained), `NeumorphismButton` and its xib, two
  orphan xibs that referenced it (`OnbordingMain.xib`,
  `FriendsViewController.xib`, in no target), the blur decorator,
  `CustomVisualEffectView` and the token generator.

### Key safety

- UI only. No code path that reads, writes, moves or deletes wallet keys,
  the account store, migration state or settings was changed. Recovery and
  upgrade screens keep every action, identifier and availability rule; only
  their presentation and copy changed. The theme preference key is not
  rewritten.

### User-visible effects

- New SORA Neon look in dark and light: Sora headlines and buttons, neon
  gradient CTAs, glass-edged cards, cyan focus, a neon swap disc and an
  aurora backdrop. Dark mode is dark everywhere: launch, splash, modals,
  alerts, keyboards and system bars.
- Warning and success banners are readable in dark mode.
- Recovery, Welcome back, upgrade and low-storage screens are calm,
  themed and localised in English and Japanese.
- Text bar buttons (for example in Explore) are visible again.

### Verification (Xcode 27.0, SORA-Release-A, iOS 27)

- Builds: `SoraPassport` Debug (simulator), `SoraPassportDev`
  (simulator) and unsigned `SoraPassport` Release for
  `generic/platform=iOS` succeed.
- New `SoraNeonDesignTests` (6 tests): Sora font names resolve and are
  cached; palette contrast ≥ 4.5:1 for 17 text/container pairs in both
  themes; caller backgrounds and image tints survive theme changes, the
  primary CTA draws its gradient and the disabled state; windows get the
  in-app interface style; legacy cards get one hairline; recovery, upgrade
  and Welcome back screens use the theme canvas.
- `SoraPassportTests` (live class skipped): 466 tests, 0 failures
  (460 before plus the 6 new ones). After the last two small commits,
  `SoraNeonDesignTests` and `WalletUXTests` were run again: 36 tests,
  0 failures.
- Simulator (dark and light, Japanese): launch, splash, onboarding,
  phrase import with a fixture phrase, PIN setup and unlock, wallet home,
  More and app settings; live switching between system light/dark and the
  in-app Dark switch (alerts, status bar and Liquid Glass buttons follow).
  Recovery, Welcome back, 1.x upgrade and low-storage panels rendered in
  both themes by a temporary hosted test (not committed). Screenshots:
  `scratchpad/screens/ios/i6-ui-foundation/final/` (launch, splash,
  onboarding, wallet home, More, settings and the Safe Mode screens, dark
  and light).
- The KVC tab bar on iOS 27: tabs switch, the swap disc renders with its
  glyph and responds, and the system selection capsule is shown.
- Found while testing, not changed here (pre-existing, reported for a
  separate fix): typing quickly into the phrase field with the Japanese
  kana keyboard can crash in `InputHandler.didReceiveReplacement`
  (range out of bounds). See RELEASE-CHECKLIST.md.

### Commits

`009fcc84` fonts, `0ef521b9` tokens and palettes, `8ac0f24b` Neon
components, `0d8d6344` cards, shadows, buttons, inputs and backdrops,
`ea491390` dead UI code, `73792a16` theme sync, tab bar and chrome,
`e9e43a3d` WalletUX and Safe Mode screens, `fa6071bf` launch screen,
splash and low-storage panel, `14af4171` tests, `42bef7dd` main-thread
appearance read, `fd24cc65` live re-colouring of toggles and terms text.

## Fix: crash when typing the recovery phrase with the Japanese kana keyboard

### Why

- Typing quickly into the recovery phrase field (Welcome → Import account →
  Passphrase) with the Japanese kana keyboard crashed the app:
  `NSInvalidArgumentException` "-[__NSCFString
  replaceCharactersInRange:withString:]: Range or index out of bounds" in
  `InputHandler.didReceiveReplacement`, called from
  `ImportAccountViewController.textView(_:shouldChangeTextIn:replacementText:)`.
  Found during i6 (see RELEASE-CHECKLIST.md). Japanese users import with
  that keyboard.
- Cause: UIKit computes the edit range against the text the field shows.
  The delegate passed that range to the input handler, which applies it to
  its own `value`. While a keyboard composes, the two differ:
  `InputTextView` rewrites its text on every change, which drops the marked
  range, so UIKit inserts the composition again. Recorded on the simulator:
  the field showed "aab" while the handler held "ab", and the next key came
  with range {3, 0}. The account-name field passed ranges the same way.

### What changed

- New `InputHandling.didReceiveReplacement(_:for:displayedText:)`
  (`SoraPassport/Common/Extensions/ViewModel/InputHandling+TextInput.swift`).
  While the field shows the handler's value, the edit is forwarded
  unchanged. Otherwise the field's text with the edit applied (the range
  clamped to that text) is offered to the handler as its whole new value,
  so the handler's own character set, length limit and processor still
  decide what it keeps. If UIKit would not produce the same text, the
  delegate returns `false` and the field shows the handler's value again,
  as after any rejected edit.
- Used by every `InputHandler`-backed text delegate: the phrase and seed
  text view of `ImportAccountViewController` (and its unused text-field
  delegate) and the account-name field of `SetupAccountNameViewController`.
- Unchanged: the vendored `InputHandler` and `InputTextView`, the phrase
  handler's settings (a–z and whitespace, 250 characters, runs of
  whitespace collapsed), mnemonic validation, derivation and key handling,
  and the x86_64 autotest bypass in these delegates.

### User-visible effects

- No crash. The phrase field still takes only a–z and whitespace; kana
  committed from the kana keyboard is dropped. The phrase that is imported
  is the text the field shows.
- Known, pre-existing, not changed here: when the kana keyboard composes
  Latin letters from a hardware keyboard, a letter can go missing, because
  `InputTextView` rewrites its text mid-composition (typing "abandon
  ability able" gave "aandonabilityable"; the kana keyboard also turns
  spaces into conversion, as in any app). Use the English keyboard for the
  phrase.

### Verification (Xcode 27.0, new iPhone 17 Pro simulators, iOS 27)

- Before the fix, with the Japanese kana keyboard: typing "abandon ability
  able" into the phrase field crashed with the same exception and stack as
  the report (`acceptCurrentCandidateIfSelected` → `InputTextView` →
  `ImportAccountViewController` → `InputHandler.didReceiveReplacement`).
  The new tests for the phrase field and the account-name field failed
  with the same exception.
- After the fix: the same typing does not crash. After 確定 the field and
  the handler hold the same text (checked with temporary logging, not
  committed). With the English keyboard the phrase is typed as before.
- New `InputHandlingReplacementTests` (10 tests): a replay of the
  recorded kana sequence, a committed kana candidate the handler never saw
  (direct and through real marked text), ordinary typing still filtered
  (digits, capitals, double spaces, 250-character limit, backspace), a
  committed Japanese account name, and the helper alone (unchanged
  forwarding, UTF-16 ranges, filters kept, out-of-range ranges clamped).
- `SoraPassport` Debug build-for-testing and `SoraPassportDev` Debug
  simulator build succeed. `SoraPassportTests` (live class skipped):
  476 tests, 0 failures (466 before plus the 10 new ones).

## Fix: letters lost while a keyboard composes in the recovery phrase field

- Why: the "Known, pre-existing" item of the kana crash fix above. With the
  Japanese kana keyboard and a hardware keyboard, "abandon ability able"
  typed into the phrase field became "aandonabilityable" (Safari:
  "abandonabilityable"). `InputTextView.textViewDidChange(_:)` copied the
  text into `SoramitsuTextView.sora.text` on every change, which reassigns
  `attributedText` and drops the marked range the keyboard still holds, so
  UIKit inserted the composition again ("a" → "aab") or lost letters. That
  mismatch also produced the out-of-range ranges behind the crash.
- What changed (SoraUIKit only):
  - `InputTextView` skips the `sora.text` sync while the text view has
    marked text. UIKit calls `textViewDidChange(_:)` again when the
    composition is committed, and the sync runs then. The delegate call and
    the height update still run on every change.
  - `SoramitsuTextViewConfiguration` now always sets the view's `font`,
    `textColor` and `typingAttributes`, also when `text` is nil. Marked text
    is drawn with them until it is committed; before, it could get UIKit's
    defaults (no font, `labelColor` instead of `fgPrimary`), for example in
    an empty field. The `attributedText` (link) path is unchanged.
  - Unchanged: `InputHandler`, `didReceiveReplacement(_:for:displayedText:)`,
    the phrase handler's filters, mnemonic validation, derivation and key
    handling.
- Not changed: the kana keyboard turns a space into conversion, as in any
  app, so the English keyboard is still the one to type a phrase with. A
  theme or text-size change in the middle of a composition still rewrites
  the text.
- Verification (Xcode 27.0, new iPhone 17 Pro simulator, iOS 27):
  - New `InputTextViewMarkedTextTests` (3 tests, field in a window of the
    app's scene): the marked range survives `textViewDidChange(_:)`;
    "abandon" and "ability" composed key by key keep every letter and reach
    `sora.text` on commit; marked text has the field's font and `fgPrimary`
    in light and dark, with and without a dynamic text style, in an empty,
    filled and emptied field and after a theme switch. With the old code
    they fail ("abandon" became "aabandon"); with only the `InputTextView`
    change, marked text in an empty field had no font and `labelColor`.
  - `SoraPassport` Debug build-for-testing succeeds. `SoraPassportTests`
    (live class skipped) on a freshly booted simulator: 479 tests, 0
    failures (476 before plus the 3 new ones).
  - Pending: typing "abandon" quickly with the kana keyboard on the
    simulator (simulator access was not granted during this session).


## ik0: Recovery layout completion

Completed the interrupted UI review: scrollable legacy/recovery content, usable
large-text actions, theme contrast and safe status presentation. Current recovery
screens also expand read-only explanations and show full-width backup choices.
Details: [ik0](fixes/ik0-ui-wip.md), [ik4](fixes/ik4-recovery-ux.md).

## ik1: Local startup without a network dependency

Local storage verification and routing proceed independently of asset/node
readiness. Bounded wallet-opening retries offer a node/recovery path and preserve
cached balances when an asset response is empty. Details: [ik1](fixes/ik1-startup.md).

## ik2: Interrupted durable files remain recoverable

Recognized writer helpers are classified safely across network, migration,
account and transaction journals. Unknown or unreadable evidence is retained;
recovery never interprets it as a successful transaction. Details:
[ik2](fixes/ik2-leftover-files.md).

## ik3: Per-wallet ownership and durable PIN changes

Retained wallet ownership uses salted device-only verifiers, persistent
per-wallet attempt limits and sealed manual grants. The stored app PIN and old
PIN copies cannot claim an unbound wallet. Exact setup intents, rebind receipts
and durable rotation keep interrupted writes from bypassing authentication.
Details: [ik3](fixes/ik3-pin-binding.md).

## ik4: Recovery choices and preserved data return

Actual database/key state determines onboarding, Welcome back and read-only
recovery. Text and actions share one flag model. Set-up-again preserves the
complete allowlist/settings with hashes and backup exclusions; a verified return
requires an empty live wallet plus each wallet's ownership proof. Explicit repair
can restore an existing or absent account from fresh supplied material while
quarantining failed keys and keeping working keys add-only. Details:
[ik4](fixes/ik4-recovery-ux.md), [repair](fixes/credential-repair.md).

## in1: Live indexer values and honest unavailable prices

Asset numeric fields accept the observed indexer representations; catalog
fetching and price state distinguish unavailable data from a measured zero.
Details: [in1](fixes/in1-indexer.md).

## in2: Transaction reconciliation after interruptions

Pending sends reconcile from network status without signing or resubmitting.
Runtime changes and ambiguous submission stay explicit, with Activity guiding
follow-up. Integrated Activity paging preserves a stable row list while loading
older pages and refreshing newer results. Details: [in2](fixes/in2-tx-reconcile.md).

## in3: Historical identity and backup compatibility

Production signing proves direct retained secrets independently of stale backup
metadata. Original dependency fixtures cover historical Substrate families and
1.x IrohaCrypto, including encrypted backup and restart boundaries. Short legacy
phrases require the known address; independent Drive sources can restore a valid
identity without adopting mismatching siblings. Details:
[in3](fixes/in3-identity-compat.md).

## in4: Data and release hygiene

Unrecognized/corrupt auxiliary chain stores and SQLite companions are preserved;
unknown failures remain retryable. The bundled whitelist was refreshed from the
published source with a recorded address/name diff. Release scripts retain pinned
dependencies and explicit signing/identity gates. Details:
[in4](fixes/in4-hygiene.md).

Current validation and limitations are in [VERIFICATION](VERIFICATION.md),
[UPGRADE-PATHS](UPGRADE-PATHS.md) and [RELEASE-CHECKLIST](RELEASE-CHECKLIST.md).
These changes do not constitute a signed-store release approval.

## Final integration: node lookup and large-text recovery controls

A custom-node save now waits for both the network probe and duplicate-node
lookup. Previously a fast network response could race the lookup and reject a
valid node; the delayed-lookup regression reproduces this order. The optimized
test retains its interactor for the same lifetime as the app presenter and injects
a deterministic genesis operation for its synthetic URL. The Release production
node-identity check remains enabled.

The account switcher measures read-only badges using the actual label width,
including the cell's outer margins. The selected-account header reserves the
wrapped restore-button label and padding before its self-sizing row is measured.
Both have rendered-cell regressions at the largest Dynamic Type size.

Recovery copy is present in all 28 shipped locales (235 keys each). The checked-in
validation report covers 6,580 entries and placeholder integrity. Native review
and RTL/device interaction are still release-checklist tasks.

Release unit-test hosts explicitly opt into `WALLET_TESTING` for durable-writer
fault checkpoints and use local simulator signing for Keychain entitlements.
Ordinary unsigned device Release compilation excludes those test hooks. CI uses
the pinned package graph and disables verbose failure diagnostics that previously
left completed XCTest runs waiting in Xcode's diagnostic collector.


## Final integration: missing PIN and legacy names

Missing application PIN with retained signing rows now opens recovery unless
every row has the exact durable intent created by a verified fresh setup. A
selected read-only account cannot hide another retained signer from this check.
The routing preflight is read-only; the PIN writer repeats ownership checks.
PIN setup errors clear both PIN buffers and present from the visible screen,
including a localized fallback for errors without a specialized presentation.

Pre-account-model legacy upgrade keeps its display name in place until the
legacy resolver consumes it. Stale-metadata preservation still runs for unrelated
metadata and failed proof. The original global-key and entropy-only launch
cases both pass with name, phrase, identity and key preservation assertions.

Four wallet-opening keys that occur in tuple/conditional call sites are included
in the translation inventory as well as direct literal calls. The scope is
235 recovery/authentication strings in each of 28 locales; other pre-existing
application translation gaps are outside this manifest.

Final local validation: Debug and optimized Release each pass 843 tests with
8 opt-in skips and no failures; ordinary unsigned device Release compilation
passes. The 56-case normal-app simulator matrix includes two actual uninstalls,
missing-PIN recovery and authenticated return of preserved data. All six owned
iOS test simulators were removed after exporting their evidence. Exact results,
failed-attempt history and external release gates are in VERIFICATION.md.
