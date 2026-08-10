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

import UIKit
import SoraUIKit
import RobinHood
import SoraFoundation

final class ConfirmRemoveLiquidityViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var completionHandler: (() -> Void)?

    weak var view: ConfirmViewProtocol?
    var wireframe: ConfirmWireframeProtocol?
    var poolInfo: PoolInfo
    let poolsService: PoolsServiceInputProtocol
    let assetManager: AssetManagerProtocol

    var firstAssetAmount: Decimal
    var secondAssetAmount: Decimal
    var slippageTolerance: PolkaswapSlippage
    var details: [DetailViewModel]
    /// Exact fee shown on the source review screen. A higher pre-sign fee
    /// invalidates this confirmation and requires a new review.
    let fee: Decimal
    let operationFactory: WalletNetworkOperationFactoryProtocol
    let feeChangeHandler: () -> Void
    let walletService: WalletServiceProtocol
    private var isSubmitting = false
    private var feeReviewInvalidated = false
    private var preflightTask: Task<Void, Never>?
    private let signingAuthorization = LiquiditySigningAuthorization()

    var title: String? {
        return R.string.localizable.removePoolConfirmationTitle(preferredLanguages: .currentLocale)
    }

    var imageName: String? {
        return nil
    }

    init(
        wireframe: ConfirmWireframeProtocol?,
        poolInfo: PoolInfo,
        poolsService: PoolsServiceInputProtocol,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        details: [DetailViewModel],
        operationFactory: WalletNetworkOperationFactoryProtocol,
        feeChangeHandler: @escaping () -> Void,
        walletService: WalletServiceProtocol,
        fee: Decimal
    ) {
        self.poolInfo = poolInfo
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.assetManager = assetManager
        self.firstAssetAmount = firstAssetAmount
        self.secondAssetAmount = secondAssetAmount
        self.slippageTolerance = slippageTolerance
        self.details = details
        self.fee = fee
        self.operationFactory = operationFactory
        self.feeChangeHandler = feeChangeHandler
        self.walletService = walletService
        self.slippageTolerance = slippageTolerance
    }
}

extension ConfirmRemoveLiquidityViewModel: ConfirmViewModelProtocol {
    func viewDidLoad() {
        updateContent()
    }

    func viewWillDisappear() {
        signingAuthorization.revoke()
        preflightTask?.cancel()
        preflightTask = nil
    }
}

extension ConfirmRemoveLiquidityViewModel {
    func updateContent() {
        let firstAsset = assetManager.assetInfo(for: poolInfo.baseAssetId)
        let firstAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)

        let secondAsset = self.assetManager.assetInfo(for: self.poolInfo.targetAssetId)
        let secondAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)

        let firstAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: firstAsset?.icon ?? ""),
                                                         amountText: firstAssetFormatter.stringFromDecimal(self.firstAssetAmount) ?? "",
                                                         symbol: firstAsset?.symbol ?? "")

        let secondAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: secondAsset?.icon ?? ""),
                                                          amountText: secondAssetFormatter.stringFromDecimal(self.secondAssetAmount) ?? "",
                                                          symbol: secondAsset?.symbol ?? "")

        let confirmAssetsItem = ConfirmAssetsItem(firstAssetImageModel: firstAssetImageModel,
                                                  secondAssetImageModel: secondAssetImageModel,
                                                  operationImageName: "roundPlus")

        let text = R.string.localizable.polkaswapOutputEstimated(slippageTolerance.displayValue, preferredLanguages: .currentLocale)
        let textItem = SoramitsuTextItem(text: text, fontData: FontType.paragraphS, textColor: .fgPrimary, alignment: .center)
        let slippageTextItem = SoraTextItem(text: textItem)

        let detailItem = ConfirmDetailsItem(detailViewModels: self.details)

        let slipageItem = ConfirmOptionsItem(toleranceText: slippageTolerance.displayValue)

        let buttonText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM,
                                           textColor: .bgSurface,
                                           alignment: .center)
        let buttonItem = SoramitsuButtonItem(title: buttonText) { [weak self] in
            self?.submit()
        }

        self.setupItems?([confirmAssetsItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          slippageTextItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          detailItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          slipageItem,
                          SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                          buttonItem])
    }

    func submit() {
        guard !isSubmitting, !feeReviewInvalidated else { return }
        guard isConfirmationActive,
              fee > 0,
              firstAssetAmount > 0,
              secondAssetAmount > 0,
              !poolInfo.baseAssetId.isEmpty,
              !poolInfo.targetAssetId.isEmpty,
              poolInfo.baseAssetId != poolInfo.targetAssetId,
              assetManager.assetInfo(for: poolInfo.baseAssetId) != nil,
              assetManager.assetInfo(for: poolInfo.targetAssetId) != nil,
              (poolInfo.baseAssetReserves ?? .zero) > 0,
              (poolInfo.targetAssetReserves ?? .zero) > 0,
              (poolInfo.totalIssuances ?? .zero) > 0 else {
            presentPreflightError(.unavailable)
            return
        }

        isSubmitting = true
        wireframe?.showActivityIndicator()
        preflightTask = Task { @MainActor [weak self] in
            await self?.runPreflight()
        }
    }

    @MainActor
    private func runPreflight() async {
        do {
            let pairState = try await poolsService.loadPairState(
                baseAssetId: poolInfo.baseAssetId,
                targetAssetId: poolInfo.targetAssetId
            )
            guard pairState.isPresented, pairState.isEnabled,
                  let freshPool = await poolsService.loadPool(
                    by: poolInfo.baseAssetId,
                    targetAssetId: poolInfo.targetAssetId
                  ) else {
                throw LiquidityConfirmationPreflightError.unavailable
            }

            try validateLivePool(freshPool)
            let xorBalance = try await fetchLiveXORBalance()
            let reviewInfo = try makeTransferInfo(fee: .zero)
            try Task.checkCancellation()
            try signingAuthorization.requireAuthorized()
            guard isConfirmationActive else {
                throw CancellationError()
            }
            let prepared = try await operationFactory
                .prepareLiquiditySubmission(
                    for: reviewInfo,
                    preSigningValidation: { [signingAuthorization] in
                        try signingAuthorization.requireAuthorized()
                    }
                )
            defer { prepared.discard() }
            let freshFee = prepared.fee
            guard LiquidityFeeQualification.accepts(freshFee: freshFee, reviewedFee: fee) else {
                throw LiquidityConfirmationPreflightError.feeChanged
            }

            guard xorBalance >= freshFee else {
                throw LiquidityConfirmationPreflightError.insufficientBalance(
                    assetId: WalletAssetId.xor.rawValue
                )
            }

            let submissionInfo = try makeTransferInfo(fee: freshFee)
            try Task.checkCancellation()
            try signingAuthorization.requireAuthorized()
            guard isConfirmationActive else {
                throw CancellationError()
            }
            do {
                let transactionHash = try await operationFactory
                    .submitPreparedLiquidity(
                        prepared,
                        info: submissionInfo,
                        preTransportValidation: {
                            [signingAuthorization] in
                            try signingAuthorization.requireAuthorized()
                        }
                    )
                handlePreparedTransfer(
                    transactionHash: transactionHash,
                    rawFee: prepared.rawFee
                )
            } catch let transportError as PreparedExtrinsicTransportError {
                switch transportError {
                case .failedBeforeTransport:
                    throw LiquidityConfirmationPreflightError.unavailable
                case .submissionUnknown:
                    throw LiquidityConfirmationPreflightError.submissionUnknown
                }
            }
        } catch let error as LiquidityConfirmationPreflightError {
            finishPreflight(with: error)
        } catch is CancellationError {
            isSubmitting = false
            preflightTask = nil
            wireframe?.hideActivityIndicator()
        } catch {
            finishPreflight(with: .unavailable)
        }
    }

    private func validateLivePool(_ freshPool: PoolInfo) throws {
        guard freshPool.baseAssetId == poolInfo.baseAssetId,
              freshPool.targetAssetId == poolInfo.targetAssetId,
              let originalBaseReserves = poolInfo.baseAssetReserves,
              originalBaseReserves > 0,
              let originalTotalIssuances = poolInfo.totalIssuances,
              originalTotalIssuances > 0,
              let freshBaseReserves = freshPool.baseAssetReserves,
              freshBaseReserves > 0,
              let freshTargetReserves = freshPool.targetAssetReserves,
              freshTargetReserves > 0,
              let freshTotalIssuances = freshPool.totalIssuances,
              freshTotalIssuances > 0,
              let freshAccountPoolBalance = freshPool.accountPoolBalance,
              freshAccountPoolBalance >= 0 else {
            throw LiquidityConfirmationPreflightError.unavailable
        }

        let desiredPoolTokens = firstAssetAmount / originalBaseReserves * originalTotalIssuances
        let stakedPoolTokens = freshPool.farms.compactMap(\.pooledTokens)
        guard desiredPoolTokens > 0,
              stakedPoolTokens.count == freshPool.farms.count,
              stakedPoolTokens.allSatisfy({ $0 >= 0 }) else {
            throw LiquidityConfirmationPreflightError.unavailable
        }

        let availablePoolTokens = freshAccountPoolBalance - (stakedPoolTokens.max() ?? .zero)
        guard availablePoolTokens >= desiredPoolTokens else {
            throw LiquidityConfirmationPreflightError.insufficientLiquidity
        }

        let freshBaseOutput = desiredPoolTokens / freshTotalIssuances * freshBaseReserves
        let freshTargetOutput = desiredPoolTokens / freshTotalIssuances * freshTargetReserves
        let minimumBaseOutput = slippageTolerance.minimumAmount(for: firstAssetAmount)
        let minimumTargetOutput = slippageTolerance.minimumAmount(for: secondAssetAmount)

        guard freshBaseOutput >= minimumBaseOutput,
              freshTargetOutput >= minimumTargetOutput else {
            throw LiquidityConfirmationPreflightError.insufficientLiquidity
        }
    }

    @MainActor
    private func fetchLiveXORBalance() async throws -> Decimal {
        try await withCheckedThrowingContinuation { continuation in
            walletService.fetchBalance(
                for: [WalletAssetId.xor.rawValue],
                runCompletionIn: .main
            ) { result in
                guard let result else {
                    continuation.resume(throwing: LiquidityConfirmationPreflightError.unavailable)
                    return
                }

                switch result {
                case let .success(balances):
                    guard let balances,
                          balances.filter({ $0.identifier == WalletAssetId.xor.rawValue }).count == 1,
                          let xorBalance = balances.first(where: {
                            $0.identifier == WalletAssetId.xor.rawValue
                          })?.balance.decimalValue,
                          xorBalance >= 0 else {
                        continuation.resume(throwing: LiquidityConfirmationPreflightError.unavailable)
                        return
                    }
                    continuation.resume(returning: xorBalance)
                case .failure:
                    continuation.resume(throwing: LiquidityConfirmationPreflightError.unavailable)
                }
            }
        }
    }

    private func makeTransferInfo(fee freshFee: Decimal) throws -> TransferInfo {
        let shareOfPool = details.first(where: { $0.title == Constants.apyTitle })?
            .assetAmountText.text ?? ""
        let apy = details.first(where: { $0.title == Constants.apyTitle })?
            .assetAmountText.text ?? ""
        return try LiquidityTransferInfoFactory.removal(
            poolInfo: poolInfo,
            firstAssetAmount: firstAssetAmount,
            secondAssetAmount: secondAssetAmount,
            slippageTolerance: slippageTolerance,
            fee: freshFee,
            assetManager: assetManager,
            shareOfPool: shareOfPool,
            apy: apy
        )
    }

    private func finishPreflight(with error: LiquidityConfirmationPreflightError) {
        isSubmitting = false
        preflightTask = nil
        wireframe?.hideActivityIndicator()
        if case .feeChanged = error {
            feeReviewInvalidated = true
        }
        if case .submissionUnknown = error {
            feeReviewInvalidated = true
        }
        guard isConfirmationActive else { return }
        presentPreflightError(error)
    }

    private var isConfirmationActive: Bool {
        guard let controller = view?.controller,
              let navigationController = controller.navigationController else {
            return false
        }
        return navigationController.topViewController === controller
    }

    private func presentPreflightError(_ error: LiquidityConfirmationPreflightError) {
        let message: String
        switch error {
        case let .insufficientBalance(assetId):
            let symbol = assetManager.assetInfo(for: assetId)?.symbol ?? "XOR"
            message = R.string.localizable.polkaswapInsufficientBalance(
                symbol,
                preferredLanguages: .currentLocale
            )
        case .insufficientLiquidity:
            message = R.string.localizable.polkaswapInsufficientLiqudity(
                preferredLanguages: .currentLocale
            )
        case .feeChanged:
            message = NexusToriiError.quoteChanged.localizedDescription
        case .submissionUnknown:
            message = NexusToriiError.ambiguousSubmission.localizedDescription
        case .unavailable:
            message = R.string.localizable.commonErrorRetry(preferredLanguages: .currentLocale)
        }

        if case .feeChanged = error {
            feeChangeHandler()
            wireframe?.present(
                message: message,
                title: nil,
                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                from: view,
                completion: { [weak self] in
                    guard let controller = self?.view?.controller else { return }
                    controller.navigationController?.popViewController(animated: true)
                }
            )
        } else {
            wireframe?.present(
                message: message,
                title: nil,
                closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                from: view
            )
        }
    }

    private func handlePreparedTransfer(
        transactionHash: Data,
        rawFee: String
    ) {
        isSubmitting = false
        preflightTask = nil
        wireframe?.hideActivityIndicator()
        guard isConfirmationActive,
              let exactFee = Amount(string: rawFee) else { return }
        let base = TransactionBase(
                                   txHash: transactionHash.toHex(includePrefix: true),
                                   blockHash: "",
                                   fee: exactFee,
                                   status: .pending,
                                   timestamp: "\(Date().timeIntervalSince1970)")
        let swapTransaction = Liquidity(base: base,
                                        firstTokenId: poolInfo.targetAssetId,
                                        secondTokenId: poolInfo.baseAssetId,
                                        firstAmount: Amount(value: firstAssetAmount),
                                        secondAmount: Amount(value: secondAssetAmount),
                                        type: .withdraw)
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: swapTransaction))
        wireframe?.showActivityDetails(on: view?.controller, model: swapTransaction, assetManager: assetManager) { [weak self] in
            self?.view?.dismiss(competion: self?.completionHandler)
        }
    }
}
