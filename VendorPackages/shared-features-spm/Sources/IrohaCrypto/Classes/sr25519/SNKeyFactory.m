//
//  SNKeypairFactory.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNKeyFactory.h"
#import "sr25519lib/sr25519.h"

// Zeroes key material on the stack; the volatile stores are not elided.
static void SNKeyFactoryWipe(uint8_t *bytes, size_t length) {
    volatile uint8_t *cursor = bytes;
    while (length > 0) {
        *cursor = 0;
        cursor += 1;
        length -= 1;
    }
}

@implementation SNKeyFactory

- (id<SNKeypairProtocol> _Nullable)createKeypairFromSeed:(nonnull NSData*)seed
                                                   error:(NSError*_Nullable*_Nullable)error {
    if ([seed length] != SR25519_SEED_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid seed length %@ but expected %@",
                                 @([seed length]), @(SR25519_SEED_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNKeyFactoryErrorInvalidSeed
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    uint8_t keypair[SR25519_KEYPAIR_SIZE];

    sr25519_keypair_from_seed(keypair, seed.bytes);

    NSData *keypairData = [NSData dataWithBytes:keypair length:SR25519_KEYPAIR_SIZE];
    SNKeyFactoryWipe(keypair, sizeof(keypair));

    return [[SNKeypair alloc] initWithRawData:keypairData error:error];
}

- (id<SNKeypairProtocol> _Nullable)createKeypairHard:(nonnull SNKeypair*)parent
                                           chaincode:(nonnull NSData*)chaincode
                                               error:(NSError*_Nullable*_Nullable)error {
    if ([chaincode length] != SR25519_CHAINCODE_SIZE) {
        if (error) {
            *error = [[self class] createChainCodeError:[chaincode length]];
        }

        return nil;
    }

    uint8_t pair[SR25519_KEYPAIR_SIZE];

    if (![[self class] copyValidKeypair:parent into:pair error:error]) {
        return nil;
    }

    uint8_t keypair[SR25519_KEYPAIR_SIZE];

    sr25519_derive_keypair_hard(keypair, pair, chaincode.bytes);
    SNKeyFactoryWipe(pair, sizeof(pair));

    NSData *keypairData = [NSData dataWithBytes:keypair length:SR25519_KEYPAIR_SIZE];
    SNKeyFactoryWipe(keypair, sizeof(keypair));

    return [[SNKeypair alloc] initWithRawData:keypairData error:error];
}

- (id<SNKeypairProtocol> _Nullable)createKeypairSoft:(nonnull SNKeypair*)parent
                                           chaincode:(nonnull NSData*)chaincode
                                               error:(NSError*_Nullable*_Nullable)error {
    if ([chaincode length] != SR25519_CHAINCODE_SIZE) {
        if (error) {
            *error = [[self class] createChainCodeError:[chaincode length]];
        }

        return nil;
    }

    uint8_t pair[SR25519_KEYPAIR_SIZE];

    if (![[self class] copyValidKeypair:parent into:pair error:error]) {
        return nil;
    }

    uint8_t keypair[SR25519_KEYPAIR_SIZE];

    sr25519_derive_keypair_soft(keypair, pair, chaincode.bytes);
    SNKeyFactoryWipe(pair, sizeof(pair));

    NSData *keypairData = [NSData dataWithBytes:keypair length:SR25519_KEYPAIR_SIZE];
    SNKeyFactoryWipe(keypair, sizeof(keypair));

    return [[SNKeypair alloc] initWithRawData:keypairData error:error];
}

- (nullable SNPublicKey*)createPublicKeySoft:(nonnull SNPublicKey*)parentPublicKey
                                   chaincode:(nonnull NSData*)chaincode
                                       error:(NSError*_Nullable*_Nullable)error {
    if ([chaincode length] != SR25519_CHAINCODE_SIZE) {
        if (error) {
            *error = [[self class] createChainCodeError:[chaincode length]];
        }

        return nil;
    }

    NSData *parentData = parentPublicKey.rawData;

    if (parentData.length != SR25519_PUBLIC_SIZE || !sr25519_public_key_is_valid(parentData.bytes)) {
        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNKeyFactoryErrorInvalidPublicKey
                                     userInfo:@{NSLocalizedDescriptionKey: @"Provided public key is invalid"}];
        }

        return nil;
    }

    uint8_t publicKeyBytes[SR25519_PUBLIC_SIZE];

    sr25519_derive_public_soft(publicKeyBytes, parentData.bytes, chaincode.bytes);

    NSData *publicKeyData = [NSData dataWithBytes:publicKeyBytes length:SR25519_PUBLIC_SIZE];

    return [[SNPublicKey alloc] initWithRawData:publicKeyData error:error];
}

// Copies [secret | public] of the parent into pair, after checking what the C
// library would otherwise end the process on: a secret scalar that is not
// canonical, a public key that is not a Ristretto point. The same checks as the
// Android JNI layer's read_pair.
+ (BOOL)copyValidKeypair:(nonnull id<SNKeypairProtocol>)parent
                    into:(uint8_t *)pair
                   error:(NSError*_Nullable*_Nullable)error {
    NSData *secretKey = parent.privateKey.rawData;
    NSData *publicKey = parent.publicKey.rawData;

    if (secretKey.length != SR25519_SECRET_SIZE ||
        publicKey.length != SR25519_PUBLIC_SIZE ||
        !sr25519_secret_is_valid(secretKey.bytes) ||
        !sr25519_public_key_is_valid(publicKey.bytes)) {
        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:SNKeyFactoryErrorInvalidKeypair
                                     userInfo:@{NSLocalizedDescriptionKey: @"Provided pair is invalid"}];
        }

        return NO;
    }

    memcpy(pair, secretKey.bytes, SR25519_SECRET_SIZE);
    memcpy(pair + SR25519_SECRET_SIZE, publicKey.bytes, SR25519_PUBLIC_SIZE);

    return YES;
}

+ (nonnull NSError*)createChainCodeError:(NSUInteger)actualSize {
    NSString *message = [NSString stringWithFormat:@"Invalid chaincode length %@ but expected %@",
                         @(actualSize), @(SR25519_CHAINCODE_SIZE)];
    return [NSError errorWithDomain:NSStringFromClass([self class])
                               code:SNKeyFactoryErrorInvalidChaincode
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

@end
