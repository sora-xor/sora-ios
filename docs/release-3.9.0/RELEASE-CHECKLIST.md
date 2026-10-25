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

## i1: UIScene and local validation

### Local build machine

- [ ] Select an installed Xcode 26 or 27 version and use the same version
      for local validation and the App Store archive. Record `xcodebuild -version`
      with the release evidence.
- [ ] Run the local source gate and Debug/Release unit tests documented in
      `README.md`, then review their results before preparing an archive.
      No Jenkins or hosted CI result is required.
- [ ] Watch for one possibly flaky unit test:
      `WalletModernizationTests.testCancelledLifecycleAcquireOperationDoesNotLeakLease`
      timed out (2-second wait) once in several local full runs. It passed
      on every rerun and 50 of 50 times alone. If it fails locally, rerun the
      test once; if it fails again, treat it as a real failure of the wallet
      lifecycle lease and investigate before release.

### Archive

- [ ] Archive with plain `xcodebuild archive` (or Xcode Organizer). No
      qualification mode variables are needed any more.
- [ ] Pass `-onlyUsePackageVersionsFromResolvedFile` to `xcodebuild archive`
      and confirm `git status` shows no change to
      `Package.resolved` afterwards, so the archive uses the pinned
      dependency versions tested locally.
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
      lock appears. The app switcher shows the opaque SORA cover.
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

- [ ] Reconcile the privacy nutrition label for the released version. SORA Card
      and its KYC are gone, but Google Sign-In still declares linked profile
      and identifier data. Remove a former KYC category only when no remaining
      app or SDK behavior collects it; do not remove Name, Email Address or
      Phone Number solely because KYC was removed. Wallet addresses are User ID,
      not Physical Address. Keep the public label accurate for the version
      currently available until the new version is released.
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
      shipped (for example, from `env-vars.sh` on the local build machine). A Release archive fails without them.
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
      the app bundle has no `akk.lproj` or `egy-Egyp.lproj`. Check both on
      a fresh Release build. A local incremental build can keep stale
      `.lproj` folders from older builds, so archive from a clean build
      folder.

### App Store Connect

- [ ] App Privacy answers: combine the app's actual behavior with every packaged
      SDK declaration. The root manifest retains unlinked crash/diagnostic data;
      product interaction, device ID and coarse location are linked Analytics
      data because collection can retain device/instance associations. User ID,
      Other User Content and Other Financial Info are linked App Functionality
      data: Drive backup stores readable wallet address/nickname metadata in
      the user's own Google account, and submitted financial transactions are
      public on-chain. Backup secret fields are encrypted locally; this does
      not claim a developer-operated server can read users' recovery phrases.
      Google Sign-In and Firebase Messaging have additional SDK declarations,
      including linked profile data and Other Data Types. Generate the archive
      Privacy Report and reconcile it with actual behavior; Analytics has no
      separate manifest, so the report alone is not an exhaustive inventory.
- [ ] Before publishing the tracking/advertising answers, verify production
      Analytics Google Signals, linked advertising accounts, conversion exports,
      ad personalization and data-sharing settings. Linked data is not itself
      advertising tracking. Current manifests declare no tracking, but the old
      GoogleService-Info.plist IS_ADS_ENABLED/IS_ANALYTICS_ENABLED flags do not
      prove those remote settings or disable collection. Confirm the current
      privacy policy describes the resulting practices.
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
- [ ] The same command also runs
      `testWalletStorageDecodesWithTheLiveMainnetRuntime`, which decodes live
      XOR balances, Demeter farming and pool storage with the app's models.
      It must pass too. If it fails with `keyNotFound`, a runtime upgrade
      renamed a field that a wallet model reads, as runtime 124 did for the
      balances layout. Fix the model before release.

### Device QA

- [ ] XOR balance: over an existing 3.8.6 wallet that holds XOR, the wallet
      shows the same XOR balance as the explorer. Before the recheck fix,
      every XOR balance read as 0 on the current network. An account with
      frozen XOR (for example, bonded or locked) shows a lower transferable
      amount on Send than its free balance.
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
- [ ] Pending-transfer recovery (the full pass now has a unit test over a
      stubbed node; this checks it on a device): send a
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
- [ ] Support: App Store 3.8.6 has the same XOR balance model as the
      candidate had before the recheck fix, with an older version of the
      decoding library. On a device with 3.8.6 and a funded wallet, check
      whether it shows the right XOR balance on the current network
      (runtime 124 and later). If it shows 0, brief support before release:
      funds are safe on chain, and 3.9.0 shows the balance again.
- [ ] Polkamarkt keeps its runtime-130 contract pins (mutations are compiled
      off and the feature is hidden). Re-qualify against the live runtime
      before enabling it.
- [ ] FirebaseAnalytics stays linked (no code calls it; automatic collection
      runs). Removing it would change the App Privacy answers. Product and
      privacy owner to decide.

## i4: Key safety, lockouts and recovery (core)

### Product and security decisions (confirm before release)

- [ ] Security owner reviews the implemented per-wallet PIN model: salted,
      device-only scrypt ownership verifiers; persistent per-wallet attempt
      limits using boot identity/uptime; sealed manual authorization; durable
      rotation and rebind journals. The global app PIN and historical
      `earlierInstallPin-*` copies cannot claim retained wallets. No new copies
      are created. Unbound 3.8.6 wallets require a phrase or encrypted backup.
- [x] Review first-PIN recovery using exact-account, operation-scoped Keychain
      setup intents. Preferences flags alone grant no setup authority. An
      interrupted rotation completes before any authentication, including
      biometrics. Failed PIN saves do not report success.
- [x] Read-only accounts show their capability, reason and restore action in
      the account header/picker. Phrase/seed/JSON/Drive repairs require fresh
      supplied proof, current PIN and explicit confirmation for failed keys;
      every replaced byte is quarantined and verified first. Working keys stay
      add-only. An empty reinstall chooses a fresh PIN and binds only the
      supplied, proved wallet. Explicit watch-only accounts remain watch-only.
- [x] Set-up-again preserves the allowlisted database, migration evidence,
      network model, account journal, unreadable pending records and wallet
      settings in a manifest-verified directory excluded from device backup.
      Readable pending records stay live for reconciliation. An empty live
      installation can return complete verified generations; each wallet with
      retained keys requires owner-PIN proof before adopting the newly chosen
      app PIN. Metadata-only generations have no retained-key owner to prove.
      Unbound old wallets require supplied backups. Interrupted returns resume
      only from a Keychain-sealed exact manifest.
- [ ] Support verifies these recovery instructions on the actual signed build,
      including partial failures, unavailable Keychain and unbound older wallets.

### For the Safe Mode / UI task

- [x] Recovery actions and explanation use the same `WalletRecoveryOptions`;
      all 64 flag combinations are tested. Welcome back opens the requested
      phrase/Drive flow directly. Root/recovery/PIN messages use string tables.
- [x] Complete the recovery/authentication inventory in all 28 shipped locales:
      235 keys each, 6,580 entries, placeholders validated. Exact scope and the
      native-review manifest are in `recovery-translations.json`.
- [ ] Complete native-language and longest-string/RTL/device review; structural
      validation is not native review.
- [ ] Verify the SORA-only explanation on the signed build after importing a
      15/18/21-word phrase (no Nexus accounts for those lengths).
- [ ] Review the restyled recovery-phrase screen on a signed physical device
      (`WalletRecoveryPhraseViewController`:
      screenshot warning, words hidden in the app switcher and while the
      screen is captured) and the "Restore wallets found on this iPhone"
      entry in Add account for the SORA Neon design and usable controls.

### Device QA

- [ ] Unbound 3.8.6 reinstall: create or import a public test wallet on the
      signed old app, delete it and install 3.9.0. Welcome back must require a
      supplied phrase or encrypted backup; the old stored app PIN cannot claim
      its retained keys. A matching import chooses a fresh PIN and retains the
      expected address, with no false duplicate-account refusal.
- [ ] Previously owner-bound reinstall: after a verified binding exists, delete
      and reinstall. Manual owner-PIN restoration restores only matching wallets
      and explicitly re-protects them with the chosen/current app PIN. Confirm
      exact address and ownership isolation on the signed device build.
- [ ] New iPhone: back up a 3.8.6 phone to iCloud (or Finder, unencrypted),
      restore it on another iPhone, install 3.9.0. The wallet opens; sending
      shows "This account's keys are not on this iPhone…". Add account →
      import that account's phrase: it is restored in place (same name,
      no "already imported") and can send.
- [ ] Reinstall with two previously owner-bound wallets: restore one with its
      phrase from Welcome back (answer "Continue without them"), set a new PIN,
      then Add account → "Restore wallets found on this iPhone" with the other
      wallet's owner PIN restores only that wallet. Unbound 3.8.6 wallets remain
      supplied-backup-only; the first wallet's new PIN must not claim them.
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
- [ ] Kill the app right after tapping Import (twice, at different moments);
      reopen. Verified committed work resumes; an unresolved/failed proof opens
      actionable recovery without deleting keys or claiming import success.
- [ ] Welcome back actions (fix round 2): after a reinstall, tap each of
      "Restore with recovery phrase", "Restore from Google Drive" and "Set
      up this iPhone again" (from a fresh Welcome back each time). Phrase and
      Drive actions open the requested import directly; set-up-again preserves
      existing data and offers the next explicit recovery/onboarding choice.
- [ ] Stop before PIN setup: from Welcome back, restore with a phrase, then
      kill the app on the PIN setup screen. Reopening shows PIN setup, not
      the earlier PIN. After the new PIN is set, Add account → "Restore
      wallets found on this iPhone" accepts an earlier owner PIN only for wallets
      with a matching durable owner binding. Unbound wallets require a backup.
- [ ] 1.x upgrade: on a 1.x-era install, "Upgrade wallet" completes and
      reaches the verified PIN/wallet path. It must not spin forever.
- [ ] New iPhone from iCloud: Add account → Import with the phrase of a
      read-only account, and Add account → Google Drive with its backup, each
      restore the keys. The account is not reported as already imported.

## i5: Port of the App Store 3.8.6 commits

### Before archiving

- [x] Refresh the bundled whitelist from the published source: 277 entries,
      previously 185. The recorded diff adds 99 and removes 7 addresses and
      changes 18 retained display names; symbols/precision stay unchanged.
      Commit `62fb1889`; see `fixes/in4-hygiene.md` and the recorded source diff.
- [ ] On a signed device, test first launch with the whitelist server unreachable:
      the refreshed bundled/last-good fallback must remain usable and fail closed.

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

- [x] Empty installs default to Dark. Retained preferences, wallet files,
      unreadable storage or Keychain entries preserve existing behavior.
      Existing installs receive no new appearance marker before migration.
- [x] Inter 4.1 Regular, SemiBold and Bold are bundled with their OFL licence;
      runtime registration and the packaged resources are verified.
- [ ] Headlines and buttons now render in Sora, which is about 8–10 % wider
      than the system font. Run a truncation pass on every screen in
      English, Japanese and the longest locales (de, ru), at default and
      large text sizes.
- [x] The release adds the balance hero, neumorphic PIN keypad, private
      phrase grid, settings theme selector and Reduce Effects control.
      Ordinary list cards retain their performance-conscious surfaces;
      glass remains opt-in per screen. These source changes still require
      the signed physical-device checks below.
- [ ] The 1.x upgrade screen copy changed (title, two assurances, details
      behind "What happens during the upgrade?"). Per spec §9.1-2 an
      engineering owner signs off that both assurances hold for that flow:
      "Your original keys are not deleted or replaced" and "If a check
      fails, SORA stops safely and shows your options".
- [ ] Native review of the unified recovery translation inventory, including
      all Safe Mode strings, and longest-string/RTL layout review after the
      remaining locale additions. See the shared translation gate above.

### Device QA

- [ ] Launch in dark and light on a real iPhone (iOS 16, 18 and 26+): no
      light flash in dark mode; the splash rings and mark match the theme.
- [ ] iOS 16–25: the tab bar keeps its notch with the chrome colour and a
      top hairline; check that items, the swap disc and the notch line up
      and that the disc and the area around it respond to taps. This path
      has normal-app simulator evidence on 17.5 and 18.4; iOS 16 runtime and
      the complete signed physical hit-target/theme matrix remain open.
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

## Recovery integration validation — 12 October 2026

- [x] 72 targeted tests pass with one opt-in visual-capture skip (exit 0),
      including 9 orphan-repair/PIN tests, 15 credential-repair tests, 9 owner-PIN
      intent tests, 5 capability tests, 2 real import-routing tests and 32 UX
      tests. Every simulated repair interruption preserves original bytes.
- [x] Original dependency fixtures: 120 historical Substrate vectors pass every
      migration checkpoint; 2 original 1.x vectors pass production derivation/
      signing checks. This proves the tested source/dependency families, not
      the missing 2.x source releases or signed-store upgrade matrix.
- [x] 176 English/Japanese light/dark normal/maximum-font screenshots captured
      from production controllers with synthetic display states. Layout review
      fixed truncated reasons and backup choices. The latest Debug app launches
      on iOS 17.5 with its real onboarding screen.
- [x] Final iOS 27 full Debug and optimized Release each pass 843 tests,
      8 opt-in skips, zero failures, Xcode exit 0. Full 17.5/18.4/26.5 Debug
      runs each pass 838 tests/8 skips; later changes have focused/normal-app
      checks and final iOS 27 full-suite coverage. Final ordinary unsigned
      generic-device Release compile passes. Exact scope: VERIFICATION.md.
- [x] Simulator historical-writer launch matrix: 56 distinct complete cases,
      including actual two-uninstall ownership isolation, missing-PIN recovery,
      original legacy names, erased-simulator/files-only restore, and authenticated
      preserved-generation return with a new PIN. See the
      exact scope, source adapters and retained failed attempts in VERIFICATION.md.
- [ ] Complete signed historical-binary and physical-device upgrade/restore
      evidence; simulator source qualification does not close this gate.
- [ ] Verify actual App Store/TestFlight signing/identity continuity, public
      link eligibility, Google identity and release metadata before publishing.
      No upload or publication has been made by this continuation.
