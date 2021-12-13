/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

struct ChainStorageDecodedItem<T: Equatable & Decodable>: Equatable {
    let identifier: String
    let item: T
}

extension ChainStorageDecodedItem: Identifiable {}
