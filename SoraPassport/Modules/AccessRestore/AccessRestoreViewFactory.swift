/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraKeystore
import IrohaCrypto
import SoraFoundation

final class AccessRestoreViewFactory: AccessRestoreViewFactoryProtocol {
    static func createView() -> AccessRestoreViewProtocol? {
        guard let invitationLinkService: InvitationLinkServiceProtocol = DeepLinkService.shared.findService() else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let view = AccessRestoreViewController(nib: R.nib.accessRestoreViewController)
        let presenter = AccessRestorePresenter()

        let interactor = AccessRestoreInteractor(identityLocalOperationFactory: IdentityOperationFactory.self,
                                                 accountOperationFactory: ProjectOperationFactory(),
                                                 keystore: Keychain(),
                                                 settings: SettingsManager.shared,
                                                 applicationConfig: ApplicationConfig.shared,
                                                 mnemonicCreator: IRBIP39MnemonicCreator(language: .english),
                                                 invitationLinkService: invitationLinkService,
                                                 operationManager: OperationManager.shared)
        interactor.logger = Logger.shared

        let wireframe = AccessRestoreWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
