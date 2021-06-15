/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

extension CompoundAttributedStringDecorator {
    static func legal(for locale: Locale?) -> AttributedStringDecoratorProtocol {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.baseContentQuaternary()!,
            .font: UIFont.styled(for: .paragraph2)!
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.baseContentPrimary()!
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
}
