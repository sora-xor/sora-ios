//
//  MasterCardData.h
//  MPQRCoreSDK
//
//  Created by Tejashree Waghmare on 29/04/21.
//  Copyright © 2021 Muchamad Chozinul Amri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AbstractData.h"

NS_ASSUME_NONNULL_BEGIN

@interface MasterCardData : AbstractData
/**
 Alias
 */
@property (retain,nullable) NSString* alias;
/**
 MAID
 */
@property (retain,nullable) NSString* MAID;
/**
 PFID or Payment Facilitator ID
 */
@property (retain,nullable) NSString* PFID;
/**
 Market Specific Alias
 */
@property (retain,nullable) NSString* marketSpecificAlias;

- (BOOL) setValue:(NSString* _Nonnull) value forTag:(NSString* _Nonnull) tag error:(NSError*_Nullable*_Nullable) error;
@end

NS_ASSUME_NONNULL_END
