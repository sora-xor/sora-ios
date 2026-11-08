# blake2lib

BLAKE2b and BLAKE2s, built from source. Replaces the prebuilt
`blake2lib.xcframework`.

- Upstream: https://github.com/mjosaarinen/blake2_mjosref, commit
  `3491779dbf2465596b3db121701922cf7a9fd0a2` — the RFC 7693 reference code by
  Markku-Juhani O. Saarinen. License: CC0 1.0 (`LICENSE`).
- Files: `blake2b.c`, `blake2s.c`, `include/blake2lib/blake2b.h`,
  `include/blake2lib/blake2s.h`, unchanged. The old framework's headers were
  byte-identical to these.
- Compatibility: `../../Tests/CryptoCompatibility` compares every output with
  the old prebuilt library.
