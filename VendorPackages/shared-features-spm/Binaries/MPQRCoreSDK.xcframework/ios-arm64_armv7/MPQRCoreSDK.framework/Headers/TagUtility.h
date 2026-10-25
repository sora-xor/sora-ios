//
//  TagUtility.h
//  ErrorObjCinSwift
//
//  Created by MasterCard on 14/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol Tag;
@class TagInfo;

/**
    Utility class to retrieve `TagInfo` given a tag in string format.
 */
@interface TagUtility : NSObject

/**
 Return tagInfo for tag with provided string and of provided type
 
 @param string String to search for
 @param type Type of the tagInfo
 @note Throws: `MPQRError.unknownTag` if tag cannot be found
 */
+ (TagInfo* _Nullable) tagInfoFrom:(NSString* _Nullable) string of:(Class<Tag> _Nullable) type error:(NSError*_Nullable *_Nullable) error;


@end

