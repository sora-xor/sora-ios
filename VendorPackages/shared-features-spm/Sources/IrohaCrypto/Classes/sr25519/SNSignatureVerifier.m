//
//  SNSignatureVerifier.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNSignatureVerifier.h"
#import "sr25519lib/sr25519.h"

@implementation SNSignatureVerifier

- (BOOL)verify:(nonnull SNSignature*)signature
forOriginalData:(nonnull NSData*)originalData
usingPublicKey:(nonnull SNPublicKey*)publicKey {
    NSData *signatureData = signature.rawData;
    NSData *publicKeyData = publicKey.rawData;

    // sr25519_verify reads 64 and 32 bytes and returns false for a malformed
    // signature or a public key that is not a Ristretto point.
    if (signatureData.length != SR25519_SIGNATURE_SIZE || publicKeyData.length != SR25519_PUBLIC_SIZE) {
        return NO;
    }

    return sr25519_verify(signatureData.bytes,
                          originalData.bytes,
                          originalData.length,
                          publicKeyData.bytes);
}

@end
