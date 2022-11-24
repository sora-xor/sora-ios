/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import IrohaCrypto
import SoraKeystore
import FearlessUtils

enum SigningWrapperError: Error {
    case missingSelectedAccount
    case missingSecretKey
}

final class SigningWrapper: SigningWrapperProtocol {
    let keystore: KeystoreProtocol
    let account: AccountItem

    init(keystore: KeystoreProtocol, account: AccountItem) {
        self.keystore = keystore
        self.account = account
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        guard let secretKey = try keystore.fetchSecretKeyForAddress(account.address) else {
            throw SigningWrapperError.missingSecretKey
        }

        switch account.cryptoType {
        case .sr25519:
            return try signSr25519(originalData,
                                   secretKeyData: secretKey,
                                   publicKeyData: account.publicKeyData)
        case .ed25519:
            return try signEd25519(originalData,
                                   secretKey: secretKey)
        case .ecdsa:
            return try signEcdsa(originalData,
                                 secretKey: secretKey)
        }
    }
}
