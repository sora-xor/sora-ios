//
//  SNSMobileSDKInfo.h
//  IdensicMobileSDK
//

#ifndef SNSMobileSDKInfoProtocol_h
#define SNSMobileSDKInfoProtocol_h

/**
 * SDK's Info Protocol
 */
@protocol SNSMobileSDKInfoProtocol <NSObject>

/// The SDK's version number
@property (nonnull, readonly) NSString *version;
/// The SDK's build number
@property (nonnull, readonly) NSString *build;
/// The list of the steps supported
@property (nonnull, readonly) NSArray<SNSVerificationStepKey> *supportedSteps;
/// The list of the pluggable modules and their status
@property (nonnull, readonly) NSDictionary<NSString *, NSString *> *modules;

@end

#endif /* SNSMobileSDKInfoProtocol_h */
