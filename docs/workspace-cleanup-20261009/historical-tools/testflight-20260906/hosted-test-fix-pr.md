Hosted Release tests fail before compilation because both hosted bundles and SoraPassport link the static JOSESwift product. Remove the test bundles’ direct linkage; they continue to load the application through TEST_HOST/BUNDLE_LOADER. Application linkage and archive runtime checks remain intact.

Apple also flagged `egy-Egyp.lproj` with localization warning 90176. Package the language as `egy.lproj` and normalize a retained `egy-Egyp` selection through the existing settings manager before UI initialization. Keep the language picker option, font, plurals and InfoPlist resources. Synchronize two translations with the current English import/onboarding copy; the other 950 translations retain their exact values.

The generator validates all 952 translated entries and the existing, explicitly declared 150-key English fallback section. It rejects missing/changed translations, duplicate or empty keys, fallback overrides and unreviewed changes to the two source messages. Restore one original vendor-license space so its bytes match the existing frozen digest. CI runs the generator and the new saved-language/packaging regression suite.

Validation:

- Local full Release suite after the hosted-test fix: 291 passed, zero failures, two opt-in visual-fixture skips; includes 202 wallet modernization, 11 recovery-gate and 12 recovery-exporter methods.
- GitHub source-contract and full Release jobs passed for the final PR revision. The downloaded XCResult confirms 291 passed, zero failures and two opt-in skips on arm64 iOS 26.2; all 202 source-defined modernization methods passed. The tested merge tree is identical to the PR head tree.
- Final source gate: 174 tests and 13 lints passed, including Swift/shell parsing.
- Final localization suite: 16 tests passed, including saved-selection/restart behavior against the actual localization manager and 13 generator rejection cases.
- Generator: 952 translations, 150 explicit English fallback entries, zero unknown terms. Project and localized property lists parse successfully.

Apple validation of the new packaging requires a future archive. This PR does not replace the already processed 3.8.7 (2026090601) binary, which was uploaded from `fabcd06ef3d3324b16c1ee076d0300704f1970c3` with warning 90176. Simulator tests do not establish retained physical-device migration qualification or production rollout approval.
