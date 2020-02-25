/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraCrypto
import SoraKeystore
import SoraFoundation

final class PersonalInfoViewFactory: PersonalInfoViewFactoryProtocol {
    static func createView(with form: PersonalForm) -> PersonalInfoViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            Logger.shared.error("Can't create request signer")
            return nil
        }

        guard let invitationLinkService: InvitationLinkServiceProtocol = DeepLinkService.shared.findService() else {
            return nil
        }

        let locale = LocalizationManager.shared.selectedLocale

        let view = PersonalInfoViewController(nib: R.nib.personalInfoViewController)
        let presenter = PersonalInfoPresenter(viewModelFactory: PersonalInfoViewModelFactory(),
                                              personalForm: form,
                                              locale: locale)
        let wireframe = PersonalInfoWireframe()

        let projectService = ProjectUnitService(unit: ApplicationConfig.shared.defaultProjectUnit)
        projectService.requestSigner = requestSigner

        let interactor = PersonalInfoInteractor(registrationService: projectService,
                                                settings: SettingsManager.shared,
                                                keystore: Keychain(),
                                                invitationLinkService: invitationLinkService)
        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
