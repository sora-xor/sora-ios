# Complete the SORA iOS and Android UX fixes

The active goal is to implement the approved UX plan in the primary iOS and Android working copies, preserve unrelated changes, and close implementation and verification with reviewable evidence.

## Fixed navigation requirement

Keep the Polkaswap icon centered with its existing appearance and action on both apps. Contextual routing to Polkaswap or Soraswap is a future change. Source comparison confirms this requirement is preserved.

## Milestones

- [x] Reuse and finish wallet hierarchy, compact iOS backup, wallet network access, Android network-activity separation and iOS Explore market placement.
- [x] Apply existing SORA styling, readable contrast and resource-backed copy with English fallback.
- [x] Complete readable signing review and block unsupported requests before the signer.
- [x] Preserve send drafts; show balance/full recipient; support Paste/Scan; review exact amount, fee and total; invalidate edited quotes.
- [x] Distinguish completed/pending/uncertain/failed results, reject repeat callbacks and restore drafts only for proven pre-submission failures.
- [x] Finish Android lazy cloud provider and onboarding/account/debug consumers, recipient QR contract and result copy.
- [x] Add the iOS development harness membership while retaining strict compiler flags and build gates.
- [x] Improve large-text scrolling, semantics, plain recovery choices and chart date/value context.
- [x] Build Android and both iOS targets; run focused behavior tests. Android: 75 unit and 10 device tests. iOS: 31 focused/related tests and two distinct UI flows pass.
- [x] Obtain usable Android screenshots and iOS sample-state visual evidence in light/dark, narrow screens and large text.
- [x] Deliver a critique-to-implementation/test report, preserving unrelated working-copy changes.
- [x] Close normal iOS onboarding, account creation, phrase confirmation, PIN, restart/unlock, Wallet, network access and Polkaswap entry in isolated simulators. Fix and regression-test the two clean-install admission errors found along that path.
- [x] Finish automated iOS maximum-text scrolling/navigation acceptance and final evidence audit, including the final editing-font regression and onboarding retest.

## Evidence and remaining scope

The [implementation report](/Users/takemiyamakoto/dev/sora-wallet/UX-IMPLEMENTATION-REPORT.md) maps each critique item to code and proof. It links the Android and iOS logs, screenshots, fixture notes and explicit verification limits. Implementation, sample-account verification and the delivery audit are complete. The report states the exact mocked-service and hardware limits.

Sample accounts and mocked outcomes were used. No transaction, live signature or cloud write was performed. Android QR photo decoding, camera callback, picker cancellation, real Fragment-to-draft delivery and denial recovery pass instrumentation. Physical camera capture, live OAuth, funded transactions and spoken screen-reader output are not claimed. Android normal navigation mocks only the unavailable connection observation at PIN. No backend, wire-format or database schema change was made; startup admission and compatible encrypted-DataStore fixes are documented and regression-tested.
