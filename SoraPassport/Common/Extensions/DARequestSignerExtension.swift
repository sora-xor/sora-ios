/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto
import SoraKeystore
import IrohaCrypto

extension DARequestSigner {
    static func createDefault(with logger: LoggerProtocol? = Logger.shared) -> DARequestSigner? {
        guard let decentralizedId = SettingsManager.shared.decentralizedId else {
            logger?.warning("Decentralized identifier is missing")
            return nil
        }

        guard let publicKeyId = SettingsManager.shared.publicKeyId else {
            logger?.warning("Public key identifier is missing")
            return nil
        }

        let rawSigner = IRSigningDecorator(keystore: Keychain(), identifier: KeystoreKey.privateKey.rawValue)
        rawSigner.logger = logger

        let signer = DARequestSigner()
            .with(rawSigner: rawSigner)
            .with(decentralizedId: decentralizedId)
            .with(publicKeyId: publicKeyId)

        return signer
    }

    static func createFrom(document: DecentralizedDocumentObject,
                           rawSigner: IRSignatureCreatorProtocol) -> DARequestSigner? {
        guard let publicKeyId = document.publicKey.first?.pubKeyId else {
            return nil
        }

        let signer = DARequestSigner()
            .with(rawSigner: rawSigner)
            .with(decentralizedId: document.decentralizedId)
            .with(publicKeyId: publicKeyId)

        return signer
    }
}
