# SORA Wallet iOS 3.9.0: release checklist

Human and operations actions for the release. Each task adds its items here.

## Legal decisions

- [ ] Export compliance: `SoraPassport/Info.plist` sets
      `ITSAppUsesNonExemptEncryption = false` (the key was absent in 3.8.6).
      The code is unchanged on purpose. Legal decides whether the app's
      encryption (encrypted backups, IrohaConnect key agreement) is exempt.
      If not, set it to `true` and add `ITSEncryptionExportComplianceCode`,
      or remove the key and answer the question in App Store Connect for
      each build.

## i1: UIScene, retired gates, lean CI

### CI and build machines

- [ ] GitHub branch protection: remove the old required checks
      "Modernization Source Contract", "Full Release XCTest Closure" and
      "Unsigned Release Device Compile". Require "Build and unit tests
      (simulator)", "Unit tests, Release configuration (simulator)" and
      "Unsigned Release device compile" from `iOS CI`.
- [ ] Confirm that `/Applications/Xcode_27.0.app` exists on the GitHub
      `macos-26` runner image. If it does not, the "Select Xcode" step fails
      and lists the installed versions; set `DEVELOPER_DIR` in
      `.github/workflows/ios_ci.yml` to the newest Xcode 27.x (or 26.x) shown.
- [ ] Jenkins `mac-sora` agent: set `DEVELOPER_DIR` to the same Xcode as CI.
      Archive the App Store build with that same Xcode.
- [ ] Jenkins: disable the production-promotion and migration-evidence jobs.
      Their Jenkinsfiles were deleted.
- [ ] Watch for one possibly flaky unit test:
      `WalletModernizationTests.testCancelledLifecycleAcquireOperationDoesNotLeakLease`
      timed out (2-second wait) once in several local full runs. It passed
      on every rerun and 50 of 50 times alone. If it fails in CI, rerun the
      job once; if it fails again, treat it as a real failure of the wallet
      lifecycle lease and investigate before release.

### Archive

- [ ] Archive with plain `xcodebuild archive` (or Xcode Organizer). No
      qualification mode variables are needed any more.
- [ ] Pass `-onlyUsePackageVersionsFromResolvedFile` to `xcodebuild archive`
      (as CI does) and confirm `git status` shows no change to
      `Package.resolved` afterwards, so the archive uses the pinned
      dependency versions that CI tested.
- [ ] Pass the build number explicitly: `CURRENT_PROJECT_VERSION` must be
      greater than `2026091402` (format `YYYYMMDDNN`, e.g. `2026101001`).
      `MARKETING_VERSION` must be `3.9.0`.
- [ ] Signing continuity, so existing users keep Keychain access to their
      wallets. Check the signed archive:
      - bundle ID `co.jp.soramitsu.sora`
      - team `YLWWUD25VZ`
      - `application-identifier` `YLWWUD25VZ.co.jp.soramitsu.sora`
      - no new `keychain-access-groups` entitlement
        (`SoraPassport/SoraPassport.entitlements` is an empty dictionary,
        as in 3.8.6)
- [ ] Check that `Payload/SoraPassport.app/Frameworks/` has no `*.a` files
      and no static-library frameworks.

### Device QA (UIScene behaviour)

Test on a physical iPhone with iOS 26 or 27, upgrading over 3.8.6 with an
existing wallet:

- [ ] Cold launch: Splash, then the PIN screen. The wallet opens with the
      same accounts and balances.
- [ ] Background the app longer than the PIN timeout, then return. The PIN
      lock appears. The app switcher shows the blur overlay.
- [ ] Send and swap confirmation: the blocking spinner is visible while the
      transaction is submitted.
- [ ] Toasts (e.g. "copied") appear.
- [ ] Network status banner position under the status bar (Dynamic Island
      devices).
- [ ] Google Drive backup: sign in, back up, and restore a backup made by
      3.8.6.
- [ ] External display: with the wallet open (and with an IrohaConnect
      session active, if possible), start AirPlay Screen Mirroring or plug
      in a USB-C/HDMI display. The TV or monitor mirrors the phone; the
      phone keeps showing and controlling the wallet. Stop mirroring or
      unplug: the phone is unchanged and the IrohaConnect session is still
      connected.

## i2: SORA Card residue and dead code removed

### App Store Connect

- [ ] Privacy nutrition label: SORA Card and its KYC are gone. If the label
      still declares KYC data (identity documents, photos, name, address,
      etc.), remove those data types. `SoraPassport/PrivacyInfo.xcprivacy`
      declares no collected data, so there is no code change.
- [ ] After the first TestFlight upload, confirm App Store Connect sends no
      ITMS-90683 "missing purpose string" email for the microphone. The
      microphone usage text was removed because nothing records audio.
- [ ] Export compliance (see "Legal decisions"): JOSESwift (JWE/RSA/AES) is
      no longer linked into the app. Tell legal, as it reduces the
      encryption in the binary.

### Archive

- [ ] `Payload/SoraPassport.app/Frameworks/` must not contain
      `MPQRCoreSDK.framework` or a `SoraDocuments` framework.

### Device QA (QR codes)

- [ ] Receive: open Receive, show the QR code, and scan it from another
      phone running 3.8.6 (Send > scan). The address and the asset match.
- [ ] Scan: in 3.9.0, scan a receive QR code shown by 3.8.6, with and
      without an amount. Address, asset and amount are filled in correctly.

### Not done on purpose (owner decisions)

- [ ] Leftover SORA Card SDK tokens on upgraded phones (Keychain or
      UserDefaults items under unknown SDK service names) are not cleaned
      up: any Keychain deletion code risks wallet keys. They are inert.
- [ ] `FirebaseMessaging` is linked but unused (no push code). Unlinking it
      would stop FCM auto-init (an installation/token fetch at launch).
      Product/privacy owner to decide; the change is a pbxproj edit only.
- [ ] Unused images (for example `KatanaGirl`, 1.6 MB, and some old
      PIN/profile icons) are left for the UI redesign owner, who may reuse
      some of them.
- [ ] `SoraLocalizable/de.lproj`, `it.lproj` and `nn-NO.lproj` exist but are
      not in the project, so they never ship. Localization owner to add or
      delete them.
- [ ] Legal: `RecaptchaEnterprise` (Google) and `MPQRCoreSDK` (Mastercard)
      binaries remain in the public git history. `MPQRCoreSDK.xcframework`
      is also still in `VendorPackages/shared-features-spm/Binaries`, but it
      is no longer linked or shipped.
