//
//  MAIData.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 21/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import "TemplateData.h"

/**
  MAIData class is used to store Merchant Account Information of Push Payment Data (tags 26-51).
 
  @note To assign Application Identifier (tag 00), use AID property from TemplateData class.
 */
@interface MAIData : TemplateData

// MARK: - Convenient Accessor
/**
 Get Payment Network Specific value for tag string. The tags are from 1 to 99.
 
 @param tag NSString* tag for which to get value
 
 @return Value if found else `nil`
 */
- (NSString* _Nullable) getPaymentNetworkSpecificForTag:(NSString* _Nonnull) tag error:(NSError*_Nullable*_Nullable) error;

/**
 Set Payment Network Specific value for tag string. The tags are from 1 to 99.
 
 @param value NSString* to set
 @param tag NSString* tag to set the value of
 */
- (BOOL) setPaymentNetworkSpecific:(NSString* _Nonnull) value forTag:(NSString* _Nonnull) tag error:(NSError*_Nullable*_Nullable) error;

/**
 Set Payment Network Specific value for tag string. This method is similar to (setPaymentNetworkSpecific:error:). In this method user do not specify the tag, the function will determine the tag. The tags are from 1 to 99.
 
 @param value NSString* to be inserted
 */
- (BOOL) setDynamicPaymentNetworkSpecific:(NSString* _Nonnull) value error:(NSError* _Nullable *_Nullable) error;

/**
 Get Payment Network Specific all available tag. The return value can then be use to get the value by calling method (getTagInfoValueForTagString:error:). The tags are from 1 to 99.
 
 @return NSArray of available tag in string
 */
- (NSArray<NSString*>* _Nullable) getAllDynamicPaymentNetworkSpecificTags;

@end
