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
import CommonWallet
import SoraUIKit
import RobinHood
import SCard

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
        
    func showChangeAccountView(from view: MoreMenuViewProtocol?) {
        guard let changeAccountView = ChangeAccountViewFactory.changeAccountViewController(with: {}) else {
            return
        }
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: changeAccountView.controller, on: presentingVC)
    }
    
    func showSoraCard(from view: MoreMenuViewProtocol?) {
        guard let view = view else { return }
        SCard.shared?.start(in: view.controller)
    }
    
    func showInformation(from view: MoreMenuViewProtocol?) {
        let informationView = SettingsInformationFactory.createInformation()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: informationView.controller, on: presentingVC)
    }
    
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

    func showAppSettings(from view: MoreMenuViewProtocol?) {
        let settingsView = AppSettingsFactory.createAppSettings()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: settingsView.controller, on: presentingVC)
    }
    
    func showSecurity(from view: MoreMenuViewProtocol?) {
        let securityView = ProfileLoginFactory.createView()
        
        guard let presentingVC = view?.controller else {
            return
        }
        
        present(blurred: securityView.controller, on: presentingVC)
    }
}
