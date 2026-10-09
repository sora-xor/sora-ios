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
      `MPQRCoreSDK.framework` (it was the only embedded framework removed
      in i2; `SoraDocuments` was static code and never had a framework
      there).

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

## i3: Live-runtime signing, indexer tolerance, flags, version, privacy

### Archive and build settings

- [ ] Build number: pass `SORA_IOS_BUILD_NUMBER=<YYYYMMDDNN>` (environment
      or build setting) to `xcodebuild archive`; `CURRENT_PROJECT_VERSION`
      is derived from it. It must be greater than `2026091402` and greater
      than every earlier 3.9.0 upload. Without it, the default is
      `2026101001` (fine for the first candidate only).
- [ ] Google Sign-In client (keeps existing Google Drive backups visible):
      the archive job must supply `SORA_GOOGLE_TOKEN_DEV` and
      `SORA_GOOGLE_URL_SCHEME_DEV` with exactly the values App Store 3.8.6
      shipped (the Jenkins credential of that name, or `env-vars.sh` on the
      build machine). A Release archive fails without them.
      - Verify once: compare `GIDClientID` and `CFBundleURLTypes[0]` of the
        3.9.0 archive with the 3.8.6 IPA
        (`unzip -p SORA.ipa 'Payload/*.app/Info.plist' | plutil -p -`).
        They must be identical.
      - Do not set `SORA_GOOGLE_TOKEN` or `SORA_IOS_GOOGLE_TOKEN_PROD` to a
        different client; the build fails if they differ.
- [ ] Do not pass `SORA_EVIDENCE_HARNESS_CONDITION` to the App Store
      archive. Check that `strings Payload/SoraPassport.app/SoraPassport |
      grep keychain-baseline-v3.sealed` prints nothing.
- [ ] Migration-evidence QA builds (`SoraPassportMigrationEvidence*`
      schemes, Release configuration) now need
      `SORA_EVIDENCE_HARNESS_CONDITION=SORA_MIGRATION_EVIDENCE_HARNESS` on
      the command line. Such builds must never be uploaded.
- [ ] The archive's `Info.plist` has no `iroha`/`irohaconnect` URL scheme and
      the app bundle has no `akk.lproj` or `egy-Egyp.lproj`. CI checks both on
      its fresh Release build. A local incremental build can keep stale
      `.lproj` folders from older builds, so archive from a clean build
      folder.

### App Store Connect

- [ ] App Privacy answers: `PrivacyInfo.xcprivacy` now declares crash data
      and other diagnostic data (Crashlytics, app functionality), and product
      interaction and device ID (Firebase Analytics automatic collection,
      analytics). None of it is linked to identity or used for tracking.
      Generate the Privacy Report from the archive (Organizer > Generate
      Privacy Report) and make the App Privacy answers match it. They should
      match the 3.8.6 answers, minus any SORA Card/KYC data (see i2).
- [ ] Watch the upload email for ITMS-91053 (missing required-reason
      declarations) and ITMS-91061 (SDK without a privacy manifest; the
      statically linked Kingfisher 6.3.1 and Starscream 4.0.12 have none).
      The app manifest covers their API use; if Apple still flags them,
      upgrade them or add manifests.
- [ ] Review notes: prediction markets, the Taira testnet and IrohaConnect
      are not part of this version.

### Release day

- [ ] Before submitting, run the live signing test once more against
      mainnet. A runtime upgrade happened three times in September/October.
      `TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1 xcodebuild test -project
      SoraPassport.xcodeproj -scheme SoraPassport -destination
      'platform=iOS Simulator,name=<iPhone>' -only-testing:SoraPassportTests/Sora2MainnetLiveSigningTests`.
      It must end with "rejected 1010 Inability to pay some fees". If it
      fails with `unresolvedType`, a runtime upgrade renamed a type that the
      bundled `runtime-sora.json` must alias (as was done for `Index`).

### Device QA

- [ ] Over an existing 3.8.6 wallet with a small XOR balance: open Send, wait
      for the network fee, send a small amount to your own second account,
      and check it in the history and on the explorer. Repeat a swap.
- [ ] Share a receive QR code and choose Save Image: the permission prompt
      shows "SORA Wallet saves a QR code image to your photos…" (Japanese on
      a Japanese phone) and the image is saved.
- [ ] Scan a QR code from a photo: the prompt shows the new photo-library
      text.
- [ ] Settings shows no "Test networks / Taira" section. Explore shows no
      "Prediction markets" button. The account header shows no network
      button. Opening `irohaconnect://connect?...` from Safari does not open
      the app.
- [ ] Friends screen: referral rewards load (or show an empty list).

### Not done on purpose / open (owner decisions)

- [ ] History: the deployed PI public query plan allows history filters
      only on the exact signer `address`. The app's filter (signer OR
      `dataFrom` OR `dataTo`, so that incoming transfers appear) is rejected,
      so Activity shows its "could not load" state on the live indexer. A
      signer-only fallback would hide incoming transfers, so it was not
      added. Indexer owners: deploy a plan that indexes `dataTo` (receiver),
      or decide that a signer-only history is acceptable.
- [ ] Polkamarkt keeps its runtime-130 contract pins (mutations are compiled
      off and the feature is hidden). Re-qualify against the live runtime
      before enabling it.
- [ ] FirebaseAnalytics stays linked (no code calls it; automatic collection
      runs). Removing it would change the App Privacy answers. Product and
      privacy owner to decide.
