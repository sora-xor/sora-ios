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

extension CharacterSet {
    static var personName: CharacterSet {
        CharacterSet.letters.union(CharacterSet.personNameSeparators).union(CharacterSet.emojiSet)
    }

    static var personNameSeparators: CharacterSet {
        CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-'"))
    }

    static var email: CharacterSet {
        CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._%+-@"))
    }

    static var phone: CharacterSet {
        CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "+"))
    }

    static var emojiSet: CharacterSet {
        var emoji = CharacterSet()

        for codePoint in 0x0000...0x2F0000 {
            guard let scalarValue = Unicode.Scalar(codePoint) else {
                continue
            }

            if scalarValue.properties.isEmojiPresentation {
                emoji.insert(scalarValue)
//                print(scalarValue, " ", codePoint)
            }
        }
        return emoji
    }

}
