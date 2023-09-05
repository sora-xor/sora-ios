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
