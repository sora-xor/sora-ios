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
import SoraUIKit


protocol ExploreWireframeProtocol {
    func showAssetDetails(on viewController: UIViewController?, assetId: String)
    func showAccountPoolDetails(on viewController: UIViewController?, poolInfo: PoolInfo)
    func showLiquidity(on controller: UIViewController?)
    func showFarmDetails(on viewController: UIViewController?, farm: Farm)
}

final class ExploreWireframe: ExploreWireframeProtocol {
    
    weak var fiatService: FiatServiceProtocol?
    let itemFactory: ExploreItemFactory
    let assetManager: AssetManagerProtocol
    let marketCapService: MarketCapServiceProtocol
    let explorePoolsService: ExplorePoolsServiceInputProtocol
    let apyService: APYServiceProtocol?
    let assetViewModelFactory: AssetViewModelFactory
    let poolsService: PoolsServiceInputProtocol
    let poolViewModelsFactory: PoolViewModelFactory
    let providerFactory: BalanceProviderFactory
    let networkFacade: WalletNetworkOperationFactoryProtocol?
    let accountId: String
    let address: String
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    let qrEncoder: WalletQREncoderProtocol
    let sharingFactory: AccountShareFactoryProtocol
    let referralFactory: ReferralsOperationFactoryProtocol
    let assetsProvider: AssetProviderProtocol
    let farmingService: DemeterFarmingServiceProtocol
    let poolViewModelsService: ExplorePoolsViewModelService
    let feeProvider: FeeProviderProtocol
    let walletService: WalletServiceProtocol

    init(
        fiatService: FiatServiceProtocol?,
        itemFactory: ExploreItemFactory,
        assetManager: AssetManagerProtocol,
        marketCapService: MarketCapServiceProtocol,
        explorePoolsService: ExplorePoolsServiceInputProtocol,
        apyService: APYServiceProtocol?,
        assetViewModelFactory: AssetViewModelFactory,
        poolsService: PoolsServiceInputProtocol,
        poolViewModelsFactory: PoolViewModelFactory,
        providerFactory: BalanceProviderFactory,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        accountId: String,
        address: String,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        referralFactory: ReferralsOperationFactoryProtocol,
        assetsProvider: AssetProviderProtocol,
        farmingService: DemeterFarmingServiceProtocol,
        poolViewModelsService: ExplorePoolsViewModelService,
        feeProvider: FeeProviderProtocol,
        walletService: WalletServiceProtocol
    ) {
        
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.assetManager = assetManager
        self.marketCapService = marketCapService
        self.explorePoolsService = explorePoolsService
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
        self.farmingService = farmingService
        self.poolViewModelsService = poolViewModelsService
        self.feeProvider = feeProvider
        self.walletService = walletService
    }
    
    @MainActor
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
                                                                              assetsProvider: assetsProvider,
                                                                              marketCapService: marketCapService,
                                                                              farmingService: farmingService,
                                                                              feeProvider: feeProvider) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        containerView.add(assetDetailsController)
        
        viewController?.present(containerView, animated: true)
    }
    
    @MainActor
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
                                                                             marketCapService: marketCapService, 
                                                                             farmingService: farmingService,
                                                                             feeProvider: feeProvider,
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
    
    @MainActor
    func showLiquidity(on controller: UIViewController?) {
        guard let fiatService = fiatService, let networkFacade = networkFacade else { return }
        
        guard let assetDetailsController = LiquidityViewFactory.createView(poolInfo: nil,
                                                                           assetManager: assetManager,
                                                                           fiatService: fiatService,
                                                                           poolsService: poolsService,
                                                                           operationFactory: networkFacade,
                                                                           assetsProvider: assetsProvider,
                                                                           marketCapService: marketCapService) else { return }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: assetDetailsController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    @MainActor
    func showFarmDetails(on viewController: UIViewController?, farm: Farm) {
        let wireframe = FarmDetailsWireframe(feeProvider: feeProvider, walletService: walletService, assetManager: assetManager)
        let userFarmService = UserFarmsService()
        let viewModel = FarmDetailsViewModel(farm: farm,
                                             poolsService: poolsService,
                                             poolViewModelsService: poolViewModelsService,
                                             fiatService: fiatService,
                                             providerFactory: providerFactory,
                                             operationFactory: networkFacade,
                                             assetsProvider: assetsProvider,
                                             marketCapService: marketCapService,
                                             farmingService: farmingService,
                                             detailsFactory: DetailViewModelFactory(assetManager: assetManager),
                                             wireframe: wireframe, 
                                             userFarmService: userFarmService)
        
        let view = FarmDetailsViewController(viewModel: viewModel)
        viewModel.view = view
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen

        let navigationController = UINavigationController(rootViewController: view)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        
        containerView.add(navigationController)
        
        viewController?.present(containerView, animated: true)
    }
}
