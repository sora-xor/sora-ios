/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension ByteLengthProcessor {
    static var username: ByteLengthProcessor {
        ByteLengthProcessor(maxLength: 32, encoding: .utf8)
    }
}
