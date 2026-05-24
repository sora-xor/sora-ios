//
//  ErrorObjCinSwift
//
//  Created by MasterCard on 13/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>
/**
 Category to check if the string is numeric
 */
@interface NSString (NSString_CheckNumber)

/**
 Category to check if the string is numeric, i.e. [0-9]
 @return `true` if it is numeric, `false` otherwise
 */
- (BOOL) isNumber;

@end
