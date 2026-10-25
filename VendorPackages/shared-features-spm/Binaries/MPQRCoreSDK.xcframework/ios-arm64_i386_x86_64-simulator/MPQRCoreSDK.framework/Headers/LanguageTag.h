//
//  LanguageTag.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 21/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Tag.h"

/**
 Tag to store language tag associated with LanguadeData
 */
@interface LanguageTag : NSObject<Tag>

/**
 Language Preferences: As defined by ISO639, should represent language used to encode TAGS 01-02
 */
@property(class,nonnull,readonly) TagInfo*  TAG_00_LANGUAGE_PREFERANCE NS_SWIFT_NAME(TAG_00_LANGUAGE_PREFERANCE);
/**
 Alternate Merchant Name: Should be the “doing business as” name for the merchant in merchant's local language.
 */
@property(class,nonnull,readonly) TagInfo* TAG_01_ALTERNATE_MERCHANT_NAME NS_SWIFT_NAME(TAG_01_ALTERNATE_MERCHANT_NAME);
/**
 Alternate Merchant City: Should be the city in which the merchant transacts in the merchant’s local language.
 */
@property(class,nonnull,readonly) TagInfo* TAG_02_ALTERNATE_MERCHANT_CITY NS_SWIFT_NAME(TAG_02_ALTERNATE_MERCHANT_CITY);

/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_03_RFU NS_SWIFT_NAME(TAG_03_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_04_RFU NS_SWIFT_NAME(TAG_04_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_05_RFU NS_SWIFT_NAME(TAG_05_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_06_RFU NS_SWIFT_NAME(TAG_06_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_07_RFU NS_SWIFT_NAME(TAG_07_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_08_RFU NS_SWIFT_NAME(TAG_08_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_09_RFU NS_SWIFT_NAME(TAG_09_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_10_RFU NS_SWIFT_NAME(TAG_10_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_11_RFU NS_SWIFT_NAME(TAG_11_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_12_RFU NS_SWIFT_NAME(TAG_12_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_13_RFU NS_SWIFT_NAME(TAG_13_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_14_RFU NS_SWIFT_NAME(TAG_14_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_15_RFU NS_SWIFT_NAME(TAG_15_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_16_RFU NS_SWIFT_NAME(TAG_16_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_17_RFU NS_SWIFT_NAME(TAG_17_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_18_RFU NS_SWIFT_NAME(TAG_18_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_19_RFU NS_SWIFT_NAME(TAG_19_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_20_RFU NS_SWIFT_NAME(TAG_20_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_21_RFU NS_SWIFT_NAME(TAG_21_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_22_RFU NS_SWIFT_NAME(TAG_22_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_23_RFU NS_SWIFT_NAME(TAG_23_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_24_RFU NS_SWIFT_NAME(TAG_24_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_25_RFU NS_SWIFT_NAME(TAG_25_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_26_RFU NS_SWIFT_NAME(TAG_26_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_27_RFU NS_SWIFT_NAME(TAG_27_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_28_RFU NS_SWIFT_NAME(TAG_28_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_29_RFU NS_SWIFT_NAME(TAG_29_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_30_RFU NS_SWIFT_NAME(TAG_30_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_31_RFU NS_SWIFT_NAME(TAG_31_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_32_RFU NS_SWIFT_NAME(TAG_32_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_33_RFU NS_SWIFT_NAME(TAG_33_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_34_RFU NS_SWIFT_NAME(TAG_34_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_35_RFU NS_SWIFT_NAME(TAG_35_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_36_RFU NS_SWIFT_NAME(TAG_36_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_37_RFU NS_SWIFT_NAME(TAG_37_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_38_RFU NS_SWIFT_NAME(TAG_38_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_39_RFU NS_SWIFT_NAME(TAG_39_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_40_RFU NS_SWIFT_NAME(TAG_40_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_41_RFU NS_SWIFT_NAME(TAG_41_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_42_RFU NS_SWIFT_NAME(TAG_42_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_43_RFU NS_SWIFT_NAME(TAG_43_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_44_RFU NS_SWIFT_NAME(TAG_44_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_45_RFU NS_SWIFT_NAME(TAG_45_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_46_RFU NS_SWIFT_NAME(TAG_46_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_47_RFU NS_SWIFT_NAME(TAG_47_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_48_RFU NS_SWIFT_NAME(TAG_48_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_49_RFU NS_SWIFT_NAME(TAG_49_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_50_RFU NS_SWIFT_NAME(TAG_50_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_51_RFU NS_SWIFT_NAME(TAG_51_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_52_RFU NS_SWIFT_NAME(TAG_52_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_53_RFU NS_SWIFT_NAME(TAG_53_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_54_RFU NS_SWIFT_NAME(TAG_54_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_55_RFU NS_SWIFT_NAME(TAG_55_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_56_RFU NS_SWIFT_NAME(TAG_56_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_57_RFU NS_SWIFT_NAME(TAG_57_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_58_RFU NS_SWIFT_NAME(TAG_58_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_59_RFU NS_SWIFT_NAME(TAG_59_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_60_RFU NS_SWIFT_NAME(TAG_60_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_61_RFU NS_SWIFT_NAME(TAG_61_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_62_RFU NS_SWIFT_NAME(TAG_62_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_63_RFU NS_SWIFT_NAME(TAG_63_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_64_RFU NS_SWIFT_NAME(TAG_64_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_65_RFU NS_SWIFT_NAME(TAG_65_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_66_RFU NS_SWIFT_NAME(TAG_66_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_67_RFU NS_SWIFT_NAME(TAG_67_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_68_RFU NS_SWIFT_NAME(TAG_68_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_69_RFU NS_SWIFT_NAME(TAG_69_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_70_RFU NS_SWIFT_NAME(TAG_70_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_71_RFU NS_SWIFT_NAME(TAG_71_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_72_RFU NS_SWIFT_NAME(TAG_72_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_73_RFU NS_SWIFT_NAME(TAG_73_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_74_RFU NS_SWIFT_NAME(TAG_74_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_75_RFU NS_SWIFT_NAME(TAG_75_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_76_RFU NS_SWIFT_NAME(TAG_76_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_77_RFU NS_SWIFT_NAME(TAG_77_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_78_RFU NS_SWIFT_NAME(TAG_78_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_79_RFU NS_SWIFT_NAME(TAG_79_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_80_RFU NS_SWIFT_NAME(TAG_80_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_81_RFU NS_SWIFT_NAME(TAG_81_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_82_RFU NS_SWIFT_NAME(TAG_82_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_83_RFU NS_SWIFT_NAME(TAG_83_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_84_RFU NS_SWIFT_NAME(TAG_84_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_85_RFU NS_SWIFT_NAME(TAG_85_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_86_RFU NS_SWIFT_NAME(TAG_86_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_87_RFU NS_SWIFT_NAME(TAG_87_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_88_RFU NS_SWIFT_NAME(TAG_88_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_89_RFU NS_SWIFT_NAME(TAG_89_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_90_RFU NS_SWIFT_NAME(TAG_90_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_91_RFU NS_SWIFT_NAME(TAG_91_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_92_RFU NS_SWIFT_NAME(TAG_92_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_93_RFU NS_SWIFT_NAME(TAG_93_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_94_RFU NS_SWIFT_NAME(TAG_94_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_95_RFU NS_SWIFT_NAME(TAG_95_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_96_RFU NS_SWIFT_NAME(TAG_96_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_97_RFU NS_SWIFT_NAME(TAG_97_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_98_RFU NS_SWIFT_NAME(TAG_98_RFU);
/**
  Reserved for future use
 */
@property(class,nonnull,readonly) TagInfo* TAG_99_RFU NS_SWIFT_NAME(TAG_99_RFU);
@end
