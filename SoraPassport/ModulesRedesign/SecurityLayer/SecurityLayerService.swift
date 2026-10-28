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

final class SecurityLayerService {
    static let pincodeTimeoutInMinutes = 5.0
    static let secondsInMinutes = 60.0
    static let pincodeDelayInSeconds: TimeInterval = pincodeTimeoutInMinutes * secondsInMinutes

    static let sharedInteractor: SecurityLayerInteractorInputProtocol = {
        let presenter = SecurityLayerPresenter()
        let interactor = SecurityLayerInteractor(applicationHandler: ApplicationHandler(),
                                                 settings: SettingsManager.shared,
                                                 keystore: Keychain(),
                                                 pincodeDelay: pincodeDelayInSeconds)
        let wireframe = SecurityLayerWireframe()

        presenter.wireframe = wireframe
        presenter.interactor = interactor
        interactor.presenter = presenter

        return interactor
    }()
}
