/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol AttributedStringDecoratorProtocol: class {
    func decorate(attributedString: NSAttributedString) -> NSAttributedString
}

final class HighlightingAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let pattern: String
    let attributes: [NSAttributedString.Key: Any]

    init(pattern: String, attributes: [NSAttributedString.Key: Any]) {
        self.pattern = pattern
        self.attributes = attributes
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        let string = attributedString.string

        guard
            let range = attributedString.string.range(of: pattern),
            let resultAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString else {
                return attributedString
        }

        let from = string.distance(from: string.startIndex, to: range.lowerBound)
        let length = string.distance(from: range.lowerBound, to: range.upperBound)

        let nsRange = NSRange(location: from, length: length)

        resultAttributedString.addAttributes(attributes, range: nsRange)

        return resultAttributedString
    }
}

final class RangeAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let range: NSRange?
    let attributes: [NSAttributedString.Key: Any]

    init(attributes: [NSAttributedString.Key: Any], range: NSRange? = nil) {
        self.range = range
        self.attributes = attributes
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        let applicationRange = range ?? NSRange(location: 0, length: attributedString.length)

        guard let resultAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString else {
            return attributedString
        }

        resultAttributedString.addAttributes(attributes, range: applicationRange)
        return resultAttributedString
    }
}

final class CompoundAttributedStringDecorator: AttributedStringDecoratorProtocol {
    let decorators: [AttributedStringDecoratorProtocol]

    init(decorators: [AttributedStringDecoratorProtocol]) {
        self.decorators = decorators
    }

    func decorate(attributedString: NSAttributedString) -> NSAttributedString {
        return decorators.reduce(attributedString) { (result, decorator) in
            return decorator.decorate(attributedString: result)
        }
    }
}
