//
//  ChecksumUtility.h
//  ErrorObjCinSwift
//
//  Created by MasterCard on 14/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Utility class to check valid checksum. It includes:
    - CRC checksum that is being used in EMVCO standard
    - Luhn checksum that is being used in Mastercard identifier
 */
@interface ChecksumUtility : NSObject

/**
 Generate CRC16
 
 @param string String to generate crc for
 @eturn CRC16 in 4 digit hex code string format with `0` as padding
 */
+ (NSString* _Nonnull) crc16:(NSString* _Nonnull) string;

/**
 Checks if the qr string includes valid CRC16
 
 @param qrString QR code string
 @return `true` if the CRC16 in the qrString is valid else `false`
 */

+ (BOOL) isValidCrc16:(NSString* _Nonnull) qrString;

/**
 Sum to single digit
 
 @param digit Digit to sum
 @return Single digit sum
 */
+ (NSInteger) sumToSingleDigit:(NSInteger) digit;

/**
 Generate luhn checksum of the string
 
 @param string String to valid luhn checksum for
 @param hasCheckDigit Whether `Check digit` is already present in the string or not.
 @return Integer luhn checksum
 @note Throw `MPQRError.invalidFormat` if the the string is not numeric
 */

+ (NSNumber* _Nullable) luhnChecksum:(NSString* _Nonnull) string hasCheckDigit:(BOOL) hasCheckDigit error:(NSError* _Nullable * _Nullable) error;

/**
 Generate luhn checksum of the string.
 
 @param string String to valid luhn checksum for
 @return Integer luhn checksum
 @note Throws: `MPQRError.invalidFormat` if the the string is not numeric
 @note Precondition: Check digit should **not** be present in the string
 */
+ (NSNumber* _Nullable) luhnChecksum:(NSString* _Nonnull) string error:(NSError* _Nullable *_Nullable) error;

// MARK: - Luhn checksum

/**
 Valid luhn checksum of the string
 
 @param string String to valid luhn checksum for
 @return `true` if luhn checksum of the string is valid
 @note Precondition: `string` should be numeric otherwise this method returns false
 */
+ (BOOL) validateLuhnChecksum:(NSString* _Nonnull) string;



@end

