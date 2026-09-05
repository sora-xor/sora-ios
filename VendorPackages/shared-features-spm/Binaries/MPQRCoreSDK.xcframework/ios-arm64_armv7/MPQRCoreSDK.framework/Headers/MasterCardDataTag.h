//
//  MasterCardDataTag.h
//  MPQRCoreSDK
//
//  Created by Tejashree Waghmare on 29/04/21.
//  Copyright © 2021 Muchamad Chozinul Amri. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Tag.h"

NS_ASSUME_NONNULL_BEGIN

/**
 Tag class that store tag infomation of MasterCard Reserved Tag
 */
@interface MasterCardDataTag : NSObject<Tag>
/**
 Sub Tag 01 of Mastercard Data Tag used as Alias.
 */
@property(class,nonnull,readonly) TagInfo* TAG_01_ALIAS NS_SWIFT_NAME(TAG_01_ALIAS);
/**
 Sub Tag 02 of Mastercard Data Tag used as MAID.
 */
@property(class,nonnull,readonly) TagInfo* TAG_02_MAID NS_SWIFT_NAME(TAG_02_MAID);
/**
 Sub Tag 03 of Mastercard Data Tag used as PFID - Payment facilitator ID.
 */
@property(class,nonnull,readonly) TagInfo* TAG_03_PFID NS_SWIFT_NAME(TAG_03_PFID);
/**
 Sub Tag 04 of Mastercard Data Tag used as Market Specific Alias.
 */
@property(class,nonnull,readonly) TagInfo* TAG_04_MARKET_SPECIFIC_ALIAS NS_SWIFT_NAME(TAG_04_MARKET_SPECIFIC_ALIAS);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_05_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_05_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_06_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_06_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_07_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_07_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_08_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_08_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_09_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_09_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_10_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_10_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_11_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_11_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_12_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_12_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_13_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_13_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_14_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_14_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_15_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_15_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_16_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_16_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_17_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_17_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_18_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_18_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_19_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_19_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_20_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_20_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_21_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_21_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_22_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_22_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_23_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_23_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_24_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_24_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_25_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_25_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_26_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_26_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_27_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_27_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_28_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_28_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_29_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_29_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_30_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_30_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_31_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_31_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_32_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_32_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_33_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_33_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_34_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_34_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_35_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_35_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_36_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_36_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_37_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_37_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_38_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_38_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_39_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_39_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_40_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_40_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_41_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_41_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_42_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_42_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_43_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_43_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_44_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_44_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_45_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_45_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_46_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_46_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_47_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_47_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_48_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_48_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_49_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_49_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_50_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_50_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_51_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_51_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_52_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_52_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_53_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_53_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_54_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_54_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_55_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_55_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_56_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_56_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_57_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_57_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_58_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_58_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_59_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_59_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_60_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_60_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_61_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_61_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_62_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_62_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_63_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_63_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_64_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_64_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_65_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_65_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_66_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_66_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_67_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_67_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_68_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_68_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_69_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_69_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_70_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_70_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_71_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_71_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_72_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_72_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_73_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_73_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_74_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_74_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_75_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_75_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_76_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_76_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_77_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_77_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_78_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_78_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_79_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_79_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_80_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_80_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_81_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_81_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_82_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_82_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_83_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_83_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_84_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_84_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_85_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_85_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_86_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_86_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_87_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_87_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_88_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_88_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_89_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_89_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_90_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_90_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_91_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_91_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_92_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_92_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_93_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_93_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_94_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_94_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_95_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_95_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_96_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_96_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_97_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_97_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_98_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_98_MASTERCARD_DATA_SUB_TAG);
/**
 Reserved for future use for Mastercard
 */
@property(class,nonnull,readonly) TagInfo* TAG_99_MASTERCARD_DATA_SUB_TAG NS_SWIFT_NAME(TAG_99_MASTERCARD_DATA_SUB_TAG);

@end

NS_ASSUME_NONNULL_END
