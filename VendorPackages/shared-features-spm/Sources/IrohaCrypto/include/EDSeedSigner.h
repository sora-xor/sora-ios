//
//  EDSeedSigner.h
//  IrohaCrypto
//

#import <Foundation/Foundation.h>
#import "EDSignature.h"

/// RFC 8032 signer that expands the original 32-byte seed into the complete
/// 64-byte private material required by libed25519 before signing.
@interface EDSeedSigner : NSObject<IRSignatureCreatorProtocol>

- (nonnull instancetype)initWithSeed:(nonnull NSData *)seed NS_DESIGNATED_INITIALIZER;
- (nonnull instancetype)init NS_UNAVAILABLE;
- (nullable EDSignature *)sign:(nonnull NSData *)originalData
                          error:(NSError *_Nullable *_Nullable)error;

@end
