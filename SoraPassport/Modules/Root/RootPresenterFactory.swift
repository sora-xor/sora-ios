/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit
import SoraKeystore

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        let wireframe = RootWireframe()
        let interator = RootInteractor(settings: SettingsManager.shared,
                                       keystore: Keychain(),
                                       securityLayerService: SecurityLayerService.sharedInteractor)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interator

        interator.presenter = presenter

        return presenter
    }
}
