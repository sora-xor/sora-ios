/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import SoraCrypto
import IrohaCrypto

protocol IdentityOperationFactoryProtocol {
    static func createNewIdentityOperation() -> IdentityCreationOperation
    static func createRestorationOperation(with mnemonic: IRMnemonicProtocol) -> IdentityRestorationOperation
    static func createVerificationOperation() -> IdentityVerifyOperation
    static func createLocalRemoveOperation() -> IdentityLocalRemoveOperation
}

final class IdentityOperationFactory: IdentityOperationFactoryProtocol {
    static func createNewIdentityOperation() -> IdentityCreationOperation {
        return IdentityCreationOperation(keystore: Keychain())
    }

    static func createRestorationOperation(with mnemonic: IRMnemonicProtocol) -> IdentityRestorationOperation {
        return IdentityRestorationOperation(keystore: Keychain(), mnemonic: mnemonic)
    }

    static func createVerificationOperation() -> IdentityVerifyOperation {
        return IdentityVerifyOperation(verifier: DDOVerifier.createDefault(),
                                       keystore: Keychain())
    }

    static func createLocalRemoveOperation() -> IdentityLocalRemoveOperation {
        return IdentityLocalRemoveOperation(keystore: Keychain(),
                                            settings: SettingsManager.shared)
    }
}
