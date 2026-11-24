#ifndef ED25519_SHA2_H
#define ED25519_SHA2_H

/* Standard Ed25519 (SHA-512), orlp/ed25519 API with the ed25519_sha2_ prefix.
 * Built from the sources in orlp/ in this package.
 * private_key is the 64-byte expanded key: clamped scalar | nonce prefix. */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef ED25519_NO_SEED
/** Fills seed with 32 bytes from the platform CSPRNG. Returns 0. */
int ed25519_sha2_create_seed(unsigned char *seed);
#endif

void ed25519_sha2_create_keypair(unsigned char *public_key, unsigned char *private_key, const unsigned char *seed);
/** Public key of the 32-byte clamped scalar at private_key (nothing is written to it). */
void ed25519_sha2_derive_keypair(unsigned char *public_key, unsigned char *private_key);
void ed25519_sha2_sign(unsigned char *signature, const unsigned char *message, size_t message_len, const unsigned char *public_key, const unsigned char *private_key);
int ed25519_sha2_verify(const unsigned char *signature, const unsigned char *message, size_t message_len, const unsigned char *public_key);
void ed25519_sha2_key_exchange(unsigned char *shared_secret, const unsigned char *public_key, const unsigned char *private_key);

#ifdef __cplusplus
}
#endif

#endif
