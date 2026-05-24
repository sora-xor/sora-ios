//
//  TLV.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 12/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TagInfo;

/**
 Object derived from tag-length-value string of data object in scanned QR string.
 */
@interface TLV : NSObject

/**
 The tag information
 */
@property(nonnull,readonly) TagInfo* tagInfo;

/**
 The length of the value between 0 to 99
 */
@property(readonly) NSInteger length;

/**
 The value of the tag
 */
@property(nonnull,readonly) NSString* value;

/**
 Initializer
 @param tag The tag information, non null
 @param length The length of the value
 @param value The value of the tag, non null
 */
- (id _Nonnull) initWithTagInfo:(TagInfo* _Nonnull) tag length:(NSInteger) length value:(NSString* _Nonnull) value;

@end
