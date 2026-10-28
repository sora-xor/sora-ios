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

protocol AttributedStringDecoratorProtocol: AnyObject {
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
        let string = attributedString.string as NSString
        let range = string.range(of: pattern)

        guard
            range.location != NSNotFound,
            let resultAttributedString = attributedString.mutableCopy() as? NSMutableAttributedString else {
                return attributedString
        }

        resultAttributedString.addAttributes(attributes, range: range)

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
