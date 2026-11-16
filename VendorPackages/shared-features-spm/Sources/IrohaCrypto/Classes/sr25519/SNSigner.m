//
//  SNSigner.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNSigner.h"
#import "sr25519lib/sr25519.h"

@interface SNSigner()

@property(strong, nonatomic)_Nonnull id<SNKeypairProtocol> keypair;

@end

@implementation SNSigner

- (nonnull instancetype)initWithKeypair:(id<SNKeypairProtocol> _Nonnull)keypair {
    if (self = [super init]) {
        self.keypair = keypair;
    }

    return self;
}

- (nullable SNSignature*)sign:(nonnull NSData*)originalData
                              error:(NSError*_Nullable*_Nullable)error {
    NSData *secretKey = _keypair.privateKey.rawData;
    NSData *publicKey = _keypair.publicKey.rawData;

    // sr25519_sign ends the process on key material that is not valid (a
    // non-canonical secret scalar, a public key that is not a Ristretto point),
    // as the Rust library's panic did. Check it first and return an error, as
    // the Android JNI layer does.
    NSString *invalid = nil;
    if (secretKey.length != SR25519_SECRET_SIZE || !sr25519_secret_is_valid(secretKey.bytes)) {
        invalid = @"Provided private key is invalid";
    } else if (publicKey.length != SR25519_PUBLIC_SIZE || !sr25519_public_key_is_valid(publicKey.bytes)) {
        invalid = @"Provided public key is invalid";
    }

    if (invalid) {
        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRSignatureErrorSignerFailed
                                     userInfo:@{NSLocalizedDescriptionKey: invalid}];
        }

        return nil;
    }

    uint8_t signatureBytes[SR25519_SIGNATURE_SIZE];

    sr25519_sign(signatureBytes,
                 publicKey.bytes,
                 secretKey.bytes,
                 originalData.bytes,
                 originalData.length);

    NSData *signatureData = [NSData dataWithBytes:signatureBytes length:SR25519_SIGNATURE_SIZE];

    return [[SNSignature alloc] initWithRawData:signatureData error:error];;
}

@end
