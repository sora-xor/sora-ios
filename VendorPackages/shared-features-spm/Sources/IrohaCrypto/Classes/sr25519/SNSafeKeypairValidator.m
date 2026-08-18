#import "SNSafeKeypairValidator.h"
#import <sora_sr25519_safe_validator.h>

@implementation SNSafeKeypairValidator

static const NSUInteger SNSr25519SecretKeyLength = 64;

+ (BOOL)isValidSr25519SecretKey:(NSData *)secretKey
                      publicKey:(NSData *)publicKey {
    return sora_sr25519_keypair_is_valid(
        secretKey.bytes,
        secretKey.length,
        publicKey.bytes,
        publicKey.length
    );
}

+ (nullable NSData *)sr25519SecretKeyFromEd25519:(NSData *)ed25519SecretKey {
    NSMutableData *convertedSecret = [NSMutableData dataWithLength:SNSr25519SecretKeyLength];
    BOOL didConvert = sora_sr25519_secret_from_ed25519(
        ed25519SecretKey.bytes,
        ed25519SecretKey.length,
        convertedSecret.mutableBytes,
        convertedSecret.length
    );

    return didConvert ? [convertedSecret copy] : nil;
}

+ (BOOL)containsForcedPanicForReleaseValidation {
    return sora_sr25519_validator_contains_forced_panic();
}

@end
