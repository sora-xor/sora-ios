//
//  LanguageData.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 21/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import "AbstractData.h"

/**
 Class to store the language data
 */
@interface LanguageData : AbstractData

/**
 Language Preferences: As defined by ISO639, should represent language used to encode TAGS 01-02
 */
@property (retain,nullable) NSString* languagePreference;

/**
 Alternate Merchant Name: Should be the “doing business as” name for the merchant in merchant's local language.
 */
@property (retain,nullable) NSString* alternateMerchantName;

/**
 Alternate Merchant City: Should be the city in which the merchant transacts in the merchant’s local language.
 */
@property (retain,nullable) NSString* alternateMerchantCity;

@end
