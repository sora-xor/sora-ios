# iOS localization fallback qualification — 2026-09-25

The release candidate keeps all 33 bundled language catalogs. For generated
R.swift lookups, it now checks whether the selected locale contains a usable
value for the requested key. If the key is absent or its `.strings` value is
empty, lookup continues through the language fallback and then the English
development catalog. Existing translations and deliberately empty plural
formats in `.stringsdict` remain available. `WalletUX.text` also skips an empty
selected value before trying English. No catalog content or language selection
has been changed.

The legacy `L10n` path used by transfer and QR scanning now checks the selected
locale, its base language, and English for a nonempty key value. Eleven active
error keys are absent even from the shipped English catalog, so their existing
English comments are explicit last-resort text. The active transfer error title
uses the existing generated `common.error.general.title` key. An audit found
88 legacy keys absent from the English catalog; historical keys without active
callsites remain outside this bounded fix and can still resolve to empty text.

An audit of the source `Localizable.strings` catalogs found 1,111 nonempty
English keys, 5,060 missing key/locale pairs across the 32 non-English catalogs,
and three additional empty values in `egy-Egyp`. The fallback makes those
entries display English when an English value exists; it does not provide
translations. Product and language-owner approval of English text in those
locales is still pending.

The four focused Release simulator XCTest cases in `WalletUXTests.swift` passed
with no failures. They cover selected translations, missing and empty values,
formatted strings, selected plurals, an intentionally empty plural format, and
active legacy error messages. The vendored R.swift package passed 23 tests,
the generated source parsed for arm64 iOS Simulator, and the iOS migration
Release source gate passed (94 migration, 8 internal-TestFlight, 17
Release-package, 15 Taira-admission, 10 vendored-binary, 10 signing-identity,
and 20 production-promotion tests; 13 lints plus shell/Swift parse). These
checks are non-authorizing simulator and source evidence, not language-owner
approval or a production signing qualification.
