// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import SoraKeystore
import SoraFoundation

protocol ScreenAuthorizationWireframeProtocol: AnyObject {
    func showAuthorizationCompletion(with result: Bool)
}

final class PinViewFactory {
    
    fileprivate static func extractedFunc(_ config: ApplicationConfig) -> PinSetupInteractor {
        return PinSetupInteractor(secretManager: KeychainManager.shared,
                                  settingsManager: SettingsManager.shared,
                                  biometryAuth: BiometryAuth(),
                                  config: config as ApplicationConfigProtocol
        )
    }
    
    static func createRedesignPinEditView() -> PinSetupViewProtocol? {
        let pinSetupView = PincodeViewController()

        pinSetupView.mode = .create

        let presenter = SetupPincodePresenter()
        presenter.isNeedChangePinCode = true
        let wireframe = PinSetupWireframe(
            localizationManager: LocalizationManager.shared
        )

        let config = ApplicationConfig.shared!
        let interactor = extractedFunc(config)

        pinSetupView.presenter = presenter
        presenter.view = pinSetupView
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return pinSetupView
    }
    
    static func createRedesignPinSetupView() -> PinSetupViewProtocol? {
        let pinSetupView = PincodeViewController()

        pinSetupView.mode = .create

        let presenter = SetupPincodePresenter()
        let wireframe = PinSetupWireframe(
            localizationManager: LocalizationManager.shared
        )

        let config = ApplicationConfig.shared!
        let interactor = PinSetupInteractor(secretManager: KeychainManager.shared,
                                            settingsManager: SettingsManager.shared,
                                            biometryAuth: BiometryAuth(),
                                            config: config as ApplicationConfigProtocol
        )

        pinSetupView.presenter = presenter
        presenter.view = pinSetupView
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return pinSetupView
    }
    
    static func createRedesignSecuredPinView() -> PinSetupViewProtocol? {
        let pinView = PincodeViewController()

        pinView.mode = .securedInput

        let presenter = InputPincodePresenter()
        let wireframe = PinSetupWireframe(
            localizationManager: LocalizationManager.shared
        )
        let interactor = LocalAuthInteractor(
            secretManager: KeychainManager.shared,
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )

        pinView.presenter = presenter
        presenter.interactor = interactor
        presenter.view = pinView
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return pinView
    }
    
    static func createRedesignScreenAuthorizationView(with wireframe: ScreenAuthorizationWireframeProtocol, cancellable: Bool)
    -> PinSetupViewProtocol? {
        let pinView = PincodeViewController()
        pinView.cancellable = cancellable
        
        pinView.mode = .securedInput
        
        let presenter = AuthorizationPresenter()
        let interactor = LocalAuthInteractor(
            secretManager: KeychainManager.shared,
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            locale: LocalizationManager.shared.selectedLocale
        )
        
        pinView.presenter = presenter
        presenter.interactor = interactor
        presenter.view = pinView
        presenter.wireframe = wireframe
        
        interactor.presenter = presenter
        
        return pinView
    }
}
