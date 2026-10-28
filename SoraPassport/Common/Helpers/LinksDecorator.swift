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

import Foundation

protocol LinkDecoratorProtocol {
    func links(inText: inout String) -> [(URL, NSRange)]
}

class LinkDecorator: LinkDecoratorProtocol {
    let pattern: String
    let urls: [URL]

    init(pattern: String, urls: [URL]) {
        self.pattern = pattern
        self.urls = urls
    }

    func links(inText text: inout String) -> [(URL, NSRange)] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: text.utf16.count)
        let results = regex.matches(in: text, options: [], range: range)
        var links: [(URL, NSRange)] = []
        for result in results.enumerated() {
            let locationAfterRemovingPercents = result.element.range.location - 2 * 2 * result.offset
            let lengthAfterRemovingPercents = result.element.range.length - 4
            let trimmedRange = NSRange(location: locationAfterRemovingPercents, length: lengthAfterRemovingPercents)
            links.append((urls[result.offset], trimmedRange))
        }
        text = text.replacingOccurrences(of: "%%", with: "")

        return links
    }
}

class LinkDecoratorFactory {
    static func disclaimerDecorator() -> LinkDecorator {
        let pattern = "(%%.*?%%)" //detects substrings like %%Polkaswap FAQ%%
        let urls = [URL(string: "https://wiki.sora.org/polkaswap/polkaswap-faq")!,
                    URL(string: "https://wiki.sora.org/polkaswap/terms")!,
                    URL(string: "https://wiki.sora.org/polkaswap/privacy")!
        ]

        return LinkDecorator(pattern: pattern, urls: urls)
    }
    
    static func contactDecorator() -> LinkDecorator {
        let pattern = "(%%.*?%%)" //detects substrings like %%Polkaswap FAQ%%
        let urls = [URL(string: "https://wiki.sora.org/polkaswap/polkaswap-faq")!
        ]

        return LinkDecorator(pattern: pattern, urls: urls)
    }
    
    static func termsDecorator() -> LinkDecorator {
        let pattern = "(%%.*?%%)" //detects substrings like %%Polkaswap FAQ%%
        let urls = [ ApplicationConfig.shared.termsURL, ApplicationConfig.shared.privacyPolicyURL ]
        return LinkDecorator(pattern: pattern, urls: urls)
    }
}
