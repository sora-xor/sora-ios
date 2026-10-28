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


final class AssetDetailsViewFactory {
    static func createView(assetInfo: AssetInfo,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           assetViewModelFactory: AssetViewModelFactory,
                           poolsService: PoolsServiceInputProtocol,
                           poolViewModelsFactory: PoolViewModelFactory,
                           providerFactory: BalanceProviderFactory,
                           networkFacade: WalletNetworkOperationFactoryProtocol?,
                           accountId: String,
                           address: String,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           referralFactory: ReferralsOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           marketCapService: MarketCapServiceProtocol,
                           farmingService: DemeterFarmingServiceProtocol,
                           feeProvider: FeeProviderProtocol)
    -> AssetDetailsViewController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let aseetList = assetManager.getAssetList(),
              let assetsProvider = assetsProvider else { return nil }

        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: aseetList)

        let viewModelFactory = ActivityViewModelFactory(walletAssets: aseetList, assetManager: assetManager)
        
        let eventCenter = EventCenter.shared
        let priceInfoService = PriceInfoService.shared

        let wireframe = AssetDetailsWireframe(accountId: accountId,
                                              address: address,
                                              assetManager: assetManager,
                                              fiatService: fiatService,
                                              eventCenter: eventCenter,
                                              assetInfo: assetInfo,
                                              providerFactory: providerFactory,
                                              networkFacade: networkFacade,
                                              polkaswapNetworkFacade: polkaswapNetworkFacade,
                                              assetsProvider: assetsProvider,
                                              marketCapService: marketCapService,
                                              qrEncoder: qrEncoder,
                                              sharingFactory: sharingFactory, 
                                              farmingService: farmingService,
                                              feeProvider: feeProvider)
        
        let recentActivityService = RecentActivityItemService(assetId: assetInfo.assetId,
                                                              viewModelFactory: viewModelFactory,
                                                              historyService: historyService,
                                                              eventCenter: eventCenter,
                                                              assetsProvider: assetsProvider)
        
        let transferableItemService = TransferableItemService(assetInfo: assetInfo,
                                                              eventCenter: eventCenter,
                                                              assetsProvider: assetsProvider,
                                                              referralFactory: referralFactory)
        
        let itemsFactory = AssetDetailsItemFactory(assetsProvider: assetsProvider,
                                                   poolViewModelsFactory: poolViewModelsFactory,
                                                   historyService: historyService,
                                                   recentActivityService: recentActivityService,
                                                   wireframe: wireframe, 
                                                   poolsService: poolsService,
                                                   transferableItemService: transferableItemService)

        let viewModel = AssetDetailsViewModel(wireframe: wireframe,
                                              assetInfo: assetInfo,
                                              referralFactory: referralFactory,
                                              priceInfoService: priceInfoService,
                                              itemsFactory: itemsFactory)

        let view = AssetDetailsViewController(viewModel: viewModel)
        viewModel.view = view
        wireframe.controller = view
        return view
    }
}



