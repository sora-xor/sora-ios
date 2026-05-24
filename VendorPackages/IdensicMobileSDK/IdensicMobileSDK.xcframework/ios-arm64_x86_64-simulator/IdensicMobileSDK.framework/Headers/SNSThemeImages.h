//
//  SNSThemeImages.h
//  IdensicMobileSDK
//

#import "SNSThemeSection.h"

@interface SNSThemeImages : SNSThemeSection

#pragma mark - Icons (templates)

/// Used for the close bar button across all the screens.
/// Default is a cross icon.
@property (nonatomic, nonnull) UIImage *iconClose;

/// Used for the back bar button.
/// Default is a back arrow icon. Setting to `nil` forces the system back button to be used instead.
@property (nonatomic, nullable) UIImage *iconBack;

/// Used for the search bar.
/// Default is a magnifying glass icon.
@property (nonatomic, nonnull) UIImage *iconSearch;

/// Used to indicate the disclosability.
/// Default is a simple disclosing arrow icon.
@property (nonatomic, nonnull) UIImage *iconDisclosure;

/// Used for dropdown fields.
/// Default is a down arrow icon.
@property (nonatomic, nonnull) UIImage *iconDropdown;

/// Used for date fields.
/// Default is a calendar icon.
@property (nonatomic, nonnull) UIImage *iconCalendar;

/// Used for attachments fields when the field is empty.
/// Default is a clip icon.
@property (nonatomic, nonnull) UIImage *iconAttachment;

/// Used for attachments fields when the document is attached.
/// Default is a picture icon.
@property (nonatomic, nonnull) UIImage *iconPicture;

/// Used for attachments fields when the document can be removed.
/// Default is a trash bin icon.
@property (nonatomic, nonnull) UIImage *iconBin;

/// Used for the turned-on flashlight button on the Camera Screen.
/// Default is a filled flash icon.
@property (nonatomic, nonnull) UIImage *iconTorchOn;

/// Used for the turned-off flashlight button on the Camera Screen.
/// Default is an outlined flash icon.
@property (nonatomic, nonnull) UIImage *iconTorchOff;

/// Used for the gallery button on the Camera Screen.
/// Default is a photos stack icon.
@property (nonatomic, nonnull) UIImage *iconGallery;

/// Used for the camera toggle button on the VideoIdent Screen.
/// Default is a rounded arrows icon.
@property (nonatomic, nonnull) UIImage *iconCameraToggle;

/// Used for the rotation bar button on the Preview Screen.
/// Default is a photo rotation icon.
@property (nonatomic, nonnull) UIImage *iconRotate;

/// Used for the default E-Mail support item.
/// Default is a letter icon.
@property (nonatomic, nonnull) UIImage *iconMail;

/// Used for the play button on the Preview screen.
/// Default is a play icon in the circle.
@property (nonatomic, nonnull) UIImage *iconPlay;

/// Used on the verification comment block at the Status Screen
/// Default is an exclamation mark in the triangle.
@property (nonatomic, nonnull) UIImage *iconNotice;

/// Used for unmarked checkboxes.
/// Default is an empty rectangle icon with `contentWeak` border color.
@property (nonatomic, nonnull) UIImage *iconCheckboxOff;

/// Used for marked checkboxes.
/// Default is a white checkmark icon on a background rectangle with `fieldTint` color.
@property (nonatomic, nonnull) UIImage *iconCheckboxOn;

/// Used for unselected radio buttons.
/// Default is an empty circle icon with `contentWeak` border color.
@property (nonatomic, nonnull) UIImage *iconRadioButtonOff;

/// Used for selected radio buttons.
/// Default is a white circle icon on a backround circle with `fieldTint` color.
@property (nonatomic, nonnull) UIImage *iconRadioButtonOn;

/// Used for "Other" option on Agreement screen.
/// Default is a earth icon.
@property (nonatomic, nonnull) UIImage *iconOtherCountry;

/// Used to compose the auto-generated `pictureSuccess`.
/// Default is a checkmark icon.
@property (nonatomic, nonnull) UIImage *iconSuccess;

/// Used for the warnings bottom sheet and to compose the auto-generated `pictureWarning`.
/// Default is an exclamation mark in the triangle.
@property (nonatomic, nonnull) UIImage *iconWarning;

/// Used to compose the auto-generated `pictureFailure`.
/// Default is a cross icon.
@property (nonatomic, nonnull) UIImage *iconFailure;

/// Used to compose the auto-generated `pictureSubmitted`.
/// Default is an uploading-to-the-cloud icon.
@property (nonatomic, nonnull) UIImage *iconSubmitted;


#pragma mark - Pictures

/// The "success" image. Could be used if you'd like to override the auto-generated one.
/// Default is `nil`
///
/// @discussion
/// The auto-generated image looks like the `iconSuccess` icon in the circles composed on the basis of the `colors.contentSuccess` and `colors.backgroundSuccess` colors.
@property (nonatomic, nullable) UIImage *pictureSuccess;

/// The "warning" image. Could be used if you'd like to override the auto-generated one.
/// Default is `nil`
///
/// @discussion
/// The auto-generated image looks like the `iconWarning` icon in the circles composed on the basis of the `colors.contentWarning` and `colors.backgroundWarning` colors.
@property (nonatomic, nullable) UIImage *pictureWarning;

/// The "failure" image. Could be used if you'd like to override the auto-generated one.
/// Default is `nil`
///
/// @discussion
/// The auto-generated image looks like the `iconFailure` icon in the circles composed on the basis of the `colors.contentCritical` and `colors.backgroundFailure` colors.
@property (nonatomic, nullable) UIImage *pictureFailure;

/// The "submitted" image. Could be used if you'd like to override the auto-generated one.
/// Default is `nil`
///
/// @discussion
/// The auto-generated image looks like the `iconSubmitted` icon in the circles composed on the basis of the `colors.contentWarning` and `colors.backgroundWarning` colors.
@property (nonatomic, nullable) UIImage *pictureSubmitted;

/// Used as the image on the Geolocation Screen before the start of geolocation detection.
/// Default is a geolocation pin icon.
@property (nonatomic, nullable) UIImage *pictureGeolocationOn;

/// Used as the image on the Geolocation Screen when the app has no permissions to get the geolocation.
/// Default is a crossed geolocation pin icon.
@property (nonatomic, nullable) UIImage *pictureGeolocationOff;

/// Displayed at the top of the Agreement Screen.
/// Default is a globe decorated.
@property (nonatomic, nullable) UIImage *pictureAgreement;

/// Displayed at the Camera Screen before the back side of a document is going to be captured.
/// Default is an ID document with a rotating arrow below.
@property (nonatomic, nullable) UIImage *pictureDocumentFlip;


#pragma mark - Verification Steps

/// Verification steps icons.
///
/// Default icons are defined for the following keys: `.identity`, `.selfie`, `.selfie2`, `.proofOfResidence`, `.proofOfResidence2`, `.applicantData`, `.emailVerification`, `.phoneVerification`, `.questionnaire`, `.videoIdent` and `.ekyc`.
/// Also the `.default` key is filled with the `.identity` icon.
@property (nonatomic, nonnull) NSDictionary<SNSVerificationStepKey, UIImage *> *verificationStepIcons;

- (void)setIcon:(UIImage * _Nullable)icon forVerificationStep:(SNSVerificationStepKey _Nonnull)step NS_SWIFT_UNAVAILABLE("Use .verificationStepIcons instead.");

/// Verification steps icons by the step' states
///
/// By default the same icons are used for any step state, see `metrics.verificationStepIcons`, here is the way to adjust more preciously if required
- (void)setIcon:(UIImage * _Nullable)icon forVerificationStep:(SNSVerificationStepKey _Nonnull)step andState:(SNSVerificationStepState _Nonnull)state;


#pragma mark - Documents

/// Document types icons.
///
/// Default icons are defined for the following keys: `.idCard`, `.passport`, `.drivers` and `.residencePermit`.
/// Also the `.default` key is filled with the `.idCard` icon.
@property (nonatomic, nonnull) NSDictionary<SNSDocumentTypeKey, UIImage *> *documentTypeIcons;

- (void)setIcon:(UIImage * _Nullable)icon forDocumentType:(SNSDocumentTypeKey _Nonnull)documentType NS_SWIFT_UNAVAILABLE("Use .documentTypeIcons instead.");


#pragma mark - Instructions

/// Instruction pictures.
///
/// When an image is referred with one of the following text keys:
///
/// @textblock
/// - `sns_step_{STEP}_{scene}_instructions_image`
/// - `sns_step_{STEP}_{scene}_instructions_doImage`
/// - `sns_step_{STEP}_{scene}_instructions_dontImage`
/// @/textblock
///
/// the sdk will look through `instructionsImages` for the corresponding image object.
/// At that it takes the value of the text key and uses it as a key for `instructionsImages` dictionary.
///
/// Feel free to add your own pictures or use the predefined ones:
///
/// @textblock
/// - `default/videoident`
/// - `default/facescan`
/// - `default/do_idCard`
/// - `default/dont_idCard`
/// - `default/do_passport`
/// - `default/dont_passport`
/// - `default/do_idCard_backSide`
/// - `default/dont_idCard_backSide`
/// @/textblock
///
@property (nonatomic, nonnull) NSDictionary<NSString *, UIImage *> *instructionsImages;

- (void)setInstructionsImage:(UIImage * _Nullable)image forKey:(NSString * _Nonnull)imageKey NS_SWIFT_UNAVAILABLE("Use .documentTypeIcons instead.");

@end
