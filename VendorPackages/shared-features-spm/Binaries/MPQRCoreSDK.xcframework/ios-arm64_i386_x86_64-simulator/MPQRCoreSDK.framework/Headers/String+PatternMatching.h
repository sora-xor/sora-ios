//
//  String+PatternMatching.h
//  ErrorObjCinSwift
//
//  Created by MasterCard on 13/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Category of regex string and check if some string match the regex
 */
@interface NSString (NSString_PatternMatching)

/**
 Regex string that check if some string match the regex
 @param string Other string to be matches to the regex string
 @return `true` if it is match and `false` otherwise
 */
- (BOOL) matchesString:(NSString *) string;


/**
 Regex string that check if some string match the regex with Case Insensitive option
 @param string Other string to be matches to the regex string
 @return `true` if it is match and `false` otherwise
 */
- (BOOL) matchesStringCaseInsensitive:(NSString *) string;

@end

