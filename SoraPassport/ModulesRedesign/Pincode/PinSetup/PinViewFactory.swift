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
    
    fileprivate static func extractedFunc(_ config: ApplicationConfig, authorization: WalletOwnerPIN.Authorization) -> PinSetupInteractor {
        return PinSetupInteractor(secretManager: KeychainManager.shared,
                                  settingsManager: SettingsManager.shared,
                                  biometryAuth: BiometryAuth(),
                                  config: config as ApplicationConfigProtocol,
                                  authorization: authorization
        )
    }
    
    static func createRedesignPinEditView(authorization: WalletOwnerPIN.Authorization) -> PinSetupViewProtocol? {
        let pinSetupView = PincodeViewController()

        pinSetupView.mode = .create

        let presenter = SetupPincodePresenter()
        presenter.isNeedChangePinCode = true
        let wireframe = PinSetupWireframe(
            localizationManager: LocalizationManager.shared
        )

        let config = ApplicationConfig.shared!
        let interactor = extractedFunc(config, authorization: authorization)

        pinSetupView.presenter = presenter
        presenter.view = pinSetupView
        presenter.interactor = interactor
        presenter.wireframe = wireframe

        interactor.presenter = presenter

        return pinSetupView
    }
    
    /// A conflict repair during empty onboarding may already have completed
    /// explicit new-PIN setup. Never ask to overwrite that PIN a second time.
    static func createPostImportPinView() -> PinSetupViewProtocol? {
        guard let account = SelectedWalletSettings.shared.currentAccount else {
            return createRedesignPinSetupView()
        }
        do {
            let needsSetup = try needsPostImportPINSetup(keystore: Keychain(),
                settings: SettingsManager.shared, accounts: [account])
            return needsSetup ? createRedesignPinSetupView() : createRedesignSecuredPinView()
        } catch {
            // A secured screen cannot approve access without resolving the
            // underlying Keychain failure; retry keeps the wallet protected.
            return createRedesignSecuredPinView()
        }
    }

    static func needsPostImportPINSetup(keystore: KeystoreProtocol, settings: SettingsManagerProtocol,
                                       accounts: [AccountItem]) throws -> Bool {
        if accounts.isEmpty { return true }
        if try !keystore.checkKey(for: KeystoreTag.pincode.rawValue) { return true }
        return try WalletOwnerPIN(keystore: keystore, settings: settings).requiresInitialSetup(accounts: accounts)
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
                                            config: config as ApplicationConfigProtocol,
                                            ownerPINKeystore: Keychain()
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
