# Wallet-opening localization handoff

The release candidate added nine user-visible wallet-opening and connection-recovery
messages. As of source revision `8af8112b`, all nine keys are present in `en` and
`ja`. For 30 other checked-in catalogs, `Try again` reuses the existing,
checked-in `common.retry` translation for the same retry button action. Catalan
uses a retry phrase derived from its existing `common.error.retry` value. The
remaining eight keys are missing in each of the 31 other catalogs: 248 missing
locale/key pairs.
The app falls back to English for those messages. This is an inventory for
translation review, not approval of the fallback or of machine-generated
translations.

## Exact keys

1. `Opening wallet`
2. `Preparing wallet services…`
3. `Try again`
4. `Change node`
5. `Check wallet again`
6. `Wallet verification needs attention. Check your saved wallet again.`
7. `Wallet services are not ready. Try again or choose another node.`
8. `Node settings are still loading. Try again.`
9. `Network unavailable. Retrying connection…`

## Reused translation provenance

`Try again` is the button that invokes `retry()` in
`PinSetupWireframe.swift`. Thirty non-English/Japanese values were copied
byte-for-byte from `common.retry` in the same catalog, a tracked generic retry
action label.
The English source wording differs (`Try again` versus
`Retry`), but both label the same immediate retry action. This reuse does not
claim a new translation review, and a language reviewer should still inspect
each value in the wallet-opening screen. The existing `common.retry` value in
`ca` reads `Reintentar`, which appears to be Spanish; that value was not reused.
The Catalan value `Torna-ho a provar` removes the existing polite prefix
`Siusplau` from `common.error.retry = "Siusplau torna-ho a provar"`, whose
English source is `Please try again`. This preserves a checked-in Catalan
retry phrase; language review is still needed for the wallet-opening context.
The storage-upgrade retry, retained-wallet recovery retry, and PIN-unavailable
alert also use this existing `Try again` lookup for the same retry action.
Their surrounding safety messages remain English and need separate review.

No other key has an equivalently direct, complete match. The existing
`switch.node` is the closest label to `Change node`, but most catalogs still
contain the English placeholder `Switch node`, and the action here opens node
settings; it was not copied. Android's `switch_node` catalogs have the same
placeholder issue and no exact text for the other new wallet-opening messages.

## Observed fallback for missing keys

`WalletUX.text` looks in the selected locale's `Localizable.strings`, then in
`en`, and finally returns the English phrase passed by the caller. The nine
new wallet-opening call sites pass English phrases as keys. A macOS Foundation
probe using the same lookup sequence against the checked-in `.lproj` folders
produces these values at the current candidate:

| Selected locale | Opening wallet | Try again | Node settings are still loading. Try again. |
| --- | --- | --- | --- |
| `fr` | Opening wallet | Recommencer | Node settings are still loading. Try again. |
| `ja` | ウォレットを開いています | 再試行 | ノード設定を読み込んでいます。再試行してください。 |
| `ca` | Opening wallet | Torna-ho a provar | Node settings are still loading. Try again. |
| unknown `xx` | Opening wallet | Try again | Node settings are still loading. Try again. |

Reproduce from the repository root:

```sh
/usr/bin/swift -e 'import Foundation; let root = URL(fileURLWithPath: CommandLine.arguments[1]); func text(_ key: String, _ selected: String) -> String { for locale in [selected, "en"] { let path = root.appendingPathComponent("\(locale).lproj").path; guard let bundle = Bundle(path: path) else { continue }; let result = bundle.localizedString(forKey: key, value: key, table: "Localizable"); if result != key { return result } }; return key }; for locale in ["fr", "ja", "ca", "xx"] { print("\(locale): \(text("Opening wallet", locale)) | \(text("Try again", locale)) | \(text("Node settings are still loading. Try again.", locale))") }' "$PWD/SoraPassport/SoraLocalizable"
```

This probes the source resources and Foundation lookup, not a rendered iPhone
screen. Missing keys display the English phrase in this path; that behavior does
not approve the 248 missing translations for release. The separate wallet
recovery screen also contains English-only safety guidance and needs its own
localization review.

## Catalogs needing reviewed translations

`akk`, `ar`, `az`, `ca`, `cs`, `de-DE`, `de`, `egy-Egyp`, `es`, `fa`,
`fi-FI`, `fr`, `he`, `hi-IN`, `hu`, `id`, `it-IT`, `it`, `ms-MY`, `nl`,
`nn-NO`, `no`, `pl`, `pt`, `ru`, `sl`, `sr`, `tr`, `vi`, `zh-Hans`,
`zh-Hant-TW`.

## Source check

Run from the repository root. The command exits nonzero until each checked-in
catalog defines all nine keys. It checks coverage, not translation quality.

```sh
python3 - <<'PY'
from pathlib import Path
import re

root = Path('SoraPassport/SoraLocalizable')
english = (root / 'en.lproj/Localizable.strings').read_text()
keys = (
    'Opening wallet',
    'Preparing wallet services…',
    'Try again',
    'Change node',
    'Check wallet again',
    'Wallet verification needs attention. Check your saved wallet again.',
    'Wallet services are not ready. Try again or choose another node.',
    'Node settings are still loading. Try again.',
    'Network unavailable. Retrying connection…',
)
def contains(text, key):
    return re.search(r'^\s*"' + re.escape(key) + r'"\s*=', text, re.M) is not None

assert all(contains(english, key) for key in keys)
missing = {
    catalog.parent.name.removesuffix('.lproj'): [
        key for key in keys if not contains(catalog.read_text(), key)
    ]
    for catalog in sorted(root.glob('*.lproj/Localizable.strings'))
}
missing = {locale: keys for locale, keys in missing.items() if keys}
for locale, keys in missing.items():
    print(f'{locale}: {len(keys)} missing')
print(f'{sum(map(len, missing.values()))} missing locale/key pairs')
raise SystemExit(bool(missing))
PY
```

The current expected result is `248 missing locale/key pairs`. To verify the
reused values have not diverged from their checked-in source, run:

```sh
python3 - <<'PY'
from pathlib import Path
import re

root = Path('SoraPassport/SoraLocalizable')
def value(text, key):
    pattern = r'^\s*"' + re.escape(key) + r'"\s*=\s*"((?:\\.|[^"\\])*)"\s*;'
    match = re.search(pattern, text, re.M)
    assert match, key
    return match.group(1)

for catalog in sorted(root.glob('*.lproj/Localizable.strings')):
    if catalog.parent.name in {'en.lproj', 'ja.lproj', 'ca.lproj'}:
        continue
    text = catalog.read_text()
    assert value(text, 'Try again') == value(text, 'common.retry'), catalog
print('30 existing retry translations reused byte-for-byte')
PY
```

After translation review, rerun the source check and the Release simulator
tests. Review the rendered messages on an iPhone for truncation and direction,
including the retry and recovery actions. The separate `WalletRecoveryViewController`
also contains English-only safety guidance and needs its own localization review.
