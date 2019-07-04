/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraCrypto
import SoraKeystore

final class PersonalInfoViewFactory: PersonalInfoViewFactoryProtocol {
    static func createView(with applicationForm: ApplicationFormData?,
                           invitationCode: String) -> PersonalInfoViewProtocol? {
        guard let decentralizedResolverUrl = URL(string: ApplicationConfig.shared.didResolverUrl) else {
            Logger.shared.error("Can't create decentralized resolver url")
            return nil
        }

        let view = PersonalInfoViewController(nib: R.nib.personalInfoViewController)
        let presenter = PersonalInfoPresenter(applicationForm: applicationForm,
                                              invitationCode: invitationCode,
                                              viewModelFactory: PersonalInfoViewModelFactory())
        let wireframe = PersonalInfoWireframe()

        let identityNetworkOperationFactory = DecentralizedResolverOperationFactory(url: decentralizedResolverUrl)
        let interactor = PersonalInfoInteractor(projectOperationFactory: ProjectOperationFactory(),
                                                identityNetworkOperationFactory: identityNetworkOperationFactory,
                                                identityLocalOperationFactory: IdentityOperationFactory.self,
                                                settings: SettingsManager.shared,
                                                keystore: Keychain(),
                                                applicationConfig: ApplicationConfig.shared,
                                                operationManager: OperationManager.shared)
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
