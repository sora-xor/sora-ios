import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation
import XNetworking

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
    var lpFee: Decimal
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
        lpFee: Decimal,
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
        self.lpFee = lpFee
        self.interactor = interactor
        self.quoteParams = quoteParams
        self.assetsProvider = assetsProvider
        self.fiatData = fiatData
        self.eventCenter = eventCenter
    }
}

extension ConfirmSwapViewModel: ConfirmViewModelProtocol {
    func viewDidLoad() {
        setupContent()
        subscribeToPoolUpdates()
        assetsProvider?.add(observer: self)
    }
}

extension ConfirmSwapViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        if !self.firstAssetId.isEmpty, let firstAssetBalance = assetsProvider?.getBalances(with: [self.firstAssetId]).first {
            self.firstAssetBalance = firstAssetBalance
        }
        
        if !self.secondAssetId.isEmpty, let secondAssetBalance = assetsProvider?.getBalances(with: [self.secondAssetId]).first {
            self.secondAssetBalance = secondAssetBalance
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
        let amountText =  "\(amount) \(symbol)"
        
        let minReward = R.string.localizable.polkaswapOutputEstimated(amountText,
                                                                      preferredLanguages: .currentLocale)
        let maxSold = R.string.localizable.polkaswapInputEstimated(amountText,
                                                                   preferredLanguages: .currentLocale)
        let minimalRewardText = swapVariant == .desiredInput ? minReward : maxSold
        
        let paragrathStyle = NSMutableParagraphStyle()
        paragrathStyle.alignment = .center
        
        let minimalRewardAttributedText: NSMutableAttributedString = FontType.paragraphS.attriburedString(with: minimalRewardText)
        minimalRewardAttributedText.addAttribute(.paragraphStyle,
                                                 value: paragrathStyle,
                                                 range: NSRange(location: 0, length: minimalRewardAttributedText.length))
        minimalRewardAttributedText.addAttribute(.font,
                                                 value: FontType.paragraphBoldS.font,
                                                 range: NSString(string: minimalRewardAttributedText.string).range(of: amountText))
        
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
        let lpFee = Fee(value: AmountDecimal(value: lpFee), feeDescription: networkFeeDescription)
        
        let amount = AmountDecimal(value: firstAssetAmount)
        let sourceAsset = firstAssetId
        let estimatedAmount = AmountDecimal(value: secondAssetAmount)
        let destinationAsset = secondAssetId
        
        let transferInfo = TransferInfo(source: "",
                                        destination: destinationAsset,
                                        amount: amount,
                                        asset: sourceAsset,
                                        details: "",
                                        fees: [networkFee, lpFee],
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
                                   fee: Amount(value: fee),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
        
        let swapTransaction = Swap(base: base,
                                   fromTokenId: firstAssetId,
                                   toTokenId: secondAssetId,
                                   fromAmount:  Amount(value: firstAssetAmount),
                                   toAmount:  Amount(value: secondAssetAmount),
                                   market: market,
                                   lpFee: Amount(value: lpFee))
        
        eventCenter.notify(with: NewTransactionCreatedEvent(item: swapTransaction))
        wireframe?.showActivityDetails(on: view?.controller, model: swapTransaction, assetManager: assetManager) { [weak self] in
            self?.view?.dissmiss(competion: {})
        }
    }
    
    func subscribeToPoolUpdates() {
        let xorID = WalletAssetId.xor.rawValue
        guard !firstAssetId.isEmpty, !secondAssetId.isEmpty else { return }

        interactor.unsubscribePoolXYK()
        interactor.unsubscribePoolTBC()

        if market == .smart || market == .xyk {
            if xorID != firstAssetId {
                interactor.subscribePoolXYK(assetId1: xorID, assetId2: firstAssetId)
            }
            if xorID != secondAssetId {
                interactor.subscribePoolXYK(assetId1: xorID, assetId2: secondAssetId)
            }
        }

        if market == .smart || market == .tbc {
            interactor.subscribePoolTBC(assetId: xorID)
            if xorID != firstAssetId {
                interactor.subscribePoolTBC(assetId: firstAssetId)
            }
            if xorID != secondAssetId {
                interactor.subscribePoolTBC(assetId: secondAssetId)
            }
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
        self.lpFee = amounts.lpAmount
        
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
    
    func lpFeeInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapLiqudityFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.polkaswapLiqudityFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
}
