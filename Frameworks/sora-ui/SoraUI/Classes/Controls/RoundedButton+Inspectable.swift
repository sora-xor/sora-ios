/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation
import UIKit

/// Extension of the RoundedButton to support design through Interface Builder
extension RoundedButton {
    @IBInspectable
    private var fillColor: UIColor {
        get {
            return self.roundedBackgroundView!.fillColor
        }

        set(newValue) {
            self.roundedBackgroundView!.fillColor = newValue
        }
    }

    @IBInspectable
    private var highlightedFillColor: UIColor {
        get {
            return self.roundedBackgroundView!.highlightedFillColor
        }

        set(newValue) {
            self.roundedBackgroundView!.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    private var strokeColor: UIColor {
        get {
            return self.roundedBackgroundView!.strokeColor
        }

        set(newValue) {
            self.roundedBackgroundView!.strokeColor = newValue
        }
    }

    @IBInspectable
    private var highlightedStrokeColor: UIColor {
        get {
            return self.roundedBackgroundView!.highlightedStrokeColor
        }

        set(newValue) {
            self.roundedBackgroundView!.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    private var strokeWidth: CGFloat {
        get {
            return self.roundedBackgroundView!.strokeWidth
        }

        set(newValue) {
            self.roundedBackgroundView!.strokeWidth = newValue
        }
    }

    @IBInspectable
    private var layoutType: UInt8 {
        get {
            return self.imageWithTitleView!.layoutType.rawValue
        }

        set(newValue) {
            if let layoutType = ImageWithTitleView.LayoutType(rawValue: newValue) {
                self.imageWithTitleView!.layoutType = layoutType
            }
        }
    }

    @IBInspectable
    private var title: String? {
        get {
            return self.imageWithTitleView!.title
        }

        set(newValue) {
            self.imageWithTitleView!.title = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var titleColor: UIColor? {
        get {
            return self.imageWithTitleView!.titleColor
        }

        set(newValue) {
            self.imageWithTitleView!.titleColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var highlightedTitleColor: UIColor? {
        get {
            return self.imageWithTitleView!.highlightedTitleColor
        }

        set(newValue) {
            self.imageWithTitleView!.highlightedTitleColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var iconImage: UIImage? {
        get {
            return self.imageWithTitleView!.iconImage
        }

        set(newValue) {
            self.imageWithTitleView!.iconImage = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var highlightedIconImage: UIImage? {
        get {
            return self.imageWithTitleView!.highlightedIconImage
        }

        set(newValue) {
            self.imageWithTitleView!.highlightedIconImage = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var iconTintColor: UIColor? {
        get {
            return imageWithTitleView!.iconTintColor
        }

        set(newValue) {
            imageWithTitleView!.iconTintColor = newValue
        }
    }

    @IBInspectable
    private var titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                self.imageWithTitleView?.titleFont = nil
                return
            }

            guard let pointSize = self.imageWithTitleView!.titleFont?.pointSize else {
                self.imageWithTitleView!.titleFont = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            self.imageWithTitleView!.titleFont = UIFont(name: fontName, size: pointSize)

            self.invalidateLayout()
        }

        get {
            return self.imageWithTitleView!.titleFont?.fontName
        }
    }

    @IBInspectable
    private var titleFontSize: CGFloat {
        set(newValue) {
            guard let fontName = self.imageWithTitleView!.titleFont?.fontName else {
                self.imageWithTitleView!.titleFont = UIFont.systemFont(ofSize: newValue)
                return
            }

            self.imageWithTitleView!.titleFont = UIFont(name: fontName, size: newValue)

            self.invalidateLayout()
        }

        get {
            if let pointSize = self.imageWithTitleView!.titleFont?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var shadowColor: UIColor {
        get {
            return self.roundedBackgroundView!.shadowColor
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var shadowOffset: CGSize {
        get {
            return self.roundedBackgroundView!.shadowOffset
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOffset = newValue
        }
    }

    @IBInspectable
    private var shadowRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.shadowRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowRadius = newValue
        }
    }

    @IBInspectable
    private var shadowOpacity: Float {
        get {
            return self.roundedBackgroundView!.shadowOpacity
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOpacity = newValue
        }
    }

    @IBInspectable
    private var cornerRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.cornerRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.cornerRadius = newValue
        }
    }

    @IBInspectable
    private var spacingBetweenItems: CGFloat {
        get {
            return self.imageWithTitleView!.spacingBetweenLabelAndIcon
        }

        set(newValue) {
            self.imageWithTitleView!.spacingBetweenLabelAndIcon = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var didContentOpacityWhenHighlighted: CGFloat {
        get {
            return contentOpacityWhenHighlighted
        }

        set(newValue) {
            contentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var didContentOpacityWhenDisabled: CGFloat {
        get {
            return contentOpacityWhenDisabled
        }

        set(newValue) {
            contentOpacityWhenDisabled = newValue
        }
    }

    @IBInspectable
    private var didChangesContentOpacityWhenHighlighted: Bool {
        get {
            return changesContentOpacityWhenHighlighted
        }

        set(newValue) {
            changesContentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var displacementBetweenLabelAndIcon: CGFloat {
        get {
            return imageWithTitleView!.displacementBetweenLabelAndIcon
        }

        set(newValue) {
            imageWithTitleView!.displacementBetweenLabelAndIcon = newValue
        }
    }

    @IBInspectable
    private var topLeftRounded: Bool {
        get {
            return self.roundedBackgroundView!.roundingCorners.contains(UIRectCorner.topLeft)
        }

        set(newValue) {
            if newValue {
                self.roundedBackgroundView!.roundingCorners.insert(UIRectCorner.topLeft)
            } else {
                self.roundedBackgroundView!.roundingCorners.remove(UIRectCorner.topLeft)
            }

        }
    }

    @IBInspectable
    private var topRightRounded: Bool {
        get {
            return self.roundedBackgroundView!.roundingCorners.contains(UIRectCorner.topRight)
        }

        set(newValue) {
            if newValue {
                self.roundedBackgroundView!.roundingCorners.insert(UIRectCorner.topRight)
            } else {
                self.roundedBackgroundView!.roundingCorners.remove(UIRectCorner.topRight)
            }
        }
    }

    @IBInspectable
    private var bottomLeftRounded: Bool {
        get {
            return self.roundedBackgroundView!.roundingCorners.contains(UIRectCorner.bottomLeft)
        }

        set(newValue) {
            if newValue {
                self.roundedBackgroundView!.roundingCorners.insert(UIRectCorner.bottomLeft)
            } else {
                self.roundedBackgroundView!.roundingCorners.remove(UIRectCorner.bottomLeft)
            }

        }
    }

    @IBInspectable
    private var bottomRightRounded: Bool {
        get {
            return self.roundedBackgroundView!.roundingCorners.contains(UIRectCorner.bottomRight)
        }

        set(newValue) {
            if newValue {
                self.roundedBackgroundView!.roundingCorners.insert(UIRectCorner.bottomRight)
            } else {
                self.roundedBackgroundView!.roundingCorners.remove(UIRectCorner.bottomRight)
            }

        }
    }
}
