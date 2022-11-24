/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct StorageRequestParams {
    let path: StorageCodingPath
    let shouldFallback: Bool

    init(path: StorageCodingPath, shouldFallback: Bool = true) {
        self.path = path
        self.shouldFallback = shouldFallback
    }
}
