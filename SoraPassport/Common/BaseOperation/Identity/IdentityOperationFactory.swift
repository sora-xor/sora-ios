import Foundation
import RobinHood
import SoraKeystore
import SoraCrypto
import IrohaCrypto

protocol IdentityOperationFactoryProtocol {
    func createNewIdentityOperation(with keystore: KeystoreProtocol) -> IdentityCreationOperation
    func createRestorationOperation(with mnemonic: IRMnemonicProtocol,
                                    keystore: KeystoreProtocol) -> IdentityRestorationOperation
    func createCopyingOperation(oldKeystore: KeystoreProtocol, newKeystore: KeystoreProtocol) -> IdentityCopyOperation
    func createVerificationOperation(with keystore: KeystoreProtocol) -> IdentityVerifyOperation
    func createLocalRemoveOperation(with keystore: KeystoreProtocol,
                                    settings: SettingsManagerProtocol) -> IdentityLocalRemoveOperation
    func createSecondaryIdentitiesOperation(with keystore: KeystoreProtocol, skipIfExists: Bool) -> BaseOperation<Void>
}

struct IdentityOperationFactory: IdentityOperationFactoryProtocol {

    func createNewIdentityOperation(with keystore: KeystoreProtocol) -> IdentityCreationOperation {
        let ethIdentityService = EthereumIdentityService()
        return IdentityCreationOperation(keystore: keystore,
                                         secondaryServices: [ethIdentityService])
    }

    func createRestorationOperation(with mnemonic: IRMnemonicProtocol,
                                    keystore: KeystoreProtocol) -> IdentityRestorationOperation {
        let ethIdentityService = EthereumIdentityService()
        return IdentityRestorationOperation(keystore: keystore, mnemonic: mnemonic,
                                            secondaryServices: [ethIdentityService])
    }

    func createVerificationOperation(with keystore: KeystoreProtocol) -> IdentityVerifyOperation {
        IdentityVerifyOperation(verifier: DDOVerifier.createDefault(), keystore: keystore)
    }

    func createLocalRemoveOperation(with keystore: KeystoreProtocol,
                                    settings: SettingsManagerProtocol) -> IdentityLocalRemoveOperation {
        let ethIdentityService = EthereumIdentityService()

        return IdentityLocalRemoveOperation(keystore: keystore,
                                            settings: settings,
                                            secondaryServices: [ethIdentityService])
    }

    func createCopyingOperation(oldKeystore: KeystoreProtocol, newKeystore: KeystoreProtocol) -> IdentityCopyOperation {
        let ethIdentityService = EthereumIdentityService()

        return IdentityCopyOperation(oldKeystore: oldKeystore,
                                     newKeystore: newKeystore,
                                     secondaryServices: [ethIdentityService])
    }

    func createSecondaryIdentitiesOperation(with keystore: KeystoreProtocol,
                                            skipIfExists: Bool) -> BaseOperation<Void> {
        return ClosureOperation {
            try EthereumIdentityService().createIdentity(using: keystore, skipIfExists: skipIfExists)
        }
    }
}
