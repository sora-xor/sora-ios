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

import UIKit
import SoraUIKit

import RobinHood
import SoraFoundation
import sorawallet

final class ConfirmSwapViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var view: ConfirmViewProtocol?
    var wireframe: ConfirmWireframeProtocol?
    let assetManager: AssetManagerProtocol
    let eventCenter: EventCenterProtocol
    let debouncer = Debouncer(interval: 0.8)
    
    var firstAssetId: String
    var secondAssetId: String
    var firstAssetAmount: Decimal
    var secondAssetAmount: Decimal
    var slippageTolerance: PolkaswapSlippage
    var details: [DetailViewModel]
    var amounts: SwapQuoteAmounts
    let market: LiquiditySourceType
    let walletService: WalletServiceProtocol
    let fee: Decimal
    var swapVariant: SwapVariant
    var minMaxValue: Decimal
    private var dexId: UInt32
    /// The route of the quote on screen; empty until the review's first quote.
    private var quoteRoute: [String] = []
    private let interactor: PolkaswapMainInteractorInputProtocol
    private var quoteParams: PolkaswapMainInteractorQuoteParams
    private weak var assetsProvider: AssetProviderProtocol?
    private var items: [SoramitsuTableViewItemProtocol] = [] {
        didSet {
            setupItems?(items)
        }
    }
    private var isQuoteAvailable = true
    private var isEnoughtBalance: Bool = true {
        didSet {
            guard oldValue != isEnoughtBalance, let firstAsset = assetManager.assetInfo(for: firstAssetId) else { return }
            let insufficientBalanceText = R.string.localizable.polkaswapInsufficientBalance(firstAsset.symbol, preferredLanguages: .currentLocale)
            let buttonText = isEnoughtBalance ? R.string.localizable.commonConfirm(preferredLanguages: .currentLocale) : insufficientBalanceText
            let disableColor = SoramitsuUI.shared.theme.palette.color(.fgPrimary).withAlphaComponent(0.04)
            let textColor: SoramitsuColor = isEnoughtBalance ? .bgSurface : .custom(uiColor: disableColor)
            let buttonAttributedText = SoramitsuTextItem(text: buttonText,
                                                         fontData: FontType.buttonM,
                                                         textColor: textColor,
                                                         alignment: .center)
            items.compactMap { $0 as? SoramitsuButtonItem }.first?.title = buttonAttributedText
            items.compactMap { $0 as? SoramitsuButtonItem }.first?.isEnable = isEnoughtBalance
            reloadItems?(items)
        }
    }
    
    private var firstAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            updateBalanceAvailability()
        }
    }
    
    private var secondAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            updateBalanceAvailability()
        }
    }
    private var feeAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            updateBalanceAvailability()
        }
    }
    private lazy var detailsFactory = DetailViewModelFactory(assetManager: assetManager)
    private let fiatData: [PIExactFiatData]
    var title: String? {
        return nil
    }
    
    var imageName: String? {
        return "Wallet/polkaswapLogo"
    }
    
    init(
        wireframe: ConfirmWireframeProtocol?,
        firstAssetId: String,
        secondAssetId: String,
        assetManager: AssetManagerProtocol,
        eventCenter: EventCenterProtocol,
        firstAssetAmount: Decimal,
        secondAssetAmount: Decimal,
        slippageTolerance: PolkaswapSlippage,
        details: [DetailViewModel],
        market: LiquiditySourceType,
        amounts: SwapQuoteAmounts,
        walletService: WalletServiceProtocol,
        fee: Decimal,
        swapVariant: SwapVariant,
        minMaxValue: Decimal,
        dexId: UInt32,
        interactor: PolkaswapMainInteractorInputProtocol,
        quoteParams: PolkaswapMainInteractorQuoteParams,
        assetsProvider: AssetProviderProtocol?,
        fiatData: [PIExactFiatData]
    ) {
        self.firstAssetId = firstAssetId
        self.secondAssetId = secondAssetId
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.firstAssetAmount = firstAssetAmount
        self.secondAssetAmount = secondAssetAmount
        self.slippageTolerance = slippageTolerance
        self.details = details
        self.market = market
        self.amounts = amounts
        self.walletService = walletService
        self.fee = fee
        self.swapVariant = swapVariant
        self.minMaxValue = minMaxValue
        self.dexId = dexId
        self.interactor = interactor
        self.quoteParams = quoteParams
        self.assetsProvider = assetsProvider
        self.fiatData = fiatData
        self.eventCenter = eventCenter
        self.eventCenter.add(observer: self)
    }
    
    private func updateBalanceData() {
        firstAssetBalance = assetsProvider?.getBalances(with: [firstAssetId]).first
            ?? .unavailable(identifier: firstAssetId)
        secondAssetBalance = assetsProvider?.getBalances(with: [secondAssetId]).first
            ?? .unavailable(identifier: secondAssetId)
        let feeAssetId = assetManager.getAssetList()?.first(where: { $0.isFeeAsset })?.assetId ?? WalletAssetId.xor.rawValue
        feeAssetBalance = assetsProvider?.getBalances(with: [feeAssetId]).first
            ?? .unavailable(identifier: feeAssetId)
    }

    private func updateBalanceAvailability() {
        let maximumSpend = swapVariant == .desiredOutput
            ? minMaxValue
            : firstAssetAmount
        guard isQuoteAvailable,
              fee > 0,
              !firstAssetBalance.isUnavailable,
              !firstAssetId.isEmpty,
              !secondAssetId.isEmpty,
              firstAssetId != secondAssetId,
              maximumSpend > 0,
              maximumSpend <= firstAssetBalance.balance.decimalValue,
              let fromAsset = assetManager.assetInfo(for: firstAssetId),
              let toAsset = assetManager.assetInfo(for: secondAssetId),
              let feeAsset = assetManager.getAssetList()?.first(where: { $0.isFeeAsset }) else {
            isEnoughtBalance = false
            return
        }

        if fromAsset.isFeeAsset {
            guard fromAsset.assetId == feeAsset.assetId,
                  maximumSpend + fee <= firstAssetBalance.balance.decimalValue else {
                isEnoughtBalance = false
                return
            }
            isEnoughtBalance = true
            return
        }

        if toAsset.isFeeAsset {
            let guaranteedReceive = swapVariant == .desiredInput
                ? minMaxValue
                : secondAssetAmount
            guard toAsset.assetId == feeAsset.assetId,
                  !secondAssetBalance.isUnavailable,
                  guaranteedReceive > 0,
                  secondAssetBalance.balance.decimalValue + guaranteedReceive >= fee else {
                isEnoughtBalance = false
                return
            }
            isEnoughtBalance = true
            return
        }

        guard feeAssetBalance.identifier == feeAsset.assetId,
              !feeAssetBalance.isUnavailable,
              feeAssetBalance.balance.decimalValue >= fee else {
            isEnoughtBalance = false
            return
        }
        isEnoughtBalance = true
    }

    private func hasCurrentExactQuote() -> Bool {
        guard fee > 0,
              !firstAssetId.isEmpty,
              !secondAssetId.isEmpty,
              firstAssetId != secondAssetId,
              assetManager.assetInfo(for: firstAssetId) != nil,
              assetManager.assetInfo(for: secondAssetId) != nil,
              amounts.fromAmount > 0,
              amounts.toAmount > 0 else {
            return false
        }
        let expectedLimit = slippageLimit(for: amounts)
        let amountsMatch = swapVariant == .desiredInput
            ? firstAssetAmount == amounts.fromAmount
                && secondAssetAmount == amounts.toAmount
            : firstAssetAmount == amounts.toAmount
                && secondAssetAmount == amounts.fromAmount
        // The signer needs the decimals the quote was decoded with, and a
        // limit of less than one unit of its asset cannot be signed.
        return amountsMatch
            && amounts.sourcePrecision != nil && amounts.destinationPrecision != nil
            && minMaxValue > 0 && minMaxValue == expectedLimit
    }

    /// The slippage limit of a quote as it is signed: the least received in
    /// whole units of the destination asset, or the most sold in whole units
    /// of the source asset. The review shows, checks balances against and
    /// submits this value.
    private func slippageLimit(for amounts: SwapQuoteAmounts) -> Decimal {
        amounts.slippageLimit(slippageTolerance,
                              direction: swapVariant,
                              fromAsset: assetManager.assetInfo(for: firstAssetId),
                              toAsset: assetManager.assetInfo(for: secondAssetId))
    }

    /// What a Confirm button was drawn with. A newer quote changes the model
    /// before the screen is redrawn; the button still on screen belongs to
    /// the quote it shows and does not submit another.
    private struct ShownQuote: Equatable {
        let firstAssetAmount: Decimal
        let secondAssetAmount: Decimal
        let limit: Decimal
        let dexId: UInt32
        let route: [String]
    }

    private var shownQuote: ShownQuote {
        ShownQuote(firstAssetAmount: firstAssetAmount, secondAssetAmount: secondAssetAmount, limit: minMaxValue,
                   dexId: dexId, route: quoteRoute)
    }
}
 
extension ConfirmSwapViewModel: EventVisitorProtocol {
    func processNewBlockAppeared(event: NewBlockEvent) {
        loadQuote()
    }
}

extension ConfirmSwapViewModel: ConfirmViewModelProtocol {
    func viewDidLoad() {
        updateBalanceData()
        setupContent()
        assetsProvider?.add(observer: self)
    }
}

extension ConfirmSwapViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        if Thread.isMainThread {
            updateBalanceData()
        } else {
            DispatchQueue.main.async { [weak self] in self?.updateBalanceData() }
        }
    }
}


extension ConfirmSwapViewModel {
    func loadQuote() {
        debouncer.perform { [weak self] in
            guard let self = self else { return }
            self.interactor.quote(params: self.quoteParams)
        }
    }

    func setupContent() {
        guard let firstAsset = assetManager.assetInfo(for: firstAssetId) else { return }
        // Each amount is written with all the decimals the quote was decoded
        // with, the decimals it is signed with, so it is shown exactly.
        let firstAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(
            with: amounts.sourcePrecision.flatMap { UInt32(exactly: $0) } ?? firstAsset.precision)

        let secondAsset = assetManager.assetInfo(for: secondAssetId)
        let secondAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(
            with: amounts.destinationPrecision.flatMap { UInt32(exactly: $0) } ?? secondAsset?.precision ?? 18)
        
        // The amount sold is never written as less than it is, the amount
        // received never as more.
        let firstAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: firstAsset.icon ?? ""),
                                                         amountText: SwapAmountText.string(firstAssetAmount, formatter: firstAssetFormatter, roundingUp: true),
                                                         symbol: firstAsset.symbol)
        
        let secondAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: secondAsset?.icon ?? ""),
                                                          amountText: SwapAmountText.string(secondAssetAmount, formatter: secondAssetFormatter, roundingUp: false),
                                                          symbol: secondAsset?.symbol ?? "")
        
        let confirmAssetsItem = ConfirmAssetsItem(firstAssetImageModel: firstAssetImageModel,
                                                  secondAssetImageModel: secondAssetImageModel,
                                                  operationImageName: "Wallet/swapArrow")
        
        let symbol = swapVariant == .desiredInput ? "\(secondAsset?.symbol ?? "")" : "\(firstAsset.symbol)"
        let amount = slippageLimit(for: amounts)
        
        // Eight decimals are shown: the most sold rounded up to what is
        // shown, the least received down, never better than what is signed.
        let amountText = SwapAmountText.string(amount, formatter: NumberFormatter.cryptoAssets,
                                               roundingUp: swapVariant == .desiredOutput)
        let minMaxAmountText =  "\(amountText) \(symbol)"
        
        let minReward = R.string.localizable.polkaswapOutputEstimated(minMaxAmountText,
                                                                      preferredLanguages: .currentLocale)
        let maxSold = R.string.localizable.polkaswapInputEstimated(minMaxAmountText,
                                                                   preferredLanguages: .currentLocale)
        let minimalRewardText = swapVariant == .desiredInput ? minReward : maxSold

        let minimalRewardAttributedText = SoramitsuTextItem(text: minimalRewardText,
                                                            fontData: FontType.paragraphS,
                                                            textColor: .fgPrimary,
                                                            alignment: .center)
        
        let minimalRewardTextItem = SoraTextItem(text: minimalRewardAttributedText)
        
        let detailItem = ConfirmDetailsItem(detailViewModels: details)
        
        let slipageItem = ConfirmOptionsItem(toleranceText: slippageTolerance.displayValue, market: market)
        
        let buttonText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM,
                                           textColor: .bgSurface,
                                           alignment: .center)
        let shown = shownQuote
        let buttonItem = SoramitsuButtonItem(title: buttonText,
                                             buttonBackgroudColor: .additionalPolkaswap,
                                             isEnable: isEnoughtBalance) { [weak self] in
            guard let self, self.shownQuote == shown else { return }
            self.submit()
        }
        items = [confirmAssetsItem,
                 SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                 minimalRewardTextItem,
                 SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                 detailItem,
                 SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                 slipageItem,
                 SoramitsuTableViewSpacerItem(space: 24, color: .custom(uiColor: .clear)),
                 buttonItem]
    }
    
    func submit() {
        updateBalanceData()
        guard isEnoughtBalance, hasCurrentExactQuote() else {
            isEnoughtBalance = false
            return
        }

        let networkFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                   assetId: WalletAssetId.xor.rawValue,
                                                   type: "fee",
                                                   parameters: [],
                                                   accountId: nil,
                                                   minValue: nil,
                                                   maxValue: nil,
                                                   context: nil)
        let networkFee = Fee(value: AmountDecimal(value: fee), feeDescription: networkFeeDescription)

        let amount = AmountDecimal(value: firstAssetAmount)
        let sourceAsset = firstAssetId
        let estimatedAmount = AmountDecimal(value: secondAssetAmount)
        let destinationAsset = secondAssetId
        
        var context = [TransactionContextKeys.transactionType: TransactionType.swap.rawValue,
                       TransactionContextKeys.estimatedAmount: estimatedAmount.stringValue,
                       TransactionContextKeys.marketType: market.rawValue,
                       TransactionContextKeys.slippage: slippageTolerance.contextValue,
                       TransactionContextKeys.desire: swapVariant.rawValue,
                       TransactionContextKeys.minMaxValue: AmountDecimal(value: minMaxValue).stringValue,
                       TransactionContextKeys.dex: "\(dexId)"]
        // The decimals the reviewed amounts were scaled by. The signer scales
        // by its own and refuses when they differ.
        if let sourcePrecision = amounts.sourcePrecision, let destinationPrecision = amounts.destinationPrecision {
            context[TransactionContextKeys.sourcePrecision] = String(sourcePrecision)
            context[TransactionContextKeys.destinationPrecision] = String(destinationPrecision)
        }
        let transferInfo = TransferInfo(source: "",
                                        destination: destinationAsset,
                                        amount: amount,
                                        asset: sourceAsset,
                                        details: "",
                                        fees: [networkFee],
                                        context: context)

        // A newer quote can arrive while the swap is being sent. The activity
        // record is made from the amounts that were submitted.
        let submitted = (first: firstAssetAmount, second: secondAssetAmount)
        wireframe?.showActivityIndicator()
        walletService.transfer(info: transferInfo, runCompletionIn: .main) { [weak self] (optionalResult) in
            self?.wireframe?.hideActivityIndicator()

            if let result = optionalResult {
                self?.handleTransfer(result: result, firstAssetAmount: submitted.first, secondAssetAmount: submitted.second)
            }
        }
    }
    
    private func handleTransfer(result: Result<Data, Swift.Error>, firstAssetAmount: Decimal, secondAssetAmount: Decimal) {
        var status: TransactionBase.Status = .pending
        var txHash = ""
        if case let .failure = result {
            status = .failed
        }
        if case let .success(hex) = result {
            txHash = hex.toHex(includePrefix: true)
        }
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "", 
                                   fee: Amount(value: fee * pow(10, 18)),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
        
        let swapTransaction = Swap(base: base,
                                   fromTokenId: firstAssetId,
                                   toTokenId: secondAssetId,
                                   fromAmount:  Amount(value: firstAssetAmount),
                                   toAmount:  Amount(value: secondAssetAmount),
                                   market: market)
        
        eventCenter.notify(with: NewTransactionCreatedEvent(item: swapTransaction))
        wireframe?.showActivityDetails(on: view?.controller, model: swapTransaction, assetManager: assetManager) { [weak self] in
            self?.view?.dismiss(competion: {})
        }
    }
    
    func updateDetails(params: PolkaswapMainInteractorQuoteParams? = nil,
                       quote: SwapValues? = nil,
                       dexId: UInt32 = 0,
                       completion: (() -> Void)? = nil) {
        if let params, !matchesReviewedRequest(params) {
            completion?()
            return
        }
        guard let quote,
              let fromAsset = assetManager.assetInfo(for: firstAssetId),
              let toAsset = assetManager.assetInfo(for: secondAssetId),
              let amounts = SwapQuoteAmountsFactory().createAmounts(
                fromAsset: fromAsset, toAsset: toAsset, params: quoteParams, quote: quote),
              amounts.fromAmount > 0, amounts.toAmount > 0 else {
            isQuoteAvailable = false
            updateBalanceAvailability()
            completion?()
            return
        }
        isQuoteAvailable = true
        self.amounts = amounts
        self.dexId = dexId
        self.quoteRoute = quote.route
        
        let route = quote.route.compactMap({ self.assetManager.assetInfo(for: $0)?.symbol }).joined(separator: " → ")
        
        minMaxValue = slippageLimit(for: amounts)
        details = detailsFactory.createSwapViewModels(fromAsset: fromAsset,
                                                      toAsset: toAsset,
                                                      slippage: slippageTolerance,
                                                      amount: amounts.fromAmount,
                                                      quote: amounts,
                                                      direction: swapVariant,
                                                      fiatData: fiatData,
                                                      swapFee: fee,
                                                      route: route,
                                                      viewModel: self)
        
        if swapVariant == .desiredInput {
            firstAssetAmount = amounts.fromAmount
            secondAssetAmount = amounts.toAmount
        } else {
            firstAssetAmount = amounts.toAmount
            secondAssetAmount = amounts.fromAmount
        }
        updateBalanceData()
        setupContent()
        completion?()
    }
}

extension ConfirmSwapViewModel: PolkaswapMainInteractorOutputProtocol {
    func didLoadQuote(_ quote: SwapValues?, dexId: UInt32, params: PolkaswapMainInteractorQuoteParams) {
        guard matchesReviewedRequest(params) else { return }
        updateDetails(params: params, quote: quote, dexId: dexId)
    }

    private func matchesReviewedRequest(_ params: PolkaswapMainInteractorQuoteParams) -> Bool {
        params.fromAssetId == quoteParams.fromAssetId &&
            params.toAssetId == quoteParams.toAssetId &&
            params.amount == quoteParams.amount &&
            params.swapVariant == quoteParams.swapVariant &&
            params.liquiditySources == quoteParams.liquiditySources &&
            params.filterMode == quoteParams.filterMode
    }

    func didUpdatePoolSubscription() {
        loadQuote()
    }
}

extension ConfirmSwapViewModel: DetailViewModelDelegate {
    func minMaxReceivedInfoButtonTapped() {
        wireframe?.present(
            message: swapVariant.message,
            title: swapVariant.title,
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func networkFeeInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
    
    func swapFeeInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapLiquidityTotalFeeDesc(preferredLanguages: .currentLocale),
            title: R.string.localizable.polkaswapLiquidityTotalFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
}
