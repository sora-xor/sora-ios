# Wallet-opening localization handoff

The release candidate added nine user-visible wallet-opening and connection-recovery
messages. As of source revision `8af8112b`, all nine keys are present in `en` and
`ja`. Every other checked-in `SoraLocalizable/*.lproj/Localizable.strings` catalog
lacks all nine keys: 279 missing locale/key pairs. The app falls back to English
for those messages. This is an inventory for translation review, not approval of
the fallback or of machine-generated translations.

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

After translation review, rerun the source check and the Release simulator
tests. Review the rendered messages on an iPhone for truncation and direction,
including the retry and recovery actions. The separate `WalletRecoveryViewController`
also contains English-only safety guidance and needs its own localization review.
