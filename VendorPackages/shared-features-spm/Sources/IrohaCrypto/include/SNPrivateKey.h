//
//  SNPrivateKey.h
//  IrohaCrypto
//
//  Created by Ruslan Rezin on 23.06.2020.
//

#import <Foundation/Foundation.h>
#import "IRCryptoKey.h"

@interface SNPrivateKey : NSObject<IRPrivateKeyProtocol>

/// The secret from its Ed25519 representation. Fails, instead of returning a key
/// that cannot sign, when the scalar divided by the cofactor is not canonical.
- (nullable instancetype)initWithFromEd25519:(nonnull NSData*)data
                                       error:(NSError*_Nullable*_Nullable)error;

/// The secret in its Ed25519 representation (`toEd25519Data() throws` in Swift).
/// Fails when the stored scalar is not canonical.
- (nullable NSData*)toEd25519DataAndReturnError:(NSError*_Nullable*_Nullable)error;

@end
