# Next internal TestFlight build preparation

Prepared from the isolated `historical-writer-ios` worktree and live GitHub protection settings on 2026-09-06 at 12:38 UTC. This is a preparation note; no next build, commit, push, or upload has been performed by this subtask.

The consumed build is **3.8.7 (2026090601)**. The proposed next one-time build is **2026090602**, with **2026090601** as the observed App Store lower bound. Recheck the app's build inventory immediately before publication in case another delivery has consumed a newer number. Preserve the original upload/archive/evidence for 0601.

## Exact commit sequence

1. Finish and verify the runtime selection-completion fix, its existing-method regression, and the historical-writer rehearsal. Commit that complete tested runtime/test/project state as **S**. Use the actual resulting full 40-character commit ID; do not prefill or fabricate it. Include any changed qualification source inventory in S if its verifier requires it.
2. Create **one child commit C of S** containing only the four contract files listed below. The existing contract permits exactly this four-path successor. Keep `HEAD^ == S`, `rev-list --count S..HEAD == 1`, and the exact path/change-type checks.
3. Push the complete C source to the single explicitly pinned upstream and use a clean checkout whose `HEAD == @{upstream} == C`. The uploader and archive build phase both independently enforce this. Runtime/test edits must not be added to C or performed after it is pushed.

## Minimal successor changes

Paths below are relative to the iOS repository.

| File | Exact update |
| --- | --- |
| `SoraPassport/Scripts/upload-ios-internal-testflight.sh` | Set `reviewed_base_revision` from `ffd14b0124bdc5a95ef33d7348d592ed4894665b` to S; set `reviewed_build_number="2026090602"`; set `reviewed_lower_bound="2026090601"`; set `reviewed_upstream` to the selected exact pushed branch and update its matching error text. Leave `reviewed_successor_paths` at its existing four files. |
| `SoraPassport/Scripts/verify-modernization-dependencies.sh` | Update the internal capability's exact build comparison at current line 714, upstream/base/one-child/path comparisons around 750-757, and matching uploader-source marker assertions around 2393-2395. Keep clean-source, signing, fixed platform/target, exported-option digest, and non-authorizing source-gate execution intact. |
| `SoraPassport/Scripts/verify-ios-internal-testflight-delivery.py` | Set the exact `BUILD_NUMBER` constant to `"2026090602"`. Keep all delivery-event, signing/profile, internal-only options and Mach-O dependency-closure validation unchanged. |
| `SoraPassport/Scripts/test-ios-internal-testflight-upload.py` | Update valid capability/build fixtures, exact wrapper/gate base/upstream markers, valid delivery fixtures and expected build arguments to C's new contract. Update the lower-bound fixture to 0601. Preserve deliberate invalid-build values and all negative cases, including missing-framework and export/signing mutations. |

The latest local build exposed Xcode updating transitive package pins when package updates were allowed. In the uploader's archive invocation, carry forward the rehearsal's `-disableAutomaticPackageResolution` and `-skipPackageUpdates` flags; add assertions for them in the existing wrapper-contract test. This remains inside the same four-file successor and preserves the checked-in `Package.resolved`. Do not refresh dependency pins to make an archive pass. The current wrapper already rechecks the qualification source snapshot before upload, so source drift must remain fatal.

Do not edit the eight-key export-options plist: it must continue to contain `destination=upload`, `method=app-store-connect`, `manageAppVersionAndBuildNumber=false`, and `testFlightInternalTestingOnly=true`. Keep the current marketing version, bundle ID, team, certificate fingerprints, profile UUIDs/hashes, entitlement assertions and application dependency-closure checks. Verify the existing signing inputs are still available/current; do not silently substitute new credentials or profiles.

## Checks before the upload command

Run the focused callback regression and require one executed passing test, then retain passing producer/migrate/restart XCResults from the disposable historical-writer run. Verify the existing full Release suite against the runtime changes as appropriate. Passing simulator evidence does not become an original App Store binary or physical-device migration receipt.

After C exists, run from its clean checkout:

```sh
/bin/sh SoraPassport/Scripts/upload-ios-internal-testflight.sh --lint-contract
python3 -B SoraPassport/Scripts/test-ios-internal-testflight-upload.py
/bin/sh SoraPassport/Scripts/verify-modernization-dependencies.sh --lint-ios-migration-release-source-gate
```

The current source gate includes the eight internal-TestFlight contract tests plus the migration, package, Taira, vendor, signing and promotion suites. Do not reduce counts, erase failing checks, or manufacture receipts. The existing historical-writer provenance verifier should also pass against the committed source.

Use fresh paths under a new current-user-owned mode-0700 directory outside the checkout. The wrapper requires the shown suffixes and refuses existing output paths:

```sh
/bin/sh SoraPassport/Scripts/upload-ios-internal-testflight.sh \
  --archive-and-upload \
  --build-number 2026090602 \
  --app-store-build-lower-bound 2026090601 \
  --derived-data-path /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090602/SORA-2026090602-DerivedData \
  --archive-path /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090602/SORA-2026090602.xcarchive \
  --export-path /Users/takemiyamakoto/dev/sora-wallet/testflight-20260906/next-upload-2026090602/SORA-2026090602-upload
```

That command includes the upload; execute it only after the above preparation is complete. The user's TestFlight publication request already authorizes this delivery scope. A successful wrapper still needs App Store Connect processing/compliance and tester-group status verified separately. France remains included; do not submit another declaration or claim approval unless Apple's current state requires/supports that action.

If Xcode accepts the upload with warnings but the strict verifier fails, the build number is nevertheless consumed. Preserve the actual warning and delivery record, do not relabel it clean, and do not rerun the consumed build. The existing verifier requires `state=success`, the exact upload event title, and empty errors/warnings. The Egyptian packaging fix already present in this worktree addresses the 0601 `egy-Egyp.lproj` warning; verify the new delivered result rather than assuming it is gone.

## GitHub protection versus publication

Live API observations: PR 468 is open at `8c194ff340f0b9163b3719e4eb4d26e80d821b68`, with both GitHub Actions checks successful, `REVIEW_REQUIRED`, and merge state `BLOCKED`. Classic protection patterns are `develop`, `master`, and `release/*`; each requires one approving review, signed commits, strict `continuous-integration/jenkins/pr-merge`, and enforcement for administrators. The release branch's REST protection additionally reports last-push approval required. The repository currently returns no rulesets, and `release/testflight-2026090602` does not exist.

Consequently, merging/updating a protected release branch still requires its real review/checks. Do not impersonate a reviewer, force-push, disable protections, or claim that existing Actions checks satisfy Jenkins. `codex/*` is not matched by the observed classic patterns: a concrete candidate can be prepared, tested, and pushed to an explicitly pinned allowed source branch (for example the current `codex/historical-writer-rehearsal-20260906`) without representing PR 468 as merged. This is a separate publication checkout, not an alteration of the protected branch. If the chosen upload contract pins `origin/release/testflight-2026090602`, inspect the actual branch-creation result and applicable protection rather than assuming it accepts new commits. Preserve the same exact clean/pushed-source and single-successor checks whichever one concrete upstream is selected.

Sources inspected: the four repository scripts above, `ios-internal-testflight-export-options.plist`, `.github/workflows/ios_modernization.yml`, GitHub PR 468, the release branch protection REST endpoint, repository rulesets, and GraphQL `branchProtectionRules`.
