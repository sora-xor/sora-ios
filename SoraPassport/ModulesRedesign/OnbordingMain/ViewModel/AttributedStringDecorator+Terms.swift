// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
