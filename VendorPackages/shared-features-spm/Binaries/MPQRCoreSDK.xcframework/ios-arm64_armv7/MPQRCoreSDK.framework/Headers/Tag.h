//
//  TagInfo.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 12/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Superclass of all tag class
 */
@interface TagInfo : NSObject<NSCopying>

/**
 Tag string
 */
@property (nonnull) NSString* tag;

/**
 Tag regex pattern
 */
@property (nullable) NSString* pattern;
/**
 Tell if this tag is mandatory in protocol
 */
@property BOOL isMandatory;

/**
 Tag name
 */
@property (nonnull) NSString* name;

/**
 * Initializer
 @param tag Tag in string
 @param pattern Regex pattern to check if tag value is correct
 @param isMandatory This tell if the value and tag has to exist in order of the whole data structure to be valid
 */
- (id _Nonnull) initWithTag:(NSString* _Nonnull) tag pattern:(NSString* _Nullable) pattern isMandatory:(BOOL) isMandatory name:(NSString* _Nonnull) name;


@end

@protocol Tag

/**
 All tag that belong to this class
 */
@property (readonly, class, nonnull) NSArray<TagInfo*>* allTags;

/**
 Get valid tag info given specific tag in string
 @param name tag name in string
 @return TagInfo if the tag is valid and belong to this class
 */
+ (TagInfo* _Nullable) tagFor:(NSString* _Nonnull) name;

@end
