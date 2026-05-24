//
//  SNSThemeFonts.h
//  IdensicMobileSDK
//

#import "SNSThemeSection.h"

@interface SNSThemeFonts : SNSThemeSection

/// Used for screen titles in conjunction with `colors.contentStrong` mostly.
/// Default is System Bold, 24pt.
@property (nonatomic, nonnull) UIFont *headline1;

/// Used for section titles in conjunction with `colors.contentStrong` mostly.
/// Default is System Bold, 20pt.
@property (nonatomic, nonnull) UIFont *headline2;

/// Used for subtitles in conjunction with `colors.contentStrong` mostly.
/// Default is System Semibold, 18pt.
@property (nonatomic, nonnull) UIFont *subtitle1;

/// Used for subtitles in conjunction with `colors.contentNeutral` mostly.
/// Default is System Regular, 16pt.
@property (nonatomic, nonnull) UIFont *subtitle2;

/// Used for paragraphs, text fields, etc. in conjunction with `colors.contentNeutral` mostly.
/// Default is System Regular, 14pt.
@property (nonatomic, nonnull) UIFont *body;

/// Used for minor captions in conjunction with `colors.contentWeak` mostly.
/// Default is System Regular, 12pt.
@property (nonatomic, nonnull) UIFont *caption;

@end
