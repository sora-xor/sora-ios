//
//  IRSignatureCreator.m
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 08/10/2018.
//

#import "EDSigner.h"
#import "EDSignature.h"

@implementation EDSigner

- (nonnull instancetype)initWithPrivateKey:(id<IRPrivateKeyProtocol> _Nonnull)privateKey {
    if (self = [super init]) {
        // Retained for source compatibility only. The historic wrapper stored
        // half of libed25519's expanded key and could not sign memory-safely.
        (void)privateKey;
    }

    return self;
}

- (nullable EDSignature *)sign:(nonnull NSData*)originalData error:(NSError*_Nullable*_Nullable)error {
    (void)originalData;
    if (error) {
        NSString *message = @"Legacy EDSigner is unavailable; use EDSeedSigner with the original seed";
        *error = [NSError errorWithDomain:NSStringFromClass([self class])
                                     code:IRSignatureErrorSignerFailed
                                 userInfo:@{NSLocalizedDescriptionKey: message}];
    }

    return nil;
}

@end
