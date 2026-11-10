/* Public key of an Ed25519 (SHA-512) key from its expanded secret scalar.
 * Part of the libed25519 API the app shipped with (not in orlp/ed25519):
 * private_key holds the clamped scalar (the first 32 bytes of SHA-512(seed));
 * only those 32 bytes are read and nothing is written to private_key. */
#include "ed25519.h"
#include "ge.h"

void ed25519_sha2_derive_keypair(unsigned char *public_key, unsigned char *private_key) {
    ge_p3 A;
    ge_scalarmult_base(&A, private_key);
    ge_p3_tobytes(public_key, &A);
}
