//
//  SNSTheme.h
//  IdensicMobileSDK
//

#import <UIKit/UIKit.h>

#import "SNSThemeFonts.h"
#import "SNSThemeColors.h"
#import "SNSThemeImages.h"
#import "SNSThemeMetrics.h"

typedef NSString * _Nullable(^SNSAssetNameHandler)(NSString * _Nonnull assetName);

@interface SNSTheme : NSObject

+ (nonnull instancetype)fromJSON:(nullable NSDictionary<NSString *, id> *)json NS_SWIFT_NAME(init(fromJSON:));
+ (nonnull instancetype)fromJSON:(nullable NSDictionary<NSString *, id> *)json
                      assetsPath:(nullable NSString *)assetsPath NS_SWIFT_NAME(init(fromJSON:assetsPath:));
+ (nonnull instancetype)fromJSON:(nullable NSDictionary<NSString *, id> *)json
                assetNameHandler:(nullable SNSAssetNameHandler)assetNameHandler NS_SWIFT_NAME(init(fromJSON:assetNameHandler:));
+ (nonnull instancetype)fromJSON:(nullable NSDictionary<NSString *, id> *)json
                      assetsPath:(nullable NSString *)assetsPath
                assetNameHandler:(nullable SNSAssetNameHandler)assetNameHandler NS_SWIFT_NAME(init(fromJSON:assetsPath:assetNameHandler:));

+ (nonnull instancetype)darkTheme;

#pragma mark -

@property (nonatomic, nonnull) SNSThemeFonts *fonts;
@property (nonatomic, nonnull) SNSThemeColors *colors;
@property (nonatomic, nonnull) SNSThemeImages *images;
@property (nonatomic, nonnull) SNSThemeMetrics *metrics;

#pragma mark -

typedef NSString* SNSIdDocType;

typedef NS_ENUM(NSInteger, SNSThemeDimmingEffect) {
    SNSThemeDimmingEffect_None,
    SNSThemeDimmingEffect_Blur SNS_THEME_DEPRECATED("Use .fadeIn instead."),
    SNSThemeDimmingEffect_FadeIn,
};

#pragma mark - General

@property (nonatomic) UIStatusBarStyle sns_preferredStatusBarStyle SNS_THEME_DEPRECATED("Replaced with `metrics.commonStatusBarStyle`");

@property (nonatomic, nullable) UIColor *sns_navbarBarTintColor SNS_THEME_DEPRECATED("Not used. The background color of the navigation bar matches the screen background.");
@property (nonatomic, nullable) UIColor *sns_navbarTintColor SNS_THEME_DEPRECATED("Replaced with `colors.navigationBarItem`");

@property (nonatomic, nullable) UIImage *sns_closeButtonImage SNS_THEME_DEPRECATED("Use `images.iconClose` instead.");
@property (nonatomic, nullable) UIImage *sns_searchIconImage SNS_THEME_DEPRECATED("Use `images.iconSearch` instead.");

@property (nonatomic, nullable) UIColor *sns_alertTintColor SNS_THEME_DEPRECATED("Replaced with `colors.alertTint`");

@property (nonatomic, nullable) UIFont *sns_poweredByFont SNS_THEME_DEPRECATED("Replaced with `fonts.caption`");
@property (nonatomic, nullable) UIColor *sns_poweredByColor SNS_THEME_DEPRECATED("Replaced with `colors.contentWeak`");

/**
 * Matches to `fonts.caption` by default
 */
@property (nonatomic, nullable) UIFont *sns_loadingMessageFont;
/**
 * Matches to `colors.contentWeak` by default
 */
@property (nonatomic, nullable) UIColor *sns_loadingMessageColor;
@property (nonatomic) UIActivityIndicatorViewStyle sns_loadingSpinnerStyle SNS_THEME_DEPRECATED("Replaced with `metrics.activityIndicatorStyle`");

#pragma mark - Buttons

/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_actionButtonFont;
@property (nonatomic) CGFloat sns_actionButtonCornerRadius SNS_THEME_DEPRECATED("Use `metrics.buttonCornerRadius` instead.");
@property (nonatomic) CGFloat sns_actionButtonHeight SNS_THEME_DEPRECATED("Use `metrics.buttonHeight` instead.");

@property (nonatomic, nullable) UIColor *sns_actionButtonTitleColor SNS_THEME_DEPRECATED("Replaced with `colors.primaryButtonContent`");
@property (nonatomic, nullable) UIColor *sns_actionButtonBackgroundColor SNS_THEME_DEPRECATED("Replaced with `colors.primaryButtonBackground`");
@property (nonatomic, nullable) UIColor *sns_actionButtonHighlightedTitleColor SNS_THEME_DEPRECATED("Replaced with `colors.primaryButtonContentHighlighted`");
@property (nonatomic, nullable) UIColor *sns_actionButtonHighlightedBackgroundColor SNS_THEME_DEPRECATED("Replaced with `colors.primaryButtonBackgroundHighlighted`");

@property (nonatomic, nullable) UIColor *sns_alternativeButtonTitleColor SNS_THEME_DEPRECATED("Replaced with `colors.secondaryButtonContent`");
@property (nonatomic, nullable) UIColor *sns_alternativeButtonBackgroundColor SNS_THEME_DEPRECATED("Replaced with `colors.secondaryButtonBackground`");
@property (nonatomic, nullable) UIColor *sns_alternativeButtonHighlightedTitleColor SNS_THEME_DEPRECATED("Replaced with `colors.secondaryButtonContentHighlighted`");
@property (nonatomic, nullable) UIColor *sns_alternativeButtonHighlightedBackgroundColor SNS_THEME_DEPRECATED("Replaced with `colors.secondaryButtonBackgroundHighlighted`");
/**
 * Matches to `colors.secondaryButtonContent` by default
 */
@property (nonatomic, nullable) UIColor *sns_alternativeButtonBorderColor;

#pragma mark - Oops Screen

/**
 * Matches to `fonts.headline2` by default
 */
@property (nonatomic, nullable) UIFont *sns_OopsScreenTitleFont;
/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_OopsScreenTextFont;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_OopsScreenTitleColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_OopsScreenTextColor;
/**
 * Matches to `colors.contentLink` by default
 */
@property (nonatomic, nullable) UIColor *sns_OopsScreenLinkColor;

/**
 * Matches to `images.pictureWarning` by default
 */
@property (nonatomic, nullable) UIImage *sns_OopsScreenNetworkFailImage;
/**
 * Matches to `images.pictureFailure` by default
 */
@property (nonatomic, nullable) UIImage *sns_OopsScreenFatalFailImage;

@property (nonatomic, nullable) UIImage *sns_OopsScreenWordlessNetworkFailImage;
@property (nonatomic, nullable) UIImage *sns_OopsScreenWordlessFatalFailImage;
@property (nonatomic, nullable) UIImage *sns_OopsScreenWordlessRetryButtonImage;
@property (nonatomic, nullable) UIImage *sns_OopsScreenWordlessGoBackButtonImage;

#pragma mark - Status Screen

/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusScreenBackgroundColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusScreenSpinnerColor;

/**
 * Matches to `fonts.headline1` by default
 */
@property (nonatomic, nullable) UIFont *sns_StatusHeaderTitleFont;
/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_StatusHeaderSubtitleFont;
/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_StatusHeaderTextFont;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusHeaderTitleColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusHeaderSubtitleColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusHeaderTextColor;

/**
 * Default is .fadeIn
 */
@property (nonatomic) SNSThemeDimmingEffect sns_StatusFooterDimmingEffect;
/**
 * Default is .fadeIn
 */
@property (nonatomic) SNSThemeDimmingEffect sns_StatusFooterDimmingEffectDark;
@property (nonatomic) UIBlurEffectStyle sns_StatusFooterBlurEffectStyle SNS_THEME_DEPRECATED("Unused");

/**
 * Matches to `fonts.caption` by default
 */
@property (nonatomic, nullable) UIFont *sns_StatusFooterTextFont;
/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusFooterBackgroundColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusFooterTextColor;
/**
 * Matches to `colors.contentLink` by default
 */
@property (nonatomic, nullable) UIColor *sns_StatusFooterLinkColor;

/**
 * Size of the image displayed at the header of the Status Screen
 *
 * Default is 112pt x 112pt
 */
@property (nonatomic) CGSize sns_StatusHeaderImageSize;

/**
 * An optional image displayed on Status Screen when the applicant has been approved. If it's defined, it will be used instead of the steps list.
 *
 * Matches to `images.pictureSuccess` by default
 */
@property (nonatomic, nullable) UIImage *sns_StatusScreenApprovedImage;
/**
 * An optional image displayed on Status Screen when the applicant has been finally rejected.
 *
 * Matches to `images.pictureFailure` by default
 */
@property (nonatomic, nullable) UIImage *sns_StatusScreenFinalRejectImage;

#pragma mark - idDocs

/**
 * The paddings applied to idDoc status cells at the Status Screen
 *
 * Default are: 10pt vertically and 12pt horizontally
 */
@property (nonatomic) UIEdgeInsets sns_idDocStatusPaddings;

/**
 * The horizontal spacing between icons and the texts on idDoc status cells at the Status Screen
 *
 * Default is 8pt
 */
@property (nonatomic) CGFloat sns_idDocStatusIconSpacing;

/**
 * The vertical spacing between the texts on idDoc status cells at the Status Screen
 *
 * Default is 2pt
 */
@property (nonatomic) CGFloat sns_idDocStatusTextsSpacing;

@property (nonatomic, nullable) UIFont *sns_idDocStatusPromptTextFont SNS_THEME_DEPRECATED("Unused");
@property (nonatomic, nullable) UIColor *sns_idDocStatusPromptTextColor SNS_THEME_DEPRECATED("Unused");
@property (nonatomic, nullable) UIColor *sns_idDocStatusPromptBackgroundColor SNS_THEME_DEPRECATED("Unused");

/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusSubmittedTitleFont;
/**
 * Matches to `fonts.body` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusSubmittedSubtitleFont;
/**
 * Matches to `colors.contentWarning` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusSubmittedTextColor;
/**
 * Matches to `colors.backgroundWarning` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusSubmittedBackgroundColor;
@property (nonatomic, nullable) UIImage *sns_idDocStatusSubmittedImage SNS_THEME_DEPRECATED("Use images.setIcon(:forVerificationStep:andState:)");

/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusNotSubmittedTitleFont;
/**
 * Matches to `fonts.body` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusNotSubmittedSubtitleFont;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusNotSubmittedTextColor;
/**
 * Matches to `colors.backgroundNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusNotSubmittedBackgroundColor;
@property (nonatomic, nullable) UIImage *sns_idDocStatusNotSubmittedImage SNS_THEME_DEPRECATED("Use images.setIcon(:forVerificationStep:andState:)");

/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusReviewingTitleFont;
/**
 * Matches to `fonts.body` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusReviewingSubtitleFont;
/**
 * Matches to `colors.contentWarning` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusReviewingTextColor;
/**
 * Matches to `colors.backgroundWarning` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusReviewingBackgroundColor;
@property (nonatomic, nullable) UIImage *sns_idDocStatusReviewingImage SNS_THEME_DEPRECATED("Use images.setIcon(:forVerificationStep:andState:)");

/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusDeclinedTitleFont;
/**
 * Matches to `fonts.body` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusDeclinedSubtitleFont;
/**
 * Matches to `colors.contentCritical` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusDeclinedTextColor;
/**
 * Matches to `colors.backgroundCritical` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusDeclinedBackgroundColor;
@property (nonatomic, nullable) UIImage *sns_idDocStatusDeclinedImage SNS_THEME_DEPRECATED("Use images.setIcon(:forVerificationStep:andState:)");

/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusApprovedTitleFont;
/**
 * Matches to `fonts.body` by default
 */
@property (nonatomic, nullable) UIFont *sns_idDocStatusApprovedSubtitleFont;
/**
 * Matches to `colors.contentSuccess` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusApprovedTextColor;
/**
 * Matches to `colors.backgroundSuccess` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocStatusApprovedBackgroundColor;
@property (nonatomic, nullable) UIImage *sns_idDocStatusApprovedImage SNS_THEME_DEPRECATED("Use images.setIcon(:forVerificationStep:andState:)");

/**
 * Matches to `metrics.cardCornerRadius` by default
 */
@property (nonatomic) CGFloat sns_idDocBackgroundCornerRadius;
/**
 * Used to estimate the highlighted background color by applying the factor to the normal background color
 *
 * Default is 0.05f
 */
@property (nonatomic) CGFloat sns_idDocHighlightDarkFactor;

/**
 * Used to estimate the color of the disclosure indicator by applying the factor to the normal background color
 *
 * The dark factor has no effect when `sns_idDocDisclosureTintColor` is not nil.
 *
 * Default is 0.15f
 */
@property (nonatomic) CGFloat sns_idDocDisclosureDarkFactor;
/**
 * The disclosure color, if defined, is applied instead of the `sns_idDocDisclosureDarkFactor`
 *
 * Matches to `colors.contentWeak` by default
 */
@property (nonatomic, nullable) UIColor *sns_idDocDisclosureTintColor;
/**
 * Matches to `images.iconDisclosure` by default
 */
@property (nonatomic, nullable) UIImage *sns_idDocDisclosureImage;

@property (nonatomic, nullable) UIImage *sns_idDocTypeDefaultImage SNS_THEME_DEPRECATED("Use `images.documentTypeIcons[.default]` instead");
@property (nonatomic, nullable) NSDictionary<SNSIdDocType, UIImage *> *sns_idDocTypeImages SNS_THEME_DEPRECATED("Use `images.documentTypeIcons` instead");

#pragma mark - DocType Selector Screen

/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenBackgroundColor;

/**
 * Matches to `fonts.caption` by default
 */
@property (nonatomic, nullable) UIFont *sns_DocTypeScreenFooterTextFont;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenFooterTextColor;
/**
 * Matches to `colors.contentLink` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenFooterLinkColor;

/**
 * Matches to `fonts.headline2` by default
 */
@property (nonatomic, nullable) UIFont *sns_DocTypeScreenSectionTitleFont;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenSectionTitleColor;

/**
 * Matches to `metrics.sectionHeaderAlignment` by default
 */
@property (nonatomic) NSTextAlignment sns_DocTypeScreenSectionTitleAlignment;

/**
 * Matches to `fonts.headline2` by default
 */
@property (nonatomic, nullable) UIFont *sns_DocTypeScreenSectionSubtitleFont;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenSectionSubtitleColor;

/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_DocTypeScreenItemTextFont;
/**
 * Matches to `colors.backgroundNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenItemBackgroundColor;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenItemTextColor;
/**
 * Matches to `colors.fieldPlaceholder` by default
 */
@property (nonatomic, nullable) UIColor *sns_DocTypeScreenItemPlaceholderColor;

/**
 * Matches to `images.iconDisclosure` by default
 */
@property (nonatomic, nullable) UIImage *sns_DocTypeScreenItemDisclosureImage;

/**
 * The paddings applied to the item cells at the DocType Selector Screen
 *
 * Default are: 12pt vertically and 12pt horizontally
 */
@property (nonatomic) UIEdgeInsets sns_DocTypeScreenItemPaddings;

/**
 * The mininum height of the item cells at the DocType Selector Screen
 *
 * Default is 0
 */
@property (nonatomic) CGFloat sns_DocTypeScreenItemMinHeight;

/**
 * The horizontal spacing between icons and the texts at the DocType Selector Screen
 *
 * Default is 8pt
 */
@property (nonatomic) CGFloat sns_DocTypeScreenItemIconSpacing;

/**
 * Use to force the vertically centering of the elements on the item cells at the DocType Selector Screen
 *
 * Default is false
 */
@property (nonatomic) BOOL sns_DocTypeScreenItemVerticallyCentering;

/**
 * Matches to `metrics.cardCornerRadius`
 */
@property (nonatomic) CGFloat sns_DocTypeScreenItemCornerRadius;

#pragma mark - Countries Screen

/**
 * Matches to `colors.backgroundCommon`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenBackgroundColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.listSeparator`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenSeparatorColor SNS_THEME_DEPRECATED("Unused");

/**
 * Matches to `fonts.subtitle2`
 */
@property (nonatomic, nullable) UIFont *sns_CountriesScreenItemTextFont SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.contentNeutral`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenItemTextColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.listSelectedItemBackground`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenSelectedItemBackgroundColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.contentNeutral`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenSelectedItemTextColor SNS_THEME_DEPRECATED("Unused");

/**
 * Matches to `fonts.subtitle2`
 */
@property (nonatomic, nullable) UIFont *sns_CountriesScreenSearchFieldFont SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.fieldContent`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenSearchFieldTextColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.fieldBackground`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenSearchFieldBackgroundColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.fieldBorder`
 */
@property (nonatomic, nullable) UIColor *sns_CountriesScreenSearchFieldBorderColor SNS_THEME_DEPRECATED("Unused");

#pragma mark - Camera Screen

@property (nonatomic, nullable) UIColor *sns_CameraScreenBackgroundColor SNS_THEME_DEPRECATED("Replaced with `colors.cameraBackground`");
/**
 * Matches to `colors.cameraContent` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenSpinnerColor;

/**
 * Matches to `colors.cameraContent` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenCloseButtonTintColor;
/**
 * Matches to `colors.cameraContent` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenTorchButtonTintColor;

/**
 * Default is #FFFFFF
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenCaptureButtonColor;
/**
 * Default is #F4F4F4
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenCaptureButtonHighlightedColor;

@property (nonatomic, nullable) UIFont *sns_CameraScreenScanResultStatusTextFont SNS_THEME_DEPRECATED("Unused");
@property (nonatomic, nullable) UIColor *sns_CameraScreenScanResultStatusTextColor SNS_THEME_DEPRECATED("Unused");
@property (nonatomic, nullable) UIColor *sns_CameraScreenScanResultStatusBackgroundColor SNS_THEME_DEPRECATED("Unused");
@property (nonatomic, nullable) UIColor *sns_CameraScreenScanActivityIndicatorColor SNS_THEME_DEPRECATED("Unused");

/**
 * Matches to `fonts.headline2` by default
 */
@property (nonatomic, nullable) UIFont *sns_CameraScreenInfoTitleFont;
/**
 * Matches to `fonts.body` by default
 */
@property (nonatomic, nullable) UIFont *sns_CameraScreenInfoTextFont;
/**
 * Matches to `colors.bottomSheetBackground` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenInfoBackgroundColor;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenInfoTitleColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenInfoTextColor;
/**
 * Matches to `colors.bottomSheetHandle` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenInfoHandlerOutsideColor;
/**
 * Matches to `colors.bottomSheetHandle` by default
 */
@property (nonatomic, nullable) UIColor *sns_CameraScreenInfoHandlerInsideColor;

/**
 * Default is `.center`
 */
@property (nonatomic) NSTextAlignment sns_CameraScreenInfoTitleAlignment;
/**
 * Default is `.center`
 */
@property (nonatomic) NSTextAlignment sns_CameraScreenInfoBriefAlignment;
/**
 * Default is `.natural`
 */
@property (nonatomic) NSTextAlignment sns_CameraScreenInfoDetailsAlignment;

@property (nonatomic, nullable) UIImage *sns_CameraScreenTorchOnImage SNS_THEME_DEPRECATED("Use `images.iconTorchOn` instead.");
@property (nonatomic, nullable) UIImage *sns_CameraScreenTorchOffImage SNS_THEME_DEPRECATED("Use `images.iconTorchOff` instead.");

@property (nonatomic, nullable) UIImage *sns_CameraScreenGalleryImage SNS_THEME_DEPRECATED("Use `images.iconGallery` instead.");

#pragma mark - Video Screen

/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenBackgroundColor;
/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenDimColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenSpinnerColor;

/**
 * Matches to `fonts.headline1` by default
 */
@property (nonatomic, nullable) UIFont *sns_VideoScreenCountDownFont;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenCountDownColor;

/**
 * Matches to `colors.navigationBarItem` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenCloseButtonTintColor;

/**
 * Matches to `colors.contentWeak` with alpha 40% by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenRecordButtonBorderColor;
/**
 * Matches to `colors.contentCritical` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenRecordingColor;

/**
 * Matches to `colors.contentInfo` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenViewPortBorderColor;
/**
 * Matches to `colors.contentInfo` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenViewPortBorderActiveColor;
/**
 * Matches to `metrics.viewportBorderWidth` by default
 */
@property (nonatomic) CGFloat sns_VideoScreenViewPortBorderWidth;

/**
 * Matches to `fonts.headline1` by default
 */
@property (nonatomic, nullable) UIFont *sns_VideoScreenReadAloudTextFont;

/**
 * Foreground color of the Video Screen's panel the text to read is displayed at
 *
 * Default is #FFFFFF
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenReadAloudTextColor;
/**
 * Background color of the Video Screen's panel the text to read is displayed at
 *
 * Default is #1E232E
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenReadAloudBackgroundColor;

/**
 * Matches to `fonts.headline1` by default
 */
@property (nonatomic, nullable) UIFont *sns_VideoScreenFooterHeaderFont;
/**
 * Matches to `fonts.subtitle1` by default
 */
@property (nonatomic, nullable) UIFont *sns_VideoScreenFooterTextFont;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenFooterHeaderColor;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_VideoScreenFooterTextColor;

#pragma mark - FaceScan Screen

/**
 * Matches to `fonts.headline2` by default
 */
@property (nonatomic, nullable) UIFont *sns_FaceScanScreenResultTitleFont;
/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_FaceScanScreenResultTextFont;
/**
 * Matches to `fonts.headline2` by default
 */
@property (nonatomic, nullable) UIFont *sns_FaceScanScreenHintFont;

/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenBackgroundColor;
/**
 * Matches to `colors.navigationBarItem` by default
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenCloseButtonTintColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenSpinnerColor;

/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenResultTitleColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenResultTextColor;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenHintColor;
/**
 * Matches to `colors.contentSuccess` by default
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenOvalColor;

/**
 * The color applied to the hint text at the FaceScan Screen when low light conditions are detected
 *
 * Default is #333333
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenLowLightHintColor;
/**
 * The color applied to the close button at the FaceScan Screen when low light conditions are detected
 *
 * Default is #333333
 */
@property (nonatomic, nullable) UIColor *sns_FaceScanScreenLowLightCloseButtonTintColor;

/**
 * Matches to `images.pictureSuccess` by default
 */
@property (nonatomic, nullable) UIImage *sns_FaceScanScreenSuccessImage;
/**
 * Matches to `images.pictureFailure` by default
 */
@property (nonatomic, nullable) UIImage *sns_FaceScanScreenFailedImage;
/**
 * Matches to `images.pictureSubmitted` by default
 */
@property (nonatomic, nullable) UIImage *sns_FaceScanScreenSubmittedImage;

/**
 * Size of the image displayed at the FaceScan Screen when the processing is done
 *
 * Equals to `sns_StatusHeaderImageSize` by default (112pt x 112pt)
 */
@property (nonatomic) CGSize sns_FaceScanScreenResultImageSize;

#pragma mark - Preview Screen

/**
 * Matches to `fonts.headline2` by default
 */
@property (nonatomic, nullable) UIFont *sns_PreviewScreenTitleFont;
/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_PreviewScreenSubtitleFont;
/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenBackgroundColor;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenTitleColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenSubtitleColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenSpinnerColor;

@property (nonatomic, nullable) UIImage *sns_PreviewScreenVideoPlayImage SNS_THEME_DEPRECATED("Use `images.iconPlay` instead.");

/**
 * Matches to `metrics.bottomSheetCornerRadius` by default
 */
@property (nonatomic) CGFloat sns_PreviewScreenSliderCornerRadius;
/**
 * Specifies the shift of the warning icon displayed at the top right corner of the slider (only vertical shift is applied)
 *
 * Default vertical shift is 0pt
 */
@property (nonatomic) CGPoint sns_PreviewScreenSliderIconPosition;

/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_PreviewScreenSliderBriefFont;
/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_PreviewScreenSliderDetailsFont;
/**
 * Matches to `colors.bottomSheetBackground` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenSliderBackgroundColor;
/**
 * Matches to `colors.bottomSheetHandle` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenSliderHandlerColor;
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenSliderBriefColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_PreviewScreenSliderDetailsColor;
/**
 * Matches to `images.iconWarning` by default
 */
@property (nonatomic, nullable) UIImage *sns_PreviewScreenSliderIconImage;

#pragma mark - Support Screen

/**
 * Matches to `fonts.subtitle1`
 */
@property (nonatomic, nullable) UIFont *sns_SupportScreenItemButtonFont SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `fonts.body`
 */
@property (nonatomic, nullable) UIFont *sns_SupportScreenItemDescriptionFont SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.backgroundCommon`
 */
@property (nonatomic, nullable) UIColor *sns_SupportScreenBackgroundColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.contentStrong`
 */
@property (nonatomic, nullable) UIColor *sns_SupportScreenItemButtonColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.contentNeutral`
 */
@property (nonatomic, nullable) UIColor *sns_SupportScreenItemDescriptionColor SNS_THEME_DEPRECATED("Unused");

@property (nonatomic, nullable) UIColor *sns_SupportScreenEmailImageTintColor SNS_THEME_DEPRECATED("Unused");
@property (nonatomic, nullable) UIImage *sns_SupportScreenEmailImage SNS_THEME_DEPRECATED("Replaced with `images.iconMail`");

#pragma mark - ToS Screen

/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_TosScreenBackgroundColor;
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_TosScreenSpinnerColor;

#pragma mark - Applicant Data Screen

/**
 * Matches to `colors.backgroundCommon` by default
 */
@property (nonatomic, nullable) UIColor *sns_DataScreenBackgroundColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.contentNeutral` by default
 */
@property (nonatomic, nullable) UIColor *sns_DataScreenSpinnerColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.listSeparator` by default
 */
@property (nonatomic, nullable) UIColor *sns_DataScreenSeparatorColor SNS_THEME_DEPRECATED("Unused");

/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_DataScreenNameFont SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `fonts.subtitle2` by default
 */
@property (nonatomic, nullable) UIFont *sns_DataScreenValueFont SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.contentStrong` by default
 */
@property (nonatomic, nullable) UIColor *sns_DataScreenNameColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.fieldContent` by default
 */
@property (nonatomic, nullable) UIColor *sns_DataScreenValueColor SNS_THEME_DEPRECATED("Unused");
/**
 * Matches to `colors.contentCritical` by default
 */
@property (nonatomic, nullable) UIColor *sns_DataScreenErrorColor SNS_THEME_DEPRECATED("Unused");

@end
