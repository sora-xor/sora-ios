/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import SoraKeystore

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: SoraWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        let wireframe = RootWireframe()

        NetworkAvailabilityLayerService.shared.setup(with: view, logger: Logger.shared)
        let networkAvailabilityInteractor = NetworkAvailabilityLayerService.shared.interactor

        let interactor = RootInteractor(settings: SettingsManager.shared,
                                        keystore: Keychain(),
                                        securityLayerInteractor: SecurityLayerService.sharedInteractor,
                                        networkAvailabilityLayerInteractor: networkAvailabilityInteractor)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
