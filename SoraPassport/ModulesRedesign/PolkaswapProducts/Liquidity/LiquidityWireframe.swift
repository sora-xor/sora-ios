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

enum LiquidityConfirmationPreflightError: Swift.Error, Sendable {
    case unavailable
    case insufficientBalance(assetId: String)
    case insufficientLiquidity
    case feeChanged
    case submissionUnknown
}

enum LiquidityTransferInfoFactoryError: Swift.Error {
    case invalidAssets
    case invalidAmounts
    case invalidPool
    case invalidTransactionType
    /// The base asset is not the base of any DEX the app knows (for example KXOR).
    case unknownDex
}

enum LiquidityFeeQualification {
    static func accepts(freshFee: Decimal, reviewedFee: Decimal) -> Bool {
        reviewedFee > 0 && freshFee > 0 && freshFee <= reviewedFee
    }
}

/// One-shot, thread-safe authorization shared with the background signing
/// operation. `viewWillDisappear` revokes it before a queued signer can read a
/// secret; once revoked, this confirmation can never authorize another sign.
final class LiquiditySigningAuthorization: @unchecked Sendable {
    private let lock = NSLock()
    private var isAuthorized = true

    func requireAuthorized() throws {
        lock.lock()
        defer { lock.unlock() }
        guard isAuthorized else {
            throw CancellationError()
        }
    }

    func revoke() {
        lock.lock()
        isAuthorized = false
        lock.unlock()
    }
}

/// Produces the canonical wire context consumed by the exact liquidity call
/// builder. Review-stage estimation and final submission both use this factory.
enum LiquidityTransferInfoFactory {
    static func supply(
        baseAssetId: String,
        targetAssetId: String,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        transactionType: TransactionType,
        fee: Decimal,
        assetManager: AssetManagerProtocol,
        shareOfPool: String = "",
        apy: String = ""
    ) throws -> TransferInfo {
        guard transactionType == .liquidityAdd
                || transactionType == .liquidityAddNewPool
                || transactionType == .liquidityAddToExistingPoolFirstTime else {
            throw LiquidityTransferInfoFactoryError.invalidTransactionType
        }
        try validate(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            firstAssetAmount: firstAssetAmount,
            secondAssetAmount: secondAssetAmount,
            fee: fee,
            assetManager: assetManager
        )
        let dex = try dexId(for: baseAssetId)

        return transferInfo(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            firstAssetAmount: firstAssetAmount,
            fee: fee,
            context: [
                TransactionContextKeys.transactionType: transactionType.rawValue,
                TransactionContextKeys.firstAssetAmount: AmountDecimal(value: firstAssetAmount).stringValue,
                TransactionContextKeys.secondAssetAmount: AmountDecimal(value: secondAssetAmount).stringValue,
                TransactionContextKeys.slippage: slippageTolerance.contextValue,
                TransactionContextKeys.dex: dex,
                TransactionContextKeys.shareOfPool: shareOfPool,
                TransactionContextKeys.sbApy: apy
            ]
        )
    }

    static func removal(
        poolInfo: PoolInfo,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        fee: Decimal,
        assetManager: AssetManagerProtocol,
        shareOfPool: String = "",
        apy: String = ""
    ) throws -> TransferInfo {
        try validate(
            baseAssetId: poolInfo.baseAssetId,
            targetAssetId: poolInfo.targetAssetId,
            firstAssetAmount: firstAssetAmount,
            secondAssetAmount: secondAssetAmount,
            fee: fee,
            assetManager: assetManager
        )
        guard let baseAssetReserves = poolInfo.baseAssetReserves,
              baseAssetReserves > 0,
              let totalIssuances = poolInfo.totalIssuances,
              totalIssuances > 0 else {
            throw LiquidityTransferInfoFactoryError.invalidPool
        }
        let dex = try dexId(for: poolInfo.baseAssetId)

        return transferInfo(
            baseAssetId: poolInfo.baseAssetId,
            targetAssetId: poolInfo.targetAssetId,
            firstAssetAmount: firstAssetAmount,
            fee: fee,
            context: [
                TransactionContextKeys.transactionType: TransactionType.liquidityRemoval.rawValue,
                TransactionContextKeys.firstAssetAmount: AmountDecimal(value: firstAssetAmount).stringValue,
                TransactionContextKeys.secondAssetAmount: AmountDecimal(value: secondAssetAmount).stringValue,
                TransactionContextKeys.firstReserves: AmountDecimal(value: baseAssetReserves).stringValue,
                TransactionContextKeys.totalIssuances: AmountDecimal(value: totalIssuances).stringValue,
                TransactionContextKeys.shareOfPool: shareOfPool,
                TransactionContextKeys.slippage: slippageTolerance.contextValue,
                TransactionContextKeys.sbApy: apy,
                TransactionContextKeys.dex: dex
            ]
        )
    }

    private static func validate(
        baseAssetId: String,
        targetAssetId: String,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        fee: Decimal,
        assetManager: AssetManagerProtocol
    ) throws {
        guard !baseAssetId.isEmpty,
              !targetAssetId.isEmpty,
              baseAssetId != targetAssetId,
              assetManager.assetInfo(for: baseAssetId) != nil,
              assetManager.assetInfo(for: targetAssetId) != nil else {
            throw LiquidityTransferInfoFactoryError.invalidAssets
        }
        guard firstAssetAmount > 0,
              secondAssetAmount > 0,
              fee >= 0 else {
            throw LiquidityTransferInfoFactoryError.invalidAmounts
        }
    }

    /// The DEX of the pool's base asset, as read from the chain (XOR and XSTUSD are always
    /// known). An unknown base is refused rather than guessed: a wrong DEX id fails on
    /// chain after the fee is charged.
    private static func dexId(for baseAssetId: String) throws -> String {
        guard let dexId = DexInfoService.shared.knownDexId(forBaseAssetId: baseAssetId) else {
            throw LiquidityTransferInfoFactoryError.unknownDex
        }
        return String(dexId)
    }

    private static func transferInfo(
        baseAssetId: String,
        targetAssetId: String,
        firstAssetAmount: Decimal,
        fee: Decimal,
        context: [String: String]
    ) -> TransferInfo {
        let feeDescription = FeeDescription(
            identifier: WalletAssetId.xor.rawValue,
            assetId: WalletAssetId.xor.rawValue,
            type: "fee",
            parameters: [],
            accountId: nil,
            minValue: nil,
            maxValue: nil,
            context: nil
        )
        let networkFee = Fee(
            value: AmountDecimal(value: fee),
            feeDescription: feeDescription
        )
        return TransferInfo(
            source: baseAssetId,
            destination: targetAssetId,
            amount: AmountDecimal(value: firstAssetAmount),
            asset: baseAssetId,
            details: "",
            fees: [networkFee],
            context: context
        )
    }
}

protocol LiquidityWireframeProtocol: AlertPresentable {
    func showChoiсeBaseAsset(on controller: UIViewController?,
                             assetManager: AssetManagerProtocol,
                             fiatService: FiatServiceProtocol,
                             assetViewModelFactory: AssetViewModelFactory,
                             assetsProvider: AssetProviderProtocol?,
                             assetIds: [String],
                             marketCapService: MarketCapServiceProtocol,
                             completion: @escaping (String) -> Void)
    
    func showSlippageTolerance(
        on controller: UINavigationController?,
        currentLocale: PolkaswapSlippage,
        completion: @escaping (PolkaswapSlippage) -> Void
    )
    
    func showChoiсeMarket(on controller: UINavigationController?,
                          selectedMarket: LiquiditySourceType,
                          markets: [LiquiditySourceType],
                          completion: @escaping (LiquiditySourceType) -> Void)
    
    func showSupplyLiquidityConfirmation(
        on controller: UINavigationController?,
        baseAssetId: String,
        targetAssetId: String,
        fiatService: FiatServiceProtocol,
        poolsService: PoolsServiceInputProtocol,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        details: [DetailViewModel],
        transactionType: TransactionType,
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        feeChangeHandler: @escaping () -> Void
    )
    
    
    func showRemoveLiquidityConfirmation(
        on controller: UINavigationController?,
        poolInfo: PoolInfo,
        poolsService: PoolsServiceInputProtocol,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        details: [DetailViewModel],
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        feeChangeHandler: @escaping () -> Void,
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
        slippageTolerance: PolkaswapSlippage,
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
        fiatData: [PIExactFiatData],
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
    
    func showSlippageTolerance(
        on controller: UINavigationController?,
        currentLocale: PolkaswapSlippage,
        completion: @escaping (PolkaswapSlippage) -> Void
    ) {
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
        poolsService: PoolsServiceInputProtocol,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        details: [DetailViewModel],
        transactionType: TransactionType,
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        feeChangeHandler: @escaping () -> Void
    ) {

        let viewModel = ConfirmSupplyLiquidityViewModel(wireframe: ConfirmWireframe(),
                                                        baseAssetId: baseAssetId,
                                                        targetAssetId: targetAssetId,
                                                        poolsService: poolsService,
                                                        assetManager: assetManager,
                                                        firstAssetAmount: firstAssetAmount,
                                                        secondAssetAmount: secondAssetAmount,
                                                        slippageTolerance: slippageTolerance,
                                                        details: details,
                                                        transactionType: transactionType,
                                                        fee: fee,
                                                        operationFactory: operationFactory,
                                                        feeChangeHandler: feeChangeHandler,
                                                        walletService: WalletService(operationFactory: operationFactory))
        let view = ConfirmViewController(viewModel: viewModel)
        viewModel.view = view
        controller?.pushViewController(view, animated: true)
    }
    
    func showRemoveLiquidityConfirmation(
        on controller: UINavigationController?,
        poolInfo: PoolInfo,
        poolsService: PoolsServiceInputProtocol,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        details: [DetailViewModel],
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        feeChangeHandler: @escaping () -> Void,
        completionHandler: (() -> Void)?
    ) {

        let viewModel = ConfirmRemoveLiquidityViewModel(wireframe: ConfirmWireframe(),
                                                        poolInfo: poolInfo,
                                                        poolsService: poolsService,
                                                        assetManager: assetManager,
                                                        firstAssetAmount: firstAssetAmount,
                                                        secondAssetAmount: secondAssetAmount,
                                                        slippageTolerance: slippageTolerance,
                                                        details: details,
                                                        operationFactory: operationFactory,
                                                        feeChangeHandler: feeChangeHandler,
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
        slippageTolerance: PolkaswapSlippage,
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
        fiatData: [PIExactFiatData],
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
