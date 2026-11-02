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


final class RedesignWalletViewFactory {
    static func createView(providerFactory: BalanceProviderFactory,
                           assetManager: AssetManagerProtocol,
                           fiatService: FiatServiceProtocol,
                           farmingService: DemeterFarmingServiceProtocol,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           accountId: String,
                           address: String,
                           polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           poolsService: PoolsServiceInputProtocol,
                           referralFactory: ReferralsOperationFactoryProtocol,
                           assetsProvider: AssetProviderProtocol,
                           walletContext: CommonWalletContextProtocol,
                           poolsViewModelService: PoolsItemService,
                           assetsViewModelService: AssetsItemService,
                           marketCapService: MarketCapServiceProtocol,
                           editViewService: EditViewServiceProtocol,
                           feeProvider: FeeProviderProtocol) -> RedesignWalletViewController {
        
        let wireframe = RedesignWalletWireframe(feeProvider: feeProvider)
        let viewModel = RedesignWalletViewModel(wireframe: wireframe,
                                                providerFactory: providerFactory,
                                                assetManager: assetManager,
                                                fiatService: fiatService,
                                                farmingService: farmingService,
                                                itemFactory: WalletItemFactory(),
                                                networkFacade: networkFacade,
                                                accountId: accountId,
                                                address: address,
                                                polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                qrEncoder: qrEncoder,
                                                sharingFactory: sharingFactory,
                                                poolsService: poolsService,
                                                referralFactory: referralFactory,
                                                assetsProvider: assetsProvider,
                                                walletContext: walletContext,
                                                editViewService: editViewService,
                                                poolsViewModelService: poolsViewModelService,
                                                assetsViewModelService: assetsViewModelService,
                                                marketCapService: marketCapService)
        
        let view = RedesignWalletViewController(viewModel: viewModel)
        viewModel.view = view
        return view
    }
}



