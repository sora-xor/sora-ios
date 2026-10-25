# Primary iOS retry integration recommendation

Read-only observation while retry validation3 was running. No source was changed; no merge, cherry-pick, commit or apply was performed. `git apply --check` was used only as a non-mutating applicability check.

Primary `/Users/takemiyamakoto/dev/sora-wallet/sora-ios` is on **modernize**, HEAD **9a69699414f14e73bb0c832d155b9835f9190699**, with an empty `git status --short`. Its merge base with published 0602 commit `d3f9f2490e1b73c9ac199c489ec3dd8c81e7c826` is `e3f1cf94cd0c1a5cc698b26474b621461aba3bdd`; the branches contain 3 primary-only and 7 publication-only commits. Primary-only commits are 9a696994 (merge), 74ec0b60 (gitignore), aaa7e8b0 (sora3 support). A wholesale reset or tree replacement is unnecessary and would discard unrelated primary work.

The exact six-file retry-only patch from `upgrade-retry-ios` against d3 passes `git apply --check` in primary. Five files (the four Splash files and WalletUXTests) match d3 byte-for-byte before the retry. Primary WalletModernizationTests differs from d3 only by absence of the 146-line callback regression/helper added by 6a36f498. Primary SelectedWalletSettings likewise lacks the callback lease release/order fix; both primary files are byte-identical to their versions in 6a36f498's parent. This is not an overlapping primary implementation that must be discarded.

**Recommendation after the current validation succeeds:** integrate the exact **seven-file** delta consisting of all six retry files plus `SoraPassport/Common/Storage/SelectedWalletSettings.swift` from `upgrade-retry-ios`. That seventh file is unchanged from d3 and matches the already published/passing callback implementation. The final WalletModernizationTests file includes both the earlier callback helper and the new low-storage checks. Applying only the retry hunks would leave the callback runtime bug in primary; copying only the six final retry files would add its regression without the production fix.

Before integration, recheck primary HEAD/status and every before hash below; require the validated retry source hashes to match the target hashes. If any differ, inspect that precise file instead of overwriting it. Apply only these seven files, preserve their modes, then require the exact seven-path modified diff, no other edits, and target byte hashes. Retain the actual validation receipt, earlier 225-test/historical rehearsal evidence for the callback fix, and an integration observation. Do not claim that the complete primary branch has been exercised merely because these individual files match the validated publication branch. This bounded review does not authorize merging protected branches or replacing unrelated build, dependency or upload contracts.

| Path | Primary before SHA256 | Validating retry target SHA256 |
| --- | --- | --- |
| `SoraPassport/ModulesRedesign/SplashScreen/SplashFactory.swift` | `7d02670f27d81710c139db26be0cecf15a867cdf8bd13c3350f84516c6b990b2` | `3ab1097e063aafcccecfda9d954dc3f8149a962a00fa2fba4897646dd98e7aae` |
| `SoraPassport/ModulesRedesign/SplashScreen/SplashInteractor.swift` | `c89389420dede59961d69198caaeb8512972f4c6fb9796ac890c91e7b6b18c5c` | `09b9400116a15f9c81c99882505e0c10b6a42bdfdcb24647ba58348376339b97` |
| `SoraPassport/ModulesRedesign/SplashScreen/SplashPresenter.swift` | `6bc787e9149851bda6d989b8f31807d233c402941462b54fbaac1958b70a4bbe` | `77fdf70518952b42300247f5eadc8d5e903a56222ae096e80f1eac7c924967e3` |
| `SoraPassport/ModulesRedesign/SplashScreen/SplashViewController.swift` | `fc90fcb5610042ad42c7f104359055de885696194807ce2469b43f331086f16e` | `c70fc06f6f4304990018c32e2652f62672a2f417462d407655cf5a9bdc51cab4` |
| `SoraPassportTests/Common/Modernization/WalletModernizationTests.swift` | `77685258b6f20d9dc2d3bcb2b0e75a8d72ca1900e5163ef8a236feafc40a80ac` | `3b5a7c94e91b5d2e3027e80559fc70b115ded09a4203f150cdc07cf49903ed1b` |
| `SoraPassportTests/Common/Modernization/WalletUXTests.swift` | `8578245eae35e2ffd8406655fc7512014afb2aca229e9c32af4ec3d004505ab8` | `1a6c34b976d8cf3333f5319ee7eeb074e9697b49bce0f01b74d31f2b80268138` |
| `SoraPassport/Common/Storage/SelectedWalletSettings.swift` | `37afa14759974ed3b0e757cf19889aaaa3020b4fe48571962dfd6068c23d0017` | `58956331a47d3c55d1290f36dfed606c9a964bbddfd4b09eeec7bb0750c2d60c` |

The publication successor remains separate: commit the validated retry source, then the four-file 0701 upload contract in a clean publication checkout. Do not copy that one-time publication contract into primary as part of this seven-file runtime/test integration.
