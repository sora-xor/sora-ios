//
//  TemplateData.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 21/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import "AbstractData.h"

/**
 Superclass of MAI data and Unrestricted Data
 */
@interface TemplateData : AbstractData

/**
 Application Identifier (AID) or 'UUID' or 'REVERSE DOMAIN NAME'
 */
@property (retain, nullable) NSString* AID NS_SWIFT_NAME(AID);

@end
