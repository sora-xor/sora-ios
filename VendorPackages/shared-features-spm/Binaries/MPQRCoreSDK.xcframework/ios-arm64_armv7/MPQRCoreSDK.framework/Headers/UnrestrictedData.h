//
//  UnrestrictedData.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 21/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import "TemplateData.h"

/**
 This class is to store Unreserved Template Data of Push Payment Data tags 80-99 and to store Unreserved Template Data of Additional Data tags 50-99.
 
 @note To assign Application Identifier (tag 00), use AID property from TemplateData class.
 */
@interface UnrestrictedData : TemplateData


// MARK: - Convenient Accessor
/**
 Get Context Specific Data value for tag string. The tags are from 1 to 99.
 
 @param tag NSString* tag for which to get value.
 
 @return Value if found else `nil`
 */
- (NSString* _Nullable) getContextSpecificDataForTag:(NSString* _Nonnull) tag error:(NSError*_Nullable*_Nullable) error;

/**
 Set Context Specific Data value for tag string. The tags are from 1 to 99.
 
 @param value NSString* to set
 @param tag NSString* tag to set the value of
 */
- (BOOL) setContextSpecificData:(NSString* _Nonnull) value forTag:(NSString* _Nonnull) tag error:(NSError*_Nullable*_Nullable) error;

/**
 Set Context Specific Data value for tag string. This method is similar to (setContextSpecificData:error:). In this method user do not specify the tag, the function will determine the tag. The tags are from 1 to 99.
 
 @param value NSString* to be inserted
 */
- (BOOL) setDynamicContextSpecificData:(NSString* _Nonnull) value error:(NSError* _Nullable *_Nullable) error;

/**
 Get Context Specific Data all available tag. The return value can then be use to get the value by calling method (getTagInfoValueForTagString:error:). The tags are from 1 to 99.
 
 @return NSArray of available tag in string
 */
- (NSArray<NSString*>* _Nullable) getAllDynamicContextSpecificDataTags;


@end
