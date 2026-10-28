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
import RobinHood

import SSFUtils

protocol LiquidityViewFactoryProtocol: AnyObject {
    static func createView(poolInfo: PoolInfo?,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           marketCapService: MarketCapServiceProtocol) -> PolkaswapViewController?
    
    static func createRemoveLiquidityView(poolInfo: PoolInfo,
                                          farms: [UserFarm],
                                          assetManager: AssetManagerProtocol,
                                          fiatService: FiatServiceProtocol,
                                          poolsService: PoolsServiceInputProtocol,
                                          providerFactory: BalanceProviderFactory,
                                          operationFactory: WalletNetworkOperationFactoryProtocol,
                                          assetsProvider: AssetProviderProtocol?,
                                          marketCapService: MarketCapServiceProtocol,
                                          farmingService: DemeterFarmingServiceProtocol,
                                          completionHandler: (() -> Void)?) -> PolkaswapViewController?
}

final class LiquidityViewFactory: LiquidityViewFactoryProtocol {
    static func createView(poolInfo: PoolInfo?,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           marketCapService: MarketCapServiceProtocol) -> PolkaswapViewController? {
        let viewModel = SupplyLiquidityViewModel(
            wireframe: LiquidityWireframe(),
            poolInfo: poolInfo,
            fiatService: fiatService,
            apyService: APYService.shared,
            poolsService: poolsService,
            assetManager: assetManager,
            detailsFactory: DetailViewModelFactory(assetManager: assetManager),
            operationFactory: operationFactory,
            assetsProvider: assetsProvider,
            marketCapService: marketCapService)
        
        let view = PolkaswapViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
    
    static func createRemoveLiquidityView(poolInfo: PoolInfo,
                                          farms: [UserFarm],
                                          assetManager: AssetManagerProtocol,
                                          fiatService: FiatServiceProtocol,
                                          poolsService: PoolsServiceInputProtocol,
                                          providerFactory: BalanceProviderFactory,
                                          operationFactory: WalletNetworkOperationFactoryProtocol,
                                          assetsProvider: AssetProviderProtocol?,
                                          marketCapService: MarketCapServiceProtocol,
                                          farmingService: DemeterFarmingServiceProtocol,
                                          completionHandler: (() -> Void)?) -> PolkaswapViewController? {
        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else { return nil }
        let viewModel = RemoveLiquidityViewModel(
            wireframe: LiquidityWireframe(),
            poolInfo: poolInfo,
            farms: farms,
            apyService: APYService.shared,
            fiatService: fiatService,
            poolsService: poolsService,
            assetManager: assetManager,
            detailsFactory: DetailViewModelFactory(assetManager: assetManager),
            providerFactory: providerFactory,
            operationFactory: operationFactory,
            assetsProvider: assetsProvider,
            farmingService: farmingService,
            marketCapService: marketCapService)
        viewModel.completionHandler = completionHandler
        
        let view = PolkaswapViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



