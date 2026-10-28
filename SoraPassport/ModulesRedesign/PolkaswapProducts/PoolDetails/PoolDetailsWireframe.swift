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
import UIKit
import SoraUIKit

import RobinHood

protocol PoolDetailsWireframeProtocol: AlertPresentable {
    func showLiquidity(
        on controller: UIViewController?,
        poolInfo: PoolInfo,
        farms: [UserFarm],
        type: Liquidity.TransactionLiquidityType,
        assetManager: AssetManagerProtocol,
        poolsService: PoolsServiceInputProtocol?,
        fiatService: FiatServiceProtocol?,
        farmingService: DemeterFarmingServiceProtocol,
        completionHandler: (() -> Void)?)
    
    func showFarmDetails(
        on viewController: UIViewController?,
        poolsService: PoolsServiceInputProtocol?,
        fiatService: FiatServiceProtocol?,
        assetManager: AssetManagerProtocol,
        farmingService: DemeterFarmingServiceProtocol,
        poolInfo: PoolInfo?,
        farm: Farm
    )
}

final class PoolDetailsWireframe: PoolDetailsWireframeProtocol {
    
    private let feeProvider: FeeProviderProtocol
    private let providerFactory: BalanceProviderFactory
    private let operationFactory: WalletNetworkOperationFactoryProtocol
    private let assetsProvider: AssetProviderProtocol?
    private let marketCapService: MarketCapServiceProtocol
    
    init(feeProvider: FeeProviderProtocol,
         providerFactory: BalanceProviderFactory,
         operationFactory: WalletNetworkOperationFactoryProtocol,
         assetsProvider: AssetProviderProtocol?,
         marketCapService: MarketCapServiceProtocol
    ) {
        self.feeProvider = feeProvider
        self.providerFactory = providerFactory
        self.operationFactory = operationFactory
        self.assetsProvider = assetsProvider
        self.marketCapService = marketCapService
    }
    
    @MainActor
    func showLiquidity(
        on controller: UIViewController?,
        poolInfo: PoolInfo,
        farms: [UserFarm],
        type: Liquidity.TransactionLiquidityType,
        assetManager: AssetManagerProtocol,
        poolsService: PoolsServiceInputProtocol?,
        fiatService: FiatServiceProtocol?,
        farmingService: DemeterFarmingServiceProtocol,
        completionHandler: (() -> Void)?) {
            guard let fiatService = fiatService,
                  let poolsService = poolsService else { return }
            
            guard let assetDetailsController = type == .add ? LiquidityViewFactory.createView(poolInfo: poolInfo,
                                                                                              assetManager: assetManager,
                                                                                              fiatService: fiatService,
                                                                                              poolsService: poolsService,
                                                                                              operationFactory: operationFactory,
                                                                                              assetsProvider: assetsProvider,
                                                                                              marketCapService: marketCapService)
                    :
                        LiquidityViewFactory.createRemoveLiquidityView(poolInfo: poolInfo,
                                                                       farms: farms,
                                                                       assetManager: assetManager,
                                                                       fiatService: fiatService,
                                                                       poolsService: poolsService,
                                                                       providerFactory: providerFactory,
                                                                       operationFactory: operationFactory,
                                                                       assetsProvider: assetsProvider,
                                                                       marketCapService: marketCapService,
                                                                       farmingService: farmingService,
                                                                       completionHandler: completionHandler) else { return }
            
            
            
            let containerView = BlurViewController()
            containerView.modalPresentationStyle = .overFullScreen
            
            let navigationController = UINavigationController(rootViewController: assetDetailsController)
            navigationController.navigationBar.backgroundColor = .clear
            navigationController.addCustomTransitioning()
            
            containerView.add(navigationController)
            
            controller?.present(containerView, animated: true)
        }
    
    @MainActor
    func showFarmDetails(
        on viewController: UIViewController?,
        poolsService: PoolsServiceInputProtocol?,
        fiatService: FiatServiceProtocol?,
        assetManager: AssetManagerProtocol,
        farmingService: DemeterFarmingServiceProtocol,
        poolInfo: PoolInfo?,
        farm: Farm
    ) {
        let walletService = WalletService(operationFactory: operationFactory)
        
        let wireframe = FarmDetailsWireframe(feeProvider: feeProvider,
                                             walletService: walletService,
                                             assetManager: assetManager)
        let userFarmService = UserFarmsService()
        
        let viewModel = FarmDetailsViewModel(farm: farm,
                                             poolInfo: poolInfo,
                                             poolsService: poolsService,
                                             fiatService: fiatService,
                                             providerFactory: providerFactory,
                                             operationFactory: operationFactory,
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
