# ik0-ui-wip: review fixes for the SORA Neon UI foundation

Task key `ik0-ui-wip`. Branch `claude/release-fixes-20261011-ios-keys`.
`SUK/` below is `VendorPackages/SoraUIKit/SoraUIKit/SoraUIKit/Sources/`.

## Why

A review round on the i6 SORA Neon foundation (design spec
`SORA-NEON-DESIGN.md`) was cut off half way. It left uncommitted changes in
29 files. This task read every hunk of that draft against the spec, kept
what was right, finished what was half done, changed what was wrong, and
fixed what the screenshots showed.

What the review had found in i6:

- **A way forward could be out of reach.** On a small iPhone or at a large
  text size the 1.x upgrade screen ("Upgrade your wallet") centred its
  content on the visible frame of its scroll view. The content then followed
  the scroll offset, so its lower part, with "Upgrade wallet" and "What
  happens during the upgrade?", could never be scrolled into view. The
  low-storage panel on the splash ("Free up some space") did not scroll at
  all, so "Check again" could be cut off. Both are the only action on their
  screen.
- **Glow everywhere.** Every filled primary `SoramitsuButton` glowed, also
  in table cells and several per screen. The spec allows at most three glows
  per screen and none in lists (§1, §4.5, §10.3). Under "Reduce effects" /
  Reduce Transparency the glow simply vanished instead of becoming the
  1.5 pt ring of §4.0.
- **Unreadable labels.** A button's attributed title kept its own colour on
  the neon fill: white on the dark swap gradient is 3.6:1. Polkaswap pink
  (`additionalPolkaswap`, the brand fill) was used as text on its light
  container: 4.33:1.
- **Red text on bars.** "Add node", "Edit", "Done", "Skip" and "Create pool"
  were red (`#EE2233` or `accentPrimary`): 3.3:1 on a light bar, and red
  reads as an error (§2.6, §3.2).
- **Tab bar.** iOS 16 to 25 had no active-tab indicator (§7.11). If the
  custom bar could not be swapped in, only part of the swap disc moved to
  the system bar (no fill, no glow).
- **Cost of a settings change.** Any accessibility or power change (Reduce
  Motion, Low Power Mode, a thermal change) re-applied the whole palette and
  rebuilt every label in the app, also when nothing changed for the UI.
- **Links by colour only.** The terms links on Welcome were red and not
  underlined (§8.2, §10.1).

Found on the simulator in this task:

- The Welcome logo had a line across it: the card draws its hairline above
  its own subviews, and the logo was one of them.
- Opened from More, the node list is the root of a modal. It had no visible
  way out, only pull-down gestures (as in 3.8.6).

## What changed

### Safe Mode panels scroll to their last action

- `WalletSafeMode.installScrollingContent(_:in:insets:)`
  (`SoraPassport/Common/WalletUX.swift`): content that fits is centred;
  taller content starts at the top and every part can be scrolled into
  view. The content is centred in the scroll view's content area, never on
  its frame.
- `LegacyWalletUpgradeViewController` (`RootWireframe.swift`) and the
  low-storage panel (`SplashViewController.showStorageSpaceRetry`) use it.
  These are the only lines changed in those two files; no action, text,
  identifier or startup logic changed.

### Glow is opt-in, never in lists, a ring in the MINIMAL tier

- `SoramitsuButton`: new `sora.glows` (default off). The neon gradient fill
  does not depend on it. A glow is never drawn inside a `UITableViewCell`
  or `UICollectionViewCell` (checked when the button enters a window).
  Under "Reduce effects" or Reduce Transparency the glow becomes a 1.5 pt
  ring in the glow colour at 80 %, drawn just outside the button
  (`NeonRingLayer`, `SUK/Neon/NeonLayers.swift`). Increase Contrast shows
  neither.
- `WalletNeonButton` (onboarding and Safe Mode buttons) and `GlowHostView`
  (swap disc, shield) follow the same rules. The ring of `GlowHostView` was
  a border on its own layer, hidden under the control it sits behind; it is
  now outside the control.
- The glow is turned on for the two screen-level `SoramitsuButton` CTAs
  that are not in a list: "Review" on Send (`InputAssetAmountViewController`)
  and on Swap / liquidity (`PolkaswapViewController`). It is static there
  (no pulse on money screens). The phrase screen's "Continue" has no glow:
  nothing glows next to secrets.
- `InputAssetField`: the amount card no longer clips. (That alone did not
  make its focus glow visible; see "Review round 2" below.)

### Button titles follow the fill

- `SoramitsuButton.refreshAttributedTitle`: on a neon fill a caller's
  attributed title takes the label colour (ink in dark, white in light); on
  a disabled button `text.disabled`. Elsewhere the caller's colours stay.
- New colour slot `SoramitsuColor.additionalPolkaswapText` (`polkaswap.text`
  of §2.1/§2.2: `#FF5C9E` dark, `#B0004B` light; 6.4:1 and 5.9:1 on the
  container). Used for "Remove" (pool details, both places that set it),
  "Supply liquidity" and "Edit farm" / "Start staking" on the Polkaswap
  container. The draft had missed the second "Remove" assignment in
  `PoolDetailsCell.set(item:)`.

### Text bar buttons

- `NeonChrome.navigationBarAppearances` styles every text bar button in one
  place (`buttonAppearance`, `doneButtonAppearance`): `textBoldS`; cyan on
  dark bars (7.35:1 on the worst-case bar); `text.primary` on light bars
  (10.98:1). Back titles stay hidden in every state. The style follows
  theme changes through the existing bar restyling.
- The five screens no longer set a colour themselves (`NodesViewController`,
  `ProductListViewController`, `AccountCreateViewController`,
  `ChangeAccountViewController`, `ExploreViewController`).
- Changed from the draft: the draft only removed the red and let the cyan
  bar tint colour the titles. Cyan is 3.21:1 on a light bar, and §3.2
  allows only `text.primary` and `text.secondary` for text there. Icons
  keep the cyan tint (they need 3:1).

### Tab bar

- `TabBar(frame:drawsLegacyChrome:)` (`SUK/Components/Molecules/Tabbar/`):
  on iOS 16 to 25 the bar draws its notch, hairline and a 16 × 3 red pill
  over the selected item (static `glow.tab`, 240 ms slide, none under
  Reduce Motion, no glow in the MINIMAL tier). On iOS 26 and 27 nothing is
  painted over the system Liquid Glass bar and the system selection is the
  indicator, as before.
- Changed from the draft: the pill is drawn above the bar's own views
  (`zPosition`), and its glow path is always the pill.
- `TabBar.installSwapDisc(in:)`: if a future iOS no longer lets the custom
  bar be swapped in, the whole disc (glow, gradient fill, button, tap cover
  and label) moves to the system bar and still follows theme changes.
- The key-value swap itself was checked on iOS 18.4, 26.5 and 27.0, and a
  test now checks it on whatever system the tests run on.

### Effects-only updates

- New `UpdateOptions.effects`. `ThemeManager` sends it when the effect
  policy changes; colours and text are not rebuilt. Surfaces that draw
  glass, hairlines, glows, rings or shadows handle it
  (`SoramitsuViewConfiguration`, buttons, the three input fields, `TabBar`,
  `WalletNeonButton`).
- `NeonFxCenter` posts `.neonFxChanged` only when the resulting policy
  changed, and once per burst of system notifications.
- `SoramitsuViewConfiguration.updateShadowPath`: a view with a clear fill
  gets an empty shadow path (no content-derived shadow, no offscreen pass;
  §10.3).
- Changed from the draft: `InputAssetFieldConfiguration` had a placeholder
  method that only called `updateView()`; it is gone.

### Welcome and node list

- Welcome: terms text is `text.secondary`; links are cyan and underlined,
  also while pressed, and follow theme changes. The logo sits above the
  card instead of inside it, so no hairline crosses it.
- Node list opened from More: a Close button on the left (existing
  `common.close` string as its accessibility label). Pushed from the PIN
  screen it keeps the Back arrow. The pull-down gestures still work.

## Key safety

UI only. No code that reads, writes, moves or deletes wallet keys, the
account store, migration state or settings was touched. In `RootWireframe`
and `SplashViewController` only the layout of two panels changed. Four
tests switch the `neon.reduceEffects` preference (the key added in i6) on
and off; the test class removes the key before and after every test.

## User-visible effects

- At large text sizes and on small iPhones, "Upgrade wallet" (1.x upgrade)
  and "Check again" (low storage) can always be reached by scrolling.
- Fewer glows: only the main action of a screen glows; lists are calm.
  With Reduce Transparency the glow is a thin ring.
- Labels on pink and red buttons are readable in both themes.
- "Add node", "Edit", "Skip", "Create pool": cyan in dark, black in light,
  never red.
- iOS 16 to 25: a red pill marks the active tab.
- Welcome: underlined cyan links; no line across the logo.
- The node list has a Close button.
- Identicons and other views without a fill no longer cast a faint shadow
  in light mode.

## Tests

`SoraNeonDesignTests` (`SoraPassportTests/Common/Modernization/WalletUXTests.swift`),
8 new tests and 2 new checks in `testNeonPalettesKeepTextReadable`:

| Test | What it proves |
|---|---|
| `testSafeModePanelsScrollToTheirLastAction` | In a 320 × 300 window the last action of the upgrade screen and "Check again" of the low-storage panel can be scrolled into view; content that fits is centred. |
| `testButtonGlowIsOptInNeverInListsAndARingInTheMinimalTier` | Glow off by default, on with `sora.glows`, never in table or collection cells, ring under "Reduce effects" (`SoramitsuButton` and `WalletNeonButton`). |
| `testEffectChangesSendOneEffectsUpdate` | One `.effects` update per change, no palette update, nothing for an unchanged policy. |
| `testAttributedButtonTitlesFollowTheFillAndTheDisabledState` | Ink / white on the swap gradient, `text.disabled` when disabled, caller's colour on a container. |
| `testBarTextButtonsUseColoursThatAreReadableOnBars` | ≥ 4.5:1 on the worst-case bar in both themes, back titles hidden, the node list sets no colour of its own. |
| `testTabBarChromeAndSwapDisc` | No drawing over Liquid Glass; notch, hairline and pill before it; pill follows the selection and hides for the swap item; the custom bar installs on this system; the fallback moves the whole disc. |
| `testWelcomeTermsLinksAreCyanAndUnderlined` | Link colour, underline and terms colour in both themes. |
| `testModalNodeListHasAVisibleCloseButton` | Close button when modal, none when pushed. |

Fails before, passes after: with the fixes switched back to the i6
behaviour (old layouts in `RootWireframe`, `SplashViewController`,
`WelcomeViewController`, `NodesViewController`; palette update on effect
changes; glow for every neon button; attributed titles untouched; no bar
button style; brand pink as text) the class ran with 26 failed assertions
in 8 tests, among them "the last action can be scrolled into view". With
the fixes: 14 tests, 0 failures, on iOS 27.0, 26.5 and 18.4 simulators.

## Verification (Xcode 27.0)

- Debug `build-for-testing` (simulator), `SoraPassportDev` (simulator) and
  the unsigned Release build for `generic/platform=iOS` succeed.
- `SoraPassportTests`, Debug, iOS 27.0, `Sora2MainnetLiveSigningTests`
  skipped (needs the live network): 490 tests, 0 failures (482 before this
  task plus the 8 new ones).
- Real app on the iOS 27.0 simulator (Japanese, dark and light): splash,
  Welcome, account name, backup warning, phrase screen, PIN setup and
  unlock, wallet home with the tab bar, Explore, More, node list; live
  switch from dark to light on the home screen; Close on the node list.
- Real launch on iOS 26.5 and 18.4: splash and Welcome in dark and light.
- Tab bar, bar buttons, buttons (full and MINIMAL tier), upgrade screen and
  low-storage panel (normal and largest accessibility text size) shown by
  a temporary hosted test (not committed) on iOS 18.4, 26.5 and 27.0 in
  dark and light, and screenshot from the simulator.
- Screenshots: `scratchpad/work/shots-ios-keys/final/` (54 files). The
  phrase-screen shots show the phrase of a throwaway simulator wallet and
  are kept outside that folder.

## Review round 2 (amount card, focus glow, test hygiene)

Two minor findings from the review of this task, and one defect found while
checking them on the simulator.

### The amount card had two writers (review finding 1, real)

The card of `InputAssetField` (the amount field on Send, Swap and
liquidity) was a `SoramitsuView` with a configuration of its own, while
the field's configuration drew the input chrome (fill, border, focus glow)
on the same layer. A style update reaches the two in no defined order (the
style keeps its observers in a hash table). When the card's handler ran
second:

- after an effects update (Low Power Mode off, Reduce Transparency
  toggled) it cleared the focus glow until the field was focused again;
- after a theme change it also put back the palette fill and cleared the
  border colour, so a focused or failed field lost its coloured border.

Fix: the card is a plain `UIView`, like the chrome host of `InputField` and
`InputTextView`. `InputAssetFieldConfiguration.updateView()` is its only
writer, and the chrome is applied from the first display on. Nothing else
in the app draws a shadow on a Soramitsu view's layer from outside (checked
by search), so `SoramitsuViewConfiguration.applyShadowStyle()` is unchanged.

### The focus glow was cut by the field itself (found on the simulator)

Looking at the result showed that the glow this finding is about was never
drawn properly. Every input molecule clipped to its own bounds (the default
of a Soramitsu configuration), and the glow is a shadow around a view that
fills those bounds:

- `InputField` (account name and every other text field): only a 4 pt strip
  of glow under the field, with hard edges. Visible in the earlier
  `ios27-dark-account-name.png`.
- `InputAssetField`: only the four corners of the glow. On Swap the host
  view of the two cards clipped as well.
- `InputTextView` (the field the recovery phrase or seed is typed into):
  the same strip, next to a secret.

Fix (`SUK/Neon/NeonInputStyle.swift` and the three molecules):

- `InputField` and `InputAssetField` no longer clip. All of their content
  is constrained inside their bounds, so nothing else changes.
  `InputAssetsView` (the two swap cards) no longer clips either.
- The glow is drawn whole or not at all. `NeonInputStyle` draws it only
  when no clipping ancestor is closer than the glow reaches (12 pt in
  dark), re-checked on every layout of the field, and never inside a table
  or collection cell (spec §4.5). Otherwise the field shows the 1.5 pt cyan
  border alone, as it does in light mode.
- Secrets never glow (spec §1.8): `InputTextView` and any `InputField` with
  secure text entry (passwords) keep the focused border only.

Where the glow now shows in dark mode: the account name field in
onboarding (seen in the real app), the amount card as Send and Swap /
liquidity embed it (16 pt inside a full-width container; seen in a hosted
harness with the same layout), and any other plain text field with 12 pt
of free room around it. Password fields, the phrase field, fields in list
cells and fields in tight clipping containers show the border only. Light
mode is unchanged (no focus glow there).

### `FxPolicy.reduceEffects` could miss its first change

`NeonFxCenter` takes its baseline when it is created. If it was created by
the very write that changed the preference, it compared the new policy
with itself and posted nothing. The setter now creates the centre before
it writes. In the app the centre always exists before any UI does, so this
only showed in unit tests (the app skips UI start-up under tests), where it
made the clean-up below time out.

### Test hygiene (review finding 2, real)

Two tests wrote the app's own `neon.reduceEffects` preference and restored
it only in `defer`, and skipped themselves when the effect tier was not
the default. A test run killed at the wrong moment left the key at `true`
on that simulator: both tests then skipped on every later run and the
installed dev app stayed in the MINIMAL tier.

- `SoraNeonDesignTests.setUp` and `tearDown` clear the key, through the
  policy so that every observer follows.
- Tests that need the default tier skip only for system settings a test
  cannot change (Reduce Transparency, Increase Contrast, Low Power Mode,
  thermal pressure). If the app's own key is ever still set, they fail
  instead of skipping.

### Tests of this round

| Test | What it proves |
|---|---|
| `testAmountCardChromeSurvivesStyleUpdatesInAnyOrder` | Fill, border, radius and glow of the amount card after effects and palette updates delivered field-first-then-card (the worst order), through the real notifications, in both themes, after a size change and at rest. The card is drawn before the first focus. |
| `testFocusGlowIsDrawnWholeOrNotAtAll` | Whole glow on a screen, with 12 pt of room in a clipping container and on the swap cards (no ancestor cuts it); none for a password, the phrase field, a field in a list cell and a field in a tight clipping container; follows the container when it stops or starts clipping; the same answers after an effects update. |

Fails before, passes after:

- New tests on the previous production code: 50 failed assertions in the
  two tests ("after an effects update": glow 0.0 instead of 0.35; "cut by
  InputField"; "a password never glows"; "never in a list cell").
- Previous tests with a stale `neon.reduceEffects = true` written into the
  simulator app's preferences: both tests skipped and the key stayed.
- New tests with the same stale key, before the `FxPolicy` fix: the
  clean-up timed out waiting for `.neonFxChanged`. After it: 3 of 3
  selected tests pass, none skipped, and the key is gone afterwards.

### Verification of this round (Xcode 27.0)

- Debug `build-for-testing` (simulator), `SoraPassportDev` (simulator) and
  the unsigned Release build for `generic/platform=iOS` succeed.
- `SoraPassportTests`, Debug, iOS 27.0, `Sora2MainnetLiveSigningTests`
  skipped (needs the live network): 492 tests, 0 failures, none skipped
  (490 before this round plus the 2 new ones).

### Seen on the simulator (iOS 27.0)

- Real app, dark: account name screen (whole glow around the focused
  field, no strip) and the phrase import screen (focused border, no glow).
  No account was created.
- Temporary hosted test (not committed), dark and light: swap cards and
  Send card at rest, focused, in the MINIMAL tier, focused again after an
  effects change (the glow is back without refocusing), failed plus second
  card focused; text fields focused on a screen, as a password, as the
  phrase field, in a list cell and in a tight clipping container.
- Screenshots: `scratchpad/work/shots-ios-keys/fix2/final/` (12 files,
  one of them the clipped glow before the fix).

## Human or ops actions

- None for release. Device QA should include one iPhone on iOS 16 to 18
  (notched tab bar with the pill) and one at the largest text size for the
  1.x upgrade screen.

## Not changed here

- "Reduce effects" still has no switch in Settings (the key and all
  fallbacks exist).
- The caret of text fields is not cyan yet (§7.5): white or black in
  `InputField`, red in the phrase field.
- Text fields inside a clipping container that leaves less than 12 pt
  around them show the focused border without the glow. Giving those
  screens the room is a layout change per screen.
- Links in the swap disclaimer and the migration screen are still red.
- The Welcome description and the "Not backed up" alert have no Japanese
  text (existing strings).
- No new strings were added in this task.
