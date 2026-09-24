# Wallet-opening localization handoff

The release candidate added nine user-visible wallet-opening and connection-recovery
messages. As of source revision `8af8112b`, all nine keys are present in `en` and
`ja`. For 30 other checked-in catalogs, `Try again` now reuses the existing,
checked-in `common.retry` translation for the same retry button action. The
remaining eight keys are missing in each of the 31 other catalogs, and `ca`
still needs reviewed text for `Try again`: 249 missing locale/key pairs.
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
The Catalan `Try again` action needs reviewed text before release.

No other key has an equivalently direct, complete match. The existing
`switch.node` is the closest label to `Change node`, but most catalogs still
contain the English placeholder `Switch node`, and the action here opens node
settings; it was not copied. Android's `switch_node` catalogs have the same
placeholder issue and no exact text for the other new wallet-opening messages.

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

The current expected result is `249 missing locale/key pairs`. To verify the
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
