//
//  SNSSupportItem.h
//  IdensicMobileSDK
//

#import <UIKit/UIKit.h>

@class SNSSupportItem;

typedef void(^SNSSupportItemActionHandler)(UIViewController * _Nonnull supportVC, SNSSupportItem * _Nonnull supportItem);

/**
 * Describes the item to be displayed at Support screen
 *
 * @discussion Each item must have a mandatory `title`, optional `icon`, `subtitle` and an action expressed with `actionURL` or `actionHandler`.
 *
 * If `actionHandler` is defined it would be called back when the item is tapped, otherwise `actionURL` would be opened with UIApplication's `openURL:` method.
 *
 * If no `actionURL` and `actionHandler` are provided then no action would be taken on tap.
 *
 * Optional `iconTintColor` could be used to tint the `icon` if required.
 */
@interface SNSSupportItem : NSObject

@property (nonatomic, readwrite, nonnull) NSString *title;
@property (nonatomic, readwrite, nullable) NSString *subtitle;
@property (nonatomic, readwrite, nullable) UIImage *icon;
@property (nonatomic, readwrite, nullable) UIColor *iconTintColor;
@property (nonatomic, readwrite, nullable) NSURL *actionURL;
@property (nonatomic, readwrite, nullable) SNSSupportItemActionHandler actionHandler;

- (void)actionHandler:(nullable SNSSupportItemActionHandler)handler;

@end
