# Older iOS qualification — 12 October 2026

Full Debug suites pass on iOS 17.5, 18.4 and 26.5: each 838 tests, eight opt-in
skips, zero failures, Xcode exit 0. Normal app UI on each imports the public
12-word abandon/about phrase, creates and confirms its PIN, opens Wallet and
Activity, reveals the phrase and verifies address
`cnTon6cV8Ze8ATHT1tZdHregCc3wBc8vfg7P5o2TtwdUoRf4m` and production signing.

The whole project targets iOS 16. All Swift availability sites were inspected;
the only newer scene role is guarded by iOS 26 availability. Other versioned
guards are for iOS 13/15. Direct SDK API references compile with the real iOS 16
deployment target. Targeted scans found no unguarded UIKit glass, UITab, trait
registration, content-unavailable configuration or symbol-effect calls.
Evidence: `audit-2026-10-12/ios/ios16-availability-review.json` and its complete
availability-site inventory. No iOS 16 runtime is installed; physical iOS 16
and third-party runtime behavior remain release QA, not a claimed simulator pass.

The test-created simulators and cleanup receipt are tracked in VERIFICATION.md.
No other application's simulators are part of this task.
