//
//  ValidationUtil.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 23/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Utility class to check if tag is a valid tag.
 */
@interface ValidationUtil : NSObject
/**
 * Checks if tag number is a valid value
 *
 * @param tagString number of tag to check against
 * @return number of tag
 * @throws UnknownTagException if tag number is invalid
 */
+ (BOOL) isValidTagString:(NSString* _Nonnull) tagString error:(NSError*_Nullable *_Nullable) error;

@end
