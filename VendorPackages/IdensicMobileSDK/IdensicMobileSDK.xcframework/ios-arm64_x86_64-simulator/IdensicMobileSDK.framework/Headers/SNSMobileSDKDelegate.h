//
//  SNSMobileSDKDelegate.h
//  IdensicMobileSDK
//

#ifndef SNSMobileSDKDelegate_h
#define SNSMobileSDKDelegate_h

@class SNSMobileSDK;

/**
 * General Continue/Cancel style reaction for completion handlers
 */
typedef NS_ENUM(NSInteger, SNSContinueOrCancelReaction) {

    /// Designates that no decision has been made
    SNSContinueOrCancelReaction_NotHandled = 0,

    /// Allows further processing to be continued
    SNSContinueOrCancelReaction_Continue = 1,
    
    /// Cancels further processing
    SNSContinueOrCancelReaction_Cancel = 2,
};

/**
 * Permission types
 */
typedef NSString * SNSPermissionType NS_TYPED_EXTENSIBLE_ENUM;
extern SNSPermissionType _Nonnull const SNSPermissionTypeCamera;
extern SNSPermissionType _Nonnull const SNSPermissionTypeMicrophone;
extern SNSPermissionType _Nonnull const SNSPermissionTypePhotoLibrary;
extern SNSPermissionType _Nonnull const SNSPermissionTypeUserNotifications;

/**
 * User notification types
 */
typedef NSString * SNSUserNotificationType NS_TYPED_EXTENSIBLE_ENUM;
extern SNSUserNotificationType _Nonnull const SNSUserNotificationTypeVideoIdentExpertJoined;

#pragma mark -

/**
 * Delegate protocol
 */
@protocol SNSMobileSDKDelegate

@optional

/**
 * Implement if you'd like to present a custom country picker
 *
 * @discussion
 * It's up to you to present and dismiss the picker. In case the user do pick a country, call `onSelect` passing the selected country code.
 */
- (void)      snsMobileSDK:(nonnull SNSMobileSDK *)sdk
   presentCountryPickerFor:(nonnull NSDictionary<NSString *, NSString *> *)countries
                      from:(nonnull UIViewController *)presentingViewController
                     title:(nullable NSString *)title
               preselected:(nullable NSString *)countryCode
                  onSelect:(void (^ _Nonnull)(NSString * _Nonnull))onSelect;

/**
 * Implement if you'd like to use a custom image for the selected country
 *
 * @discussion
 * Used on DocType Selector screen only at the moment.
 */
- (nullable UIImage *)snsMobileSDK:(nonnull SNSMobileSDK *)sdk
           imageForSelectedCountry:(nonnull NSString *)countryCode;

/**
 * Implement if you'd like to show a custom instruction view.
 *
 * @discussion
 * Returning `nil` means the corresponding Instructions view will be constructed and shown by the sdk itself.
 */
- (nullable UIView *)    snsMobileSDK:(nonnull SNSMobileSDK *)sdk
  instructionsViewForVerificationStep:(nonnull SNSVerificationStepKey)verificationStep
                          countryCode:(nonnull NSString *)countryCode
                         documentType:(nonnull SNSDocumentTypeKey)documentType
                            sceneType:(nonnull SNSSceneType)sceneType
                            placement:(SNSInstructionsPlacement)placement;

/**
 * Implement if you'd like to show a custom mrtd instruction view.
 *
 * @discussion
 * Returning `nil` means the view will be constructed and shown by the sdk itself.
 */
- (nullable UIView *)snsMobileSDK:(nonnull SNSMobileSDK *)sdk
                 mrtdViewForState:(nonnull SNSMRTDScanState)mrtdState;

/**
 * Implement if you'd like to show a custom verification comment view.
 *
 * @discussion
 * Verification comment view can be displayed at the Status Screen when the applicant is declined temporarily.
 *
 * Returning `nil` means the view will be constructed and shown by the sdk itself.
 */
- (nullable UIView *)snsMobileSDK:(nonnull SNSMobileSDK *)sdk
   verificationCommentViewForText:(nonnull NSString *)moderationComment;

/**
 * Implement if you'd like to show custom dialogs before asking for permissions or in respond to the permission denied.
 *
 * @discussion
 * Once you're done you must call `completion` handler with one of the following values:
 *
 * - `.notHandled` - designates that you did not do anything and the sdk should proceed on its own
 *
 * - `.continue` - the sdk then will check the permissions once again and show the corresponding alerts only if there will be no access to the required resources.
 *
 * - `.cancel` - cancels the current scene - be careful please, do so only if you found out that the permissions requested are denied and you have already notified the user of that fact.
 */
- (void)snsMobileSDK:(nonnull SNSMobileSDK *)sdk
   ensurePermissions:(nonnull NSArray<SNSPermissionType> *)permissions
                from:(nonnull UIViewController *)presentingViewController
    verificationStep:(nonnull SNSVerificationStepKey)verificationStep
           sceneType:(nonnull SNSSceneType)sceneType
          completion:(void (^ _Nonnull)(SNSContinueOrCancelReaction))completion;

/**
 * Implement if you'd like to send user notifications with your own way.
 *
 * @discussion
 * The sdk relies on UNUserNotificationCenter, using default title and sound.
 */
- (void)  snsMobileSDK:(nonnull SNSMobileSDK *)sdk
  sendUserNotification:(nonnull SNSUserNotificationType)notificationType
               message:(nonnull NSString *)message;

/**
 * Implement if you'd like to manage the URLs handling yourself
 */
- (void)snsMobileSDK:(nonnull SNSMobileSDK *)sdk
             openURL:(nonnull NSURL *)url
                from:(nonnull UIViewController *)topViewController;
/**
 * Implement if you'd like to show custom Support Screen
 */
- (void)      snsMobileSDK:(nonnull SNSMobileSDK *)sdk
  presentSupportScreenFrom:(nonnull UIViewController *)topViewController;

@end

#endif /* SNSMobileSDKDelegate_h */
