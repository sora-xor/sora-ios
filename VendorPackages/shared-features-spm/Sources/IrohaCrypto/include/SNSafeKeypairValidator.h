#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SNSafeKeypairValidator : NSObject

+ (BOOL)isValidSr25519SecretKey:(NSData *)secretKey
                      publicKey:(NSData *)publicKey;

+ (nullable NSData *)sr25519SecretKeyFromEd25519:(NSData *)ed25519SecretKey
    NS_SWIFT_NAME(sr25519SecretKey(fromEd25519:));

+ (BOOL)containsForcedPanicForReleaseValidation;

@end

NS_ASSUME_NONNULL_END
