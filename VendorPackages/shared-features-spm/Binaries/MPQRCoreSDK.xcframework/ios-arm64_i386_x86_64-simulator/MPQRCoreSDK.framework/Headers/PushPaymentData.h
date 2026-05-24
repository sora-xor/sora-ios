//
//  PushPaymentData.h
//  ErrorObjCinSwift
//
//  Created by MasterCard on 14/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import "AbstractData.h"

@class MAIData;
@class AdditionalData;
@class LanguageData;
@class UnrestrictedData;
@class MasterCardData;
@class MPQRError;
/**
 Class that contain the main data of MPQR
 */
@interface PushPaymentData : AbstractData

//MARK: - Instance methods
/**
 Generate the push payment string with new CRC checksum.
 The existing CRC field will be replaced by the new CRC checksum.
 
 @return  Generated string with CRC.
 
 @note The string is generated with ordered tags, it's not following the original order. This method is **mutating** i.e it will mutate the CRC tag.
 */
- (NSString* _Nullable) generatePushPaymentString:(NSError*_Nullable*_Nullable) error;

/**
 Get value with luhn checksum appended with the string representation of underlying value related to the tag.
 
 @param tag Tag info for which to generate value with luhn checksum
 
 @return Value with luhn checksum appended
 
 @note This is usually used for merchant id fields
 
 @note Throws: `MPQRError.invalidFormat` exception
 - If the value doesn't exist for the tag
 - If the format of the underlying value is not valid for generating the checksum
 */
- (NSString* _Nullable) valueWithLuhnChecksum:(TagInfo* _Nonnull) tag error:(NSError*_Nullable *_Nullable) error  NS_SWIFT_NAME(valueWithLuhnChecksum(_:));

/**
 Check if this data represents is dynamic
 @return `true` if dynamic, `false` otherwise
 */
- (BOOL) isDynamic;

// MARK: - Convenience Accessors
/**
 Payload format indicator
 */
@property (retain, nullable) NSString* payloadFormatIndicator;

/**
 Point of initiation method
 */
@property (retain, nullable) NSString*  pointOfInitiationMethod;

/**
 Merchant identifier Visa with tag `02`
 */
@property (retain, nullable) NSString*  merchantIdentifierVisa02;

/**
 Merchant identifier Visa with tag `03`
 */
@property (retain, nullable) NSString*  merchantIdentifierVisa03;

/**
 Merchant identifier MasterCard with tag `04`
 */
@property (retain, nullable) NSString*  merchantIdentifierMastercard04;

/**
 Merchant identifier tag 06 is reserved by EMVCo. For Bharat QR standard in India, this tag is currently defined by NCPI
 */
@property (retain, nullable) NSString*  merchantIdentifierNPCI06;

/**
 Merchant identifier with tag 07 is reserved by EMVCo. For Bharat QR standard in India, this tag is currently defined by NPCI
 */
@property (retain, nullable) NSString*  merchantIdentifierNPCI07;

/**
 Merchant identifier with tag 08 is reserved by EMVCo
 */
@property(retain, nullable) NSString* merchantIdentifierIFSCCODE08;
/**
 Merchant identifier (Discover)
 */
@property(retain, nullable) NSString* merchantIdentifierDISCOVER09;
/**
 Merchant identifier (Discover)
 */
@property(retain, nullable) NSString* merchantIdentifierDISCOVER10;
/**
 Merchant identifier (Amex)
 */
@property(retain, nullable) NSString* merchantIdentifierAMEX11;
/**
 Merchant identifier (Amex)
 */
@property(retain, nullable) NSString* merchantIdentifierAMEX12;
/**
 Merchant identifier (JCB)
 */
@property(retain, nullable) NSString* merchantIdentifierJCB13;
/**
 Merchant identifier (JCB)
 */
@property(retain, nullable) NSString* merchantIdentifierJCB14;
/**
 Merchant identifier (UnionPay)
 */
@property(retain, nullable) NSString* merchantIdentifierUNIONPAY15;
/**
 Merchant identifier (UnionPay)
 */
@property(retain, nullable) NSString* merchantIdentifierUNIONPAY16;

/*
 Get EMVCO data for some tag
 It will return 2 types of Error if tag is not valid:
    - Conflicting tag -> If tag is not in range 26 to 51, because EMVCO data tag is in that range
 If tag is valid, it will return either there is data or no data stored
 */
- (NSString* _Nullable) getMerchantIdentifierEMVCODataForTagString:(NSString* _Nonnull) tagString error:(NSError*_Nullable*_Nullable) error;

/*
 Set EMVCO data for some tag
 It will return 2 types of Error if tag is not valid and return false:
     - Invalid Value -> If the value is null
     - Conflicting tag -> If tag is not in range 26 to 51, because EMVCO tag is in that range
 If tag is valid, it will set the data and return true
 */
- (BOOL) setMerchantIdentifierEMVCODataForTagString:(NSString* _Nonnull) tagString data:(NSString* _Nonnull) data error:(NSError*_Nullable*_Nullable) error;

/**
 Get MAIData for some tag
 
 @param tagString Tag to get the value
 
 @return The value if it is available
 */
- (MAIData* _Nullable) getMAIDataForTagString:(NSString* _Nonnull) tagString error:(NSError*_Nullable*_Nullable) error;

/**
 Set MAIData tag for some tag. In case the tag need to be specified in certain tag, this function is used instead. For example, we want to set MAID to specific tag 28.
 
 @param tagString Tag to be set
 @param data The value to be set
 */
- (BOOL) setMAIDataForTagString:(NSString* _Nonnull) tagString data:(MAIData* _Nonnull) data error:(NSError*_Nullable*_Nullable) error;

/**
 Merchant Category Code: MCC as defined by ISO 18245
 */
@property (retain, nullable) NSString*  merchantCategoryCode;

/**
 Transaction Currency Code: As defined by ISO 4217
 */
@property (retain, nullable) NSString*  transactionCurrencyCode;

/**
 Transaction amount
 
 This amount is expressed as how the value appears.
 
 Defines the regex to validate amount with max length 13 chars with following rules
     - amount “100.00” is defined as “100.00”, or
     - amount “99.85” is defined as “99.85”, or
     - amount “99.333” is defined as “99.333”, or
     - amount “99.3456” is defined as “99.3456”
 */
@property (retain, nullable) NSString*  transactionAmount;

/**
 Tip or convenience indicator
     - 01 : Indicates Consumer should be prompted to enter tip
     - 02 : Indicates that merchant would mandatorily charge a flat convenience fee
     - 03 : Indicates that merchant would charge a percentage convenience fee
 */
@property (retain, nullable) NSString*  tipOrConvenienceIndicator;

/**
 Value of convenience fee fixed.
 
 The convenience fee of a fixed amount should be specified here. This amount is expressed as how the value appears.
 
 Defines the regex to validate amount with max length 13 chars with following rules
     - amount “100.00” is defined as “100.00”, or
     - amount “99.85” is defined as “99.85”, or
     - amount “99.333” is defined as “99.333”
     - amount “99.3456” is defined as “99.3456”
 */
@property (retain, nullable) NSString*  valueOfConvenienceFeeFixed;

/**
 Value of convenience fee percentage.
 
 The Convenience Fee Percentage is specified as whole integers between 00.01 (for 00.01%) to 99.99 (99.99%). E.g. 11.95
 */
@property (retain, nullable) NSString*  valueOfConvenienceFeePercentage;

/**
 Country Code: As defined by ISO 3166.
 */
@property (retain, nullable) NSString*  countryCode;

/**
 "Merchant Name: Should always be the “doing business as” name for the merchant.
 */
@property (retain, nullable) NSString*  merchantName;

/**
 Merchant city
 */
@property (retain, nullable) NSString*  merchantCity;

/**
 Postal code: Zip code or Pin code or Postal code of merchant
 */
@property (retain, nullable) NSString*  postalCode;

/**
Array of errors coming up during validating PushPaymentData object while parsing
 */
@property (nonatomic, nullable) NSArray<MPQRError *>*  validationErrors;

/**
 Additional Data Field: Additional information beyond basic may be required in certain cases. This information may be either presented by the merchant or acquirer or the Consumer may be prompted for entry on the app. For consumer prompt, the value field of Tag would be 3 asterisks i.e. ***. The acquirer / merchant should provide only minimum information in order to avoid making the size of data onerous. The length of each tag is variable up to 26 characters and overall it is not to exceed the maximum of 99 characters for the total size of the Additional Data Field.
 */
@property (retain, nullable) AdditionalData*  additionalData;

/**
 Language data, It will have:
    - mandatory tag 00,
    - mandatory Merchant Name tag 01,
    - optional Merchant City tag 02.
 */
@property (retain, nullable) LanguageData*  languageData;

/**
 Mastercard data field: Tag 05 is reserved for Mastercard Use. It has Subtags ranging from 01 to 99.
    - Sub Tag 01 is Alias,
    - Sub Tag 02 is MAID,
    - Sub Tag 03 is PFID,
    - Sub Tag 04 is Merchant Specific Alias,
    - Sub Tags 05-99 are reserved for future use.
 */
@property (retain, nullable) MasterCardData*  masterCardData;

/**
 CRC calculated to ISO/IEC 3309 compliant 16 bit CRC which includes all the preceding TLV objects till the Tag and length value of CRC i.e. A904. CRC would be the last TLV object.
 */
@property (retain, nullable) NSString*  crc;

/**
 Get Unreserved Unrestricted Data for some tag
 
 @param tagString Tag to get the value
 
 @return The value if it is available
 */
- (UnrestrictedData* _Nullable) getUnreservedDataForTagString:(NSString* _Nonnull) tagString error:(NSError*_Nullable*_Nullable) error;

/**
 Set Unreserved Unrestricted Data for some tag
 
 @param tagString Tag to be set
 @param data The value to be set
 */
- (BOOL) setUnreservedDataForTagString:(NSString* _Nonnull) tagString data:(UnrestrictedData* _Nonnull) data error:(NSError*_Nullable*_Nullable) error;

/**
 Set MAI Data for some tag without specifying the tag, the tag will be automatically assign. This function will set MAID data for tag 26 to 51 automatically given MAID data, starting from lowest tag to highest tag.
 For example,  first call of this function will assign data to tag 26. Second call of this function will assign data to tag 27, and so on.
 
 @note If the tags are all taken, it will throw error as data cannot be set

 @param value The value to be set
 */
- (BOOL) setDynamicMAIDTag:(MAIData* _Nonnull) value error:(NSError* _Nullable *_Nullable) error;

/**
 Set Unrestricted Data for some tag without specifying the tag, the tag will be automatically assign. This function will set UnrestrictedData data for tag 80 to 99 automatically given UnrestrictedData data, starting from lowest tag to highest tag.
 For example,  first call of this function will assign data to tag 80. Second call of this function will assign data to tag 81, and so on.
 
 @note If the tags are all taken, it will throw error as data cannot be set
 
 @param value The value to be set
 */
- (BOOL) setDynamicUnrestrictedTag:(UnrestrictedData* _Nonnull) value error:(NSError* _Nullable *_Nullable) error;


//MARK: - Validation
/**
 Validate merchant fields
 
 Atleast `1` field related to merchant identifiers should exist.
 
 @note Throws: `MPQRError.missingTag` exception if the none of the merchant tags is found
 */
- (BOOL) validateMerchantIdentifiers:(NSError*_Nullable *_Nullable) error;

/**
 Validate tip fields
 
 Logic for validation is as following:
 1. If the `tipIndicator` tag `PPTag.TAG_55_TIP_INDICATOR` does not exist then tip fields are *valid*
 
 2. If the `tipIndicator` is `TipConvenienceIndicator.promptedToEnterTip` then it
 - Must **NOT** have `PPTag.TAG_56_CONVENIENCE_FEE_FIXED` else it throws `MPQRError.conflictingTag`
 - Must **NOT** have `PPTag.TAG_57_CONVENIENCE_FEE_PERCENTAGE` else it throws `MPQRError.conflictingTag`
 
 3. If the `tipIndicator` is `TipConvenienceIndicator.flatConvenienceFee` then it
 - **MUST** have `PPTag.TAG_56_CONVENIENCE_FEE_FIXED` else it throws `MPQRError.missingTag`
 - Must **NOT** have `PPTag.TAG_57_CONVENIENCE_FEE_PERCENTAGE` else it throws `MPQRError.conflictingTag`
 
 4. If the `tipIndicator` is `TipConvenienceIndicator.percentageConvenienceFee` then it
 - **MUST** have `PPTag.TAG_57_CONVENIENCE_FEE_PERCENTAGE` else it throws `MPQRError.missingTag`
 - Must **NOT** have `PPTag.TAG_56_CONVENIENCE_FEE_FIXED` else it throws `MPQRError.conflictingTag`
 
 5. Else tip fields are valid
 
 @note Throws:
 - `MPQRError.conflictingTag` exception if the tags are conflicting.
 - `MPQRError.missingTag` exception if the required tag is missing.
 */
- (BOOL) validateTipFields:(NSError* _Nullable *_Nullable) error;

/**
 Validate price fields
 
 Logic for validation is as following:
 1. If `transactionAmount` is **not** present and `isDynamic` returns true then tag `PPTag.TAG_54_TRANSACTION_AMOUNT` is missing and it throws `MPQRError.missingTag` exception
 
 2. If `transactionAmount` **is** present and `isDynamic` returns false then tag `PPTag.TAG_54_TRANSACTION_AMOUNT` is conflicting and it throws `MPQRError.conflictingTag` exception
 
 3. Else price fields are valid
 
 @note Throws:
 - `MPQRError.conflictingTag` exception if the tags are conflicting.
 - `MPQRError.missingTag` exception if the required tag is missing.
 */
- (BOOL) validatePriceField:(NSError* _Nullable *_Nullable) error;

@end

