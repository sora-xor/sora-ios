# Crypto compatibility

`run.sh` builds `harness.c` and `kat.c` against the in-repo `blake2lib`,
`libed25519` and `sr25519lib` sources and checks them against what the
prebuilt libraries they replaced produced.

- `expected.txt` holds the SHA-256 of 69,000 deterministic outputs from
  3,000 seeded cases, and of 2,000 `sr25519_from_ed25519_bytes` results. They
  were recorded from the old xcframeworks running in an iOS simulator. Both
  the 64-bit and 32-bit (`ED25519_FORCE_32BIT`) arithmetic must reproduce them.
  - sr25519: keypairs, hard, soft and chained derivation, conversions
  - Ed25519 SHA-512: keys, signatures, verification
  - Iroha Ed25519 SHA3-512: public keys, signatures, verification
  - BLAKE2b/2s: one-shot and streamed
- `old-binary-signatures.txt` holds 300 sr25519 signatures made by the old
  library. sr25519 signatures are randomized, so they are checked by
  verification, not by comparison.
- When the libraries were swapped, every one of the old library's 3,000
  signatures verified with the new code, and every new signature verified
  with the old library.
- `kat.c` covers the RFC 9496 ristretto255 encodings (valid and invalid) and
  the Substrate `//Alice` and `//Bob` keys. It also checks that verify()
  rejects a missing marker bit, another message or another key.
