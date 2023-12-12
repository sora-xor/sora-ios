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
import RobinHood
import CommonWallet
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
            marketCapService: marketCapService,
            itemFactory: PolkaswapItemFactory())
        
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
            marketCapService: marketCapService,
            itemFactory: PolkaswapItemFactory())
        viewModel.completionHandler = completionHandler
        
        let view = PolkaswapViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



