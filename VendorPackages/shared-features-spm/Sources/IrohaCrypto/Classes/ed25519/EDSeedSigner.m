//
//  EDSeedSigner.m
//  IrohaCrypto
//

#import "EDSeedSigner.h"
#import "EDPublicKey.h"
#import "libed25519/ed25519_sha2.h"

static void EDSeedSignerWipe(unsigned char *bytes, size_t length) {
    volatile unsigned char *cursor = bytes;
    while (length > 0) {
        *cursor = 0;
        cursor += 1;
        length -= 1;
    }
}

@interface EDSeedSigner()

@property(strong, nonatomic) NSMutableData *seed;

@end

@implementation EDSeedSigner

- (nonnull instancetype)initWithSeed:(nonnull NSData *)seed {
    if (self = [super init]) {
        self.seed = [seed mutableCopy];
    }

    return self;
}

- (void)dealloc {
    EDSeedSignerWipe(_seed.mutableBytes, _seed.length);
}

- (nullable EDSignature *)sign:(nonnull NSData *)originalData
                          error:(NSError *_Nullable *_Nullable)error {
    const NSUInteger seedLength = 32;
    if (self.seed.length != seedLength) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Ed25519 seed must be %@ bytes but %@ received",
                                 @(seedLength), @(self.seed.length)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSignatureErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    // libed25519's keypair routine writes SHA-512(seed), including both the
    // clamped scalar and the deterministic nonce prefix consumed by sign().
    unsigned char expandedPrivateKey[64];
    unsigned char rawPublicKey[[EDPublicKey length]];
    ed25519_sha2_create_keypair(
        rawPublicKey,
        expandedPrivateKey,
        self.seed.bytes
    );

    unsigned char rawSignature[[EDSignature length]];
    ed25519_sha2_sign(
        rawSignature,
        originalData.bytes,
        originalData.length,
        rawPublicKey,
        expandedPrivateKey
    );
    EDSeedSignerWipe(expandedPrivateKey, sizeof(expandedPrivateKey));

    NSData *signatureData = [NSData dataWithBytes:rawSignature
                                           length:[EDSignature length]];
    return [[EDSignature alloc] initWithRawData:signatureData error:error];
}

@end
