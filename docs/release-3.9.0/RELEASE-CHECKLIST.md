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
- [ ] Optional, Assistive Access (iOS 26+): add SORA to Assistive Access
      (Settings > Accessibility > Assistive Access), start it and open
      SORA. The wallet appears (PIN entry or onboarding), not a blank
      screen. Exit Assistive Access: the wallet opens normally.

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
- [ ] Activity (live indexer): your own sends and swaps are listed, with
      the note about incoming transfers above the list, in English and in
      Japanese. No "could not load" state.
- [ ] Over a 3.8.6 install that has a custom node: Settings > Nodes still
      shows it under custom nodes, and the selected node is unchanged.
- [ ] Pending-transfer recovery (its full pass has no unit test): send a
      small amount, close the app from the app switcher right after
      tapping Send, wait one minute and reopen. The transfer ends as
      completed in Activity and is not sent twice. With two such transfers,
      both resolve.

### Not done on purpose / open (owner decisions)

- [ ] History: the deployed PI public query plan allows history filters
      only on the exact signer `address`. Since the i3 fix round the app
      falls back to that signer-only filter and shows a calm note in
      Activity ("Incoming transfers from other accounts may not appear in
      Activity right now…"). Incoming transfers signed by others are missing
      from Activity until the indexer serves the all-roles filter. Indexer
      owners: deploy a public plan that accepts `address OR dataFrom OR
      dataTo` (or indexes `dataTo`). The app tries the full filter again
      every 30 minutes, so no app update is needed. Product owner: confirm
      that the signer-only history with the note is acceptable for 3.9.0.
- [ ] Polkamarkt keeps its runtime-130 contract pins (mutations are compiled
      off and the feature is hidden). Re-qualify against the live runtime
      before enabling it.
- [ ] FirebaseAnalytics stays linked (no code calls it; automatic collection
      runs). Removing it would change the App Privacy answers. Product and
      privacy owner to decide.

## i4: Key safety, lockouts and recovery (core)

### Product and security decisions (confirm before release)

- [ ] "Restore wallets found on this iPhone" restores wallets left in the
      Keychain after a reinstall when the user enters the PIN used on this
      iPhone before. That is the same authority App Store 3.8.6 needed to
      open the wallet. Wrong PINs lead to waits of 1, 5, 15 and 30 minutes
      (state in UserDefaults, so a reinstall resets it; the device passcode
      still protects the Keychain). Before onboarding replaces that PIN, a
      copy is kept in the Keychain (`earlierInstallPin-N`, add-only, one per
      distinct PIN, no limit) so wallets not restored yet stay restorable
      from Add account with the earlier PIN; this install's new PIN alone
      never unlocks them. Keeping the copy is required before Welcome back
      continues to onboarding and before PIN setup replaces an existing PIN.
      Removing the last account does not delete these copies. Security
      owner: accept, or require the phrase.
- [ ] Until this install's PIN is set after Welcome back
      (`wallet.pinSetupPendingAfterWelcomeBack` in UserDefaults), the app
      opens PIN setup instead of PIN entry and does not ask for the earlier
      PIN when it returns from the background. The flag is set only from
      Welcome back, which has no account rows. Security owner: accept.
- [ ] Accounts whose keys are missing or do not match are read-only (G-full).
      A corrupted account therefore no longer stops the app; it shows as
      read-only until restored or removed. Importing the account's phrase,
      seed or Drive backup restores missing keys in place. Removing a
      read-only account removes only its row; its Keychain items, the PIN
      and the 1.x items stay. The Safe Mode UI task must show a clear
      read-only badge and a restore action (domain API:
      `WalletAccountKeyAvailability`, `restoreKeysForReadOnlyAccount`,
      signing errors `keysNotOnThisDevice` / `keysNotVerified`).
- [ ] "Set up this iPhone again" moves (never deletes) the wallet database,
      migration backups, network model and commit journals into
      `Documents/WalletSetAside/`. Nothing prunes that folder; a folder with
      an `INCOMPLETE` file is one whose moves could not all be undone (a
      retry continues in it). Superseded failed migration attempts in
      `Documents/CoreData/WalletMigrationSuperseded/` are capped at the
      newest 3. Support owner: agree how users are guided if they need data
      from these folders.

### For the Safe Mode / UI task

- [ ] Render the actions from `WalletRecoveryOptions` (see `WalletRecoveryState`)
      in the §9.2 order, and translate every Safe Mode string into all
      production locales. i4 added English and Japanese only; the existing
      recovery screen still has older hard-coded English text.
- [ ] Welcome back currently routes phrase and Google Drive restore to the
      onboarding welcome screen; deep-link to the import screens.
- [ ] Show a "SORA network only" note after importing a 15/18/21-word phrase
      (no Nexus accounts for those lengths).
- [ ] Restyle the recovery-phrase screen (`WalletRecoveryPhraseViewController`:
      screenshot warning, words hidden in the app switcher and while the
      screen is captured) and the "Restore wallets found on this iPhone"
      entry in Add account to the SORA Neon design.

### Device QA

- [ ] Reinstall: on 3.8.6 create or import a wallet, delete the app,
      install 3.9.0. Expect "Welcome back"; "Restore wallets found on this
      iPhone" with the old PIN restores the wallet with the same address and
      balance; the app then asks for that PIN. Repeat and choose "Restore
      with recovery phrase": the import succeeds (no "already imported").
- [ ] New iPhone: back up a 3.8.6 phone to iCloud (or Finder, unencrypted),
      restore it on another iPhone, install 3.9.0. The wallet opens; sending
      shows "This account's keys are not on this iPhone…". Add account →
      import that account's phrase: it is restored in place (same name,
      no "already imported") and can send.
- [ ] Reinstall with two wallets: restore one with its phrase from Welcome
      back (answer "Continue without them"), set a new PIN, then Add account
      → "Restore wallets found on this iPhone" with the earlier PIN restores
      the other one.
- [ ] Remove a read-only account (and, separately, the last account when it
      is read-only): the Keychain keeps its items; the next launch of the
      last-account case shows Welcome back.
- [ ] Downgrade after a restore: on TestFlight 3.9.0 restore an account
      created with a path (//1) or from a seed, then install App Store 3.8.6
      over it: it opens and can send from that account.
- [ ] Google Drive: restore a backup made by App Store 3.8.6 in onboarding
      and on the recovery screen; a wrong password says so and changes
      nothing.
- [ ] Downgrade: on a TestFlight 3.9.0 build, upgrade a 1.x-era or
      global-only wallet, then install App Store 3.8.6 over it. The wallet
      opens and can send (it uses the new scoped `-secretKey`).
- [ ] Kill the app right after tapping Import (twice, at different
      moments); reopen. No recovery screen; importing again works.
- [ ] Welcome back actions (fix round 2): after a reinstall, tap each of
      "Restore with recovery phrase", "Restore from Google Drive" and "Set
      up this iPhone again" (from a fresh Welcome back each time). Each one
      opens onboarding.
- [ ] Stop before PIN setup: from Welcome back, restore with a phrase, then
      kill the app on the PIN setup screen. Reopening shows PIN setup, not
      the earlier PIN. After the new PIN is set, Add account → "Restore
      wallets found on this iPhone" still accepts the earlier PIN.
- [ ] 1.x upgrade: on a 1.x-era install, "Continue protected upgrade"
      completes and opens the wallet. It must not spin forever.
- [ ] New iPhone from iCloud: Add account → Import with the phrase of a
      read-only account, and Add account → Google Drive with its backup, each
      restore the keys. The account is not reported as already imported.

## i5: Port of the App Store 3.8.6 commits

### Before archiving

- [ ] **Release blocker.** Refresh the bundled asset whitelist (not done
      in this task: no downloads were allowed). On the first launch after
      the update there is no saved list yet; if the whitelist server is
      slow or unreachable, the bundled list decides which tokens are
      listed, and today it hides every token newer than 2.3.1 (VXOR, for
      example) until the live list arrives. Download
      `https://whitelist.polkaswap2.io/whitelist.json`, check it is a JSON
      array that lists XOR (`0x0200000000…`), replace
      `SoraPassport/Resources/whitelist.json`, and review the diff (new and
      removed tokens, renamed symbols). The bundled list is used only on a
      first launch that cannot reach the whitelist server; it dates from
      2.3.1 (185 entries).

### Device QA

- [ ] Upgrade from App Store 3.8.6: add a contact, add a custom node and
      select it, and unmark a pool as favourite. Install 3.9.0 over it. The
      contact, the selected custom node and the favourite are still there.
- [ ] Then install App Store 3.8.6 over 3.9.0 again: the same data is still
      there.
- [ ] Upgrade from the 3.9.0 TestFlight build `2026091402` with a contact
      and a selected node: both are kept.
- [ ] Upgrade from App Store 3.8.4 (or any 3.0.1 to 3.8.4) with a contact,
      a selected custom node and an unmarked pool favourite: all three are
      kept after installing 3.9.0.
- [ ] First launch without the whitelist server: on 3.8.6, make a token
      that is not in the bundled list visible and move it up the list (with
      today's bundled list, VXOR; after the refresh above, use a debug build
      with the old list or a token listed after the refresh). Block
      `whitelist.polkaswap2.io`, install 3.9.0 and launch: the token is not
      listed. Unblock and relaunch: the token is back, visible, in the same
      place.
- [ ] Whitelist outage: block `whitelist.polkaswap2.io` (proxy or DNS) and
      launch a fresh install. The asset list shows only whitelisted and
      predefined assets (XOR, VAL, PSWAP, XST, XSTUSD, TBCD, KUSD, …), with
      their usual names. Unblock and relaunch: the list follows the live
      whitelist.
- [ ] Liquidity: the base asset picker offers XOR and XSTUSD only (no KXOR).
      Add and remove liquidity in a small XOR pool and a small XSTUSD pool.

### Mainnet canary (small amounts)

- [ ] Swap a small amount between assets that trade only through the KUSD
      DEX (DEX 2), for example a KUSD-paired token. The review screen shows
      a quote and the swap succeeds. In the explorer, the extrinsic's
      `dex_id` is 2.
- [ ] Swap XOR → VAL and VAL → XOR: still DEX 0 (or the DEX with the best
      quote), and the swap succeeds.
- [ ] If the chain ever adds a DEX, no app change is needed; the new DEX is
      read at the next launch.

### Notes

- The App Store archive check for static libraries (3.8.6 commits
  `42361874`/`52872616`) is already in the i1 "Archive" list.
- A downgrade from 3.9.0 to a 3.9.0 TestFlight build that predates this
  change wipes the chain store (contacts, nodes, favourites) because those
  builds use `.removeStore`. Expire or replace those TestFlight builds.
- A chain store that fails on three launches in a row while readable is
  renamed to `Documents/CoreData/SubstrateDataModel-unreadable-<date>.sqlite`
  (with side files) and a new store is used. It holds contacts, node
  choices, pool favourites and caches, no key material. Support can ignore
  such files; they are never deleted by the app.

## i6: SORA Neon UI foundation

### Design and product decisions (confirm before release)

- [ ] The theme default is unchanged: with no stored choice the app follows
      the device appearance, for upgrades and new installs alike. The spec
      wants Dark for new installs only; that needs a reliable "fresh
      install" signal and was left to the product owner.
- [ ] Body text uses the system font: the spec's Inter is not in the
      repository and no font was added. Bundling Inter (OFL, ~900 KB) is a
      design decision; if approved, add the three `.ttf` files and their
      licence to `UIAppFonts` and the font family resolves automatically.
- [ ] Headlines and buttons now render in Sora, which is about 8–10 % wider
      than the system font. Run a truncation pass on every screen in
      English, Japanese and the longest locales (de, ru), at default and
      large text sizes.
- [ ] Legacy cards stay opaque (surface colour plus a hairline); translucent
      glass is opt-in per screen (`sora.material = .glass` or `GlassView`).
      Per-screen hero treatments of the spec (§8, §9: balance hero,
      neumorphic PIN keys, phrase grid, Safe Mode step lists, settings
      theme selector and "Reduce effects" switch) are not part of this
      task.
- [ ] The 1.x upgrade screen copy changed (title, two assurances, details
      behind "What happens during the upgrade?"). Per spec §9.1-2 an
      engineering owner signs off that both assurances hold for that flow:
      "Your original keys are not deleted or replaced" and "If a check
      fails, SORA stops safely and shows your options".
- [ ] New Safe Mode strings exist in English and Japanese only (17 keys,
      "SORA Neon Safe Mode screens" block at the end of
      `Localizable.strings`); other locales fall back to English. Translate
      before release, together with the i4 recovery strings.

### Device QA

- [ ] Launch in dark and light on a real iPhone (iOS 16, 18 and 26+): no
      light flash in dark mode; the splash rings and mark match the theme.
- [ ] iOS 16–25: the tab bar keeps its notch with the chrome colour and a
      top hairline; check that items, the swap disc and the notch line up
      and that the disc and the area around it respond to taps. This path
      could not be checked here (only iOS 27 simulators are installed).
- [ ] iOS 26+: tab bar items switch, the selection capsule is the system
      Liquid Glass, and the swap disc opens Polkaswap.
- [ ] Switch Settings → Appearance between System, Dark and Light while the
      device is in the other appearance: alerts, keyboards, share sheets,
      navigation bars and the PIN lock follow the in-app choice.
- [ ] Accessibility: Reduce Transparency (opaque glass and backdrops),
      Increase Contrast (no glows, 2 pt hairlines), Reduce Motion (no press
      scaling), Low Power Mode (no pulses); VoiceOver skips the decorative
      aurora, glows and borders.
- [ ] Scroll performance on an iPhone 8 / SE 2-class device: wallet, Explore
      and Activity lists with Core Animation "Color Offscreen-Rendered" on
      (card shadows now have paths; there should be fewer offscreen passes
      than in 3.8.6).
- [ ] QR codes stay black on white in both themes (receive and request).
- [ ] Screens that stay open while the theme changes (live switch from
      Settings or the device) re-colour their SoraUIKit views, bars,
      toggles and the Welcome terms text; a few labels coloured once at
      creation in older screens may keep the previous colours until the
      screen is reopened. Note any that stay unreadable.

### Open defect found during this task (pre-existing)

- [ ] Fixed, needs device QA: typing quickly into the recovery phrase
      field with the Japanese kana keyboard crashed the app on the iOS 27
      simulator (`NSInvalidArgumentException` in
      `InputHandler.didReceiveReplacement`, called from
      `ImportAccountViewController.textView(_:shouldChangeTextIn:replacementText:)`;
      the range from the keyboard is beyond the handler's value). See
      CHANGES.md, "Fix: crash when typing the recovery phrase with the
      Japanese kana keyboard". On a physical iPhone, with the kana keyboard
      (and a hardware keyboard, if available), type quickly into the phrase
      field and confirm with 確定: no crash. Then import a phrase with the
      English keyboard: the import succeeds as before.
