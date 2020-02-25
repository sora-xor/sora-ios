/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraCrypto
import SoraFoundation

final class PersonalUpdateViewFactory: PersonalUpdateViewFactoryProtocol {
	static func createView() -> PersonalUpdateViewProtocol? {
        guard let requestSigner = DARequestSigner.createDefault() else {
            Logger.shared.error("Can't create decentralized resolver url")
            return nil
        }

        let projectUnit = ApplicationConfig.shared.defaultProjectUnit
        let projectService = ProjectUnitService(unit: projectUnit)
        projectService.requestSigner = requestSigner

        let locale = LocalizationManager.shared.selectedLocale

        let view = PersonalUpdateViewController(nib: R.nib.personalUpdateViewController)
        let viewModelFactory = PersonalInfoViewModelFactory()
        let presenter = PersonalUpdatePresenter(locale: locale, viewModelFactory: viewModelFactory)
        let interactor = PersonalUpdateInteractor(customerFacade: CustomerDataProviderFacade.shared,
                                                  projectService: projectService)
        let wireframe = PersonalUpdateWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.locale = locale

        return view
	}
}
