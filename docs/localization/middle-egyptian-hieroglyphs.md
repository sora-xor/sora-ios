# Middle Egyptian hieroglyphic localization policy

The `egy` locale uses Classical Middle Egyptian written with Unicode
Egyptian Hieroglyphs. It is a product localization, not a claim that modern
wallet terminology occurs in an ancient inscription.

## Bundle identifier and retained selections

The bundle uses `egy.lproj`, the ISO 639-2 identifier for Ancient Egyptian.
Apple's language-ID guidance permits this three-letter code, and Foundation
recognizes `egy` with the inferred `Egyp` script. The previous `egy-Egyp.lproj`
name produced an App Store localization warning. The shorter identifier keeps
the hieroglyphic writing system, fonts, and “Middle Egyptian (Hieroglyphic)” picker
option. The two copy updates described below separately synchronize earlier
English changes.

The app's shared localization manager converts a saved `egy-Egyp` selection to
`egy` before any UI consumer reads it, and persists the normalized selection
through the existing settings manager. Other saved languages are unchanged.
The alias is retained in code for upgrades; do not ship a duplicate
`egy-Egyp.lproj` directory. If `egy` resources are absent, the normalization
leaves the existing preference untouched.

Run the focused packaging and actual Foundation/localization-manager regression
checks with `python3 SoraPassport/Scripts/test-egyptian-localization.py`.
These local checks do not substitute for Apple's validation of a future archive.
The packaging repair preserves the existing plural and InfoPlist resources.
Two translation values are updated to match earlier English copy changes; the
other 950 Egyptian entries remain unchanged. The generator
fully validates the translated catalog and separately checks the English
catalog's explicitly declared UX fallback section. Every fallback key must be
its own literal English value; empty keys, duplicates, and moving an existing
Egyptian translation into fallback are rejected. New UX text continues to use
the existing English fallback without generating unreviewed Egyptian prose.

References:

- [Apple: Language and Locale IDs](https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPInternational/LanguageandLocaleIDs/LanguageandLocaleIDs.html)
- [Library of Congress: ISO 639-2 `egy`](https://www.loc.gov/standards/iso639-2/php/langcodes_name.php?code_ID=127)

## Language and writing

- Grammar and vocabulary follow Middle Egyptian, the classical language of the
  Middle Kingdom and of much later monumental writing.
- Text runs left to right. Every sign therefore faces the start of the line.
- Words use normalized, phonemically explicit spellings made from established
  hieroglyphic phonograms. A small number of familiar classifiers and logograms
  may be used where they remove ambiguity.
- Signs are laid out linearly with ordinary spaces. Unicode hieroglyph-format
  controls are deliberately excluded because the wallet still supports systems
  whose shaping engines predate them.
- Vowels are not invented. Egyptian hieroglyphic writing records consonants,
  and the UI does not present Egyptological convenience pronunciations as if
  they were ancient evidence.
- Concise imperatives and nominal phrases are preferred over word-for-word
  English syntax. Security warnings preserve every condition, quantity, and
  consequence even when their imagery is recast.

## Semantic compounds

There is no historically attested Middle Egyptian vocabulary for blockchains,
smartphones, or automated market makers. Those concepts use stable, transparent
compounds of attested ancient words. They are poetic neologisms, and must not be
cited as ancient phrases.

| Modern concept | Transliteration | Hieroglyphic spelling | Semantic image |
| --- | --- | --- | --- |
| Egyptian language | `mdw n Kmt` | `𓌃𓂧𓅱𓀁 𓈖 𓆎𓅓𓏏𓊖` | speech of Kemet |
| wallet | `pr ḥḏ` | `𓊪𓂋 𓎛𓆓` | house of silver |
| account | `ḥsb` | `𓎛𓋴𓃀` | reckoning |
| network | `jꜣdt nt wꜣwt` | `𓇋𓄿𓂧𓏏 𓈖𓏏 𓅱𓄿𓅱𓏏` | net of roads |
| node | `sbꜣ n jꜣdt` | `𓋴𓃀𓄿 𓈖 𓇋𓄿𓂧𓏏` | gate of the net |
| transaction | `jrt swnt` | `𓇋𓂋𓏏 𓋴𓅱𓈖𓏏` | act of exchange |
| hash / cryptographic proof | `ḫtm` | `𓐍𓏏𓅓` | seal |
| block | `ḏbt` | `𓆓𓃀𓏏` | brick |
| blockchain | `ṯs n ḏbwt` | `𓍿𓋴 𓈖 𓆓𓃀𓅱𓏏` | binding of bricks |
| backup | `šꜥt snnw` | `𓈙𓂝𓏏 𓋴𓈖𓈖𓅱` | second document |
| password | `mdw n wn` | `𓅓𓂧𓅱 𓈖 𓅱𓈖` | word for opening |
| passphrase | `ṯs mdw` | `𓍿𓋴 𓅓𓂧𓅱` | binding of words |
| raw seed | `prt štꜣ` | `𓊪𓂋𓏏 𓈙𓏏𓄿` | secret seed |
| liquidity | `mw ḥḏ` | `𓅓𓅱 𓎛𓆓` | waters of silver |
| liquidity pool | `š n mw` | `𓈙 𓈖 𓅓𓅱` | lake of waters |
| decentralized | `nn nb wꜥ` | `𓈖𓈖 𓈖𓃀 𓅱𓂝` | without one lord |
| email | `šꜥt nt pt` | `𓈙𓂝𓏏 𓈖𓏏 𓊪𓏏` | document of the sky |
| mobile device | `mḏꜣt nt ꜥ` | `𓅓𓆓𓄿𓏏 𓈖𓏏 𓂝` | scroll of the hand |
| vote | `rḏj ḫrw` | `𓂋𓆓𓇋 𓐍𓂋𓅱` | give voice |
| asset / token | `jḫt` | `𓇋𓐍𓏏` | property / thing |
| price | `jsw` | `𓇋𓋴𓅱` | value |
| fee | `bꜣkw` | `𓃀𓄿𓎡𓅱` | levy / pay |

Names, ticker symbols, protocol identifiers, standards, formulae, addresses,
and recovery data remain literal whenever translating them could make a wallet
operation unsafe or ambiguous. This includes SORA, Polkaswap, XOR, VAL, ETH,
ADAR, KUSD, QR, PIN, IBAN, JSON, URL, SMS, APR, LP, DeFi, AMM, DEX, TBC, XYK,
Substrate, Polkadot, Kusama, Ethereum, Google, Telegram, and `x*y=k`.

## Implementation safeguards

- `SoraPassport/Scripts/generate-middle-egyptian-localization.py` derives the
  catalog from the translated section of the English key set and fails on
  missing keys, format-token drift, or unprotected Latin prose. Unrecognized
  modern terms remain in its explicit review queue.
- Noto Sans Egyptian Hieroglyphs 2.002 is bundled as the fallback behind the
  normal Sora UI typeface. The generator pins the font and its shipped SIL Open
  Font License by SHA-256.
- Date-pattern syntax, format placeholders, protocol identifiers, and recovery
  material are display data rather than Egyptian prose and are kept intact.

## Reviewed import and onboarding copy

`import.account.message` distinguishes retained recovery words from an exported
private seed, and limits the Google choice to a previously saved Google backup.
Its final negative instruction makes that restriction explicit: without a Google
backup, do not choose Google. `onboarding.description` describes sending,
receiving, and swapping, and distinguishes creating a new recovery phrase from
importing an existing one. The generator binds both clauses to exact English
source values; later English edits require their translations to be reviewed.

These use the existing product glossary, including its modern Google-backup
compound. The negative imperative `m` and “choose” `stp` are documented by the
[Thesaurus Linguae Aegyptiae, lemma 64410](https://thesaurus-linguae-aegyptiae.de/lemma/64410)
and [lemma 148070](https://thesaurus-linguae-aegyptiae.de/lemma/148070).
These lexical references do not certify the modern product phrasing.

## Review boundary

“Complete” means every key in the translated catalog has an Egyptian value and
every format token matches the English source. The explicitly declared UX
fallback section remains English. This does not make unattested modern
compounds into attested ancient expressions. A publishing release should still
receive review by an Egyptologist who works directly with Middle Egyptian.

Primary references:

- Unicode, *Egyptian Hieroglyphs* character chart and sign annotations:
  <https://www.unicode.org/charts/PDF/U13000.pdf>
- Unicode Technical Note 32, *Unicode Egyptian Hieroglyphs: Mapping Manuel de
  Codage*: <https://www.unicode.org/notes/tn32/>
- Noto Sans Egyptian Hieroglyphs, release and source:
  <https://github.com/notofonts/egyptian-hieroglyphs>
- UCL Digital Egypt, *The System of Egyptian Hieroglyphic Writing*:
  <https://www.ucl.ac.uk/museums-static/digitalegypt/writing/system.html>
- UCL Digital Egypt, *Egyptian language: historical development*:
  <https://www.ucl.ac.uk/museums-static/digitalegypt/literature/language/development.html>
- Thesaurus Linguae Aegyptiae: `jḫt` “thing/property”
  (<https://thesaurus-linguae-aegyptiae.de/lemma/30750>), `bꜣkw`
  “taxes/pay” (<https://thesaurus-linguae-aegyptiae.de/lemma/53890>), `swnt`
  “trade/price” (<https://thesaurus-linguae-aegyptiae.de/lemma/130160>), and
  `ḏbt` “brick/ingot” (<https://thesaurus-linguae-aegyptiae.de/lemma/183120>).
- A. H. Gardiner, *Egyptian Grammar*, third edition, sign list and vocabulary.
- R. O. Faulkner, *A Concise Dictionary of Middle Egyptian*.
