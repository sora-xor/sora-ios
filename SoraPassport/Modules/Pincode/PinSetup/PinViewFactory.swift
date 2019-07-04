/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import SoraKeystore

class PinViewFactory: PinViewFactoryProtocol {
    static func createPinSetupView() -> PinSetupViewProtocol? {
        let pinSetupView = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pinSetupView.mode = .create

        let presenter = PinSetupPresenter()
        let interactor = PinSetupInteractor(secretManager: KeychainManager.shared,
                                            settingsManager: SettingsManager.shared,
                                            biometryAuth: BiometryAuth())
        let wireframe = PinSetupWireframe()

        pinSetupView.presenter = presenter
        presenter.view = pinSetupView
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return pinSetupView
    }

    static func createSecuredPinView() -> PinSetupViewProtocol? {
        let pinVerifyView = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pinVerifyView.mode = .securedInput

        let presenter = LocalAuthPresenter()
        let interactor = LocalAuthInteractor(secretManager: KeychainManager.shared,
                                             settingsManager: SettingsManager.shared,
                                             biometryAuth: BiometryAuth())
        let wireframe = PinSetupWireframe()

        pinVerifyView.presenter = presenter
        presenter.interactor = interactor
        presenter.view = pinVerifyView
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return pinVerifyView
    }

    static func createScreenAuthorizationView(with wireframe: ScreenAuthorizationWireframeProtocol)
        -> PinSetupViewProtocol? {
        let pinVerifyView = PinSetupViewController(nib: R.nib.pinSetupViewController)

        pinVerifyView.mode = .securedInput

        let presenter = ScreenAuthorizationPresenter()
        let interactor = LocalAuthInteractor(secretManager: KeychainManager.shared,
                                             settingsManager: SettingsManager.shared,
                                             biometryAuth: BiometryAuth())

        pinVerifyView.presenter = presenter
        presenter.interactor = interactor
        presenter.view = pinVerifyView
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return pinVerifyView
    }
}
