//
//  PPTag.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 12/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Tag.h"

/**
 Tag class that associate with PushPaymentData
 */
@interface PPTag : NSObject<Tag>

// MARK: - Tags
/**
 Payload format indicator
 */
@property(class,nonnull,readonly) TagInfo* TAG_00_PAYLOAD_FORMAT_INDICATOR NS_SWIFT_NAME(TAG_00_PAYLOAD_FORMAT_INDICATOR);
/**
 Point of initiation method
 */
@property(class,nonnull,readonly) TagInfo* TAG_01_POINT_INITIATION_METHOD NS_SWIFT_NAME(TAG_01_POINT_INITIATION_METHOD);
/**
 Tag to be followed by length and data as defined by (Visa)
 */
@property(class,nonnull,readonly) TagInfo* TAG_02_MERCHANT_IDENTIFIER_VISA NS_SWIFT_NAME(TAG_02_MERCHANT_IDENTIFIER_VISA);
/**
 Tag to be followed by length and data as defined by (Visa)
 */
@property(class,nonnull,readonly) TagInfo* TAG_03_MERCHANT_IDENTIFIER_VISA NS_SWIFT_NAME(TAG_03_MERCHANT_IDENTIFIER_VISA);
/**
 Tag to be followed by length and data as defined by (Mastercard)
 */
@property(class,nonnull,readonly) TagInfo* TAG_04_MERCHANT_IDENTIFIER_MASTERCARD NS_SWIFT_NAME(TAG_04_MERCHANT_IDENTIFIER_MASTERCARD);
/**
 Tag to be followed by length and data as defined by (Mastercard)
 */
@property(class,nonnull,readonly) TagInfo* TAG_05_MASTERCARD_DATA NS_SWIFT_NAME(TAG_05_MASTERCARD_DATA);
/**
 Tag 06 is reserved by EMVCo. For Bharat QR standard in India, this tag is currently defined by NCPI
 */
@property(class,nonnull,readonly) TagInfo* TAG_06_MERCHANT_IDENTIFIER_NPCI NS_SWIFT_NAME(TAG_06_MERCHANT_IDENTIFIER_NPCI);
/**
 Tag 07 is reserved by EMVCo. For Bharat QR standard in India, this tag is currently defined by NPCI
 */
@property(class,nonnull,readonly) TagInfo* TAG_07_MERCHANT_IDENTIFIER_NPCI NS_SWIFT_NAME(TAG_07_MERCHANT_IDENTIFIER_NPCI);
/**
 Tag 08 is reserved by EMVCo
 */
@property(class,nonnull,readonly) TagInfo* TAG_08_MERCHANT_IDENTIFIER_IFSCCODE NS_SWIFT_NAME(TAG_08_MERCHANT_IDENTIFIER_IFSCCODE);
/**
 Tag to be followed by length and data (Discover)
 */
@property(class,nonnull,readonly) TagInfo* TAG_09_MERCHANT_IDENTIFIER_DISCOVER NS_SWIFT_NAME(TAG_09_MERCHANT_IDENTIFIER_DISCOVER);
/**
 Tag to be followed by length and data (Discover)
 */
@property(class,nonnull,readonly) TagInfo* TAG_10_MERCHANT_IDENTIFIER_DISCOVER NS_SWIFT_NAME(TAG_10_MERCHANT_IDENTIFIER_DISCOVER);
/**
 Tag to be followed by length and data (Amex)
 */
@property(class,nonnull,readonly) TagInfo* TAG_11_MERCHANT_IDENTIFIER_AMEX NS_SWIFT_NAME(TAG_11_MERCHANT_IDENTIFIER_AMEX);
/**
 Tag to be followed by length and data (Amex)
 */
@property(class,nonnull,readonly) TagInfo* TAG_12_MERCHANT_IDENTIFIER_AMEX NS_SWIFT_NAME(TAG_12_MERCHANT_IDENTIFIER_AMEX);
/**
 Tag to be followed by length and data (JCB)
 */
@property(class,nonnull,readonly) TagInfo* TAG_13_MERCHANT_IDENTIFIER_JCB NS_SWIFT_NAME(TAG_13_MERCHANT_IDENTIFIER_JCB);
/**
 Tag to be followed by length and data (JCB)
 */
@property(class,nonnull,readonly) TagInfo* TAG_14_MERCHANT_IDENTIFIER_JCB NS_SWIFT_NAME(TAG_14_MERCHANT_IDENTIFIER_JCB);
/**
 Tag to be followed by length and data (UnionPay)
 */
@property(class,nonnull,readonly) TagInfo* TAG_15_MERCHANT_IDENTIFIER_UNIONPAY NS_SWIFT_NAME(TAG_15_MERCHANT_IDENTIFIER_UNIONPAY);
/**
 Tag to be followed by length and data (UnionPay)
 */
@property(class,nonnull,readonly) TagInfo* TAG_16_MERCHANT_IDENTIFIER_UNIONPAY NS_SWIFT_NAME(TAG_16_MERCHANT_IDENTIFIER_UNIONPAY);
/**
 Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_17_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_17_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_18_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_18_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_19_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_19_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_20_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_20_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_21_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_21_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_22_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_22_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_23_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_23_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_24_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_24_MERCHANT_IDENTIFIER_EMVCO);
/**
Tag to be followed by length and data (EMVCo)
 */
@property(class,nonnull,readonly) TagInfo* TAG_25_MERCHANT_IDENTIFIER_EMVCO NS_SWIFT_NAME(TAG_25_MERCHANT_IDENTIFIER_EMVCO);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_26_MAI_TEMPLATE NS_SWIFT_NAME(TAG_26_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_27_MAI_TEMPLATE NS_SWIFT_NAME(TAG_27_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_28_MAI_TEMPLATE NS_SWIFT_NAME(TAG_28_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_29_MAI_TEMPLATE NS_SWIFT_NAME(TAG_29_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_30_MAI_TEMPLATE NS_SWIFT_NAME(TAG_30_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_31_MAI_TEMPLATE NS_SWIFT_NAME(TAG_31_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_32_MAI_TEMPLATE NS_SWIFT_NAME(TAG_32_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_33_MAI_TEMPLATE NS_SWIFT_NAME(TAG_33_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_34_MAI_TEMPLATE NS_SWIFT_NAME(TAG_34_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_35_MAI_TEMPLATE NS_SWIFT_NAME(TAG_35_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_36_MAI_TEMPLATE NS_SWIFT_NAME(TAG_36_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_37_MAI_TEMPLATE NS_SWIFT_NAME(TAG_37_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_38_MAI_TEMPLATE NS_SWIFT_NAME(TAG_38_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_39_MAI_TEMPLATE NS_SWIFT_NAME(TAG_39_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_40_MAI_TEMPLATE NS_SWIFT_NAME(TAG_40_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_41_MAI_TEMPLATE NS_SWIFT_NAME(TAG_41_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_42_MAI_TEMPLATE NS_SWIFT_NAME(TAG_42_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_43_MAI_TEMPLATE NS_SWIFT_NAME(TAG_43_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_44_MAI_TEMPLATE NS_SWIFT_NAME(TAG_44_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_45_MAI_TEMPLATE NS_SWIFT_NAME(TAG_45_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_46_MAI_TEMPLATE NS_SWIFT_NAME(TAG_46_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_47_MAI_TEMPLATE NS_SWIFT_NAME(TAG_47_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_48_MAI_TEMPLATE NS_SWIFT_NAME(TAG_48_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_49_MAI_TEMPLATE NS_SWIFT_NAME(TAG_49_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_50_MAI_TEMPLATE NS_SWIFT_NAME(TAG_50_MAI_TEMPLATE);
/**
 Tag for MAI (Merchant Account Information)
 */
@property(class,nonnull,readonly) TagInfo* TAG_51_MAI_TEMPLATE NS_SWIFT_NAME(TAG_51_MAI_TEMPLATE);
/**
 Merchant Category Code: MCC as defined by ISO 18245
 */
@property(class,nonnull,readonly) TagInfo* TAG_52_MERCHANT_CATEGORY_CODE NS_SWIFT_NAME(TAG_52_MERCHANT_CATEGORY_CODE);
/**
 Transaction Currency Code: As defined by ISO 4217
 */
@property(class,nonnull,readonly) TagInfo* TAG_53_TRANSACTION_CURRENCY_CODE NS_SWIFT_NAME(TAG_53_TRANSACTION_CURRENCY_CODE);
/**
 Transaction amount
 
 This amount is expressed as how the value appears.
 
 Defines the regex to validate amount with max length 13 chars with following rules
    - amount “100.00” is defined as “100.00”, or
    - amount “99.85” is defined as “99.85”, or
    - amount “99.333” is defined as “99.333”, or
    - amount “99.3456” is defined as “99.3456”
 */
@property(class,nonnull,readonly) TagInfo* TAG_54_TRANSACTION_AMOUNT NS_SWIFT_NAME(TAG_54_TRANSACTION_AMOUNT);
/**
 Tip or convenience indicator
    - 01 : Indicates Consumer should be prompted to enter tip
    - 02 : Indicates that merchant would mandatorily charge a flat convenience fee
    - 03 : Indicates that merchant would charge a percentage convenience fee
 */
@property(class,nonnull,readonly) TagInfo* TAG_55_TIP_INDICATOR NS_SWIFT_NAME(TAG_55_TIP_INDICATOR);

/**
 Value of convenience fee fixed.
 
 The convenience fee of a fixed amount should be specified here. This amount is expressed as how the value appears.
 
 Defines the regex to validate amount with max length 13 chars with following rules
    - amount “100.00” is defined as “100.00”, or
    - amount “99.85” is defined as “99.85”, or
    - amount “99.333” is defined as “99.333”
    - amount “99.3456” is defined as “99.3456”
 */
@property(class,nonnull,readonly) TagInfo* TAG_56_CONVENIENCE_FEE_FIXED NS_SWIFT_NAME(TAG_56_CONVENIENCE_FEE_FIXED);

/**
 Value of convenience fee percentage.
 
 The Convenience Fee Percentage is specified as whole integers between 00.01 (for 00.01%) to 99.99 (99.99%). E.g. 11.95
 */
@property(class,nonnull,readonly) TagInfo* TAG_57_CONVENIENCE_FEE_PERCENTAGE NS_SWIFT_NAME(TAG_57_CONVENIENCE_FEE_PERCENTAGE);
/**
 Country Code: As defined by ISO 3166.
 */
@property(class,nonnull,readonly) TagInfo* TAG_58_COUNTRY_CODE NS_SWIFT_NAME(TAG_58_COUNTRY_CODE);
/**
 "Merchant Name: Should always be the “doing business as” name for the merchant.
 */
@property(class,nonnull,readonly) TagInfo* TAG_59_MERCHANT_NAME NS_SWIFT_NAME(TAG_59_MERCHANT_NAME);
/**
 Merchant City
 */
@property(class,nonnull,readonly) TagInfo* TAG_60_MERCHANT_CITY NS_SWIFT_NAME(TAG_60_MERCHANT_CITY);
/**
 Postal code: Zip code or Pin code or Postal code of merchant
 */
@property(class,nonnull,readonly) TagInfo* TAG_61_POSTAL_CODE NS_SWIFT_NAME(TAG_61_POSTAL_CODE);
/**
 Additional Data Field: Additional information beyond basic may be required in certain cases. This information may be either presented by the merchant or acquirer or the Consumer may be prompted for entry on the app. For consumer prompt, the value field of Tag would be 3 asterisks i.e. ***. The acquirer / merchant should provide only minimum information in order to avoid making the size of data onerous. The length of each tag is variable up to 26 characters and overall it is not to exceed the maximum of 99 characters for the total size of the Additional Data Field.
 */
@property(class,nonnull,readonly) TagInfo* TAG_62_ADDITIONAL_DATA_FIELD NS_SWIFT_NAME(TAG_62_ADDITIONAL_DATA_FIELD);
/**
 CRC calculated to ISO/IEC 3309 compliant 16 bit CRC which includes all the preceding TLV objects till the Tag and length value of CRC i.e. A904. CRC would be the last TLV object.
 */
@property(class,nonnull,readonly) TagInfo* TAG_63_CRC NS_SWIFT_NAME(TAG_63_CRC);


/**
 Language data, It will have:
     - mandatory tag 00,
     - mandatory Merchant Name tag 01,
     - optional Merchant City tag 02.
 */
@property(class,nonnull,readonly) TagInfo* TAG_64_LANGUAGE NS_SWIFT_NAME(TAG_64_LANGUAGE);

/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_65 NS_SWIFT_NAME(TAG_65);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_66 NS_SWIFT_NAME(TAG_66);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_67 NS_SWIFT_NAME(TAG_67);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_68 NS_SWIFT_NAME(TAG_68);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_69 NS_SWIFT_NAME(TAG_69);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_70 NS_SWIFT_NAME(TAG_70);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_71 NS_SWIFT_NAME(TAG_71);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_72 NS_SWIFT_NAME(TAG_72);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_73 NS_SWIFT_NAME(TAG_73);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_74 NS_SWIFT_NAME(TAG_74);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_75 NS_SWIFT_NAME(TAG_75);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_76 NS_SWIFT_NAME(TAG_76);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_77 NS_SWIFT_NAME(TAG_77);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_78 NS_SWIFT_NAME(TAG_78);
/**
 Reserved For Future Use
 */
@property(class,nonnull,readonly) TagInfo* TAG_79 NS_SWIFT_NAME(TAG_79);

/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_80_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_80_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_81_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_81_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_82_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_82_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_83_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_83_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_84_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_84_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_85_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_85_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_86_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_86_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_87_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_87_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_88_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_88_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_89_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_89_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_90_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_90_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_91_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_91_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_92_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_92_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_93_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_93_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_94_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_94_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_95_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_95_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_96_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_96_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_97_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_97_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_98_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_98_UNRESTRICTED_DATA);

/**
 Unrestricted Data: Context Specific Data with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_99_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_99_UNRESTRICTED_DATA);

/**
 All tag that belong to this class
 */
@property (readonly, class, nonnull) NSArray<TagInfo*>* allTags;

/**
 Merchant identifier EMVCO, tag 17 to 25
 */
@property (readonly, class, nonnull) NSArray<TagInfo*>* MerchantIdentifierEMVCOTags NS_SWIFT_NAME(MerchantIdentifierEMVCOTags);

/**
 MAID tag that belong to this class, tag 26 to 51
 */
@property (readonly, class, nonnull) NSArray<TagInfo*>* MAIDataTags NS_SWIFT_NAME(MAIDataTags);

/**
 Unrestricted Data tag that belong to this class, tag 80 to 99
 */
@property (readonly, class, nonnull) NSArray<TagInfo*>* UnreservedDataTags NS_SWIFT_NAME(UnreservedDataTags);

/**
 Get valid tag info given specific tag in string
 @param name tag name in string
 @return TagInfo if the tag is valid and belong to this class
 */
+ (TagInfo* _Nullable) tagFor:(NSString* _Nonnull) name;

@end


