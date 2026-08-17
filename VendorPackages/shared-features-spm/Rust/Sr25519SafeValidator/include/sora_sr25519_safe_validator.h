#ifndef SORA_SR25519_SAFE_VALIDATOR_H
#define SORA_SR25519_SAFE_VALIDATOR_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

bool sora_sr25519_keypair_is_valid(
    const uint8_t *secret_ptr,
    size_t secret_len,
    const uint8_t *public_ptr,
    size_t public_len
);

bool sora_sr25519_validator_contains_forced_panic(void);

#ifdef __cplusplus
}
#endif

#endif
