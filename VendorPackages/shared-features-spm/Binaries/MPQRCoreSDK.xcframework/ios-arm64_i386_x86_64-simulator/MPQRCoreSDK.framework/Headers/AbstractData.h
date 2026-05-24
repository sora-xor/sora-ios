//
//  AbstractData.h
//  MPQRCoreSDKV2
//
//  Created by MasterCard on 13/9/17.
//  Copyright © 2017 MasterCard. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol Tag;
@class TagInfo;

/**
 Abstract class `AbstractData` model is the root of Data hierarchy, containing the basic common functions applicable to all Data classes. All Data classes will have `AbstractData` model as its superclass.
 */
@interface AbstractData : NSObject
{
    /// Map of contained tagInfo and their value
    NSMutableDictionary<TagInfo*,id>* map;
}

/**
 All tags that can be represented
 */
@property (retain, nonnull) NSArray<TagInfo*>* allTags;

/**
 Type of represented tags
 */
@property (nonnull) Class<Tag> tagType;

/**
 Initializer

 @param tagType Type of tags this data represents
 */
- (id _Nonnull) init:(Class<Tag> _Nonnull) tagType;

/**
 Initializer
 
 @param tagType Type of tags this data represents
 @param regex for checking RFU
 @param rTag is the tag in the containing object
 */
- (id _Nonnull) init:(Class<Tag> _Nonnull) tagType regex:(NSString* _Nullable) regex rootTag:(NSString* _Nullable) rTag;

// MARK: - Tag value accessors
/**
 Checks if value for tagInfo is present internally
 
 @param tagInfo Tag info for which to check presence
 
 @return `true` if value exists else `false`
 */
- (BOOL) hasTagInfoValueFor:(TagInfo* _Nonnull) tagInfo;


/**
 Get value for tagInfo
 
 @param tagInfo Tag info for which to get value
 
 @return Value if found else `nil`
 
 */
- (id _Nullable) getTagInfoValueFor:(TagInfo* _Nonnull) tagInfo;

/**
 Set value for tagInfo
 
 @param value Value to set
 @param tagInfo Tag info to set the value of
 */
- (void) setTagInfoValue:(id _Nonnull) value for:(TagInfo* _Nonnull) tagInfo;


/**
 Removes value related to tagInfo

 @param tagInfo Remove value for tagInfo
 
 @note This method does nothing if the value is not found for tagInfo
 */
- (void) removeTagInfoValueFor:(TagInfo* _Nonnull) tagInfo;

/**
 Returns count of total tag info key value pair

 @return Total number of tag info key value pair
 */
- (NSInteger) tagInfoCount;

// MARK: - Convenient Accessor
/**
 Get value for tagInfo
 
 @param strTagInfo NSString* tag for which to get value
 
 @return Value if found else `nil`
 */
- (id _Nullable) getTagInfoValueForTagString:(NSString* _Nonnull) strTagInfo error:(NSError*_Nullable*_Nullable) error;

/**
 Set value for tagInfo
 
 @param value Value to set
 @param strTagInfo NSString* tag to set the value of
 */
- (BOOL) setTagInfoValue:(id _Nonnull) value forTagString:(NSString* _Nonnull) strTagInfo error:(NSError*_Nullable*_Nullable) error;

/**
 Set value in range of tag
 
 Used for MAI Data, Unrestricted data in push payment data, or unrestricted data in additional data
 
 @param value of to be inserted
 @param low lower index inclusive
 @param high higher index exclusive
 */
- (BOOL) setValueInTagRange:(id _Nonnull) value low:(int) low high:(int) high error:(NSError* _Nullable *_Nullable) error;

/**
 Remove value at specified tag
 
 @param tagInfo specified tag at which to remove value
 */
- (void) removeValue:(TagInfo* _Nonnull) tagInfo;

/**
 Set RootTag: the root tag that the object belong to
 
 @param rootTag can be null
 */
- (void) setRootTag:(NSString* _Nullable) rootTag;

/*
 Get RootTag: the root tag that the object belong to
 
 @return rootTag can be null
 */
- (NSString* _Nullable) getRootTag;

// MARK: - Validation

/**
 Validate data

 @note Throws:
    - `MPQRError.missingTag` if the value for tag info is **not** present while the tag was **mandatory**.
    - `MPQRError.invalidTagValue` If the value doesn't match pattern of the tag. And if the length of string representation of the value is out of [1, 99] range
 */
- (BOOL) validate:(NSError* _Nullable *_Nullable) err;

/**
 Validate data
 
 @note Adds errors coming during validation to ValidationErrors array of ParserValidaitonErrors class.
 */
- (BOOL) validateForParsing;

/**
 Checks internal data for RFU tags
 
 @note Throws RFUTagException if internal data contains an RFU tag
 */
- (BOOL) checkForRFU:(NSError*_Nullable*_Nullable) error;

/**
 Checks internal data for RFU tags
 
 @note Adds RFUTagError to validationErrors array of ParserValidaitonErrors class, if internal data contains an RFU tag
 */
- (BOOL) checkForRFUWithValidationErrors;

/**
 To check length of the tag
 */
- (BOOL) validateLength:(NSString* _Nonnull) value tagInfo:(TagInfo* _Nonnull) tInfo error:(NSError*_Nullable*_Nullable) error;

// MARK: - Describing data
/**
 String representation of the data. It will generate a string which is parseable back to data
 */
- (NSString* _Nonnull) description;

/**
 Dump internal data in a string representation
 *Useful for debugging purposes*
 
 @return String representation of internal data
 */
- (NSString* _Nonnull) dumpData;

// MARK: - Instance methods
/**
 Equality check
 */
- (BOOL) isEqual:(id _Nullable)object;



@end

