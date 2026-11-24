#ifndef PROJECT_ED25519_HPP_
#define PROJECT_ED25519_HPP_

/* Iroha v1 Ed25519 (SHA3-512), hyperledger/iroha-ed25519 API.
 * Built from the sources in iroha/ (ref10 + SHA3) in this package. */

#include "ed25519_export.h"

#if defined(__cplusplus)
extern "C" {
#endif

#define ed25519_pubkey_SIZE 32
#define ed25519_privkey_SIZE 32
#define ed25519_signature_SIZE 64

typedef struct {
  unsigned char data[ed25519_signature_SIZE];
} signature_t;

typedef struct {
  unsigned char data[ed25519_pubkey_SIZE];
} public_key_t;

typedef struct {
  unsigned char data[ed25519_privkey_SIZE];
} private_key_t;

/**
 * Generates a keypair from the platform CSPRNG.
 * @return 0 if failed, non-0 otherwise
 */
ED25519_EXPORT int ed25519_create_keypair(private_key_t *sk, public_key_t *pk);

/** Public key of a 32-byte private key (seed). */
ED25519_EXPORT void ed25519_derive_public_key(const private_key_t *sk, public_key_t *pk);

/** Deterministic signature of msg with {pk, sk}. */
ED25519_EXPORT void ed25519_sign(signature_t *sig, const unsigned char *msg,
                                 unsigned long long msglen, const public_key_t *pk,
                                 const private_key_t *sk);

/** @return 1 if the signature is valid, 0 otherwise */
ED25519_EXPORT int ed25519_verify(const signature_t *sig, const unsigned char *msg,
                                  unsigned long long msglen, const public_key_t *pk);

#if defined(__cplusplus)
}
#endif

#endif  /* PROJECT_ED25519_HPP_ */
