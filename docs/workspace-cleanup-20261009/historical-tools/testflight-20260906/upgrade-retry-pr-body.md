When an installed wallet upgrade runs out of storage during the preflight, startup previously set a permanent recovery marker before changing any wallet data. Users can now free storage and tap **Try again** to resume migration. Repeated taps are serialized, repeated low-space results restore the retry button, and existing integrity-recovery markers remain protected.

The release configuration prepares internal-only TestFlight build **3.8.7 (2026090701)** from the exact tested runtime commit, retaining the signing and source checks.

Validation: optimized Release simulator build passed; all **240 wallet, recovery and UI regression tests passed with zero failures or skips**, including low-space/retry across retained mnemonic formats and both Core Data versions. The three focused retry tests also passed independently. All eight upload-contract tests and the existing migration release-source gate passed.

This is based on #469 so its account-selection/signing correction remains included. The signed TestFlight archive passed. Xcode Organizer successfully uploaded **3.8.7 (2026090701)** on 2026-09-07 at 01:44:23 UTC, with no upload errors or warnings. The delivered IPA retains internal-only distribution and the verified signer/profile. Apple processing and tester availability still need a fresh App Store Connect session.
