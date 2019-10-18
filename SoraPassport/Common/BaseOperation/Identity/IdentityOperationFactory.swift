/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto

protocol IdentityOperationFactoryProtocol {
    static func createNewIdentityOperation(with keystore: KeystoreProtocol) -> IdentityCreationOperation
    static func createRestorationOperation(with mnemonic: IRMnemonicProtocol,
                                           keystore: KeystoreProtocol) -> IdentityRestorationOperation
    static func createVerificationOperation() -> IdentityVerifyOperation
    static func createVerificationOperation(with keystore: KeystoreProtocol) -> IdentityVerifyOperation
    static func createLocalRemoveOperation() -> IdentityLocalRemoveOperation
    static func createLocalRemoveOperation(with keystore: KeystoreProtocol,
                                           settings: SettingsManagerProtocol) -> IdentityLocalRemoveOperation
}

extension IdentityOperationFactoryProtocol {
    static func createNewIdentityOperation() -> IdentityCreationOperation {
        return createNewIdentityOperation(with: Keychain())
    }

    static func createRestorationOperation(with mnemonic: IRMnemonicProtocol) -> IdentityRestorationOperation {
        return createRestorationOperation(with: mnemonic, keystore: Keychain())
    }

    static func createVerificationOperation() -> IdentityVerifyOperation {
        return createVerificationOperation(with: Keychain())
    }

    static func createLocalRemoveOperation() -> IdentityLocalRemoveOperation {
        return createLocalRemoveOperation(with: Keychain(), settings: SettingsManager.shared)
    }
}

final class IdentityOperationFactory: IdentityOperationFactoryProtocol {

    static func createNewIdentityOperation(with keystore: KeystoreProtocol) -> IdentityCreationOperation {
        return IdentityCreationOperation(keystore: keystore)
    }

    static func createRestorationOperation(with mnemonic: IRMnemonicProtocol,
                                           keystore: KeystoreProtocol) -> IdentityRestorationOperation {
        return IdentityRestorationOperation(keystore: keystore, mnemonic: mnemonic)
    }

    static func createVerificationOperation(with keystore: KeystoreProtocol) -> IdentityVerifyOperation {
        return IdentityVerifyOperation(verifier: DDOVerifier.createDefault(),
                                       keystore: keystore)
    }

    static func createLocalRemoveOperation(with keystore: KeystoreProtocol,
                                           settings: SettingsManagerProtocol) -> IdentityLocalRemoveOperation {
        return IdentityLocalRemoveOperation(keystore: keystore,
                                            settings: settings)
    }
}
