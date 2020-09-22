/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood

enum IdentityVerifyOperationError: Error {
    case requiredDocumentObjectMissing
    case signatureVerificationFailed
    case signatureInvalid
    case privateKeyFetchFailed
    case privateKeyDataInvalid
    case keypairDeriviationFailed
    case authenticablePublicKeyNotFound
}

final class IdentityVerifyOperation: BaseOperation<String> {
    let verifier: DDOVerifierProtocol
    let keystore: KeystoreProtocol

    var privateKeyStoreId: String = KeystoreKey.privateKey.rawValue

    var decentralizedDocument: DecentralizedDocumentObject?

    init(verifier: DDOVerifierProtocol, keystore: KeystoreProtocol) {
        self.verifier = verifier
        self.keystore = keystore
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
            guard let decentralizedDocument = decentralizedDocument else {
                throw IdentityVerifyOperationError.requiredDocumentObjectMissing
            }

            guard let isDocumentValid = try? verifier.verify(decentralizedDocument) else {
                throw IdentityVerifyOperationError.signatureVerificationFailed
            }

            if !isDocumentValid {
                throw IdentityVerifyOperationError.signatureInvalid
            }

            guard let privateKeyData = try? keystore.fetchKey(for: privateKeyStoreId) else {
                throw IdentityVerifyOperationError.privateKeyFetchFailed
            }

            guard let privateKey = try? IRIrohaPrivateKey(rawData: privateKeyData) else {
                throw IdentityVerifyOperationError.privateKeyDataInvalid
            }

            guard let keypair = try? IRIrohaKeyFactory().derive(fromPrivateKey: privateKey) else {
                throw IdentityVerifyOperationError.keypairDeriviationFailed
            }

            let publicKeyData = keypair.publicKey().rawData()
            guard let ddoPublicKey = decentralizedDocument.authenticablePublicKey(for: publicKeyData) else {
                throw IdentityVerifyOperationError.authenticablePublicKeyNotFound
            }

            result = .success(ddoPublicKey.pubKeyId)

        } catch {
            result = .failure(error)
        }
    }
}
