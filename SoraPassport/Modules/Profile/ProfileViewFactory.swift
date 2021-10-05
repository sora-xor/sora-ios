/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import RobinHood
import SoraKeystore
import SoraFoundation

final class ProfileViewFactory: ProfileViewFactoryProtocol {
	static func createView() -> ProfileViewProtocol? {

        let profileViewModelFactory = ProfileViewModelFactory()

        let presenter = ProfilePresenter(
            viewModelFactory: profileViewModelFactory,
            settingsManager: SettingsManager.shared
        )

        presenter.localizationManager = LocalizationManager.shared

        let view = ProfileViewController(nib: R.nib.profileViewController)
        view.localizationManager = LocalizationManager.shared
        view.presenter = presenter

        presenter.view = view

        let wireframe = ProfileWireframe(
            settingsManager: SettingsManager.shared,
            localizationManager: LocalizationManager.shared
        )

        presenter.wireframe = wireframe

        let interactor = ProfileInteractor(
            keystore: Keychain(),
            settings: SettingsManager.shared,
            cacheFacade: CoreDataCacheFacade.shared,
            substrateDataFacade: SubstrateDataStorageFacade.shared,
            userDataFacade: UserDataStorageFacade.shared
        )

        interactor.presenter = presenter
        presenter.interactor = interactor

        return view
	}
}
