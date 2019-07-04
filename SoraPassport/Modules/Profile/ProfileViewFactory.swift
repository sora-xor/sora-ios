/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class ProfileViewFactory: ProfileViewFactoryProtocol {
	static func createView() -> ProfileViewProtocol? {
        let profileViewModelFactory = ProfileViewModelFactory(votesFormatter: NumberFormatter.vote,
                                                              integerFormatter: NumberFormatter.anyInteger)

        let termsData = WebData(title: R.string.localizable.termsTitle(),
                                url: ApplicationConfig.shared.termsURL)

        let view = ProfileViewController(nib: R.nib.profileViewController)
        let presenter = ProfilePresenter(viewModelFactory: profileViewModelFactory, termsData: termsData)
        let interactor = ProfileInteractor(customerDataProviderFacade: CustomerDataProviderFacade.shared)
        let wireframe = ProfileWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        presenter.logger = Logger.shared

        return view
	}
}
