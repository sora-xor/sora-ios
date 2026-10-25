//
//  MPQRParser.h
//  ErrorObjCinSwift
//
//  Created by MasterCard on 15/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol Tag;
@class PushPaymentData;
@class TLV;
@class AdditionalData;

/**
 * Primary interface of the framework.
 * This class provide interface to parse the QRCode string to structured data, i.e. `PushPaymentData`.
 *  - It has `+parse:error:` method that do parsing as well as do validation if the string is compliance with EMVCO standard.
 *  - It also has `+parseWithoutTagValidation:error:` and `+parseWithoutTagValidationAndCRC:error:` to parse the string without validating if the value is compliance with EMVCO standard.
 */
@interface MPQRParser : NSObject


/**
 Parse QR string to structured data.
 
 It performs validation by calling PushPayment data's `- (BOOL) validate:(NSError* _Nullable * _Nullable) error` after parsing

 @param string String to parse
 @return Parsed `PushPaymentData`
 @note Throws: `MPQRError` exceptions
 @note SeeAlso: parseWithoutTagValidation(string:)
*/
+ (PushPaymentData* _Nullable) parse:(NSString* _Nonnull) string error:(NSError* _Nullable * _Nullable) error NS_SWIFT_NAME(parse(string:));

/**
 Parse QR string to structured data.
 
 It performs validation by calling PushPaymentData's '- (BOOL) validateForParsing' after parsing

 @param string String to parse
 @return Parsed `PushPaymentData`
 @note Throws: `MPQRError` exceptions
 @note SeeAlso: parseWithoutTagValidation(string:)
 @note: If MissingTag or InvalidTagValue error occurs we are still sending parsed PushPaymentData along with array of validation errors
 */
+ (PushPaymentData* _Nullable) parseWithValidationWarnings:(NSString* _Nonnull) string error:(NSError* _Nullable * _Nullable) error NS_SWIFT_NAME(parseWithValidationWarnings(string:));

/**
 Parse QR string to structured data without full tag validation. It validates CRC of the provided string.
 
 @param string String to parse
 @return Parsed `PushPaymentData`
 @note Throws: `MPQRError.invalidTagValue` if the crc tag value is not valid. `MPQRError` exceptions
 @note SeeAlso: parseWithoutTagValidationAndCRC(string:)
 */
+ (PushPaymentData* _Nullable) parseWithoutTagValidation:(NSString* _Nonnull) string error:(NSError*_Nullable*_Nullable) error;


/**
 Parse QR string to structured data without full tag and crc validation
 
 @param string String to parse
 @return Parsed `PushPaymentData`
 @note Throws: `MPQRError` exceptions
 */
+ (PushPaymentData* _Nullable) parseWithoutTagValidationAndCRC:(NSString* _Nonnull) string error:(NSError* _Nullable *_Nullable) error;


// MARK: - Private methods
/**
 Read next `TLV` from the string
 
 @param string String to read from
 @param start Index from which to start reading
 @param tagType Type of the tag to read for
 @return Parsed `TLV`
 @note Throws: `MPQRError.invalidFormat` exception if length field is not numeric
 */
+ (TLV* _Nullable) readNextTLV:(NSString* _Nonnull) string start:(NSInteger) start tagType:(Class<Tag> _Nonnull) tagType error:(NSError* _Nullable * _Nullable) error;

/**
 Parse `AdditionalData` from string
 
 @param string String to parse
 @return Parsed `AdditionalData`
 @note SeeAlso: `readNextTLV(string:, start:, tagType:)`
 */
+ (AdditionalData* _Nullable) parseAdditionalData:(NSString* _Nonnull) string error:(NSError* _Nullable *_Nullable) error;


/**
 Read substring
 
 @param string String to read from
 @param start Start index of the substring *inclusive*
 @param end End index of the substring *exclusive*
 @return Substring
 @note Throws: `MPQRError.invalidFormat` if there are not enough characters to be read based on end index
 */
+ (NSString* _Nullable) readSubstring:(NSString* _Nonnull) string start:(NSInteger) start end:(NSInteger) end error:(NSError*_Nullable *_Nullable) error;

/**
 Get Additional data value
 
 @param string QR String to extract value from
 @return Additional Data Value string
 @note Throws: `MPQRError` exceptions
 */
+ (NSString* _Nullable) getAdditionalDataValueFromQRString:(NSString* _Nonnull) string error:(NSError*_Nullable *_Nullable) error;

@end

