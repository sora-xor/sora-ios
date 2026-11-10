/* Replaces orlp/ed25519's seed.c: the seed comes from the platform CSPRNG
 * (arc4random_buf on Apple platforms and Android) instead of /dev/urandom.
 * Altered from the original; see LICENSE. */
#include <stdlib.h>
#include "ed25519.h"

#ifndef ED25519_NO_SEED
int ed25519_sha2_create_seed(unsigned char *seed) {
    arc4random_buf(seed, 32);
    return 0;
}
#endif
