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

import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: SoraWindow) -> RootPresenterProtocol {

        AppearanceFactory.applyGlobalAppearance()

        let keychain = Keychain()
        let settings = SettingsManager.shared
        let wireframe = RootWireframe(keystore: keychain, settings: settings)

        NetworkAvailabilityLayerService.shared.setup(with: view,
                                                     localizationManager: LocalizationManager.shared,
                                                     logger: Logger.shared)
        let networkAvailabilityInteractor = NetworkAvailabilityLayerService.shared.interactor

        let inconsistentStateMigrator = InconsistentStateMigrator(
            settings: settings,
            keychain: keychain
        )

        let interactor = RootInteractor(settings: settings,
                                        keystore: keychain,
                                        migrators: [inconsistentStateMigrator],
                                        securityLayerInteractor: SecurityLayerService.sharedInteractor,
                                        networkAvailabilityLayerInteractor: networkAvailabilityInteractor)

        return createPresenter(with: view, interactor: interactor, wireframe: wireframe)
    }

    /// Wires the module and keeps it alive on the window (`rootModule`)
    /// until the next startup replaces it. Without that, the presenter was
    /// released as soon as launch routing returned, and the actions on
    /// Welcome back and the 1.x upgrade confirmation did nothing.
    static func createPresenter(with view: SoraWindow,
                                interactor: RootInteractor,
                                wireframe: RootWireframeProtocol) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter
        view.rootModule = presenter

        return presenter
    }
}
