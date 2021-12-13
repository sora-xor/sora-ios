/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

public protocol Withable {
    init()
}

public extension Withable {
    init(with config: (inout Self) -> Void) {
        self.init()
        config(&self)
    }

    func with(_ config: (inout Self) -> Void) -> Self {
        var copy = self
        config(&copy)
        return copy
    }
}
