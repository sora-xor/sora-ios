// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

extension RoundedCellControlView {
    @IBInspectable
    private var _fillColor: UIColor {
        get {
            return roundedBackgroundView!.fillColor
        }

        set(newValue) {
            roundedBackgroundView!.fillColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedFillColor: UIColor {
        get {
            return roundedBackgroundView!.highlightedFillColor
        }

        set(newValue) {
            roundedBackgroundView!.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    private var _strokeColor: UIColor {
        get {
            return roundedBackgroundView!.strokeColor
        }

        set(newValue) {
            roundedBackgroundView!.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedStrokeColor: UIColor {
        get {
            return roundedBackgroundView!.highlightedStrokeColor
        }

        set(newValue) {
            roundedBackgroundView!.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    private var _strokeWidth: CGFloat {
        get {
            return roundedBackgroundView!.strokeWidth
        }

        set(newValue) {
            roundedBackgroundView!.strokeWidth = newValue
        }
    }

    @IBInspectable
    private var _icon: UIImage? {
        get {
            return titleAccessoryView.titleView.iconImage
        }

        set {
            titleAccessoryView.titleView.iconImage = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _highlightedIcon: UIImage? {
        get {
            return titleAccessoryView.titleView.highlightedIconImage
        }

        set {
            titleAccessoryView.titleView.highlightedIconImage = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _title: String? {
        get {
            return titleAccessoryView.titleView.title
        }

        set(newValue) {
            titleAccessoryView.titleView.title = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            return titleAccessoryView.titleView.titleColor
        }

        set(newValue) {
            titleAccessoryView.titleView.titleColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedTitleColor: UIColor? {
        get {
            return titleAccessoryView.titleView.highlightedTitleColor
        }

        set(newValue) {
            titleAccessoryView.titleView.highlightedTitleColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            return titleAccessoryView.titleView.titleFont?.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleAccessoryView.titleView.titleFont = nil
                return
            }

            let pointSize = titleAccessoryView.titleView.titleFont?.pointSize ?? UIFont.labelFontSize
            titleAccessoryView.titleView.titleFont = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            return titleAccessoryView.titleView.titleFont?.pointSize ?? UIFont.labelFontSize
        }

        set(newValue) {
            let fontName = titleAccessoryView.titleView.titleFont?.fontName ?? UIFont
                .systemFont(ofSize: UIFont.labelFontSize).fontName
            titleAccessoryView.titleView.titleFont = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _spacingBetweenLabelAndIcon: CGFloat {
        get {
            return titleAccessoryView.titleView.spacingBetweenLabelAndIcon
        }

        set {
            titleAccessoryView.titleView.spacingBetweenLabelAndIcon = newValue
        }
    }

    @IBInspectable
    private var _subtitle: String? {
        get {
            return titleAccessoryView.accessoryLabel.text
        }

        set(newValue) {
            titleAccessoryView.accessoryLabel.text = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitleColor: UIColor? {
        get {
            return titleAccessoryView.accessoryLabel.textColor
        }

        set(newValue) {
            titleAccessoryView.accessoryLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedSubtitleColor: UIColor? {
        get {
            return titleAccessoryView.accessoryLabel.highlightedTextColor
        }

        set(newValue) {
            titleAccessoryView.accessoryLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        get {
            return titleAccessoryView.accessoryLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleAccessoryView.accessoryLabel.font = nil
                return
            }

            let pointSize = titleAccessoryView.accessoryLabel.font.pointSize
            titleAccessoryView.accessoryLabel.font = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        get {
            return titleAccessoryView.accessoryLabel.font.pointSize
        }

        set(newValue) {
            let fontName = titleAccessoryView.accessoryLabel.font.fontName
            titleAccessoryView.accessoryLabel.font = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _shadowColor: UIColor {
        get {
            return self.roundedBackgroundView!.shadowColor
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _shadowOffset: CGSize {
        get {
            return self.roundedBackgroundView!.shadowOffset
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOffset = newValue
        }
    }

    @IBInspectable
    private var _shadowRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.shadowRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowRadius = newValue
        }
    }

    @IBInspectable
    private var _shadowOpacity: Float {
        get {
            return self.roundedBackgroundView!.shadowOpacity
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOpacity = newValue
        }
    }

    @IBInspectable
    private var _cornerRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.cornerRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.cornerRadius = newValue
        }
    }

    @IBInspectable
    private var _contentOpacityWhenHighlighted: CGFloat {
        get {
            return contentOpacityWhenHighlighted
        }

        set(newValue) {
            contentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _changesContentOpacityWhenHighlighted: Bool {
        get {
            return changesContentOpacityWhenHighlighted
        }

        set(newValue) {
            changesContentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _separatorColor: UIColor {
        get {
            return borderView.strokeColor
        }

        set {
            borderView.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _separatorWidth: CGFloat {
        get {
            return borderView.strokeWidth
        }

        set {
            borderView.strokeWidth = newValue
        }
    }
}
