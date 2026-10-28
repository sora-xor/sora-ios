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


protocol MainTabBarViewProtocol: ControllerBackedProtocol {
    var middleButtonHadler: (() -> Void)? { get set }
    func didReplaceView(for newView: UIViewController, for index: Int)
}

protocol MainTabBarPresenterProtocol: AnyObject {
    func setup()
}

protocol MainTabBarInteractorInputProtocol: AnyObject {
    func setup()
//    func configureNotifications()
//    func configureDeepLink()
//
//    func searchPendingDeepLink()
//    func resolvePendingDeepLink()
}

protocol MainTabBarInteractorOutputProtocol: AnyObject {
//    func didReceive(deepLink: DeepLinkProtocol)
    func didReloadSelectedAccount()
    func didReloadSelectedNetwork()
    func didUpdateWalletInfo()
    func didRequestImportAccount()
    func didRequestMigration(with service: MigrationServiceProtocol)
    func didEndMigration()
    func didEndTransaction()
    func didUserChange()
    func didLanguageChange()
}

protocol MainTabBarWireframeProtocol: AlertPresentable, AuthorizationAccessible {
    var walletContext: CommonWalletContextProtocol { get set }

    func showNewWalletView(on view: MainTabBarViewProtocol?)
    func reloadWalletContent()

    func presentAccountImport(on view: MainTabBarViewProtocol?)
    func presentClaim(on view: MainTabBarViewProtocol?, with service: MigrationServiceProtocol)
    func removeClaim(on view: MainTabBarViewProtocol?)
    
    func showTransactionSuccess(on view: MainTabBarViewProtocol?)
    func recreateWalletViewController(on view: MainTabBarViewProtocol?)
}

protocol MainTabBarViewFactoryProtocol: AnyObject {
    static func createView() -> MainTabBarViewProtocol?
    static func reloadWalletView(on view: MainTabBarViewProtocol,
                                 wireframe: MainTabBarWireframeProtocol)
}
