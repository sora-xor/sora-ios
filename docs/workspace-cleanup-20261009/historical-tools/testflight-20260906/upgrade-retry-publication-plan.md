# Low-storage retry: next internal TestFlight publication

Prepared on 2026-09-07 JST by reading the current wrappers and the actual 2026090602 delivery evidence. No source, published checkout, signing input, or Apple state was changed. The active iOS validation must finish before its source is committed.

Use **3.8.7 (2026090701)**, lower bound **2026090602**. No 2026090701 local publication artifact or Git ref was observed. The retained Apple observation confirms 2026090602 was consumed; refresh App Store Connect's build list before finalizing the successor to catch any independent delivery.

## Source sequence and four-file successor

1. Preserve the passing validation logs/XCResult and exact six retry runtime/test file hashes from `upgrade-retry-ios`. Commit the complete tested retry change on top of `d3f9f2490e1b73c9ac199c489ec3dd8c81e7c826`; call its actual resulting full SHA **S**.
2. Make exactly one child commit **C** containing only the four contract files below. Pin the new upstream to `origin/codex/ios-wallet-upgrade-testflight-2026090701`. Keep `HEAD^ == S`, exactly one commit in `S..C`, and the existing exact four-path/change-type checks. Do not put runtime changes in C.
3. Push that ordinary internal-testing branch and use a separate clean checkout, proposed `testflight-20260906/publish-2026090701-ios`, with `HEAD == @{upstream} == C`. Keep all previously published checkouts unchanged.

All paths below are relative to the iOS checkout:

| Contract file | Minimal update |
| --- | --- |
| `SoraPassport/Scripts/upload-ios-internal-testflight.sh` | Change `reviewed_base_revision` from `6a36f498e3155be4294e90129166020ae7ca352b` to S; build from `2026090602` to `2026090701`; lower bound from `2026090601` to `2026090602`; upstream and its matching failure message to the new exact branch. |
| `SoraPassport/Scripts/verify-modernization-dependencies.sh` | Change the exact internal build comparison at line 714, upstream/base/one-child/path bindings at 750–757, and uploader marker assertions at 2393–2395 to the same new contract. |
| `SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py` | Change the sole `BUILD_NUMBER` constant from `2026090602` to `2026090701`. |
| `SoraPassport/Scripts/test-ios-internal-testflight-upload.py` | Update valid capability/delivery fixtures, wrapper/gate base/upstream markers and expected build arguments; change the lower-bound fixture to 0602. Preserve the deliberately invalid build `2026081602` and all negative cases. |

Use exact anchored replacements. Replace the old upstream before replacing the build token, and the old lower-bound token last: the new lower bound intentionally equals the old build. Baseline occurrence counts for `(old base, old upstream, old build, old lower bound)` are respectively `(1,2,3,1)`, `(4,2,4,0)`, `(0,0,1,0)`, and `(2,2,9,1)` in the table's file order. The older outside-source 0602 patch generator has obsolete SHA pins and branch defaults; do not run it unchanged.

The archive already has `-disableAutomaticPackageResolution` and `-skipPackageUpdates`, with assertions in the existing tests. Retain both. Keep Package.resolved, the eight-key export plist with `testFlightInternalTestingOnly=true`, all signing/profile pins, dependency-closure verification, qualification-source digest, clean/pushed-source enforcement and internal-only capability unchanged. No new code-signing overrides or simulator test-mode variables belong in the archive invocation.

## Validate and archive/upload

From clean C, run the existing focused contracts:

```sh
/bin/sh SoraPassport/Scripts/upload-ios-internal-testflight.sh --lint-contract
python3 -B SoraPassport/Scripts/test-ios-internal-testflight-upload.py
/bin/sh SoraPassport/Scripts/verify-modernization-dependencies.sh --lint-ios-migration-release-source-gate
```

Create only the fresh private parent directory; the wrapper creates and validates the fresh child paths:

```sh
mkdir -m 700 /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090701
/bin/sh SoraPassport/Scripts/upload-ios-internal-testflight.sh \
  --archive-and-upload \
  --build-number 2026090701 \
  --app-store-build-lower-bound 2026090602 \
  --derived-data-path /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090701/SORA-2026090701-DerivedData \
  --archive-path /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090701/SORA-2026090701.xcarchive \
  --export-path /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090701/SORA-2026090701-upload
```

This executes the actual signed `xcodebuild -project SoraPassport.xcodeproj -scheme SoraPassport -configuration Release -destination generic/platform=iOS ... archive` with the wrapper-generated internal-upload/source/export/qualification digest settings, then `xcodebuild -exportArchive` using its read-only snapshot of the internal-only upload plist. Use the wrapper, not a partial handwritten archive command that omits these bindings.

Signing remains automatic with team `YLWWUD25VZ`, bundle `co.jp.soramitsu.sora`. The wrapper verifies the archive's Apple Development leaf SHA1 `1F57A04EB10B3665696663CDA0DBD893CF7FE886` and profile UUID `908dc5a8-2b34-4617-94bb-f4a58ed5f4da` / SHA256 `ede945565f09b23b4d92eca0752cb6ad52fe47b8a6ebb0e38f424ce64de79235`. Export retains Apple Distribution leaf SHA1 `84AB95335BE14CAE9B050A353910F86FF2F9539B` and profile UUID `7ae520bc-599b-48ae-abfa-627eef530f0c` / SHA256 `19073a93bc09fe061e2346470b57aae1961aa38ad4c6b4922e0140bf8061bf93`. Exact entitlement, validity, SHA256 certificate and recursive runtime checks remain enforced by the existing scripts. Do not replace an unavailable/drifted identity silently.

## Actual Organizer route if CLI account export fails again

For 0602 the wrapper completed the signed archive, identity/source and runtime checks, then CLI export returned `Failed to Use Accounts`. The successful remedy used that same verified archive through Xcode Organizer; it did not rebuild or change source. If the new export actually has that terminal account failure and no successful upload has consumed the build, preserve its logs and open the newly verified archive:

```sh
open -a Xcode /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090701/SORA-2026090701.xcarchive
```

Select that exact archive in Organizer → Distribute App → App Store Connect → Upload. The retained 0602 log records method/destination, account/app lookup, options, signing method/assets, packaging, summary, upload and result steps. Use the authenticated Soramitsu team, preserve build 0701 (disable automatic version/build management), select internal-TestFlight-only distribution, automatic signing, Swift-symbol stripping and no symbol upload. Check the summary identity before Upload. This describes the observed distribution route and required settings; verify the actual current controls rather than assuming a dialog layout.

Record the actual terminal Apple result. Organizer imports its own archive copy: find the exact copy's Info.plist distribution event, compare all Products file bytes with the verified original, retain the actual uploaded IPA and distribution logs privately, and verify the IPA's `TFInternalTestingOnly=true`, exact source/build/bundle, pinned distribution leaf/profile, strict code signature and runtime dependency closure. Use the actual observed Products count; do not hard-code0602's 309. Keep the strict CLI verifier unchanged; a GUI delivery is recorded as GUI evidence, not a fabricated CLI receipt. Raw upload logs contain temporary URLs/account metadata and remain private.

The reference is `next-upload-2026090602/gui-upload-evidence/gui-upload-observation.json`: actual delivery `d9c4c7a7-7357-423c-abfe-2b3e65c4debd`, upload `2026-09-06T13:49:55Z`, no errors/warnings, 309 matching Products files, and the preserved internal-only IPA. After the new upload, verify App Store Connect processing, save retry-focused test notes and check internal group availability. Report Apple status separately from upload success. Broader production migration qualification and protected-branch review remain unchanged; the user's requested internal TestFlight publication is already authorized.
