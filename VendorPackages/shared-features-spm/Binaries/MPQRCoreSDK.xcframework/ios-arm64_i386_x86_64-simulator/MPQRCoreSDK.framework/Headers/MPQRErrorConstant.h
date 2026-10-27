//
//  MPQRErrorConstant.h
//  MPQRCoreSDK
//
//  Created by MasterCard on 4/10/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Error domain of the MPQRError, all MPQRError will have this value as domain.
 */
extern NSString *const MPQRErrorDomain NS_REFINED_FOR_SWIFT;

/**
 MPQRError have description, this MPQRErrorTagInfoKey is the key to get the description in the property userInfo.
 */
extern NSString *const MPQRErrorMessageKey NS_REFINED_FOR_SWIFT;

/**
 MPQRError have tag info (optional), this MPQRErrorTagInfoKey is the key to get the tag info in the property userInfo.
 */
extern NSString *const MPQRErrorTagInfoKey NS_REFINED_FOR_SWIFT;

/**
 MPQRError have value of the tag (optional), this MPQRErrorTagValueKey is the key to get the value in the property userInfo.
 */
extern NSString *const MPQRErrorTagValueKey NS_REFINED_FOR_SWIFT;

/**
 MPQRError have list of tags info (optional), this MPQRErrorTagInfoKey is the key to get list of tags info in the property userInfo.
 */
extern NSString *const MPQRErrorTagsKey NS_REFINED_FOR_SWIFT;

/**
 MPQRError have tag info (optional), this MPQRErrorRootTagInfoKey is the key to get the root-tag info in the property userInfo.
 */
extern NSString *const MPQRErrorRootTagInfoKey NS_REFINED_FOR_SWIFT;

/**
 MPQRError have property errorType, the errorType type is the MPQRErrorCode enum
 */
typedef NS_ENUM(NSInteger, MPQRErrorCode) {
    /**
     MPQRError errorType is InvalidFormat include the following error:
     - Luhn checksum is wrong
     - The value of the length of the tag is not numeric
     - The length of the value is less than what is specified
     */
    InvalidFormat,
    
    /**
     MPQRError errorType is InvalidTagValue include the following error:
     - The value has different format than it specified
     - The value is wrong, i.e. CRC, country
     */
    InvalidTagValue,
    
    /**
     MPQRError errorType is UnknownTag when the tag is not defined, i.e. more than 99
     */
    UnknownTag,
    
    /**
     MPQRError errorType is MissingTag when the mandatory tag is not present
     */
    MissingTag,
    
    /**
     MPQRError errorType is ConflictingTag include the following error:
     - The value of some tag exist when it must not exist
     - Setting MAI and Unrestricted Data beyond the defined tag
     */
    ConflictingTag, //MAI and Unreserver under here, not in android
    
    /**
     MPQRError errorType is RFUTag when try to set Reserve for Use tag
     */
    RFUTag,
    
    /**
     MPQRError errorType is DuplicateTag when parsing a QR Code and there are two same tag
     */
    DuplicateTag,
    
    /**
     MPQRError errorType is Limit when try to set MAI data and Unrestricted data more than it is allocated
     */
    Limit,
} NS_REFINED_FOR_SWIFT;
