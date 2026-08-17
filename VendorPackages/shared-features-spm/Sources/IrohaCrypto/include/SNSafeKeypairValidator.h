#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SNSafeKeypairValidator : NSObject

+ (BOOL)isValidSr25519SecretKey:(NSData *)secretKey
                      publicKey:(NSData *)publicKey;

+ (BOOL)containsForcedPanicForReleaseValidation;

@end

NS_ASSUME_NONNULL_END
