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

protocol FarmDetailsWireframeProtocol: AlertPresentable {
    func showPoolDetails(on controller: UIViewController?,
                         poolInfo: PoolInfo?,
                         fiatService: FiatServiceProtocol?,
                         poolsService: PoolsServiceInputProtocol?,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol?,
                         assetsProvider: AssetProviderProtocol?,
                         marketCapService: MarketCapServiceProtocol,
                         farmingService: DemeterFarmingServiceProtocol)
    
    func showStakeDetails(on controller: UIViewController?,
                          farm: Farm,
                          poolInfo: PoolInfo?,
                          assetsProvider: AssetProviderProtocol?,
                          detailsFactory: DetailViewModelFactoryProtocol)
    
    func showClaimRewards(on controller: UIViewController?,
                          farm: Farm,
                          poolInfo: PoolInfo?,
                          fiatService: FiatServiceProtocol?,
                          assetsProvider: AssetProviderProtocol?,
                          detailsFactory: DetailViewModelFactoryProtocol)
}

final class FarmDetailsWireframe: FarmDetailsWireframeProtocol {
    
    private let feeProvider: FeeProviderProtocol
    private let walletService: WalletServiceProtocol
    private let assetManager: AssetManagerProtocol
    
    init(feeProvider: FeeProviderProtocol,
         walletService: WalletServiceProtocol,
         assetManager: AssetManagerProtocol) {
        self.feeProvider = feeProvider
        self.walletService = walletService
        self.assetManager = assetManager
    }
    
    @MainActor func showPoolDetails(on controller: UIViewController?,
                         poolInfo: PoolInfo?,
                         fiatService: FiatServiceProtocol?,
                         poolsService: PoolsServiceInputProtocol?,
                         providerFactory: BalanceProviderFactory,
                         operationFactory: WalletNetworkOperationFactoryProtocol?,
                         assetsProvider: AssetProviderProtocol?,
                         marketCapService: MarketCapServiceProtocol,
                         farmingService: DemeterFarmingServiceProtocol) {
        guard 
            let poolInfo,
            let poolsService,
            let assetsProvider,
            let fiatService,
            let operationFactory,
            let poolDetailsController = PoolDetailsViewFactory.createView(poolInfo: poolInfo,
                                                                          assetManager: assetManager,
                                                                          fiatService: fiatService,
                                                                          poolsService: poolsService,
                                                                          providerFactory: providerFactory,
                                                                          operationFactory: operationFactory,
                                                                          assetsProvider: assetsProvider,
                                                                          marketCapService: marketCapService,
                                                                          farmingService: farmingService,
                                                                          feeProvider: feeProvider,
                                                                          dismissHandler: nil) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: poolDetailsController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController.addCustomTransitioning()
        
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    @MainActor func showStakeDetails(on controller: UIViewController?,
                          farm: Farm,
                          poolInfo: PoolInfo?,
                          assetsProvider: AssetProviderProtocol?,
                          detailsFactory: DetailViewModelFactoryProtocol) {
        guard
            let poolInfo,
            let stakeDetailsController = EditFarmViewFactory.createView(farm: farm,
                                                                        poolInfo: poolInfo,
                                                                        assetsProvider: assetsProvider,
                                                                        feeProvider: feeProvider,
                                                                        walletService: walletService,
                                                                        assetManager: assetManager) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: stakeDetailsController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController.addCustomTransitioning()
        
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
    
    @MainActor func showClaimRewards(on controller: UIViewController?,
                          farm: Farm,
                          poolInfo: PoolInfo?,
                          fiatService: FiatServiceProtocol?,
                          assetsProvider: AssetProviderProtocol?,
                          detailsFactory: DetailViewModelFactoryProtocol) {
        guard
            let poolInfo,
            let stakeDetailsController = ClaimRewardsViewFactory.createView(farm: farm,
                                                                            poolInfo: poolInfo,
                                                                            fiatService: fiatService,
                                                                            assetsProvider: assetsProvider,
                                                                            detailsFactory: detailsFactory,
                                                                            feeProvider: feeProvider,
                                                                            walletService: walletService,
                                                                            assetManager: assetManager) else {
            return
        }
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: stakeDetailsController)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController.addCustomTransitioning()
        
        containerView.add(navigationController)
        
        controller?.present(containerView, animated: true)
    }
}

