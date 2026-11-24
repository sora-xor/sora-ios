//
//  SNKeypairFactory.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import <Foundation/Foundation.h>
#import "SNKeypair.h"

typedef NS_ENUM(NSUInteger, SNKeyFactoryError) {
    SNKeyFactoryErrorInvalidSeed,
    SNKeyFactoryErrorInvalidChaincode,
    /// The parent keypair's secret is not a canonical scalar or its public key
    /// is not a Ristretto point (the C library would end the process).
    SNKeyFactoryErrorInvalidKeypair,
    /// The parent public key is not a Ristretto point.
    SNKeyFactoryErrorInvalidPublicKey
};

@protocol SNKeyFactoryProtocol

- (id<SNKeypairProtocol> _Nullable)createKeypairFromSeed:(NSData* _Nonnull)seed
                                                   error:(NSError*_Nullable*_Nullable)error;

- (id<SNKeypairProtocol> _Nullable)createKeypairHard:(id<SNKeypairProtocol> _Nonnull)parent
                                           chaincode:(nonnull NSData*)chaincode
                                               error:(NSError*_Nullable*_Nullable)error;

- (id<SNKeypairProtocol> _Nullable)createKeypairSoft:(id<SNKeypairProtocol> _Nonnull)parent
                                           chaincode:(nonnull NSData*)chaincode
                                               error:(NSError*_Nullable*_Nullable)error;

- (nullable SNPublicKey*)createPublicKeySoft:(nonnull SNPublicKey*)publicKey
                                   chaincode:(nonnull NSData*)chaincode
                                       error:(NSError*_Nullable*_Nullable)error;

@end

@interface SNKeyFactory : NSObject<SNKeyFactoryProtocol>

@end
