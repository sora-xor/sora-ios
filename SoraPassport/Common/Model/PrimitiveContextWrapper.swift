/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class PrimitiveContextWrapper<T> {
    let value: T

    init(value: T) {
        self.value = value
    }
}
