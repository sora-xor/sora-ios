//
//  IRSignatureCreator.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import "EDSigner.h"
#import "EDSignature.h"
#import "EDPrivateKey.h"
#import "EDPublicKey.h"
#import "libed25519/ed25519_sha2.h"

@interface EDSigner()

@property(strong, nonatomic)_Nonnull id<IRPrivateKeyProtocol> privateKey;

@end

@implementation EDSigner

- (nonnull instancetype)initWithPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey {
    if (self = [super init]) {
        self.privateKey = privateKey;
    }

    return self;
}

- (nullable EDSignature *)sign:(nonnull NSData*)originalData error:(NSError*_Nullable*_Nullable)error {
    NSUInteger privateKeyLength = [EDPrivateKey length];
    unsigned char rawPrivateKey[privateKeyLength];

    NSUInteger publicKeyLength = [EDPublicKey length];
    unsigned char rawPublicKey[publicKeyLength];

    memcpy(rawPrivateKey, _privateKey.rawData.bytes, privateKeyLength);

    ed25519_sha2_derive_keypair(rawPublicKey, rawPrivateKey);

    NSUInteger signatureLength = [EDSignature length];
    unsigned char signature[signatureLength];

    ed25519_sha2_sign(signature, originalData.bytes, originalData.length, rawPublicKey, rawPrivateKey);

    NSData *signatureData = [[NSData alloc] initWithBytes:signature
                                                   length:signatureLength];


    return [[EDSignature alloc] initWithRawData:signatureData error:error];
}

@end
