//
//  AdditionalDataTag.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 12/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Tag.h"

/**
 Tags collection for additional data
 */
@interface AdditionalDataTag : NSObject<Tag>

// MARK: - Tags
/**
 Sub Tag 00 of Additional Data
 */
@property(class,nonnull,readonly) TagInfo* TAG_00 NS_SWIFT_NAME(TAG_00);
/**
 Invoice number or bill number
 */
@property(class,nonnull,readonly) TagInfo* TAG_01_BILL_NUMBER NS_SWIFT_NAME(TAG_01_BILL_NUMBER);
/**
 Mobile number: To be used for top-up or bill payment
 */
@property(class,nonnull,readonly) TagInfo* TAG_02_MOBILE_NUMBER NS_SWIFT_NAME(TAG_02_MOBILE_NUMBER);
/**
 A distinctive number associated to a Store
 */
@property(class,nonnull,readonly) TagInfo* TAG_03_STORE_ID NS_SWIFT_NAME(TAG_03_STORE_ID);
/**
 Typically a loyalty card number as provided by store or airline
 */
@property(class,nonnull,readonly) TagInfo* TAG_04_LOYALTY_NUMBER NS_SWIFT_NAME(TAG_04_LOYALTY_NUMBER);
/**
 Any value as defined by merchant or acquirer in order to identify the transaction
 */
@property(class,nonnull,readonly) TagInfo* TAG_05_REFERENCE_ID NS_SWIFT_NAME(TAG_05_REFERENCE_ID);
/**
 Typically a subscriber ID for subscription services or student enrollment number etc.
 */
@property(class,nonnull,readonly) TagInfo* TAG_06_CONSUMER_ID NS_SWIFT_NAME(TAG_06_CONSUMER_ID);
/**
 A distinctive number associated to a Terminal in the store
 */
@property(class,nonnull,readonly) TagInfo* TAG_07_TERMINAL_ID NS_SWIFT_NAME(TAG_07_TERMINAL_ID);
/**
 Any value as defined by the merchant or acquirer in order to define the purpose of the transaction
 */
@property(class,nonnull,readonly) TagInfo* TAG_08_PURPOSE NS_SWIFT_NAME(TAG_08_PURPOSE);
/**
 Additional information to prompt consumer for; 'A' for Address, 'E' for email and 'M' for consumer mobile.
 */
@property(class,nonnull,readonly) TagInfo* TAG_09_ADDITIONAL_CONSUMER_DATA_REQUEST NS_SWIFT_NAME(TAG_09_ADDITIONAL_CONSUMER_DATA_REQUEST);
/**
 The tax identification number of the merchant.
 */
@property(class,nonnull,readonly) TagInfo* TAG_10_MERCHANT_TAX_ID NS_SWIFT_NAME(TAG_10_MERCHANT_TAX_ID);
/**
 A three character value that corresponds to the method used to present the QR code by the merchant including: display method, transaction location and merchant presence.
 */
@property(class,nonnull,readonly) TagInfo* TAG_11_MERCHANT_CHANNEL NS_SWIFT_NAME(TAG_11_MERCHANT_CHANNEL);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_12 NS_SWIFT_NAME(TAG_12);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_13 NS_SWIFT_NAME(TAG_13);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_14 NS_SWIFT_NAME(TAG_14);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_15 NS_SWIFT_NAME(TAG_15);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_16 NS_SWIFT_NAME(TAG_16);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_17 NS_SWIFT_NAME(TAG_17);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_18 NS_SWIFT_NAME(TAG_18);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_19 NS_SWIFT_NAME(TAG_19);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_20 NS_SWIFT_NAME(TAG_20);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_21 NS_SWIFT_NAME(TAG_21);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_22 NS_SWIFT_NAME(TAG_22);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_23 NS_SWIFT_NAME(TAG_23);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_24 NS_SWIFT_NAME(TAG_24);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_25 NS_SWIFT_NAME(TAG_25);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_26 NS_SWIFT_NAME(TAG_26);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_27 NS_SWIFT_NAME(TAG_27);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_28 NS_SWIFT_NAME(TAG_28);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_29 NS_SWIFT_NAME(TAG_29);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_30 NS_SWIFT_NAME(TAG_30);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_31 NS_SWIFT_NAME(TAG_31);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_32 NS_SWIFT_NAME(TAG_32);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_33 NS_SWIFT_NAME(TAG_33);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_34 NS_SWIFT_NAME(TAG_34);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_35 NS_SWIFT_NAME(TAG_35);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_36 NS_SWIFT_NAME(TAG_36);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_37 NS_SWIFT_NAME(TAG_37);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_38 NS_SWIFT_NAME(TAG_38);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_39 NS_SWIFT_NAME(TAG_39);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_40 NS_SWIFT_NAME(TAG_40);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_41 NS_SWIFT_NAME(TAG_41);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_42 NS_SWIFT_NAME(TAG_42);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_43 NS_SWIFT_NAME(TAG_43);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_44 NS_SWIFT_NAME(TAG_44);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_45 NS_SWIFT_NAME(TAG_45);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_46 NS_SWIFT_NAME(TAG_46);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_47 NS_SWIFT_NAME(TAG_47);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_48 NS_SWIFT_NAME(TAG_48);
/**
 Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_49 NS_SWIFT_NAME(TAG_49);

/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_50_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_50_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_51_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_51_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_52_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_52_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_53_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_53_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_54_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_54_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_55_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_55_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_56_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_56_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_57_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_57_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_58_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_58_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_59_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_59_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_60_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_60_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_61_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_61_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_62_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_62_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_63_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_63_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_64_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_64_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_65_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_65_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_66_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_66_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_67_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_67_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_68_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_68_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_69_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_69_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_70_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_70_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_71_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_71_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_72_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_72_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_73_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_73_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_74_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_74_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_75_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_75_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_76_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_76_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_77_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_77_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_78_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_78_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_79_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_79_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_80_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_80_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_81_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_81_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_82_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_82_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_83_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_83_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_84_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_84_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_85_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_85_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_86_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_86_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_87_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_87_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_88_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_88_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_89_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_89_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_90_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_90_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_91_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_91_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_92_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_92_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_93_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_93_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_94_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_94_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_95_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_95_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_96_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_96_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_97_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_97_UNRESTRICTED_DATA);
/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_98_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_98_UNRESTRICTED_DATA);

/**
 Unrestricted Data: Payment System Specific with Global Unique Identifier for Application Identifier AID
 */
@property(class,nonnull,readonly) TagInfo* TAG_99_UNRESTRICTED_DATA NS_SWIFT_NAME(TAG_99_UNRESTRICTED_DATA);

/**
 All tag that belong to this class
 */
@property (readonly, class, nonnull) NSArray<TagInfo*>* allTags;

/**
 Unrestricteddata tag that belong to this class, tag 50 to 99
 */
@property (readonly, class, nonnull) NSArray<TagInfo*>* unrestrictedDataTags;

/**
 Get valid tag info given specific tag in string
 @param name tag name in string
 @return TagInfo if the tag is valid and belong to this class
 */
+ (TagInfo* _Nullable) tagFor:(NSString* _Nonnull) name;

@end
