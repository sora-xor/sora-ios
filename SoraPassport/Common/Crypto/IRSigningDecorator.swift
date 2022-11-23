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
    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        let rawKey = try keystore.fetchKey(for: identifier)

        let privateKey = try IRIrohaPrivateKey(rawData: rawKey)

        let rawSigner = IRIrohaSigner(privateKey: privateKey)

        return try rawSigner.sign(originalData)
    }

    func sign(_ originalData: Data, privateKey: IRPrivateKeyProtocol) throws -> IRSignatureProtocol {
        let rawSigner = IRIrohaSigner(privateKey: privateKey)

        return try rawSigner.sign(originalData)
    }
}
