/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood

final class IdentityRestorationOperation: BaseOperation<DecentralizedDocumentObject> {
    let keystore: KeystoreProtocol
    let mnemonic: IRMnemonicProtocol

    let secondaryServices: [SecondaryIdentityServiceProtocol]

    var privateKeyStoreId: String = KeystoreKey.privateKey.rawValue
    var seedEntropyStoreId: String = KeystoreKey.seedEntropy.rawValue

    init(keystore: KeystoreProtocol,
         mnemonic: IRMnemonicProtocol,
         secondaryServices: [SecondaryIdentityServiceProtocol]) {
        self.keystore = keystore
        self.mnemonic = mnemonic
        self.secondaryServices = secondaryServices
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
            let (documentObject, keypair) = try createDocumentObject()
            try keystore.saveKey(mnemonic.entropy(), with: seedEntropyStoreId)
            try keystore.saveKey(keypair.privateKey().rawData(), with: privateKeyStoreId)

            try secondaryServices.forEach { try $0.createIdentity(using: keystore, skipIfExists: false) }

            result = .success(documentObject)

        } catch {
            result = .failure(error)
        }
    }

    private func createDocumentObject() throws -> (DecentralizedDocumentObject, IRCryptoKeypairProtocol) {
        let keypair = try IRKeypairFacade().deriveKeypair(from: mnemonic.toString())

        let username = keypair.publicKey().decentralizedUsername
        let domain = ApplicationConfig.shared.decentralizedDomain

        let documentFactory = DDOFactory()

        let decentralizedId = documentFactory.createDecentralizedIdFrom(username: username,
                                                                        domain: domain)

        let publicKeyId = documentFactory.createPublicKeyIdFrom(username: username,
                                                                domain: domain,
                                                                ddoIndex: IdentityOperationConstants.ddoPublicKeyIndex)

        let signatureCreator = IRIrohaSigner(privateKey: keypair.privateKey())

        let publicKey = DDOPublicKey(pubKeyId: publicKeyId,
                                     type: .ed25519Sha3Verification,
                                     owner: decentralizedId,
                                     publicKey: keypair.publicKey().rawData().soraHex)

        let auth = DDOAuthentication(type: .ed25519Sha3, publicKey: publicKeyId)

        let documentObject = try DDOBuilder.createDefault()
            .with(decentralizedId: decentralizedId)
            .with(publicKeys: [publicKey])
            .with(authentications: [auth])
            .with(signer: signatureCreator)
            .build()

        return (documentObject, keypair)
    }
}
