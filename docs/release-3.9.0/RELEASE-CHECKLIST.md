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
      (simulator)" and "Unsigned Release device compile" from `iOS CI`.
- [ ] Confirm that `/Applications/Xcode_27.0.app` exists on the GitHub
      `macos-26` runner image. If it does not, the "Select Xcode" step fails
      and lists the installed versions; set `DEVELOPER_DIR` in
      `.github/workflows/ios_ci.yml` to the newest Xcode 27.x (or 26.x) shown.
- [ ] Jenkins `mac-sora` agent: set `DEVELOPER_DIR` to the same Xcode as CI.
      Archive the App Store build with that same Xcode.
- [ ] Jenkins: disable the production-promotion and migration-evidence jobs.
      Their Jenkinsfiles were deleted.

### Archive

- [ ] Archive with plain `xcodebuild archive` (or Xcode Organizer). No
      qualification mode variables are needed any more.
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
