import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto
import RobinHood

struct IdentityOperationConstants {
    static let ddoPublicKeyIndex = 1
}

enum IdentityCreationOperationError: Error {
    case seedFactoryCreationFailed
    case invalidPrivateKeySeed
    case invalidEntropy
    case keypairCreationFailed
    case invalidKeypair
}

final class IdentityCreationOperation: BaseOperation<DecentralizedDocumentObject> {
    let keystore: KeystoreProtocol

    let secondaryServices: [SecondaryIdentityServiceProtocol]

    var privateKeyStoreId: String = KeystoreKey.privateKey.rawValue
    var seedEntropyStoreId: String = KeystoreKey.seedEntropy.rawValue

    init(keystore: KeystoreProtocol, secondaryServices: [SecondaryIdentityServiceProtocol]) {
        self.keystore = keystore
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
            let (documentObject, keypairResult) = try createDocumentObject()
            try keystore.saveKey(keypairResult.keypair.privateKey().rawData(), with: privateKeyStoreId)
            try keystore.saveKey(keypairResult.mnemonic.entropy(), with: seedEntropyStoreId)

            try secondaryServices.forEach { try $0.createIdentity(using: keystore, skipIfExists: false) }

            result = .success(documentObject)

        } catch {
            result = .failure(error)
        }
    }

    private func createDocumentObject() throws -> (DecentralizedDocumentObject, IRKeypairFacadeResult) {
        let result = try IRKeypairFacade().createKeypair()

        let username = result.keypair.publicKey().decentralizedUsername
        let domain = ApplicationConfig.shared.decentralizedDomain

        let documentFactory = DDOFactory()

        let decentralizedId = documentFactory.createDecentralizedIdFrom(username: username,
                                                                        domain: domain)

        let publicKeyId = documentFactory.createPublicKeyIdFrom(username: username,
                                                                domain: domain,
                                                                ddoIndex: IdentityOperationConstants.ddoPublicKeyIndex)

        let signatureCreator = IRIrohaSigner(privateKey: result.keypair.privateKey())

        let publicKey = DDOPublicKey(pubKeyId: publicKeyId,
                                     type: .ed25519Sha3Verification,
                                     owner: decentralizedId,
                                     publicKey: result.keypair.publicKey().rawData().soraHex)

        let auth = DDOAuthentication(type: .ed25519Sha3, publicKey: publicKeyId)

        let documentObject = try DDOBuilder.createDefault()
            .with(decentralizedId: decentralizedId)
            .with(publicKeys: [publicKey])
            .with(authentications: [auth])
            .with(signer: signatureCreator)
            .build()

        return (documentObject, result)
    }
}
