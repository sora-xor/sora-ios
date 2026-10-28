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

extension NSPredicate {

    static var personName: NSPredicate {
        let format = "\\p{L}([\\s'\\-]*\\p{L})*"
        return NSPredicate { (inputText, _) -> Bool in
            guard let inputText = inputText as? String else {
                return false
            }
            let textWithoutEmoij = inputText.unicodeScalars
            .filter { !$0.properties.isEmojiPresentation}
            .reduce("") { $0 + String($1) }
            return NSPredicate(format: "SELF MATCHES %@", format).evaluate(with: textWithoutEmoij)
        }
    }

    static var invitationCode: NSPredicate {
        return NSPredicate(format: "SELF MATCHES %@", String.invitationCodePattern)
    }

    static var ethereumAddress: NSPredicate {
        let format = "0x[A-Fa-f0-9]{40}"
        return NSPredicate(format: "SELF MATCHES %@", format)
    }
}
