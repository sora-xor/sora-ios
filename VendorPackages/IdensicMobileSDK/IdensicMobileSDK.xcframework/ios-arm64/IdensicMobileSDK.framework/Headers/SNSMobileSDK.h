//
//  SNSMobileSDK.h
//  IdensicMobileSDK
//

#import <UIKit/UIKit.h>
#import "SNSMobileSDK+Enums.h"

@class SNSMobileSDK;
@class SNSSupportItem;
@class SNSTheme;
@class SNSActionResult;
@class SNSEvent;
@class SNSDocumentDefinition;
@protocol SNSMobileSDKDelegate;
@protocol SNSMobileSDKInfoProtocol;

#pragma mark -

typedef void(^SNSTokenExpirationHandler)(void(^_Nonnull onComplete)(NSString * _Nullable newAccessToken));
typedef void(^SNSVerificationHandler)(BOOL isApproved);
typedef void(^SNSActionResultHandler)(SNSMobileSDK * _Nonnull sdk, SNSActionResult * _Nonnull result, void(^_Nonnull onComplete)(SNSActionResultHandlerReaction));
typedef void(^SNSLogHandler)(SNSLogLevel level, NSString * _Nonnull message);
typedef void(^SNSDimissHandler)(SNSMobileSDK * _Nonnull sdk, UINavigationController * _Nonnull mainVC);

typedef void(^SNSAddSupportItemBlock)(SNSSupportItem * _Nonnull item);

typedef void(^SNSOnStatusDidChangeCallback)(SNSMobileSDK * _Nonnull sdk, SNSMobileSDKStatus prevStatus);
typedef void(^SNSOnDidDismissCallback)(SNSMobileSDK * _Nonnull sdk);
typedef void(^SNSOnEventCallback)(SNSMobileSDK * _Nonnull sdk, SNSEvent * _Nonnull event);

#pragma mark -

@interface SNSMobileSDK : NSObject

/**
 * General info about the SDK
 */
@property (nonnull, readonly, class) id<SNSMobileSDKInfoProtocol> info;

#pragma mark -

/**
 * Prepares SDK for the launch in the production/sandbox environment
 *
 * @param accessToken An access token for the applicant to be verified. The token must be generated with a level name.
 *
 * @discussion
 * Upon setup check `isReady` property. It should be `true` on success, otherwise see `failReason` and `verboseStatus` for the fail details.
 *
 * The sdk will work in the production or in the sandbox environment depend on which one the `accessToken` has been generated on.
 */
+ (nonnull instancetype)setupWithAccessToken:(nonnull NSString *)accessToken

NS_SWIFT_NAME(init(accessToken:));

/**
 * Prepares SDK for the launch with a level-aware access token
 *
 * @param accessToken An access token for the applicant to be verified. The token must be generated with a level name.
 * @param environment The environment the sdk should operate on. Default is `.production`.
 *
 * @discussion
 * Upon setup check `isReady` property. It should be `true` on success, otherwise see `failReason` and `verboseStatus` for the fail details.
 *
 * In case you need a custom environment to access the service, place it like this:
 * @textblock
 * sdk = SNSMobileSDK(
 *     accessToken: accessToken,
 *     environment: SNSEnvironment("https://my-api.mydomain.com")
 * )
 * @/textblock
 */
+ (nonnull instancetype)setupWithAccessToken:(nonnull NSString *)accessToken
                                 environment:(nonnull SNSEnvironment)environment

NS_SWIFT_NAME(init(accessToken:environment:));

+ (nonnull instancetype)new NS_UNAVAILABLE;
- (nonnull instancetype)init NS_UNAVAILABLE;

/**
 * Sets token expiration handler
 *
 * @param handler A closure that takes another closure `onComplete` as the only parameter.
 *
 * @discussion
 * Token expiration handler fired when `accessToken` is expired.
 * MUST call `onComplete` with new `accessToken` as a parameter.
 */
- (void)tokenExpirationHandler:(nullable SNSTokenExpirationHandler)handler;

/**
 * Sets verification handler
 *
 * @param handler A closure that takes boolean parameter `isApproved`.
 *
 * @discussion
 * Verification handler would be called when verification is done with a final decision (the applicant is approved or finally rejected).
 *
 * See also `onStatusDidChange` to get notified of other stages of the verification process.
 */
- (void)verificationHandler:(nullable SNSVerificationHandler)handler;

#pragma mark - Initial Applicant Data

/**
 * An optional email that will be assigned to the applicant initially (not set by default)
 */
@property (nonatomic, nullable) NSString *initialEmail;

/**
 * An optional phone number that will be assigned to the applicant initially (not set by default)
 */
@property (nonatomic, nullable) NSString *initialPhone;

#pragma mark - Preferred Documents

/**
 * Sets an optional document definitions
 *
 * @discussion
 * For IDENTITY* steps it's possible to specify the preferred country and document type to be selected automatically bypassing the DocType Selector screen.
 *
 * For example:
 *
 * @textblock
 * sdk.preferredDocumentDefinitions = [
 *     .identity: SNSDocumentDefinition(
 *         idDocType: "DRIVERS",
 *         country: "USA"
 *     )
 * ]
 * @/textblock
 */
@property (nonatomic, nullable) NSDictionary<SNSVerificationStepKey, SNSDocumentDefinition *> *preferredDocumentDefinitions;

/**
 * Sets an optional document definitions from a specially formatted json
 *
 * @discussion
 * For IDENTITY* steps it's possible to specify the preferred country and document type to be selected automatically bypassing the DocType Selector screen.
 *
 * For example:
 *
 * @textblock
 * sdk.setPreferredDocumentDefinitions(json: [
 *     "IDENTITY": [
 *         "idDocType": "PASSPORT",
 *         "country": "USA"
 *     ]
 * ])
 * @/textblock
 */
- (void)setPreferredDocumentDefinitionsFromJSON:(nullable NSDictionary<NSString *, id> *)json NS_SWIFT_NAME(setPreferredDocumentDefinitions(json:));

#pragma mark - UI

/**
 * Main view controller of the SDK's user interface
 *
 * @discussion
 * Upon success setup get and present `mainVC` from your view controller
 */
@property (nonatomic, readonly, nonnull) UINavigationController *mainVC;

/**
 * Sets an optional handler to dismiss the main view controller
 *
 * @param handler A closure that takes two parameters - the SDK instance and the `mainVC` controller.
 * 
 * @discussion
 * The handler would be called when user wants to leave the main screen. It's up to you to dismiss the `mainVC` controller.
 */
- (void)dismissHandler:(nullable SNSDimissHandler)handler;

/**
 * Forces the `mainVC` to be dismissed
 */
- (void)dismiss;

/**
 * Sets a time interval the sdk will be dismissed in when the applicant is approved (3 sec by default)
 *
 * @discussion
 * By default, once the applicant is approved the sdk will be dismissed in 3 seconds automatically.
 * Here you can adjust this time interval or switch the automatic dismissal off by setting value of zero.
 */
- (void)setOnApproveDismissalTimeInterval:(NSTimeInterval)timeInterval;

#pragma mark - Shortcuts

/**
 * Shortcut for `viewController.present(mainVC, animated:true, completion: nil)`
 *
 * @param viewController a view controller you'd like the sdk be presented from
 */
- (void)presentFrom:(nonnull UIViewController *)viewController;

/**
 * Shortcut for `UIApplication.shared.keyWindow?.rootViewController.present(mainVC, animated:true, completion: nil)
 */
- (void)present;

#pragma mark - Callbacks

/**
 * Sets an optional callback fired when `mainVC` is dismissed.
 *
 * @param callback A closure that takes the SDK instance.
 */
- (void)onDidDismiss:(nullable SNSOnDidDismissCallback)callback;

/**
 * Sets an optional callback fired when `status` is changed.
 *
 * @param callback A callback that takes two parameters - the SDK instance and the previous value of the `status`.
 *
 * @discussion
 * Use the callback to get notified of the stages of the verification process.
 */
- (void)onStatusDidChange:(nullable SNSOnStatusDidChangeCallback)callback;

/**
 * Sets an optional callback fired when an Event occurs
 *
 * @param callback A callback that takes two parameters - the SDK instance and an Event object
 *
 * @discussion
 * The Event is represented by an instance of a class inherited from `SNSEvent`.
 * Please see `SNSEvent` for details.
 */
- (void)onEvent:(nullable SNSOnEventCallback)callback;

#pragma mark - Status

/**
 * SDK implies to be `Ready` when it's initialized successfully
 */
@property (nonatomic, readonly) BOOL isReady;

/**
 * Indicates that SDK is failed for some reason (see `failReason` and `verboseStatus` for details)
 */
@property (nonatomic, readonly) BOOL isFailed;

/**
 * Current SDK status
 */
@property (nonatomic, readonly) SNSMobileSDKStatus status;

/**
 * Describes the reason of the last fail if any. Makes sense when `status` is `Failed`.
 */
@property (nonatomic, readonly) SNSFailReason failReason;

/**
 * Verbose SDK status
 *
 * @discussion
 * Returns SDK status as a text. Could contain detailed info for `Failed` case.
 */
@property (nonatomic, readonly, nonnull) NSString *verboseStatus;

/**
 * Provides default description for the given SDK status
 */
- (nonnull NSString *)descriptionForStatus:(SNSMobileSDKStatus)status;

/**
 * Provides default description for the given fail reason
 */
- (nonnull NSString *)descriptionForFailReason:(SNSFailReason)failReason;

#pragma mark - Applicant Actions

/**
 * Applicant Action result
 */
@property (nonatomic, readonly, nullable) SNSActionResult *actionResult;

/**
 * Sets an optional handler to be called right after a new `actionResult` is arrived from the backend.
 *
 * @param handler A closure that takes `sdk`, `result` and `onComplete` closure.
 *
 * @discussion
 * MUST call `onComplete` with a desired reaction:
 * - pass `.continue` to proceed with default scenario
 * - or pass `.cancel` to force the processing to complete
 */
- (void)actionResultHandler:(nullable SNSActionResultHandler)handler;

#pragma mark - Customization

/**
 * Adjusts the locale the sdk should use for texts (the system locale will be used by default)
 *
 * @discussion
 * Use locale in a form of `en` or `en_US`
 */
@property (nonatomic, nullable) NSString *locale;

/**
 * Customization Theme
 * 
 * @discussion
 * One can pass own theme object of `SNSTheme` class or adjust the default one using writtable properties
 */
@property (nonatomic, nonnull) SNSTheme *theme;

/**
 * Text customization
 *
 * @discussion
 * When the sdk needs a string it will look for the corresponding key in the `strings` dictionary.
 * If the key is not found, the sdk will try to get the string with `NSLocalizedString`.
 *
 * During the initial loading the `strings` dictionary will be appended with the strings taken from the dashboard for the language corresponding to the selected `locale`.
 * Pay attention please that locally defined strings have precedence over the remotely taken ones.
 */
@property (nonatomic, nonnull) NSDictionary<NSString *, NSString *> *strings;

/**
 * Name of the .strings file to get texts from (used only when no corresponding key is found in the `strings` dictionary)
 *
 * @discussion
 * By default SDK looks for `IdensicMobileSDK.strings` file in the main bundle.
 * If you'd like to keep localizations in another .strings file, assign its name here (just the name, without .strings extension)
 */
@property (nonatomic, nonnull) NSString *localizationTableName;

/**
 * Array of items to be displayed at Support screen.
 *
 * @discussion
 * Initially an Email item would be created automatically using the Support email configured in your dashboard.
 *
 * Feel free to reconfigure support items as required. See `SNSSupportItem` for details.
 */
@property (nonatomic, nullable) NSArray<SNSSupportItem *> *supportItems;

/**
 * A convenience method to add a support item
 *
 * @param configure New support item is created and passed into the block to be configured as required
 */
- (void)addSupportItemWithBlock:(nonnull NS_NOESCAPE SNSAddSupportItemBlock)configure;

#pragma mark - Logging

/**
 * Logging level (`Off` by default)
 */
@property (nonatomic) SNSLogLevel logLevel;

/**
 * Sets an optional log handler
 *
 * @param handler A close that takes `logLevel` and `message` to be logged.
 *
 * @discussion
 * By default SDK uses `NSLog` for the logging purposes. If for some reasons it does not work for you, feel free to use `logHandler` to intercept log messages and direct them as required.
 */
- (void)logHandler:(nullable SNSLogHandler)handler;

#pragma mark - Settings

/**
 * Enables or disables the internal sdk analytics (enabled by default)
 *
 * @discussion
 * Setting to `false` disables the emitting of `SNSEventAnalytics` as well
 */
@property (nonatomic) BOOL isAnalyticsEnabled;

/**
 * Custom settings
 *
 * @discussion Reserved for the future needs.
 */
@property (nonatomic, nullable) NSDictionary *settings;

#pragma mark - Delegate

/**
 * Delegate
 */
@property (nonatomic, weak, nullable) id<SNSMobileSDKDelegate> delegate;

#pragma mark - Aliases

/// Alias for `tokenExpirationHandler:` method
- (void)setTokenExpirationHandler:(nullable SNSTokenExpirationHandler)handler;
/// Alias for `verificationHandler:` method
- (void)setVerificationHandler:(nullable SNSVerificationHandler)handler;
/// Alias for `actionResultHandler` method
- (void)setActionResultHandler:(nullable SNSActionResultHandler)handler;
/// Alias for `dismissHandler:` method
- (void)setDismissHandler:(nullable SNSDimissHandler)handler;
/// Alias for `onDidDismiss:`
- (void)setOnDidDismiss:(nullable SNSOnDidDismissCallback)callback;
/// Alias for `onStatusDidChange:` method
- (void)setOnStatusDidChange:(nullable SNSOnStatusDidChangeCallback)callback;
/// Alias for `onEvent:` method
- (void)setOnEvent:(nullable SNSOnEventCallback)callback;
/// Alias for `logHandler:` method
- (void)setLogHandler:(nullable SNSLogHandler)handler;

@end
