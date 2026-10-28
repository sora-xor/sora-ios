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

protocol RootPresenterProtocol: AnyObject {
    func loadOnLaunch()
}

protocol RootWireframeProtocol: AnyObject {
    func showLocalAuthentication(on view: UIWindow)
    func showOnboarding(on view: UIWindow)
    func showLegacyWalletUpgrade(
        on view: UIWindow,
        onConfirm: @escaping () -> Void
    )
    func showBroken(on view: UIWindow)
    func showPincodeSetup(on view: UIWindow)
    /// Keychain items from an earlier install, and no wallet database.
    func showWelcomeBack(on view: UIWindow)
}

protocol RootInteractorInputProtocol: AnyObject {
    func setup()
    func decideModuleSynchroniously()
    func performLegacyWalletUpgrade()
}

protocol RootInteractorOutputProtocol: AnyObject {
    func didDecideOnboarding()
    func didDecideLegacyWalletUpgrade()
    func didDecideLocalAuthentication()
    func didDecideBroken()
    func didDecidePincodeSetup()
    func didDecideWelcomeBack()
}

protocol RootPresenterFactoryProtocol: AnyObject {
    static func createPresenter(with view: SoraWindow) -> RootPresenterProtocol
}
