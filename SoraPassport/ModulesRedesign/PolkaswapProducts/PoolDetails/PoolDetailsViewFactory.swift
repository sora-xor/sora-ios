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

final class PoolDetailsViewFactory {
    static func createView(poolInfo: PoolInfo,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           providerFactory: BalanceProviderFactory,
                           operationFactory: WalletNetworkOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           marketCapService: MarketCapServiceProtocol,
                           farmingService: DemeterFarmingServiceProtocol,
                           feeProvider: FeeProviderProtocol,
                           dismissHandler: (() -> Void)?) -> PoolDetailsViewController? {
        let wireframe = PoolDetailsWireframe(feeProvider: feeProvider,
                                             providerFactory: providerFactory,
                                             operationFactory: operationFactory, 
                                             assetsProvider: assetsProvider,
                                             marketCapService: marketCapService)
        
        let detailsFactory = DetailViewModelFactory(assetManager: assetManager)
        
        let poolDetailsService = PoolDetailsItemService(poolInfo: poolInfo,
                                                        apyService: APYService.shared,
                                                        fiatService: fiatService,
                                                        detailsFactory: detailsFactory)
        let userFarmService = UserFarmsService()
        let viewModel = PoolDetailsViewModel(wireframe: wireframe,
                                             poolInfo: poolInfo,
                                             fiatService: fiatService,
                                             poolsService: poolsService,
                                             assetManager: assetManager,
                                             detailsFactory: detailsFactory,
                                             farmingService: farmingService,
                                             poolDetailsService: poolDetailsService, 
                                             userFarmService: userFarmService)
        viewModel.dismissHandler = dismissHandler
        
        poolDetailsService.viewModel = viewModel

        let view = PoolDetailsViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



