/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore
import IrohaCrypto

final class AccessRestoreViewFactory: AccessRestoreViewFactoryProtocol {
    static func createView() -> AccessRestoreViewProtocol? {
        let view = AccessRestoreViewController(nib: R.nib.accessRestoreViewController)
        let presenter = AccessRestorePresenter()
        let interactor = AccessRestoreInteractor(accountOperationFactory: ProjectOperationFactory(),
                                                 identityLocalOperationFactory: IdentityOperationFactory.self,
                                                 keystore: Keychain(),
                                                 operationManager: OperationManager.shared,
                                                 applicationConfig: ApplicationConfig.shared,
                                                 settings: SettingsManager.shared,
                                                 mnemonicCreator: IRBIP39MnemonicCreator(language: .english))
        interactor.logger = Logger.shared

        let wireframe = AccessRestoreWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
