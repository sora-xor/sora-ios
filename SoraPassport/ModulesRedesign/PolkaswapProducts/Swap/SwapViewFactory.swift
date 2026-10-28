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

import SoraUIKit
import UIKit

final class SwapViewFactory {
    @MainActor static func createView(
        selectedTokenId: String,
        selectedSecondTokenId: String,
        assetManager: AssetManagerProtocol,
        fiatService: FiatServiceProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        assetsProvider: AssetProviderProtocol?,
        marketCapService: MarketCapServiceProtocol) -> UIViewController? {
        let interactor = PolkaswapMainInteractor(operationManager: OperationManager(),
                                                 eventCenter: EventCenter.shared)
        interactor.polkaswapNetworkFacade = polkaswapNetworkFacade
        let viewModel = SwapViewModel(
            selectedTokenId: selectedTokenId,
            selectedSecondTokenId: selectedSecondTokenId,
            wireframe: LiquidityWireframe(),
            fiatService: fiatService,
            assetManager: assetManager,
            detailsFactory: DetailViewModelFactory(assetManager: assetManager),
            eventCenter: EventCenter.shared,
            interactor: interactor,
            networkFacade: networkFacade,
            assetsProvider: assetsProvider,
            lpServiceFee: LPFeeService(),
            polkaswapNetworkFacade: polkaswapNetworkFacade,
            marketCapService: marketCapService)
        
        interactor.presenter = viewModel
        
        let view = PolkaswapViewController(viewModel: viewModel)
        viewModel.view = view
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: view)
        navigationController.navigationBar.backgroundColor = .clear
        navigationController.addCustomTransitioning()
        
        containerView.add(navigationController)
        
        return containerView
    }
}
