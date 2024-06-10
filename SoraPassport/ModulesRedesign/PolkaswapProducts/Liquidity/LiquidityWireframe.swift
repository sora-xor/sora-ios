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
