//
//  AdditionalData.h
//  ErrorObjCinSwift
//
//  Created by MasterCard on 14/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import "AbstractData.h"

@class UnrestrictedData;

/**
 Additional Data Field: Additional information beyond basic may be required in certain cases. This information may be either presented by the merchant or acquirer or the Consumer may be prompted for entry on the app. For consumer prompt, the value field of Tag would be 3 asterisks i.e. ***.
 */
@interface AdditionalData : AbstractData

// MARK: - Convenient Accessor

/**
 Invoice number or bill number
 */
@property (retain,nullable) NSString* billNumber;

/**
 Mobile number: To be used for top-up or bill payment
 */
@property (retain,nullable) NSString* mobileNumber;

/**
 A distinctive number associated to a Store
 */
@property (retain,nullable) NSString* storeId;

/**
 Typically a loyalty card number as provided by store or airline
 */
@property (retain,nullable) NSString* loyaltyNumber;

/**
 Any value as defined by merchant or acquirer in order to identify the transaction
 */
@property (retain,nullable) NSString* referenceId;

/**
 Typically a subscriber ID for subscription services or student enrollment number etc.
 */
@property (retain,nullable) NSString* consumerId;

/**
 A distinctive number associated to a Terminal in the store
 */
@property (retain,nullable) NSString* terminalId;

/**
 Any value as defined by the merchant or acquirer in order to define the purpose of the transaction
 */
@property (retain,nullable) NSString* purpose;

/**
Additional information to prompt consumer for; 'A' for Address, 'E' for email and 'M' for consumer mobile.
 */
@property (retain,nullable) NSString* additionalConsumerDataRequest;

/**
 The tax identification number of the merchant.
 */
@property (retain,nullable) NSString* merchantTaxId;

/**
 A three character value that corresponds to the method used to present the QR code by the merchant including: display method, transaction location and merchant presence.
 */
@property (retain,nullable) NSString* merchantChannel;

// MARK: Convenient Accessor for Tag 50 to 99
/**
 Get Unreserved Data value for tag string. The tag are from 50 to 99.
 
 @param tag NSString* tag for which to get value
 
 @return Value if found else `nil`
 */
- (UnrestrictedData* _Nullable) getUnreservedDataForSubTag:(NSString* _Nonnull) tag error:(NSError*_Nullable*_Nullable) error;

/**
 Set Unreserved Data value for tag string. The tag are from 50 to 99.
 
 @param value NSString* to set
 @param tag NSString* tag to set the value of
 */
- (BOOL) setUnreservedData:(UnrestrictedData* _Nonnull) value forTag:(NSString* _Nonnull) tag error:(NSError*_Nullable*_Nullable) error;

/**
 Store value at any empty tag in dynamically allocatable range. This function is available on additional data class of tag 62. The function will set the sub-tag 50 to 99 automatically, starting from lowest sub-tag to highest sub-tag.
 
 @param value the value to assign
 @return updated AdditionalData
 @note Throws
    - UnknownTagException when the tag number is invalid
    - LimitException when all tags in range are already filled
 */
- (BOOL) setDynamicTag:(UnrestrictedData* _Nonnull) value error:(NSError* _Nullable *_Nullable) error;


/**
 Get UnrestrictedData of all available tag. The return value can then be use to get the value by calling method (getTagInfoValueForTagString:error:). The tags are from 50 to 99.
 
 @return NSArray of available tag in string
 */
- (NSArray<NSString*>* _Nullable) getAllDynamicTags;

@end

