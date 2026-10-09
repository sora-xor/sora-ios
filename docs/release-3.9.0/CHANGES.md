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
- Job 2 compiles an unsigned Release app for devices and checks arm64, the
  bundle ID `co.jp.soramitsu.sora`, the scene manifest, and that no static
  `.a` archives are embedded under `Frameworks/`.

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
