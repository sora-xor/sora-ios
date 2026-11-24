//
//  SNPrivateKey.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import "SNPrivateKey.h"
#import "sr25519lib/sr25519.h"

// Zeroes key material on the stack; the volatile stores are not elided.
static void SNPrivateKeyWipe(uint8_t *bytes, size_t length) {
    volatile uint8_t *cursor = bytes;
    while (length > 0) {
        *cursor = 0;
        cursor += 1;
        length -= 1;
    }
}

@interface SNPrivateKey()

@property(copy, nonatomic)NSData *rawData;

@end

@implementation SNPrivateKey

- (nullable instancetype)initWithRawData:(nonnull NSData *)data
                                   error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    if ([data length] != SR25519_SECRET_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid raw data length %@ but expected %@",
                                 @([data length]), @(SR25519_SECRET_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    self = [super init];

    if (self) {
        self.rawData = data;
    }

    return self;
}

- (nullable instancetype)initWithFromEd25519:(nonnull NSData*)data
                                       error:(NSError*_Nullable*_Nullable)error {
    if ([data length] != SR25519_SECRET_SIZE) {
        if (error) {
            NSString *message = [NSString stringWithFormat:@"Invalid raw data length %@ but expected %@",
                                 @([data length]), @(SR25519_SECRET_SIZE)];
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }

        return nil;
    }

    uint8_t secret_out[SR25519_SECRET_SIZE];
    sr25519_from_ed25519_bytes(secret_out, data.bytes);

    // A scalar that is not canonical after the division by the cofactor is no
    // usable key: signing with it would end the process. schnorrkel 0.11
    // rejects it here; 0.9, which the C function follows, returned it. Only
    // imports of supplied material (keystore JSON) come through here; stored
    // wallets are read with initWithRawData:, which is unchanged.
    if (!sr25519_secret_is_valid(secret_out)) {
        SNPrivateKeyWipe(secret_out, sizeof(secret_out));

        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: @"Provided private key is invalid"}];
        }

        return nil;
    }

    if (self = [super init]) {
        self.rawData = [NSData dataWithBytes:secret_out length:SR25519_SECRET_SIZE];
    }

    SNPrivateKeyWipe(secret_out, sizeof(secret_out));

    return self;
}

- (nullable NSData*)toEd25519DataAndReturnError:(NSError*_Nullable*_Nullable)error {
    // sr25519_to_ed25519_bytes ends the process on a scalar that is not
    // canonical; report an error instead.
    if (_rawData.length != SR25519_SECRET_SIZE || !sr25519_secret_is_valid(_rawData.bytes)) {
        if (error) {
            *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                         code:IRCryptoKeyErrorInvalidRawData
                                     userInfo:@{NSLocalizedDescriptionKey: @"Provided private key is invalid"}];
        }

        return nil;
    }

    uint8_t secret_out[SR25519_SECRET_SIZE];
    sr25519_to_ed25519_bytes(secret_out, _rawData.bytes);

    NSData *result = [NSData dataWithBytes:secret_out length:SR25519_SECRET_SIZE];
    SNPrivateKeyWipe(secret_out, sizeof(secret_out));

    return result;
}

@end
