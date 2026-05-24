//
//  SNSActionResult.h
//  IdensicMobileSDK
//

#import <Foundation/Foundation.h>

@interface SNSActionResult : NSObject

/**
 * Applicant action identifier to check the results against the server
 */
@property (nonatomic, readonly, nonnull) NSString *actionId;

/**
 * Applicant action type
 */
@property (nonatomic, readonly, nonnull) NSString *actionType;

/**
 * Overall result. Typical values are `GREEN`, `RED` or `ERROR`.
 */
@property (nonatomic, readonly, nullable) NSString *answer;

/**
 * A flag that allows the check to be considered successful despite of RED answer
 */
@property (nonatomic, readonly) BOOL allowContinuing;

@end
