#import "SNSafeKeypairValidator.h"
#import <sora_sr25519_safe_validator.h>

@implementation SNSafeKeypairValidator

+ (BOOL)isValidSr25519SecretKey:(NSData *)secretKey
                      publicKey:(NSData *)publicKey {
    return sora_sr25519_keypair_is_valid(
        secretKey.bytes,
        secretKey.length,
        publicKey.bytes,
        publicKey.length
    );
}

+ (BOOL)containsForcedPanicForReleaseValidation {
    return sora_sr25519_validator_contains_forced_panic();
}

@end
