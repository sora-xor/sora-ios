import Foundation
@testable import SoraPassport
//import SoraCrypto
import SoraKeystore
import IrohaCrypto
import RobinHood
/*
@discardableResult
func createIdentity(with keystore: KeystoreProtocol) -> DecentralizedDocumentObject {
    let identityOperation = IdentityOperationFactory().createNewIdentityOperation(with: keystore)

    let semaphore = DispatchSemaphore(value: 0)

    var ddo: DecentralizedDocumentObject?

    identityOperation.completionBlock = {
        defer {
            semaphore.signal()
        }

        guard let result = identityOperation.result, case .success(let document) = result else {
            return
        }

        ddo = document
    }

    OperationManagerFacade.sharedManager.enqueue(operations: [identityOperation], in: .transient)

    _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(5 * 1000)))

    return ddo!
}

@discardableResult
func setupKeystoreAndDdo(for mnemonicString: String, keystore: KeystoreProtocol) throws -> DecentralizedDocumentObject {

    let mnemonic = try IRMnemonicCreator(language: .english).mnemonic(fromList: mnemonicString)
    let ddoCreationOperation = IdentityOperationFactory()
        .createRestorationOperation(with: mnemonic, keystore: keystore)

    let semaphore = DispatchSemaphore(value: 0)

    ddoCreationOperation.completionBlock = {
        semaphore.signal()
    }

    OperationManagerFacade.sharedManager.enqueue(operations: [ddoCreationOperation],
                                                 in: .transient)

    let status = semaphore.wait(timeout: .now() + 10.0)

    guard status == .success else {
        throw BaseOperationError.unexpectedDependentResult
    }

    guard let result = ddoCreationOperation.result else {
        throw BaseOperationError.parentOperationCancelled
    }

    switch result {
    case .success(let ddo):
        return ddo
    case .failure(let error):
        throw error
    }
}
*/
