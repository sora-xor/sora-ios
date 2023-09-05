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
import SoraUIKit

extension CompoundAttributedStringDecorator {
    static func legal(for locale: Locale?) -> AttributedStringDecoratorProtocol {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.neumorphism.textDark()!,
            .font: UIFont.styled(for: .paragraph2)!
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.neumorphism.text()!,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        let termsConditions = R.string.localizable
            .tutorialTermsAndConditions3(preferredLanguages: locale?.rLanguages)
        let termDecorator = HighlightingAttributedStringDecorator(
            pattern: termsConditions, attributes: highlightAttributes)

        let privacyPolicy = R.string.localizable
            .tutorialPrivacyPolicy(preferredLanguages: locale?.rLanguages)
        let privacyDecorator = HighlightingAttributedStringDecorator(
            pattern: privacyPolicy, attributes: highlightAttributes)

        return CompoundAttributedStringDecorator(
            decorators: [rangeDecorator, termDecorator, privacyDecorator]
        )
    }

    static func legalRedesign(for locale: Locale?) -> AttributedStringDecoratorProtocol {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgPrimary),
            .font: FontType.textXS.font
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary),
            .font: FontType.textXS.font
        ]

        let termsConditions = R.string.localizable
            .tutorialTermsAndConditions3(preferredLanguages: locale?.rLanguages)
        let termDecorator = HighlightingAttributedStringDecorator(
            pattern: termsConditions, attributes: highlightAttributes)

        let privacyPolicy = R.string.localizable
            .tutorialPrivacyPolicy(preferredLanguages: locale?.rLanguages)
        let privacyDecorator = HighlightingAttributedStringDecorator(
            pattern: privacyPolicy, attributes: highlightAttributes)

        return CompoundAttributedStringDecorator(
            decorators: [rangeDecorator, termDecorator, privacyDecorator]
        )
    }
    
    static func contact(for locale: Locale?) -> AttributedStringDecoratorProtocol {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.baseContentQuaternary()!,
            .font: UIFont.styled(for: .paragraph2)!
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.baseContentPrimary()!
        ]

        let termsConditions = R.string.localizable
            .claimContact2(preferredLanguages: locale?.rLanguages)
        let termDecorator = HighlightingAttributedStringDecorator(
            pattern: termsConditions, attributes: highlightAttributes)

        return CompoundAttributedStringDecorator(
            decorators: [rangeDecorator, termDecorator]
        )
    }
    
    static func contactRedesign(for locale: Locale?) -> AttributedStringDecoratorProtocol {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: SoramitsuUI.shared.theme.palette.color(.fgPrimary),
            .font: FontType.textXS.font
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.baseContentPrimary()!
        ]

        let termsConditions = R.string.localizable
            .claimContact2(preferredLanguages: locale?.rLanguages)
        let termDecorator = HighlightingAttributedStringDecorator(
            pattern: termsConditions, attributes: highlightAttributes)

        return CompoundAttributedStringDecorator(
            decorators: [rangeDecorator, termDecorator]
        )
    }
}
