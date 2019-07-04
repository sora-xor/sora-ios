/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import IrohaCrypto

class IRSigningDecorator {
    var keystore: KeystoreProtocol
    var identifier: String

    var logger: LoggerProtocol?

    init(keystore: KeystoreProtocol, identifier: String) {
        self.keystore = keystore
        self.identifier = identifier
    }
}

extension IRSigningDecorator: IRSignatureCreatorProtocol {
    func sign(_ originalData: Data) -> IRSignatureProtocol? {
        guard let rawKey = try? keystore.fetchKey(for: identifier) else {
            logger?.error("Can't find private key for signing")
            return nil
        }

        guard let privateKey = IREd25519PrivateKey(rawData: rawKey) else {
            logger?.error("Invalid private key for signing fetched")
            return nil
        }

        let rawSigner = IREd25519Sha512Signer(privateKey: privateKey)

        return rawSigner?.sign(originalData)
    }
}
