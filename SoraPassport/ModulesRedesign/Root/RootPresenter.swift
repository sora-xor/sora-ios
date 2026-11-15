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

final class RootPresenter {
    var view: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        interactor.setup()
        interactor.decideModuleSynchroniously()
    }
}

extension RootPresenter: RootInteractorOutputProtocol {

    func didDecideOnboarding() {
        wireframe.showOnboarding(on: view)
    }

    func didDecideLegacyWalletUpgrade() {
        // An update asks nothing. The splash stays up while the 1.x wallet
        // becomes an account; routing then runs again and opens the PIN screen.
        interactor.performAutomaticLegacyWalletUpgrade()
    }

    func didRejectLegacyWalletUpgradePIN(_ error: Error) {
        wireframe.showLegacyWalletUpgradePINRejected(on: view, error: error)
    }

    func didDecideLocalAuthentication() {
        wireframe.showLocalAuthentication(on: view)
    }

    func didDecidePincodeSetup() {
        wireframe.showPincodeSetup(on: view)
    }

    func didDecideBroken() {
        wireframe.showBroken(on: view)
    }

    func didDecideWelcomeBack() {
        wireframe.showWelcomeBack(on: view)
    }
}
