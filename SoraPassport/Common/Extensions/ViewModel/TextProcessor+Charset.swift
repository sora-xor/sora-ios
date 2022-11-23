/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation

extension DuplicatingCharacterProcessor {
    static var personName: DuplicatingCharacterProcessor {
        DuplicatingCharacterProcessor(charset: CharacterSet.personNameSeparators)
    }
}

extension PrefixCharacterProcessor {
    static var personName: PrefixCharacterProcessor {
        PrefixCharacterProcessor(charset: CharacterSet.personNameSeparators)
    }
}

extension TrimmingCharacterProcessor {
    static var personName: TrimmingCharacterProcessor {
        TrimmingCharacterProcessor(charset: CharacterSet.whitespaces)
    }
}

extension CompoundTextProcessor {
    static var personName: CompoundTextProcessor {
        let processors: [TextProcessing] = [
            PrefixCharacterProcessor.personName,
            DuplicatingCharacterProcessor.personName
        ]

        return CompoundTextProcessor(processors: processors)
    }
}
