//
//  ParserValidationErrors.h
//  MPQRCoreSDK
//
//  Created by Tejashree Waghmare on 18/06/19.
//  Copyright © 2019 Muchamad Chozinul Amri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPQRError.h"

NS_ASSUME_NONNULL_BEGIN

@interface ParserValidationErrors : NSObject

/**
 Error come up during validating pushPaymentData will be added to validationErrors
 */
+(void)addValidationError:(MPQRError *)error;

/**
 Array of errors come up during validating pushPaymentData will be added to validationErrors
 */
+(void)addSetOfValidationErrors:(NSArray<MPQRError*>  *)errorSet;

/**
 Returns validationErrors
 */
+(NSArray<MPQRError *> * _Nullable)getAllValidationErrors;

/**
 Clears validationErrors
 */
+(void)clearValidationErrors;

@end

NS_ASSUME_NONNULL_END
