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

import SoraUIKit
import RobinHood

final class MoreMenuWireframe: MoreMenuWireframeProtocol, AuthorizationPresentable, CustomPresentable {

    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var localizationManager: LocalizationManagerProtocol
    private(set) var walletContext: CommonWalletContextProtocol

    private let address: AccountAddress
    private let fiatService: FiatServiceProtocol
    private let balanceFactory: BalanceProviderFactory
    private var assetsProvider: AssetProviderProtocol
    private var assetManager: AssetManagerProtocol

    init(settingsManager: SettingsManagerProtocol,
         localizationManager: LocalizationManagerProtocol,
         walletContext: CommonWalletContextProtocol,
         fiatService: FiatServiceProtocol,
         balanceFactory: BalanceProviderFactory,
         address: AccountAddress,
         assetsProvider: AssetProviderProtocol,
         assetManager: AssetManagerProtocol
    ) {
        self.settingsManager = settingsManager
        self.localizationManager = localizationManager
        self.walletContext = walletContext
        self.address = address
        self.fiatService = fiatService
        self.balanceFactory = balanceFactory
        self.assetsProvider = assetsProvider
        self.assetManager = assetManager
    }
        
    @MainActor
    func showChangeAccountView(from view: MoreMenuViewProtocol?) {
        guard let changeAccountView = ChangeAccountViewFactory.changeAccountViewController(with: {}) else {
            return
        }
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: changeAccountView.controller, on: presentingVC)
    }
    
    @MainActor
    func showInformation(from view: MoreMenuViewProtocol?) {
        let informationView = SettingsInformationFactory.createInformation()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: informationView.controller, on: presentingVC)
    }
    
    @MainActor
    func showNodes(from view: MoreMenuViewProtocol?) {
        guard let nodesView = NodesViewFactory.createView() else {
            return
        }
        if let navigationController = view?.controller.navigationController {
            nodesView.controller.hidesBottomBarWhenPushed = true

            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen

            let newNav = SoraNavigationController(rootViewController: nodesView.controller)
            newNav.navigationBar.backgroundColor = .clear
            newNav.addCustomTransitioning()
            containerView.add(newNav)
            navigationController.present(containerView, animated: true)
        }
    }

    func showPersonalDetailsView(from view: MoreMenuViewProtocol?, completion: @escaping () -> Void) {
    }

    @MainActor
    func showNexusPortfolio(from view: MoreMenuViewProtocol?) {
        guard
            ProductSurfacePolicy.showsNexusPortfolio,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        let controller = NexusPortfolioViewController(
            assetsProvider: assetsProvider,
            openSora2Experience: { [weak source = view?.controller] in
                guard
                    let tabBarController = source?.tabBarController,
                    tabBarController.viewControllers?.isEmpty == false
                else {
                    return false
                }
                // Wallet is the first tab in the retained SORA navigation.
                // Selecting it preserves the production SORA2 send/history
                // flow and its existing signing behavior.
                tabBarController.selectedIndex = 0
                return true
            }
        )
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }

    @MainActor
    func showPolkamarkt(from view: MoreMenuViewProtocol?) {
        guard
            ProductSurfacePolicy.showsPolkamarkt,
            let navigationController = view?.controller.navigationController
        else {
            return
        }
        let controller = PolkamarktViewController(walletContext: walletContext)
        controller.localizationManager = localizationManager
        controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(controller, animated: true)
    }

    @MainActor
    func showFriendsView(from view: MoreMenuViewProtocol?) {
        guard let friendsView = FriendsViewFactory.createView(walletContext: walletContext,
                                                              assetManager: assetManager)
        else {
            return
        }
        if let navigationController = view?.controller.navigationController {
            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen

            let newNav = SoraNavigationController(rootViewController: friendsView.controller)
            newNav.navigationBar.backgroundColor = .clear
            newNav.addCustomTransitioning()
            containerView.add(newNav)
            navigationController.present(containerView, animated: true)
        }
    }

    @MainActor
    func showAppSettings(from view: MoreMenuViewProtocol?) {
        let settingsView = AppSettingsFactory.createAppSettings()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: settingsView.controller, on: presentingVC)
    }
    
    @MainActor
    func showSecurity(from view: MoreMenuViewProtocol?) {
        let securityView = ProfileLoginFactory.createView()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: securityView.controller, on: presentingVC)
    }
}
