/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

func createRandomPhoneInput() -> String {
    return (0..<10).map { _ in
        return String((0..<10).randomElement()!)
    }.joined(separator: "")
}
