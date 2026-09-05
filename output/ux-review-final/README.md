# iOS UX verification — 5 September 2026

Both application targets built with the repository's existing gates enabled. The latest full main build passed 24 Connect, UX and retained-wallet tests. The final combined run passed 31 tests, including the six existing send/recovery checks and a new Dynamic Type editing/trait-change regression. Subsequent copy and accessibility refinements were compiled and linked for both targets with the recorded Xcode commands, including both the application executable and debug dylib. Source, resource and diff checks passed.

## Evidence

Representative captures: [send review](/Users/takemiyamakoto/dev/sora-wallet/sora-ios/output/ux-review-final/screenshots/small-review-final.png), [maximum text and reachable actions](/Users/takemiyamakoto/dev/sora-wallet/sora-ios/output/ux-review-final/screenshots/small-review-max-final.png), [clipboard and keyboard](/Users/takemiyamakoto/dev/sora-wallet/sora-ios/output/ux-review-final/screenshots/paste-keyboard.png), [chart context](/Users/takemiyamakoto/dev/sora-wallet/sora-ios/output/ux-review-final/screenshots/chart-light-final.png), [camera fallback](/Users/takemiyamakoto/dev/sora-wallet/sora-ios/output/ux-review-final/screenshots/scan-camera-unavailable.png).

- `sora-wallet-ux-final2-ios-tests.log`: full main build + 13 tests.
- `sora-wallet-ux-final2-dev-build.log`: full development build.
- `sora-wallet-ux-final-recovery-tests.log`: six additional one-shot, pre-transport failure, recovery, balance and availability tests.
- `sora-wallet-ux-final-format-rebuild.log`: final 64-bit block label correction compiled and linked for both targets.
- `sora-wallet-ux-delivery-tests.log`: final combined delivery XCTest run.

Screenshots are under `screenshots/`. Entry/review light and dark show the actual send controller with sample domain state; `paste-keyboard` shows the clipboard address and a reachable review action above the decimal keyboard. `small-review-final` and `small-review-max-final` show a complete wrapped recipient and reachable actions on iPhone SE. The maximum-text captures are scrolled views, not clipped fixed layouts. `completed-final` removes the stale available balance and makes View Activity primary. `uncertain` has no retry/confirm action. `scan-camera-unavailable` shows the simulator camera/permission fallback and Close.

`chart-light-final`, `chart-dark-final`, and `chart-dark-max-final` / `chart-dark-max-bottom-final` show the current chart view with sample dates/percentages. Its labels expand and the chart scrolls at maximum text. History uses equally spaced indexed snapshots and explicitly says so; DPM pricing curves have different axis/legend copy and a dashed No series.

The standalone fixture compiles the production `WalletUX.swift` and chart view with SoraUIKit/BigInt, mock domain structs, and sample values. Its source is archived under `fixture-sources/`. It does not contain a wallet, signer or submission client. No screenshot required real funds or a secret. Simulator devices were isolated from the user's existing simulators and accounts.

All temporary iOS simulators created for this work have been removed, including the disposable sample wallet. Existing simulators and accounts remain untouched.

## Normal-app verification

The latest Dev application was installed on isolated iPhone 15 Pro and SE simulators. The signing-disabled build was copied and relinked with simulator-only Keychain entitlements; repository signing settings and entitlements were not changed. The wrapper script is archived as `relink_simulator.py`.

Normal first launch, restart before onboarding, local sample account creation, phrase confirmation, PIN setup, restart/PIN unlock and Wallet are verified. `normal-onboarding-restart.png`, `normal-wallet-light.png`, and `normal-polkaswap-entry.png` are actual application captures. The center Polkaswap icon opens the existing first-use entry screen. No swap, transaction, cloud authorization or remote registration was performed.

Wallet → Choose network → Taira details also works. The live read endpoint was unavailable; the latest UI gives a visible explanation before the disabled Send action and preserves the network/transaction guards. Prepared send and signing outcomes use the sample fixtures and focused tests described above.

Runtime verification exposed two clean-install issues, now fixed: startup no longer creates an empty network snapshot and retained-wallet marker; current empty SQLite databases with ordinary sidecars are admitted after read-only inventory and protected-key checks. Missing databases with orphan sidecars, retained PIN/selection evidence, symlinks and installed-wallet safety snapshots remain covered by passing regression tests. No database schema or transaction format changed.

The Connect captures (`connect-*`) use the production controller with a stub socket, authenticator and signer that cannot connect or sign. They cover readable and blocked requests, light/dark, iPhone SE and maximum text. Actual accessibility inspection verified Technical details changes between Collapsed and Expanded. Runtime tab labels and selected traits are recorded in `tab-accessibility-final.log`; spoken VoiceOver output is not claimed.

Two distinct XCTest UI flows passed: maximum-text Wallet scrolling → Activity → selected Wallet tab, and maximum-text onboarding scrolling → name entry with visible keyboard → all recovery choices selected. The onboarding flow was repeated after the final text-control fix, and its final screenshot shows the entered name at the chosen large size. The earlier Wallet pass precedes the final asset-name word-wrap/text-control refinements; an optional cold-start repeat was stopped during XCTest’s waits on existing PIN-screen animations. The normal PIN setup/restart/unlock path had already been exercised directly. Physical camera decoding and live network transaction behavior are not established by simulator fixtures. The camera-unavailable branch was exercised; unsupported signing and duplicate/uncertain sends are established by focused tests.

## Final delivery evidence

- `sora-wallet-ux-startup4-tests.log`: full main application build and 24 tests with all gates enabled.
- `sora-wallet-ux-startup4-dev-build.log`: full Dev application build with all gates enabled.
- `sora-wallet-ux-normal-ui-tests.log`: final UI test-host build with full gates. Its initial opt-in tests were skipped; those skips are not counted as passes.
- `sora-wallet-ux-wallet-ui-final.log` and `wallet-ui-final.xcresult`: one passing maximum-text Wallet/navigation test.
- `sora-wallet-ux-onboarding-scaled-ui-final.log` and matching result bundle: one passing final maximum-text onboarding/keyboard/recovery test.
- `sora-wallet-ux-final31-delivery-tests.log` and matching result bundle: 31/31 final tests pass, zero skips/failures.
- `sora-wallet-ux-dynamic-text-{main,dev}-rebuild.log`: final SoraUIKit and both app targets compiled/linked using their recorded Xcode commands, with flags unchanged. The test-host plug-in resources were restored after the separate UI build removed them, then the same test linker command passed.
- `ui-wallet-attachments/` and `ui-onboarding-scaled-attachments/`: actual XCTest screenshots with attachment manifests. The latter supersedes the earlier smaller entered-name text.

Final review caught fixed font regeneration during editing in SoraUIKit text controls. Dynamic Type is now opt-in for both controls, applied during attributed-text regeneration and category changes; name entry and phrase import opt in. Other controls retain their existing default. A test checks both opted-in controls after repeated edits in normal and maximum categories, and an unopted control retains its base size. Asset names now wrap by word.

The read-only Taira detail walkthrough was captured before the final explanatory footer copy; the latest unavailable-Send footer is source/build verified. Screen captures do not establish live service availability. No release or hardware certification is implied.
