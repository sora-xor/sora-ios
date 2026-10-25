# iOS `Localizable.strings` key coverage — 24 September 2026

Source: iOS release candidate `2f538658` (PR #488). The Catalan
`Try again` value was added from checked-in same-language retry wording. This
audit compares the distinct parsed keys in all 33
tracked `SoraPassport/SoraLocalizable/*.lproj/Localizable.strings` catalogs with
the English catalog. Apple's `plutil` accepts all 33 catalogs.

English defines 1,112 distinct keys, including `"" = "";`. Across the 32 other
catalogs, 5,092 English-key/locale pairs are missing; 5,060 remain if the empty
English key is excluded. Three extra key/locale pairs appear outside English:
`add.liquidity.pool.share.title` in `de-DE`, `it-IT`, and `no`.

| Catalog | Parsed keys | Missing vs en | Extra vs en |
| --- | ---: | ---: | ---: |
| `en` | 1,112 | 0 | 0 |
| `akk` | 953 | 159 | 0 |
| `ar` | 953 | 159 | 0 |
| `az` | 953 | 159 | 0 |
| `ca` | 953 | 159 | 0 |
| `cs` | 953 | 159 | 0 |
| `de` | 953 | 159 | 0 |
| `de-DE` | 950 | 163 | 1 |
| `egy-Egyp` | 953 | 159 | 0 |
| `es` | 953 | 159 | 0 |
| `fa` | 953 | 159 | 0 |
| `fi-FI` | 953 | 159 | 0 |
| `fr` | 953 | 159 | 0 |
| `he` | 953 | 159 | 0 |
| `hi-IN` | 953 | 159 | 0 |
| `hu` | 953 | 159 | 0 |
| `id` | 953 | 159 | 0 |
| `it` | 953 | 159 | 0 |
| `it-IT` | 950 | 163 | 1 |
| `ja` | 961 | 151 | 0 |
| `ms-MY` | 953 | 159 | 0 |
| `nl` | 953 | 159 | 0 |
| `nn-NO` | 953 | 159 | 0 |
| `no` | 950 | 163 | 1 |
| `pl` | 953 | 159 | 0 |
| `pt` | 953 | 159 | 0 |
| `ru` | 953 | 159 | 0 |
| `sl` | 953 | 159 | 0 |
| `sr` | 953 | 159 | 0 |
| `tr` | 953 | 159 | 0 |
| `vi` | 953 | 159 | 0 |
| `zh-Hans` | 953 | 159 | 0 |
| `zh-Hant-TW` | 953 | 159 | 0 |
| **Other-catalog totals** | | **5,092** | **3** |

## Reproduce

Run from the iOS release candidate root. The command reads only tracked
`.strings` catalogs and uses Apple's property-list parser, so counts refer to
distinct parsed keys rather than line matches.

```sh
python3 - <<'PY'
import json
import subprocess
from pathlib import Path

paths = subprocess.check_output(
    ['git', 'ls-files', 'SoraPassport/SoraLocalizable/*.lproj/Localizable.strings'],
    text=True,
).splitlines()
catalogs = {}
for relative in paths:
    path = Path(relative)
    data = subprocess.check_output(['/usr/bin/plutil', '-convert', 'json', '-o', '-', relative])
    catalogs[path.parent.name.removesuffix('.lproj')] = json.loads(data)

english = set(catalogs['en'])
print('catalogs:', len(catalogs), 'English keys:', len(english))
print('locale keys missing_vs_en extra_vs_en')
missing_total = extra_total = 0
for locale, catalog in sorted(catalogs.items()):
    if locale == 'en':
        continue
    keys = set(catalog)
    missing, extra = len(english - keys), len(keys - english)
    missing_total += missing
    extra_total += extra
    print(locale, len(keys), missing, extra)
print('totals:', missing_total, extra_total)
PY
```

The nine wallet-opening and connection-recovery keys in the candidate's
`Fixtures/Modernization/ios-wallet-opening-localization-handoff.md` are a
**scoped inventory**: their 248 missing pairs are part of the 5,092 total, not
a complete localization audit. This comparison excludes `.stringsdict` and
other resource formats. Key presence alone does not establish translation
quality, formatting safety, or device rendering. Translations need human review.

## String format placeholders

A separate comparison of the 61 English values containing `%@`, `%s`, `%d`, or
`%f` against the same keys in other catalogs found format-token mismatches. Two
live `polkaswap.insufficient.balance` warnings omitted the asset-symbol `%@`;
the candidate restored it in Azerbaijani and Serbian. A Hungarian QR share
message omitted one `%s` for the token being requested. Two Dutch and two Polish
liquidity descriptions used the literal `{slippageTolerance}%` where the English
format expects `%s%%`; the candidate now accepts the supplied slippage value.
Those five corrected values retain the translated wording. All edited catalogs
pass `plutil -lint`, and the migration Release source gate passes.

Eight more `%@` count mismatches now have direct catalog-backed repairs:

- Persian `project.discussion.template`, `project.requires.votes.format`, and
  `wallet.transfer.note.hint` replace the nonfunctional `[٪s]` marker with
  `%@`. `project.founded.template` replaces both markers in place and uses one
  Persian percent sign (`٪`) after the first argument. That percent style is
  present in the same catalog's `referral.title` and `referral.subtitle`.
  Persian `project.votes.template` adds `%@` before `آرا`, matching the
  placement of the vote amount before `آرا` in `project.founded.template`;
  other Persian project and liquidity formats already use `%@`.
- Hindi (India) `liquidity.removed` fills the existing double-space gap between
  `Liquidity` and `को` with `%@`; `liquidity.added` in the same catalog already
  formats a liquidity amount.
- Italian `project.spent.format` in both `it` and `it-IT` uses `%@ voti`, as
  `project.votes.template` and `project.requires.votes.format` already do in
  those catalogs. This also removes the stray bare `%` and its `di` wording.

The remaining Azerbaijani and Persian `project.ended.template` values now
carry the required `%@` after their existing translated wording, matching
the placement used by the other applicable locale templates. All 33 catalogs
parse, and the comparison below finds zero mismatched pairs among the 61
English formatted keys.
The current source tree has generated `R.generated.swift` accessors, but a
search found no direct call sites for the affected keys, so their present
runtime reach is not established. This check covers the listed format-token types and
presence, not all printf syntax, argument order, or device rendering.

Reproduce the format-token comparison from the iOS candidate root:

```sh
python3 - <<'PY'
import json
import re
import subprocess
from pathlib import Path

root = Path('SoraPassport/SoraLocalizable')
token = re.compile(r'(?<!%)%(?:\d+\$)?([@sdf])')
def args(value):
    return tuple(sorted(token.findall(value.replace('%%', ''))))
catalogs = {
    path.parent.name.removesuffix('.lproj'): json.loads(
        subprocess.check_output(['/usr/bin/plutil', '-convert', 'json', '-o', '-', str(path)])
    )
    for path in root.glob('*.lproj/Localizable.strings')
}
english = catalogs['en']
format_keys = {key: args(value) for key, value in english.items() if args(value)}
mismatches = [
    (locale, key)
    for locale, catalog in catalogs.items() if locale != 'en'
    for key, expected in format_keys.items()
    if key in catalog and args(catalog[key]) != expected
]
print('English formatted keys:', len(format_keys), 'mismatched pairs:', len(mismatches))
for locale, key in sorted(mismatches):
    print(locale, key)
PY
```
