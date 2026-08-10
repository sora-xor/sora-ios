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
                TransactionContextKeys.dex: dexId(for: baseAssetId, assetManager: assetManager),
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
                TransactionContextKeys.dex: dexId(for: poolInfo.baseAssetId, assetManager: assetManager)
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

    private static func dexId(
        for baseAssetId: String,
        assetManager: AssetManagerProtocol
    ) -> String {
        let isFeeAsset = assetManager.assetInfo(for: baseAssetId)?.isFeeAsset ?? false
        return isFeeAsset || baseAssetId == WalletAssetId.kxor ? "0" : "1"
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
