//
//  SNSThemeSection.h
//  IdensicMobileSDK
//

#import <Foundation/Foundation.h>
#import "SNSMobileSDK+Enums.h"

#ifndef SNS_THEME_DEPRECATED
    #ifndef SNS_THEME_SUPPRESS_DEPRECATED_WARNINGS
        #define SNS_THEME_DEPRECATED(params...) __attribute((deprecated(params)))
    #else
        #define SNS_THEME_DEPRECATED(params...)
    #endif
#endif

@interface SNSThemeSection : NSObject

@end
