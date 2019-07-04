/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import IrohaCrypto

final class AccessBackupViewFactory: AccessBackupViewFactoryProtocol {
    static func createView() -> AccessBackupViewProtocol? {
        let view = AccessBackupViewController(nib: R.nib.accessBackupViewController)
        view.mode = .registration

        let presenter = AccessBackupPresenter()
        let interactor = AccessBackupInteractor(keystore: Keychain(),
                                                mnemonicCreator: IRBIP39MnemonicCreator(language: .english))
        let wireframe = AccessBackupWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
