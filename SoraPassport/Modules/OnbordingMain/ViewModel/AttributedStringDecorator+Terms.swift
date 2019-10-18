/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

extension CompoundAttributedStringDecorator {
    static var legal: AttributedStringDecoratorProtocol {
        let textColor = UIColor(red: 155.0 / 255.0, green: 155.0 / 255.0, blue: 155.0 / 255.0, alpha: 1.0)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: R.font.soraRc0040417Regular(size: 12)!
        ]

        let rangeDecorator = RangeAttributedStringDecorator(attributes: attributes)

        let highlightAttributes: [NSAttributedString.Key: Any] = [
            .underlineStyle: NSNumber(value: NSUnderlineStyle.single.rawValue)
        ]

        let termDecorator = HighlightingAttributedStringDecorator(pattern: R.string.localizable.termsTitle(),
                                                                           attributes: highlightAttributes)
        let privacyDecorator = HighlightingAttributedStringDecorator(pattern: R.string.localizable.privacyTitle(),
                                                                     attributes: highlightAttributes)

        return CompoundAttributedStringDecorator(decorators: [rangeDecorator, termDecorator, privacyDecorator])
    }
}
