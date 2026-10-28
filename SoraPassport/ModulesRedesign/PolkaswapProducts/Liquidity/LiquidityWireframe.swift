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
import RobinHood

import sorawallet
import SoraUIKit

protocol LiquidityWireframeProtocol: AlertPresentable {
    func showChoiсeBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactory,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             marketCapService: MarketCapServiceProtocol,
                             completion: @escaping (String) -> Void)
    
    func showSlippageTolerance(on controller: UINavigationController?, currentLocale: Float, completion: @escaping (Float) -> Void)
    
    func showChoiсeMarket(on controller: UINavigationController?,
                          selectedMarket: LiquiditySourceType,
                          markets: [LiquiditySourceType],
                          completion: @escaping (LiquiditySourceType) -> Void)
    
    func showSupplyLiquidityConfirmation(
        on controller: UINavigationController?,
        baseAssetId: String,
        targetAssetId: String,
        fiatService: FiatServiceProtocol,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        details: [DetailViewModel],
        transactionType: TransactionType,
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol
    )
    
    
    func showRemoveLiquidityConfirmation(
        on controller: UINavigationController?,
        poolInfo: PoolInfo,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        details: [DetailViewModel],
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        completionHandler: (() -> Void)?
    )
    
    func showSwapConfirmation(
        on controller: UINavigationController?,
        baseAssetId: String,
        targetAssetId: String,
        assetManager: AssetManagerProtocol,
        eventCenter: EventCenterProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        market: LiquiditySourceType,
        details: [DetailViewModel],
        amounts: SwapQuoteAmounts,
        fee: Decimal,
        swapVariant: SwapVariant,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        minMaxValue: Decimal,
        dexId: UInt32,
        quoteParams: PolkaswapMainInteractorQuoteParams,
        assetsProvider: AssetProviderProtocol?,
        fiatData: [FiatData],
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?)
}

final class LiquidityWireframe: LiquidityWireframeProtocol {

    @MainActor
    func showChoiсeBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactory,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             marketCapService: MarketCapServiceProtocol,
                             completion: @escaping (String) -> Void) {
        let viewModel = SelectAssetViewModel(assetViewModelFactory: assetViewModelFactory,
                                             fiatService: fiatService,
                                             assetManager: assetManager,
                                             assetsProvider: assetsProvider,
                                             assetIds: assetIds,
                                             marketCapService: marketCapService)
        viewModel.selectionCompletion = completion

        let assetListController = ProductListViewController(viewModel: viewModel)
        
        let containerView = BlurViewController()
        containerView.modalPresentationStyle = .overFullScreen
        
        let navigationController = UINavigationController(rootViewController: assetListController)
        navigationController.navigationBar.backgroundColor = .clear
        
        containerView.add(navigationController)
        controller?.present(containerView, animated: true)
    }
    
    func showSlippageTolerance(on controller: UINavigationController?, currentLocale: Float, completion: @escaping (Float) -> Void) {
        let viewModel = SlippageToleranceViewModel(value: currentLocale)
        viewModel.completion = completion
        let view = SlippageToleranceViewController(viewModel: viewModel)
        viewModel.view = view
        controller?.pushViewController(view, animated: true)
    }
    
    func showChoiсeMarket(on controller: UINavigationController?,
                          selectedMarket: LiquiditySourceType,
                          markets: [LiquiditySourceType],
                          completion: @escaping (LiquiditySourceType) -> Void) {
        let viewModel = ChoiceMarketViewModel(markets: markets, selectedMarket: selectedMarket)
        viewModel.completion = completion
        let view = ChoiceMarketViewController(viewModel: viewModel)
        viewModel.view = view
        controller?.pushViewController(view, animated: true)
    }
    
    func showSupplyLiquidityConfirmation(
        on controller: UINavigationController?,
        baseAssetId: String,
        targetAssetId: String,
        fiatService: FiatServiceProtocol,
        poolsService: PoolsServiceInputProtocol?,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        details: [DetailViewModel],
        transactionType: TransactionType,
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol
    ) {

        let viewModel = ConfirmSupplyLiquidityViewModel(wireframe: ConfirmWireframe(),
                                                        baseAssetId: baseAssetId,
                                                        targetAssetId: targetAssetId,
                                                        assetManager: assetManager,
                                                        firstAssetAmount: firstAssetAmount,
                                                        secondAssetAmount: secondAssetAmount,
                                                        slippageTolerance: slippageTolerance,
                                                        details: details,
                                                        transactionType: transactionType,
                                                        fee: fee,
                                                        walletService: WalletService(operationFactory: operationFactory))
        let view = ConfirmViewController(viewModel: viewModel)
        viewModel.view = view
        controller?.pushViewController(view, animated: true)
    }
    
    func showRemoveLiquidityConfirmation(
        on controller: UINavigationController?,
        poolInfo: PoolInfo,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        details: [DetailViewModel],
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        completionHandler: (() -> Void)?
    ) {

        let viewModel = ConfirmRemoveLiquidityViewModel(wireframe: ConfirmWireframe(),
                                                        poolInfo: poolInfo,
                                                        assetManager: assetManager,
                                                        firstAssetAmount: firstAssetAmount,
                                                        secondAssetAmount: secondAssetAmount,
                                                        slippageTolerance: slippageTolerance,
                                                        details: details,
                                                        walletService: WalletService(operationFactory: operationFactory),
                                                        fee: fee)
        viewModel.completionHandler = completionHandler
        let view = ConfirmViewController(viewModel: viewModel)
        viewModel.view = view
        controller?.pushViewController(view, animated: true)
    }
    
    func showSwapConfirmation(
        on controller: UINavigationController?,
        baseAssetId: String,
        targetAssetId: String,
        assetManager: AssetManagerProtocol,
        eventCenter: EventCenterProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: Float,
        market: LiquiditySourceType,
        details: [DetailViewModel],
        amounts: SwapQuoteAmounts,
        fee: Decimal,
        swapVariant: SwapVariant,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        minMaxValue: Decimal,
        dexId: UInt32,
        quoteParams: PolkaswapMainInteractorQuoteParams,
        assetsProvider: AssetProviderProtocol?,
        fiatData: [FiatData],
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?) {
            guard let networkFacade = networkFacade else { return }
            let interactor = PolkaswapMainInteractor(operationManager: OperationManager(),
                                                     eventCenter: eventCenter)
            interactor.polkaswapNetworkFacade = polkaswapNetworkFacade
            let viewModel = ConfirmSwapViewModel(wireframe: ConfirmWireframe(),
                                                 firstAssetId: baseAssetId,
                                                 secondAssetId: targetAssetId,
                                                 assetManager: assetManager,
                                                 eventCenter: eventCenter,
                                                 firstAssetAmount: firstAssetAmount,
                                                 secondAssetAmount: secondAssetAmount,
                                                 slippageTolerance: slippageTolerance,
                                                 details: details,
                                                 market: market,
                                                 amounts: amounts,
                                                 walletService: WalletService(operationFactory: networkFacade),
                                                 fee: fee,
                                                 swapVariant: swapVariant,
                                                 minMaxValue: minMaxValue,
                                                 dexId: dexId,
                                                 interactor: interactor,
                                                 quoteParams: quoteParams,
                                                 assetsProvider: assetsProvider,
                                                 fiatData: fiatData)
            
            interactor.presenter = viewModel
            let view = ConfirmViewController(viewModel: viewModel)
            viewModel.view = view
            controller?.pushViewController(view, animated: true)
    }
}
