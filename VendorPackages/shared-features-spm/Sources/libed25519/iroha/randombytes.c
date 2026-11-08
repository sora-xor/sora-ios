/* randombytes() for hyperledger/iroha-ed25519 from the platform CSPRNG
 * (arc4random_buf on Apple platforms and Android). Returns ED25519_SUCCESS. */
#include <stdlib.h>
#include <ed25519/ed25519/randombytes.h>
#include <ed25519/ed25519/errcode.h>

ED25519_EXPORT int randombytes(unsigned char *p, int len) {
    if (len < 0) {
        return ED25519_ERROR;
    }
    arc4random_buf(p, (size_t)len);
    return ED25519_SUCCESS;
}
