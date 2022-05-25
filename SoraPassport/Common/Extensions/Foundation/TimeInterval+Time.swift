/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

extension TimeInterval {
    var milliseconds: Int { Int(1000 * self) }
}
