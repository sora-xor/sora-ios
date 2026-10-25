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

protocol ConfirmViewModelProtocol {
    var title: String? { get }
    var imageName: String? { get }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
    func viewWillDisappear()
}

extension ConfirmViewModelProtocol {
    func viewWillDisappear() {}
}

final class ConfirmSupplyLiquidityViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?

    weak var view: ConfirmViewProtocol?
    var wireframe: ConfirmWireframeProtocol?
    let assetManager: AssetManagerProtocol
    let poolsService: PoolsServiceInputProtocol
    let debouncer = Debouncer(interval: 0.8)

    var baseAssetId: String
    var targetAssetId: String
    var firstAssetAmount: Decimal
    var secondAssetAmount: Decimal
    var slippageTolerance: PolkaswapSlippage
    var details: [DetailViewModel]
    let transactionType: TransactionType
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
        return R.string.localizable.addLiquidityConfirmationTitle(preferredLanguages: .currentLocale)
    }

    var imageName: String? {
        return nil
    }

    init(
        wireframe: ConfirmWireframeProtocol?,
        baseAssetId: String,
        targetAssetId: String,
        poolsService: PoolsServiceInputProtocol,
        assetManager: AssetManagerProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        details: [DetailViewModel],
        transactionType: TransactionType,
        fee: Decimal,
        operationFactory: WalletNetworkOperationFactoryProtocol,
        feeChangeHandler: @escaping () -> Void,
        walletService: WalletServiceProtocol
    ) {
        self.baseAssetId = baseAssetId
        self.targetAssetId = targetAssetId
        self.wireframe = wireframe
        self.poolsService = poolsService
        self.assetManager = assetManager
        self.firstAssetAmount = firstAssetAmount
        self.secondAssetAmount = secondAssetAmount
        self.slippageTolerance = slippageTolerance
        self.details = details
        self.transactionType = transactionType
        self.fee = fee
        self.operationFactory = operationFactory
        self.feeChangeHandler = feeChangeHandler
        self.walletService = walletService
    }
}

extension ConfirmSupplyLiquidityViewModel: ConfirmViewModelProtocol {
    func viewDidLoad() {
        updateContent()
    }

    func viewWillDisappear() {
        signingAuthorization.revoke()
        preflightTask?.cancel()
        preflightTask = nil
    }
}

extension ConfirmSupplyLiquidityViewModel {
    func updateContent() {
        var items: [SoramitsuTableViewItemProtocol] = []

        let firstAsset = assetManager.assetInfo(for: baseAssetId)
        let firstAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)

        let secondAsset = assetManager.assetInfo(for: targetAssetId)
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
        items.append(confirmAssetsItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))

        let text = R.string.localizable.addLiquidityPoolShareDescription(slippageTolerance.contextValue, preferredLanguages: .currentLocale)
        let textItem = SoramitsuTextItem(text: text, fontData: FontType.paragraphS, textColor: .fgPrimary, alignment: .center)
        let slippageTextItem = SoraTextItem(text: textItem)
        items.append(slippageTextItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))

        let detailItem = ConfirmDetailsItem(detailViewModels: details)
        items.append(detailItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))

        let slipageItem = ConfirmOptionsItem(toleranceText: slippageTolerance.displayValue)
        items.append(slipageItem)
        items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))

        if transactionType == .liquidityAddNewPool || transactionType == .liquidityAddToExistingPoolFirstTime {
            let warning = WarningItem()
            items.append(warning)
            items.append(SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)))
        }

        let buttonText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM,
                                           textColor: .bgSurface,
                                           alignment: .center)
        let buttonItem = SoramitsuButtonItem(title: buttonText) { [weak self] in
            self?.submit()
        }
        items.append(buttonItem)

        setupItems?(items)
    }


    func submit() {
        guard !isSubmitting, !feeReviewInvalidated else { return }
        guard isConfirmationActive,
              fee > 0,
              firstAssetAmount > 0,
              secondAssetAmount > 0,
              !baseAssetId.isEmpty,
              !targetAssetId.isEmpty,
              baseAssetId != targetAssetId,
              assetManager.assetInfo(for: baseAssetId) != nil,
              assetManager.assetInfo(for: targetAssetId) != nil,
              transactionType == .liquidityAdd
                || transactionType == .liquidityAddNewPool
                || transactionType == .liquidityAddToExistingPoolFirstTime else {
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
            // KXOR is a distinct runtime asset and trading pair. Never validate a
            // KXOR mutation against the XOR pool before signing it as KXOR.
            let poolBaseAssetId = baseAssetId
            let pairState = try await poolsService.loadPairState(
                baseAssetId: poolBaseAssetId,
                targetAssetId: targetAssetId
            )
            try await validateLivePool(
                pairState: pairState,
                poolBaseAssetId: poolBaseAssetId
            )

            let balances = try await fetchLiveBalances()
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

            try validateLiveBalances(balances, fee: freshFee)
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

    @MainActor
    private func validateLivePool(
        pairState: PoolNetworkState,
        poolBaseAssetId: String
    ) async throws {
        switch transactionType {
        case .liquidityAdd:
            guard pairState.isPresented,
                  pairState.isEnabled,
                  let pool = await poolsService.loadPool(
                    by: poolBaseAssetId,
                    targetAssetId: targetAssetId
                  ),
                  pool.baseAssetId == poolBaseAssetId,
                  pool.targetAssetId == targetAssetId,
                  let baseReserves = pool.baseAssetReserves,
                  baseReserves > 0,
                  let targetReserves = pool.targetAssetReserves,
                  targetReserves > 0,
                  let totalIssuances = pool.totalIssuances,
                  totalIssuances > 0 else {
                throw LiquidityConfirmationPreflightError.unavailable
            }

            let minimumBase = slippageTolerance.minimumAmount(for: firstAssetAmount)
            let minimumTarget = slippageTolerance.minimumAmount(for: secondAssetAmount)
            let targetForAllBase = firstAssetAmount * targetReserves / baseReserves
            let actualBase: Decimal
            let actualTarget: Decimal

            if targetForAllBase <= secondAssetAmount {
                actualBase = firstAssetAmount
                actualTarget = targetForAllBase
            } else {
                actualBase = secondAssetAmount * baseReserves / targetReserves
                actualTarget = secondAssetAmount
            }

            guard actualBase >= minimumBase,
                  actualTarget >= minimumTarget else {
                throw LiquidityConfirmationPreflightError.insufficientLiquidity
            }

        case .liquidityAddToExistingPoolFirstTime:
            guard !pairState.isPresented, pairState.isEnabled else {
                throw LiquidityConfirmationPreflightError.unavailable
            }

        case .liquidityAddNewPool:
            guard !pairState.isPresented, !pairState.isEnabled else {
                throw LiquidityConfirmationPreflightError.unavailable
            }

        default:
            throw LiquidityConfirmationPreflightError.unavailable
        }
    }

    @MainActor
    private func fetchLiveBalances() async throws -> [BalanceData] {
        let assetIds = Array(Set([
            baseAssetId,
            targetAssetId,
            WalletAssetId.xor.rawValue
        ])).sorted()

        return try await withCheckedThrowingContinuation { continuation in
            walletService.fetchBalance(for: assetIds, runCompletionIn: .main) { result in
                guard let result else {
                    continuation.resume(throwing: LiquidityConfirmationPreflightError.unavailable)
                    return
                }

                switch result {
                case let .success(balances):
                    guard let balances else {
                        continuation.resume(throwing: LiquidityConfirmationPreflightError.unavailable)
                        return
                    }
                    continuation.resume(returning: balances)
                case .failure:
                    continuation.resume(throwing: LiquidityConfirmationPreflightError.unavailable)
                }
            }
        }
    }

    private func validateLiveBalances(_ balances: [BalanceData], fee freshFee: Decimal) throws {
        let identifiers = balances.map(\.identifier)
        guard Set(identifiers).count == identifiers.count,
              balances.allSatisfy({ $0.balance.decimalValue >= 0 }) else {
            throw LiquidityConfirmationPreflightError.unavailable
        }

        var requiredByAsset: [String: Decimal] = [:]
        requiredByAsset[baseAssetId, default: .zero] += firstAssetAmount
        requiredByAsset[targetAssetId, default: .zero] += secondAssetAmount
        requiredByAsset[WalletAssetId.xor.rawValue, default: .zero] += freshFee

        let balancesByAsset = Dictionary(uniqueKeysWithValues: balances.map {
            ($0.identifier, $0.balance.decimalValue)
        })
        for assetId in requiredByAsset.keys.sorted() {
            guard let required = requiredByAsset[assetId],
                  required > 0,
                  let available = balancesByAsset[assetId] else {
                throw LiquidityConfirmationPreflightError.unavailable
            }
            guard available >= required else {
                throw LiquidityConfirmationPreflightError.insufficientBalance(assetId: assetId)
            }
        }
    }

    private func makeTransferInfo(fee freshFee: Decimal) throws -> TransferInfo {
        let shareOfPool = details.first(where: { $0.title == Constants.apyTitle })?
            .assetAmountText.text ?? ""
        let apy = details.first(where: { $0.title == Constants.apyTitle })?
            .assetAmountText.text ?? ""
        return try LiquidityTransferInfoFactory.supply(
            baseAssetId: baseAssetId,
            targetAssetId: targetAssetId,
            firstAssetAmount: firstAssetAmount,
            secondAssetAmount: secondAssetAmount,
            slippageTolerance: slippageTolerance,
            transactionType: transactionType,
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
                                        firstTokenId: targetAssetId,
                                        secondTokenId: baseAssetId,
                                        firstAmount: Amount(value: firstAssetAmount),
                                        secondAmount: Amount(value: secondAssetAmount),
                                        type: .add)
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: swapTransaction))
        wireframe?.showActivityDetails(on: view?.controller, model: swapTransaction, assetManager: assetManager) { [weak self] in
            self?.view?.dismiss(competion: {})
        }
    }
}
