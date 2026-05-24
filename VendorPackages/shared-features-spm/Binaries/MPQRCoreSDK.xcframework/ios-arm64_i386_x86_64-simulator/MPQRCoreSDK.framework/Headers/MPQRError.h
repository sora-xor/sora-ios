//
//  MPQRError.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 12/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MPQRErrorConstant.h"


@class TagInfo;

/**
 MPQRError will be thrown if there are any error during parsing or generating QRCode
 */
@interface MPQRError : NSError

/**
 MPQRError have property errorType, the errorType type is the MPQRErrorCode enum
 */
@property MPQRErrorCode errorType;

/**
 Static method that return a MPQR Object given error type, message or description, tag(s), and tag value.
 */
+ (id _Nonnull) errorWithType:(MPQRErrorCode) type str:(NSString* _Nullable) str tag:(TagInfo* _Nullable) tag tags:(NSArray<TagInfo*>* _Nullable) tags value:(NSString* _Nullable) value;

/**
 Static method that return a MPQR Object given error type, message or description, tag(s), and tag value, and RootTag.
 */
+ (id _Nonnull) errorWithType:(MPQRErrorCode) type str:(NSString* _Nullable) str tag:(TagInfo* _Nullable) tag tags:(NSArray<TagInfo*>* _Nullable) tags value:(NSString* _Nullable) value rootTag:(NSString* _Nullable) rootTag;

/**
 Return tag information of the error.
 */
- (TagInfo* _Nullable) getTag;

/**
 Return string description of the error.
 */
- (NSString* _Nullable) getString;

/**
 Return a list of tags of the error.
 */
- (NSArray<TagInfo*>* _Nullable) getTags;

/**
 Return the value of the error.
 */
- (NSString* _Nullable) getValue;

/**
 Return string root-tag of the error.
 */
- (NSString* _Nullable) getRootTag;

@end

