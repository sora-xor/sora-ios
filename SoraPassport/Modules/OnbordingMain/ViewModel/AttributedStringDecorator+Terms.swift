import UIKit

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
