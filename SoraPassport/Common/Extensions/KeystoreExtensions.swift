/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore

enum KeystoreKey: String, CaseIterable {
    case privateKey
    case pincode
    case seedEntropy
}

extension KeystoreProtocol {
    func deleteAll() throws {
        try deleteKeysIfExist(for: KeystoreKey.allCases.map({ $0.rawValue }))
    }
}
