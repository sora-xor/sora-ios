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

@IBDesignable
extension DetailsRoundedView {

    @IBInspectable
    var fillColor: UIColor {
        get {
            triangularedBackgroundView!.fillColor
        }

        set {
            triangularedBackgroundView!.fillColor = newValue
        }
    }

    @IBInspectable
    var highlightedFillColor: UIColor {
        get {
            triangularedBackgroundView!.highlightedFillColor
        }

        set {
            triangularedBackgroundView!.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    var strokeColor: UIColor {
        get {
            triangularedBackgroundView!.strokeColor
        }

        set {
            triangularedBackgroundView!.strokeColor = newValue
        }
    }

    @IBInspectable
    var highlightedStrokeColor: UIColor {
        get {
            triangularedBackgroundView!.highlightedStrokeColor
        }

        set {
            triangularedBackgroundView!.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    var title: String? {
        get {
            return titleLabel.text
        }

        set {
            titleLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var subtitle: String? {
        get {
            return subtitleLabel?.text
        }

        set {
            subtitleLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var titleColor: UIColor? {
        get {
            return titleLabel.textColor
        }

        set {
            titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    var highlightedTitleColor: UIColor? {
        get {
            return titleLabel.highlightedTextColor
        }

        set {
            titleLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    var subtitleColor: UIColor? {
        get {
            return subtitleLabel?.textColor
        }

        set {
            subtitleLabel?.textColor = newValue
        }
    }

    @IBInspectable
    var highlightedSubtitleColor: UIColor? {
        get {
            return subtitleLabel?.highlightedTextColor
        }

        set {
            subtitleLabel?.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            return titleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleLabel.font = nil
                return
            }

            let pointSize = titleLabel.font.pointSize

            titleLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            titleLabel.font.pointSize
        }

        set(newValue) {
            let fontName = titleLabel.font.fontName

            titleLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        get {
            return titleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleLabel.font = nil
                return
            }

            let pointSize = subtitleLabel?.font.pointSize ?? UIFont.labelFontSize

            subtitleLabel?.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        get {
            subtitleLabel?.font.pointSize ?? 0.0
        }

        set(newValue) {
            guard let fontName = subtitleLabel?.font.fontName else {
                return
            }

            subtitleLabel?.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var iconImage: UIImage? {
        get {
            return iconView.image
        }

        set {
            iconView.image = newValue
        }
    }

    @IBInspectable
    var actionImage: UIImage? {
        get {
            return actionView.image
        }

        set {
            actionView.image = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var actionTintColor: UIColor? {
        get {
            return actionView.tintColor
        }

        set {
            actionView.tintColor = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            triangularedBackgroundView?.strokeWidth ?? 0.0
        }

        set {
            triangularedBackgroundView?.strokeWidth = newValue
        }
    }

    @IBInspectable
    private var _iconRadius: CGFloat {
        get {
            iconRadius
        }

        set {
            iconRadius = newValue
        }
    }

    @IBInspectable
    private var _horizontalSpacing: CGFloat {
        get {
            horizontalSpacing
        }

        set {
            horizontalSpacing = newValue
        }
    }

    @IBInspectable
    private var _layout: UInt8 {
        get {
            switch layout {
            case .largeIconTitleSubtitle:
                return 0
            case .smallIconTitleSubtitle:
                return 1
            case .singleTitle:
                return 2
            }
        }

        set {
            switch newValue {
            case 0:
                layout = .largeIconTitleSubtitle
            case 1:
                layout = .smallIconTitleSubtitle
            default:
                layout = .singleTitle
            }
        }
    }
}
