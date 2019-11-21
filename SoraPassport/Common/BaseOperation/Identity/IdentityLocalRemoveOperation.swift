/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import RobinHood

enum IdentityLocalRemoveOperationError: Error {
    case privateKeyRemoveFailed
    case pincodeRemoveFailed
}

final class IdentityLocalRemoveOperation: BaseOperation<Bool> {
    let keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol

    var privateKeyStoreId: String = KeystoreKey.privateKey.rawValue
    var decentralizedIdKey: String = SettingsKey.decentralizedId.rawValue
    var publicKeyIdKey = SettingsKey.publicKeyId.rawValue

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    override func main() {
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            try keystore.deleteKeyIfExists(for: privateKeyStoreId)
            settings.removeValue(for: decentralizedIdKey)
            settings.removeValue(for: publicKeyIdKey)

            result = .success(true)
        } catch {
            result = .failure(error)
        }
    }
}
