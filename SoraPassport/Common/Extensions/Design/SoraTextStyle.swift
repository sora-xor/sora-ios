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

enum SoraTextStyle {
    /// Base ExtraBold font for large titles
    ///   - `fontSize: (base: 28, max: 32)`
    ///   - `attributes: (kern: -0.84, lineHeightMultiple: 0.0)`
    ///   - `textStyle: UIFont.TextStyle.largeTitle`
    case display1

    /// Base ExtraBold font for large titles neomorphism
    ///   - `fontSize: (base: 21, max: nil)`
    ///   - `attributes: (kern: -0.84, lineHeightMultiple: 0.0)`
    ///   - `textStyle: UIFont.TextStyle.largeTitle`
    case display2
    
    /// Base Bold font for titles
    ///   - `fontSize: (base: 24, max: 28)`
    ///   - `attributes: (kern: -0.72, lineHeightMultiple: 0.0)`
    ///   - `textStyle: UIFont.TextStyle.title1`
    case title1

    /// Base Bold font for titles
    ///   - `fontSize: (base: 22, max: 26)`
    ///   - `attributes: (kern: -0.66, lineHeightMultiple: 0.0)`
    ///   - `textStyle: UIFont.TextStyle.title2`
    case title2

    /// Base Bold font for titles
    ///   - `fontSize: (base: 20, max: 24)`
    ///   - `attributes: (kern: -0.60, lineHeightMultiple: 0.0)`
    ///   - `textStyle: UIFont.TextStyle.title3`
    case title3

    /// Base Bold font for titles
    ///   - `fontSize: (base: 18, max: 22)`
    ///   - `attributes: (kern: 0.0, lineHeightMultiple: 0.0)`
    ///   - `textStyle: UIFont.TextStyle.callout`
    case title4

    /// Base Regular or Bold font for text
    ///   - `fontSize: (base: 16, max: nil)`
    ///   - `attributes: (kern: -0.32, lineHeightMultiple: 1.09)`
    ///   - `textStyle: UIFont.TextStyle.body`
    case paragraph1

    /// Base Regular or Bold font for text
    ///   - `fontSize: (base: 14, max: nil)`
    ///   - `attributes: (kern: -0.28, lineHeightMultiple: 1.13)`
    ///   - `textStyle: UIFont.TextStyle.body`
    case paragraph2

    /// Base Regular or Bold font for text
    ///   - `fontSize: (base: 12, max: nil)`
    ///   - `attributes: (kern: -0.24, lineHeightMultiple: 1.19)`
    ///   - `textStyle: UIFont.TextStyle.body`
    case paragraph3

    /// Base Regular or Bold font for text
    ///   - `fontSize: (base: 10, max: nil)`
    ///   - `attributes: (kern: -0.20, lineHeightMultiple: 1.27)`
    ///   - `textStyle: UIFont.TextStyle.body`
    case paragraph4

    /// Base Regular or Bold font for emphasized text
    ///   - `fontSize: (base: 14, max: 18)`
    ///   - `attributes: (kern: +0.42, lineHeightMultiple: 1.13)`
    ///   - `textStyle: UIFont.TextStyle.caption2`
    case uppercase1

    /// Base Regular or Bold font for emphasized text
    ///   - `fontSize: (base: 12, max: 16)`
    ///   - `attributes: (kern: +0.48, lineHeightMultiple: 1.32)`
    ///   - `textStyle: UIFont.TextStyle.caption2`
    case uppercase2

    /// Base Regular or Bold font for emphasized text
    ///   - `fontSize: (base: 10, max: 14)`
    ///   - `attributes: (kern: +0.40, lineHeightMultiple: 1.59)`
    ///   - `textStyle: UIFont.TextStyle.caption2`
    case uppercase3

    case button

}

extension SoraTextStyle {

    func fontName(isBold: Bool = false) -> String {
        let fontStyleName: String

        switch self {
        case .display1, .display2:
            fontStyleName = "ExtraBold"
        case .title1:
            fontStyleName = "Regular"

        case .title2, .title3, .title4:
            fontStyleName = "Bold"

        case .paragraph1, .paragraph2, .paragraph3, .paragraph4:
            fontStyleName = isBold ? "Bold" : "Light"

        case .uppercase1, .uppercase2, .uppercase3:
            fontStyleName = isBold ? "Bold" : "Regular"
        case .button:
            fontStyleName = isBold ?  "SemiBold" : "Bold"
        }

        return "Sora-\(fontStyleName)"
    }

    var fontSize: (base: CGFloat, max: CGFloat?) {
        switch self {
        case .display1:     return (base: 28, max: 32)
        case .display2:     return (base: 21, max: nil)
        case .title1:       return (base: 18, max: 21)
        case .title2:       return (base: 22, max: 26)
        case .title3:       return (base: 20, max: 24)
        case .title4:       return (base: 18, max: 22)
        case .paragraph1:   return (base: 15, max: nil)
        case .paragraph2:   return (base: 13, max: nil)
        case .paragraph3:   return (base: 12, max: nil)
        case .paragraph4:   return (base: 10, max: nil)
        case .uppercase1:   return (base: 14, max: 18)
        case .uppercase2:   return (base: 12, max: 16)
        case .uppercase3:   return (base: 10, max: 14)
        case .button:       return (base: 21, max: 21)
        }
    }

    var textStyle: UIFont.TextStyle {
        switch self {
        case .display1:     return .largeTitle
        case .display2:     return .largeTitle
        case .title1:       return .title1
        case .title2:       return .title2
        case .title3:       return .title3
        case .title4:       return .callout
        case .paragraph1:   return .body
        case .paragraph2:   return .body
        case .paragraph3:   return .body
        case .paragraph4:   return .body
        case .uppercase1:   return .caption2
        case .uppercase2:   return .caption2
        case .uppercase3:   return .caption2
        case .button:       return .title1
        }
    }

    var attributes: (kern: CGFloat, lineHeightMultiple: CGFloat) {
        switch self {
        case .display1:     return (kern: -0.84, lineHeightMultiple: 0.00)
        case .display2:     return (kern: -0.84, lineHeightMultiple: 0.00)
        case .title1:       return (kern: -0.72, lineHeightMultiple: 0.00)
        case .title2:       return (kern: -0.66, lineHeightMultiple: 0.00)
        case .title3:       return (kern: -0.60, lineHeightMultiple: 0.00)
        case .title4:       return (kern: +0.00, lineHeightMultiple: 0.00)
        case .paragraph1:   return (kern: -0.32, lineHeightMultiple: 1.09)
        case .paragraph2:   return (kern: -0.28, lineHeightMultiple: 1.13)
        case .paragraph3:   return (kern: -0.24, lineHeightMultiple: 1.19)
        case .paragraph4:   return (kern: -0.20, lineHeightMultiple: 1.27)
        case .uppercase1:   return (kern: +0.42, lineHeightMultiple: 1.13)
        case .uppercase2:   return (kern: +0.48, lineHeightMultiple: 1.32)
        case .uppercase3:   return (kern: +0.40, lineHeightMultiple: 1.59)
        case .button:       return (kern: -0.63, lineHeightMultiple: 0.79)
        }
    }

    var fontFeatures: [[UIFontDescriptor.FeatureKey: Any]] {
        [
            [UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType,
             UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector
            ],
            [UIFontDescriptor.FeatureKey.featureIdentifier: kNumberCaseType,
             UIFontDescriptor.FeatureKey.typeIdentifier: kUpperCaseNumbersSelector
            ]
        ]
    }
}

extension String {

    /// Return attributed string for selected Sora text style
    /// - Parameters:
    ///   - style: Sora text style (by design)
    ///   - lineBreakMode: lineBreakMode (by design)
    /// - Returns: Modified instance of `NSAttributedString`
    func styled(_ style: SoraTextStyle,
                lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> NSAttributedString {
        return attributed(
            kern: style.attributes.kern,
            lineHeightMultiple: style.attributes.lineHeightMultiple,
            lineBreakMode: lineBreakMode
        )
    }

    /// Return attributed string
    /// - Parameters:
    ///   - kern: `CGFloat`; default value = `0.0`
    ///   - lineHeightMultiple: `CGFloat`; default value = `0.0`
    ///   - lineBreakMode: `NSLineBreakMode`; default value = `byTruncatingTail`
    /// - Returns: Instance of `NSAttributedString`
    private func attributed(
        kern: CGFloat = 0.0,
        lineHeightMultiple: CGFloat = 0.0,
        lineBreakMode: NSLineBreakMode = .byTruncatingTail) -> NSAttributedString {

        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.lineBreakMode = lineBreakMode

        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style,
            .kern: kern
        ]

        return NSAttributedString(string: self, attributes: attributes)
    }

    typealias Style = [NSAttributedString.Key: Any]
    func decoratedWith(_  baseStyle: Style, adding style: Style, to substrings: [String]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: self, attributes: baseStyle)
        for substring in substrings {
            if let range = self.range(of: substring) {
                let decoRange = NSRange(range, in: self)
                result.addAttributes(style, range: decoRange)
            }
        }
        return result
    }

    func decoratedWith(_  baseStyle: Style, adding style: Style, to range: Range<Index>) -> NSAttributedString {
        let result = NSMutableAttributedString(string: self, attributes: baseStyle)
        let decoRange = NSRange(range, in: self)
        result.addAttributes(style, range: decoRange)
        return result
    }

    func prettyCurrency(baseFont: UIFont, smallSize: CGFloat = 13, locale currentLocale: Locale) -> NSAttributedString {
        let result: NSAttributedString
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byCharWrapping
        style.lineHeightMultiple = 0.95
        style.alignment = .right
        let attributes: Style = [.font: baseFont, .paragraphStyle: style, .kern: -1]

        if let separation = self.firstIndex(of: Character(currentLocale.decimalSeparator ?? ".")) {
            let adjusted = self.index(after: separation)
            let range: Range = adjusted..<self.endIndex
            let decorated = self.decoratedWith(attributes, adding: [.font: baseFont.withSize(smallSize)], to: range)

            result = decorated
        } else {
            result = NSMutableAttributedString(string: self, attributes: attributes)
        }
        return result
    }
}

extension UIFont {

    /// Return instance of SoraFont with style by design
    /// - Parameters:
    ///   - style: Sora text style (by design)
    ///   - isBold: bold or regular font
    /// - Returns: Return instance of SoraFont
    static func styled(
        for style: SoraTextStyle,
        isBold: Bool = false) -> UIFont! {

        let font = UIFont(
            name: style.fontName(isBold: isBold),
            size: style.fontSize.base
        )

        let fontDescriptor = font?.fontDescriptor.addingAttributes([UIFontDescriptor.AttributeName.featureSettings: style.fontFeatures])
        let featuredFont = UIFont(descriptor: fontDescriptor!, size: style.fontSize.base)
        return featuredFont.with(soraStyle: style)
    }

    private func with(soraStyle: SoraTextStyle) -> UIFont {
        return with(
            textStyle: soraStyle.textStyle,
            baseFontSize: soraStyle.fontSize.base,
            maxFontSize: soraStyle.fontSize.max
        )
    }

    private func with(
        textStyle: UIFont.TextStyle,
        baseFontSize: CGFloat,
        maxFontSize: CGFloat? = nil) -> UIFont {

        if let maxPointSize = maxFontSize {
            return UIFontMetrics(forTextStyle: textStyle)
                .scaledFont(
                    for: self.withSize(baseFontSize),
                    maximumPointSize: maxPointSize
                )
        }

        return UIFontMetrics(forTextStyle: textStyle)
            .scaledFont(
                for: self.withSize(baseFontSize)
            )
    }
}

extension NSAttributedString {

    var wholeRange: NSRange {
        NSRange(location: 0, length: self.length)
    }

    static var space: NSAttributedString {
        NSAttributedString(string: " ")
    }

    func aligned(_ alignment: NSTextAlignment) -> NSAttributedString {

        let attributedString = NSMutableAttributedString(attributedString: self)

        let style = NSMutableParagraphStyle()
        style.alignment = alignment

        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: style
        ]

        let range = NSRange(location: 0, length: attributedString.length)

        attributedString.addAttributes(attributes, range: range)

        return attributedString
    }
}
