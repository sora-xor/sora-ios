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
    var slippageTolerance: Float
    var details: [DetailViewModel]
    var amounts: SwapQuoteAmounts
    let market: LiquiditySourceType
    let walletService: WalletServiceProtocol
    let fee: Decimal
    var swapVariant: SwapVariant
    var minMaxValue: Decimal
    private var dexId: UInt32
    private let interactor: PolkaswapMainInteractorInputProtocol
    private var quoteParams: PolkaswapMainInteractorQuoteParams
    private weak var assetsProvider: AssetProviderProtocol?
    private var items: [SoramitsuTableViewItemProtocol] = [] {
        didSet {
            setupItems?(items)
        }
    }
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
            // check if balance is enough
            if firstAssetAmount > firstAssetBalance.balance.decimalValue {
                isEnoughtBalance = false
                return
            }

            // check if exchanging from XOR, and have not enough XOR to pay the fee
            if let fromAsset = assetManager.assetInfo(for: firstAssetId),
               fromAsset.isFeeAsset,
               firstAssetAmount + fee > firstAssetBalance.balance.decimalValue {
                isEnoughtBalance = false
                return
            }

            isEnoughtBalance = true
        }
    }
    
    private var secondAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0))
    private lazy var detailsFactory = DetailViewModelFactory(assetManager: assetManager)
    private let fiatData: [FiatData]
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
        slippageTolerance: Float,
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
        fiatData: [FiatData]
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
        if !self.firstAssetId.isEmpty, let firstAssetBalance = assetsProvider?.getBalances(with: [self.firstAssetId]).first {
            self.firstAssetBalance = firstAssetBalance
        }
        
        if !self.secondAssetId.isEmpty, let secondAssetBalance = assetsProvider?.getBalances(with: [self.secondAssetId]).first {
            self.secondAssetBalance = secondAssetBalance
        }
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
        updateBalanceData()
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
        let firstAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)
        
        let secondAsset = assetManager.assetInfo(for: secondAssetId)
        let secondAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: 8)
        
        let firstAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: firstAsset.icon ?? ""),
                                                         amountText: firstAssetFormatter.stringFromDecimal(firstAssetAmount) ?? "",
                                                         symbol: firstAsset.symbol)
        
        let secondAssetImageModel = ConfirmAssetViewModel(imageViewModel: WalletSvgImageViewModel(svgString: secondAsset?.icon ?? ""),
                                                          amountText: secondAssetFormatter.stringFromDecimal(secondAssetAmount) ?? "",
                                                          symbol: secondAsset?.symbol ?? "")
        
        let confirmAssetsItem = ConfirmAssetsItem(firstAssetImageModel: firstAssetImageModel,
                                                  secondAssetImageModel: secondAssetImageModel,
                                                  operationImageName: "Wallet/swapArrow")
        
        let symbol = swapVariant == .desiredInput ? "\(secondAsset?.symbol ?? "")" : "\(firstAsset.symbol)"
        let amount = swapVariant == .desiredInput ? amounts.toAmount * (1 - Decimal(Double(slippageTolerance)) / 100.0) : amounts.toAmount * (1 + Decimal(Double(slippageTolerance)) / 100.0)
        
        let amountText = NumberFormatter.cryptoAssets.stringFromDecimal(amount) ?? ""
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
        
        let slipageItem = ConfirmOptionsItem(toleranceText: "\(slippageTolerance)%", market: market)
        
        let buttonText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM,
                                           textColor: .bgSurface,
                                           alignment: .center)
        let buttonItem = SoramitsuButtonItem(title: buttonText,
                                             buttonBackgroudColor: .additionalPolkaswap,
                                             isEnable: isEnoughtBalance) { [weak self] in
            self?.submit()
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
        
        let transferInfo = TransferInfo(source: "",
                                        destination: destinationAsset,
                                        amount: amount,
                                        asset: sourceAsset,
                                        details: "",
                                        fees: [networkFee],
                                        context: [TransactionContextKeys.transactionType: TransactionType.swap.rawValue,
                                                  TransactionContextKeys.estimatedAmount: estimatedAmount.stringValue,
                                                  TransactionContextKeys.marketType: market.rawValue,
                                                  TransactionContextKeys.slippage: String(slippageTolerance),
                                                  TransactionContextKeys.desire: swapVariant.rawValue,
                                                  TransactionContextKeys.minMaxValue: AmountDecimal(value: minMaxValue).stringValue,
                                                  TransactionContextKeys.dex: "\(dexId)"
                                        ])
        
        wireframe?.showActivityIndicator()
        walletService.transfer(info: transferInfo, runCompletionIn: .main) { [weak self] (optionalResult) in
            self?.wireframe?.hideActivityIndicator()

            if let result = optionalResult {
                self?.handleTransfer(result: result)
            }
        }
    }
    
    private func handleTransfer(result: Result<Data, Swift.Error>) {
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
        guard let quote = quote,
              let fromAsset = assetManager.assetInfo(for: firstAssetId),
              let toAsset = assetManager.assetInfo(for: secondAssetId) else {
            completion?()
            return
        }
        
        
        guard let amounts = SwapQuoteAmountsFactory().createAmounts(
            fromAsset: fromAsset,
            toAsset: toAsset,
            params: quoteParams,
            quote: quote), self.amounts != amounts else {
            completion?()
            return
        }
        self.amounts = amounts
        self.dexId = dexId
        
        let route = quote.route.compactMap({ self.assetManager.assetInfo(for: $0)?.symbol }).joined(separator: " → ")
        
        minMaxValue = amounts.toAmount * (1 - Decimal(Double(slippageTolerance)) / 100.0)
        details = detailsFactory.createSwapViewModels(fromAsset: fromAsset,
                                                      toAsset: toAsset,
                                                      slippage: Decimal(Double(slippageTolerance)),
                                                      amount: amounts.fromAmount,
                                                      quote: amounts,
                                                      direction: swapVariant,
                                                      fiatData: fiatData,
                                                      swapFee: fee,
                                                      route: route,
                                                      viewModel: self)
        
        items.compactMap { $0 as? ConfirmDetailsItem }.first?.detailViewModels = details
        
        if swapVariant == .desiredInput {
            firstAssetAmount = amounts.fromAmount
            secondAssetAmount = amounts.toAmount
            
            let secondAssetPrecision = assetManager.assetInfo(for: secondAssetId)?.precision ?? 0
            let secondAssetFormatter = NumberFormatter.inputedAmoutFormatter(with: secondAssetPrecision)
            let secondAmountText = secondAssetFormatter.stringFromDecimal(amounts.toAmount) ?? ""
            
            items.compactMap { $0 as? ConfirmAssetsItem }.first?.secondAssetImageModel.amountText = secondAmountText
        } else {
            firstAssetAmount = amounts.toAmount
            secondAssetAmount = amounts.fromAmount
            
            let firstAssetPrecision = assetManager.assetInfo(for: firstAssetId)?.precision ?? 0
            let firstAssetFormatter = NumberFormatter.inputedAmoutFormatter(with: firstAssetPrecision)
            let firstAmountText = firstAssetFormatter.stringFromDecimal(amounts.toAmount) ?? ""

            items.compactMap { $0 as? ConfirmAssetsItem }.first?.firstAssetImageModel.amountText = firstAmountText
        }

        reloadItems?(items)
        completion?()
    }
}

extension ConfirmSwapViewModel: PolkaswapMainInteractorOutputProtocol {
    func didLoadQuote(_ quote: SwapValues?, dexId: UInt32, params: PolkaswapMainInteractorQuoteParams) {
        guard let quote = quote else {
            isEnoughtBalance = false
            return
        }
        
        updateDetails(params: params, quote: quote, dexId: dexId) { [weak self] in
            guard let self = self else { return }
            // check if exchanging to XOR, we'll receive enough XOR to pay nework fee from it
            if let toAsset = self.assetManager.assetInfo(for: self.secondAssetId),
               toAsset.isFeeAsset {
                let xorAmount = self.swapVariant == .desiredInput ? self.minMaxValue : self.amounts.toAmount
                let xorAmountFuture = self.secondAssetBalance.balance.decimalValue + xorAmount
                guard xorAmountFuture > self.fee else {
                    self.isEnoughtBalance = false
                    return
                }
            }

            self.isEnoughtBalance = true
        }
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
