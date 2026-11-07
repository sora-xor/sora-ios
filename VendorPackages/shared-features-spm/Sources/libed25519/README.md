# libed25519

Ed25519 in two flavours, built from source. Replaces the prebuilt
`libed25519.xcframework`, with the same functions and symbol names.

## `ed25519_sha2_*`: standard Ed25519 (SHA-512)

- Upstream: https://github.com/orlp/ed25519, commit
  `b1f19fab4aebe607805620d25a5e42566ce46a0e` (Orson Peters). License: zlib
  (`orlp/LICENSE`).
- Altered as the zlib license requires us to mark:
  - The functions are renamed `ed25519_*` → `ed25519_sha2_*` and SHA-512
    `sha512*` → `sha2_512*`, the names the old binary exported.
  - `seed.c` is replaced: the seed comes from `arc4random_buf`.
  - `derive_keypair.c` is new. It makes the public key from the 32-byte
    scalar, as the old binary did.
  - `add_scalar.c` and the Windows code are left out.

## `ed25519_*` and `sha256`/`sha512`: Iroha v1 Ed25519 (SHA3-512)

- Upstream: https://github.com/hyperledger/iroha-ed25519, commit
  `4c4de7b6df64e6b5e14dfe2ed515c60a8ad2612e`. License: Apache-2.0
  (`iroha/LICENSE`).
- `iroha/ref10` holds the SUPERCOP ref10 code and the API. `iroha/sha3` holds
  Andrey Jivsov's public-domain SHA-3. As upstream, `sha256`/`sha512` are
  **SHA3**-256/512; `NSData+SHA3` in IrohaCrypto calls them.
- `iroha/randombytes.c` is new: `randombytes` uses `arc4random_buf`.

## Compatibility

`../../Tests/CryptoCompatibility` checks that every function returns the same
bytes as the old prebuilt library: keys, signatures, verification results and
hashes.
