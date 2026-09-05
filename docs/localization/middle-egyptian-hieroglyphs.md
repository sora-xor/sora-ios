# Middle Egyptian hieroglyphic localization policy

The `egy-Egyp` locale uses Classical Middle Egyptian written with Unicode
Egyptian Hieroglyphs. It is a product localization, not a claim that modern
wallet terminology occurs in an ancient inscription.

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
  catalog from the English key set and fails on missing keys, format-token
  drift, unknown modern words, or unprotected Latin prose.
- Noto Sans Egyptian Hieroglyphs 2.002 is bundled as the fallback behind the
  normal Sora UI typeface. The generator pins the font and its shipped SIL Open
  Font License by SHA-256.
- Date-pattern syntax, format placeholders, protocol identifiers, and recovery
  material are display data rather than Egyptian prose and are kept intact.

## Review boundary

“Complete” means every shipped localization key has an Egyptian value and every
format token matches the English source. It does not make unattested modern
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
