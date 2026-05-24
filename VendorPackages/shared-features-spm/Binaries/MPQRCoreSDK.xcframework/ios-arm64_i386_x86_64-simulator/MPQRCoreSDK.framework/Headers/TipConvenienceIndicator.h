//
//  TipConvenienceIndicator.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 12/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Defines possible values for Tip Convenience Indicator
 */
typedef NS_ENUM(NSInteger, TipConvenienceIndicator) {
    /**
     Value is equal to 01
     */
    promptedToEnterTip,
    /**
     Value is equal to 02
     */
    flatConvenienceFee,
    /**
     Value is equal to 03
     */
    percentageConvenienceFee,
    /**
     Mark that this is an error
     */
    unknownTipConvenienceIndicator
};

/**
 Class to access value and set value for enum `TipConvenienceIndicator`
 */
@interface ClassTipConvenienceIndicator : NSObject

/**
 Get the correcponding string value of the tip
 @param inputEnum The enum to get the value
 @return Value of the enum, return unknown if the value is invalid
 */
+ (NSString*) enumValue:(enum TipConvenienceIndicator) inputEnum;

/**
 Get the correcponding enum given a string
 @param input The value of the Tip Convenience Indicator
 @return Corresponding enum value
 */
+ (enum TipConvenienceIndicator) enumFor:(NSString*) input;

@end
