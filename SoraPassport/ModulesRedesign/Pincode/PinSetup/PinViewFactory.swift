// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
