//
//  SNSDocumentDefinition.h
//  IdensicMobileSDK
//

#import <Foundation/Foundation.h>
#import "SNSMobileSDK+Enums.h"

@interface SNSDocumentDefinition : NSObject

/// idDocType as it's represented in the API
@property (nonatomic, nullable) NSString *idDocType;
/// 3-letter country code
@property (nonatomic, nullable) NSString *country;

+ (nonnull instancetype)new NS_UNAVAILABLE;
- (nonnull instancetype)init NS_UNAVAILABLE;

- (nonnull instancetype)initWithIdDocType:(nullable NSString *)idDocType country:(nullable NSString *)country;
- (nonnull instancetype)initWithIdDocType:(nullable NSString *)idDocType;
- (nonnull instancetype)initWithCountry:(nullable NSString *)country;

- (nonnull instancetype)initWithDocumentType:(nullable SNSDocumentTypeKey)documentType country:(nullable NSString *)country;
- (nonnull instancetype)initWithDocumentType:(nullable SNSDocumentTypeKey)documentType;

@end
