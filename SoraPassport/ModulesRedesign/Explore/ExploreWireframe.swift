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
import SoraUIKit
import CommonWallet

protocol ExploreWireframeProtocol {
    func showAssetList(on viewController: UIViewController?, viewModelService: ExploreAssetViewModelService)
    func showPoolList(on viewController: UIViewController?, viewModelService: ExplorePoolViewModelService)
    func showAssetDetails(on viewController: UIViewController?, assetId: String)
    func showAccountPoolDetails(on viewController: UIViewController?, poolInfo: PoolInfo)
}

final class ExploreWireframe: ExploreWireframeProtocol {
    
    weak var fiatService: FiatServiceProtocol?
    let itemFactory: ExploreItemFactory
    let assetManager: AssetManagerProtocol
    let marketCapService: MarketCapServiceProtocol
    let poolService: ExplorePoolsServiceInputProtocol
    let apyService: APYServiceProtocol?
    let assetViewModelFactory: AssetViewModelFactoryProtocol
    let poolsService: PoolsServiceInputProtocol
    let poolViewModelsFactory: PoolViewModelFactoryProtocol
    let providerFactory: BalanceProviderFactory
    let networkFacade: WalletNetworkOperationFactoryProtocol?
    let accountId: String
    let address: String
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let qrEncoder: WalletQREncoderProtocol
    let sharingFactory: AccountShareFactoryProtocol
    let referralFactory: ReferralsOperationFactoryProtocol
    let assetsProvider: AssetProviderProtocol

    init(
        fiatService: FiatServiceProtocol?,
        itemFactory: ExploreItemFactory,
        assetManager: AssetManagerProtocol,
        marketCapService: MarketCapServiceProtocol,
        poolService: ExplorePoolsServiceInputProtocol,
        apyService: APYServiceProtocol?,
        assetViewModelFactory: AssetViewModelFactoryProtocol,
        poolsService: PoolsServiceInputProtocol,
        poolViewModelsFactory: PoolViewModelFactoryProtocol,
        providerFactory: BalanceProviderFactory,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        accountId: String,
        address: String,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        referralFactory: ReferralsOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol
    ) {
        
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.assetManager = assetManager
        self.marketCapService = marketCapService
        self.poolService = poolService
        self.apyService = apyService
        self.assetViewModelFactory = assetViewModelFactory
        self.poolsService = poolsService
        self.poolViewModelsFactory = poolViewModelsFactory
        self.providerFactory = providerFactory
        self.networkFacade = networkFacade
        self.accountId = accountId
        self.address = address
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.referralFactory = referralFactory
        self.assetsProvider = assetsProvider
    }
    
    func showAssetList(on viewController: UIViewController?, viewModelService: ExploreAssetViewModelService) {
        let viewModel = ViewAssetListViewModel(viewModelService: viewModelService, wireframe: self)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: assetListController)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        viewController?.present(containerView, animated: true)
    }
    
    func showPoolList(on viewController: UIViewController?, viewModelService: ExplorePoolViewModelService) {
        let viewModel = ViewPoolListViewModel(viewModelService: viewModelService, wireframe: self, accountPoolsService: poolsService)
        
        let assetListController = ProductListViewController(viewModel: viewModel)
        viewModel.view = assetListController
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        let newNav = SoraNavigationController(rootViewController: assetListController)
        newNav.navigationBar.backgroundColor = .clear
        newNav.addCustomTransitioning()
        
        containerView.add(newNav)
        viewController?.present(containerView, animated: true)
    }
    
    func showAssetDetails(on viewController: UIViewController?, assetId: String) {
        guard let assetInfo = assetManager.assetInfo(for: assetId),
              let fiatService = fiatService,
              let polkaswapNetworkFacade = polkaswapNetworkFacade,
              let assetDetailsController = AssetDetailsViewFactory.createView(assetInfo: assetInfo,
                                                                              assetManager: assetManager,
                                                                              fiatService: fiatService,
                                                                              assetViewModelFactory: assetViewModelFactory,
                                                                              poolsService: poolsService,
                                                                              poolViewModelsFactory: poolViewModelsFactory,
                                                                              providerFactory: providerFactory,
                                                                              networkFacade: networkFacade,
                                                                              accountId: accountId,
                                                                              address: address,
                                                                              polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                                              qrEncoder: qrEncoder,
                                                                              sharingFactory: sharingFactory,
                                                                              referralFactory: referralFactory,
                                                                              assetsProvider: assetsProvider) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(assetDetailsController)
        
        viewController?.present(containerView, animated: true)
    }
    
    func showAccountPoolDetails(on viewController: UIViewController?, poolInfo: PoolInfo) {
        guard let fiatService = fiatService,
              let networkFacade = networkFacade,
              let assetDetailsController = PoolDetailsViewFactory.createView(poolInfo: poolInfo,
                                                                             assetManager: assetManager,
                                                                             fiatService: fiatService,
                                                                             poolsService: poolsService,
                                                                             providerFactory: providerFactory,
                                                                             operationFactory: networkFacade,
                                                                             assetsProvider: assetsProvider,
                                                                             dismissHandler: nil) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let assetDetailNavigationController = UINavigationController(rootViewController: assetDetailsController)
        assetDetailNavigationController.navigationBar.backgroundColor = .clear
        assetDetailNavigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        assetDetailNavigationController.addCustomTransitioning()
        
        containerView.add(assetDetailNavigationController)
        
        viewController?.present(containerView, animated: true)
    }
}
