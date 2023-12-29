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
import UIKit
import SoraUIKit
import CommonWallet
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
    
    func showPoolDetails(on controller: UIViewController?,
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
    
    func showStakeDetails(on controller: UIViewController?,
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
    
    func showClaimRewards(on controller: UIViewController?,
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

