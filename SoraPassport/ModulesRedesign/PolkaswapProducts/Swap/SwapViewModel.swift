import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SoraFoundation
import XNetworking

final class SwapViewModel {
    var detailsItem: PoolDetailsItem?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var fiatService: FiatServiceProtocol?
    weak var view: LiquidityViewProtocol?
    weak var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?
    var wireframe: LiquidityWireframeProtocol?
    let assetManager: AssetManagerProtocol?
    let detailsFactory: DetailViewModelFactoryProtocol
    let eventCenter: EventCenterProtocol
    let interactor: PolkaswapMainInteractorInputProtocol
    let networkFacade: WalletNetworkOperationFactoryProtocol?
    
    let debouncer = Debouncer(interval: 0.8)
    
    var title: String? {
        return nil
    }
    
    var imageName: String? {
        return "Wallet/polkaswapLogo"
    }
    
    var isSwap: Bool {
        return true
    }
    
    var firstFieldEmptyStateFullFiatText: String? { R.string.localizable.swapWantFrom(preferredLanguages: .currentLocale) }
    var secondFieldEmptyStateFullFiatText: String? { R.string.localizable.swapWantTo(preferredLanguages: .currentLocale) }
    
    var actionButtonImage: UIImage? {
        return R.image.wallet.swapButton()
    }
    
    var middleButtonActionHandler: (() -> Void)?
    
    var details: [DetailViewModel] = [] {
        didSet {
            DispatchQueue.main.async {
                self.view?.update(details: self.details)
            }
        }
    }
    
    var firstAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            let fiatText = setupFullBalanceText(from: firstAssetBalance)
            view?.updateFirstAsset(balance: fiatText)
            checkBalances()
            
            let inputedFiatText = setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId)
            let text = isEnoughtFirstAssetLiquidity ? inputedFiatText : R.string.localizable.commonNotEnoughBalance(preferredLanguages: .currentLocale)
            let amountColor: SoramitsuColor = isEnoughtFirstAssetLiquidity ? .fgPrimary : .statusError
            let fiatColor: SoramitsuColor = isEnoughtFirstAssetLiquidity ? .fgSecondary : .statusError
            var state: InputFieldState = focusedField == .one ? .focused : .default
            state = isEnoughtFirstAssetLiquidity ? state : .fail
            
            view?.updateFirstAsset(state: state, amountColor: amountColor, fiatColor: fiatColor)
            view?.updateFirstAsset(fiatText: text)
        }
    }
    
    var secondAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            let fiatText = setupFullBalanceText(from: secondAssetBalance)
            view?.updateSecondAsset(balance: fiatText)
        }
    }
    
    var firstAssetId: String = "" {
        didSet {
            guard let asset = assetManager?.assetInfo(for: firstAssetId) else { return }
            let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
            view?.updateFirstAsset(symbol: asset.symbol, image: image)
            updateAssetsBalance()
            view?.updateMiddleButton(isEnabled: !secondAssetId.isEmpty && !firstAssetId.isEmpty)
            
            if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                marketSourcer = SwapMarketSourcer(fromAssetId: firstAssetId, toAssetId: secondAssetId)
                interactor.checkIsPathAvailable(fromAssetId: firstAssetId, toAssetId: secondAssetId)
                loadQuote()
            }
        }
    }
    
    var secondAssetId: String = "" {
        didSet {
            guard let asset = assetManager?.assetInfo(for: secondAssetId) else { return }
            let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
            view?.updateSecondAsset(symbol: asset.symbol, image: image)
            updateAssetsBalance()
            view?.updateMiddleButton(isEnabled: !secondAssetId.isEmpty && !firstAssetId.isEmpty)
            
            if !firstAssetId.isEmpty, !secondAssetId.isEmpty {
                marketSourcer = SwapMarketSourcer(fromAssetId: firstAssetId, toAssetId: secondAssetId)
                interactor.checkIsPathAvailable(fromAssetId: firstAssetId, toAssetId: secondAssetId)
                loadQuote()
            }
        }
    }
    
    var inputedFirstAmount: Decimal = 0 {
        didSet(oldValue) {
            if oldValue != inputedFirstAmount, swapVariant == .desiredInput {
                loadQuote()
            }

            let inputedFiatText = setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId)
            let text = isEnoughtFirstAssetLiquidity ? inputedFiatText : R.string.localizable.commonNotEnoughBalance(preferredLanguages: .currentLocale)
            let amountColor: SoramitsuColor = isEnoughtFirstAssetLiquidity ? .fgPrimary : .statusError
            let fiatColor: SoramitsuColor = isEnoughtFirstAssetLiquidity ? .fgSecondary : .statusError
            var state: InputFieldState = focusedField == .one ? .focused : .default
            state = isEnoughtFirstAssetLiquidity ? state : .fail
            
            view?.updateFirstAsset(state: state, amountColor: amountColor, fiatColor: fiatColor)
            view?.updateFirstAsset(fiatText: text)
        }
    }
    
    var inputedSecondAmount: Decimal = 0 {
        didSet(oldValue) {
            if oldValue != inputedSecondAmount, swapVariant == .desiredOutput {
                loadQuote()
            }

            let inputedFiatText = setupInputedFiatText(from: inputedSecondAmount, assetId: secondAssetId)
            let state: InputFieldState = self.focusedField == .two ? .focused : .default
            view?.updateSecondAsset(state: state, amountColor: .fgPrimary, fiatColor: .fgSecondary)
            view?.updateSecondAsset(fiatText: inputedFiatText)
        }
    }
    
    var slippageTolerance: Float = 0.5 {
        didSet {
            let slippageToleranceText = "\(slippageTolerance)%"
            view?.update(slippageTolerance: slippageToleranceText)
            loadQuote()
        }
    }
    
    var selectedMarket: LiquiditySourceType = .smart {
        didSet {
            loadQuote()
            view?.update(selectedMarket: selectedMarket.titleForLocale(.current))
        }
    }
    
    var amounts: SwapQuoteAmounts? {
        didSet {
            switch swapVariant {
            case .desiredInput:
                inputedSecondAmount = amounts?.toAmount ?? 0
                let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: secondAssetId)?.precision ?? 0)
                view?.set(secondAmountText: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
            case .desiredOutput:
                inputedFirstAmount = amounts?.toAmount ?? 0
                let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
                view?.set(firstAmountText: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
            }
            
            updateWarningModel()
        }
    }
    
    var focusedField: FocusedField = .one {
        didSet {
            swapVariant = focusedField == .one ? .desiredInput : .desiredOutput
            view?.setAccessoryView(isHidden: focusedField == .two)
        }
    }
    var swapVariant: SwapVariant = .desiredInput
    var marketSourcer: SwapMarketSourcerProtocol?

    private var quote: SwapValues?
    private var quoteParams: PolkaswapMainInteractorQuoteParams?
    
    private let feeProvider: FeeProviderProtocol
    private var fiatData: [FiatData] = [] {
        didSet {
            updateAssetsBalance()
        }
    }
    private var fee: Decimal = 0 {
        didSet {

        }
    }
    private var dexId: UInt32 = 0
    private var minBuy: Decimal = 0
    private var selectedTokenId: String
    private var selectedSecondTokenId: String
    private weak var assetsProvider: AssetProviderProtocol?
    private var lpServiceFee: LPFeeServiceProtocol
    
    private var warningViewModelFactory: WarningViewModelFactory
    private var warningViewModel: WarningViewModel? {
        didSet {
            guard let warningViewModel else { return }
            view?.updateWarinignView(model: warningViewModel)
        }
    }

    private var isEnoughtFirstAssetLiquidity: Bool {
        if inputedFirstAmount > firstAssetBalance.balance.decimalValue {
            return false
        }

        if let fromAsset = assetManager?.assetInfo(for: firstAssetId),
           fromAsset.isFeeAsset,
           inputedFirstAmount + fee > firstAssetBalance.balance.decimalValue {
            return false
        }

        return true
    }
    
    init(
        selectedTokenId: String = WalletAssetId.xor.rawValue,
        selectedSecondTokenId: String = "",
        wireframe: LiquidityWireframeProtocol?,
        fiatService: FiatServiceProtocol?,
        assetManager: AssetManagerProtocol?,
        detailsFactory: DetailViewModelFactoryProtocol,
        eventCenter: EventCenterProtocol,
        interactor: PolkaswapMainInteractor,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        assetsProvider: AssetProviderProtocol?,
        lpServiceFee: LPFeeServiceProtocol,
        polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol?,
        warningViewModelFactory: WarningViewModelFactory = WarningViewModelFactory()
    ) {
        self.assetsProvider = assetsProvider
        self.fiatService = fiatService
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.feeProvider = FeeProvider()
        self.interactor = interactor
        self.networkFacade = networkFacade
        self.selectedTokenId = selectedTokenId
        self.selectedSecondTokenId = selectedSecondTokenId
        self.eventCenter = eventCenter
        self.lpServiceFee = lpServiceFee
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.warningViewModelFactory = warningViewModelFactory
    }
}

extension SwapViewModel: LiquidityViewModelProtocol {
    func didSelect(variant: Float) {
        if focusedField == .one {
            guard firstAssetBalance.balance.decimalValue > 0 else { return }
            let isFeeAsset = assetManager?.assetInfo(for: firstAssetId)?.isFeeAsset ?? false
            let value = firstAssetBalance.balance.decimalValue * (Decimal(string: "\(variant)") ?? 0)
            inputedFirstAmount = isFeeAsset ? value - fee : value
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(firstAmountText: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
        }
        
        if focusedField == .two {
            guard secondAssetBalance.balance.decimalValue > 0 else { return }
            let isFeeAsset = assetManager?.assetInfo(for: secondAssetId)?.isFeeAsset ?? false
            let value = secondAssetBalance.balance.decimalValue * (Decimal(string: "\(variant)") ?? 0)
            inputedSecondAmount = isFeeAsset ? value - fee : value
            let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
            view?.set(secondAmountText: formatter.stringFromDecimal(inputedSecondAmount) ?? "")
        }
    }
    
    func viewDidLoad() {
        firstAssetId = selectedTokenId
        secondAssetId = selectedSecondTokenId
        selectedMarket = .smart
        slippageTolerance = 0.5

        middleButtonActionHandler = { [weak self] in
            guard let self = self else { return }

            let tmpAssetId = self.firstAssetId
            self.firstAssetId = self.secondAssetId
            self.secondAssetId = tmpAssetId
            
            let firstFormatter = NumberFormatter.inputedAmoutFormatter(with: self.assetManager?.assetInfo(for: self.firstAssetId)?.precision ?? 0)
            self.view?.set(secondAmountText: firstFormatter.stringFromDecimal(self.inputedFirstAmount) ?? "")
            
            let secondFormatter = NumberFormatter.inputedAmoutFormatter(with: self.assetManager?.assetInfo(for: self.secondAssetId)?.precision ?? 0)
            self.view?.set(firstAmountText: secondFormatter.stringFromDecimal(self.inputedSecondAmount) ?? "")
            
            if self.focusedField == .one {
                self.inputedSecondAmount = self.inputedFirstAmount
            } else {
                self.inputedFirstAmount = self.inputedSecondAmount
            }
            self.view?.focus(field: self.focusedField == .one ? .two : .one)
            self.view?.update(isNeedLoadingState: true)
        }

        view?.updateMiddleButton(isEnabled: false)
        view?.setupButton(isEnabled: false)
        assetsProvider?.add(observer: self)
        updateDetails()
    }
    
    func choiсeBaseAssetButtonTapped() {
        guard let assetManager = assetManager,
              let fiatService = fiatService,
              let assets = assetManager.getAssetList()?.filter({ $0.identifier != secondAssetId }) else { return }
        
        let factory = AssetViewModelFactory(walletAssets: assets,
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        wireframe?.showChoiсeBaseAsset(on: view?.controller,
                                       assetManager: assetManager,
                                       fiatService: fiatService,
                                       assetViewModelFactory: factory,
                                       assetsProvider: assetsProvider,
                                       assetIds: assets.map { $0.identifier }) { [weak self] assetId in
            self?.firstAssetId = assetId
        }
    }
    
    func choiсeTargetAssetButtonTapped() {
        guard let assetManager = assetManager,
              let fiatService = fiatService,
              let assets = assetManager.getAssetList()?.filter({ $0.identifier != firstAssetId }) else { return }

        let factory = AssetViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        wireframe?.showChoiсeBaseAsset(on: view?.controller,
                                       assetManager: assetManager,
                                       fiatService: fiatService,
                                       assetViewModelFactory: factory,
                                       assetsProvider: assetsProvider,
                                       assetIds: assets.map { $0.identifier }) { [weak self] assetId in
            self?.secondAssetId = assetId
        }
    }
    
    func changeSlippageTolerance() {
        wireframe?.showSlippageTolerance(on: view?.controller.navigationController,
                                         currentLocale: slippageTolerance,
                                         completion: { [weak self] slippageTolerance in
            self?.slippageTolerance = slippageTolerance
        })
    }
    
    func changeMarket() {
        wireframe?.showChoiсeMarket(on: view?.controller.navigationController,
                                    selectedMarket: selectedMarket,
                                    markets: (marketSourcer?.getMarketSources().filter { $0 == .smart || $0 == .tbc }) ?? [ .smart ],
                                    completion: { [weak self] market in
            self?.selectedMarket = market
        })
    }
    
    func reviewButtonTapped() {
        guard let assetManager = assetManager, let amounts = amounts, let quoteParams = quoteParams else { return }
        wireframe?.showSwapConfirmation(on: view?.controller.navigationController,
                                        baseAssetId: firstAssetId,
                                        targetAssetId: secondAssetId,
                                        assetManager: assetManager,
                                        eventCenter: eventCenter,
                                        firstAssetAmount: inputedFirstAmount,
                                        secondAssetAmount: inputedSecondAmount,
                                        slippageTolerance: slippageTolerance,
                                        market: selectedMarket,
                                        details: details,
                                        amounts: amounts,
                                        fee: fee,
                                        swapVariant: swapVariant,
                                        networkFacade: networkFacade,
                                        minMaxValue: minBuy,
                                        dexId: dexId,
                                        lpFee: amounts.lpAmount,
                                        quoteParams: quoteParams,
                                        assetsProvider: assetsProvider,
                                        fiatData: fiatData,
                                        polkaswapNetworkFacade: polkaswapNetworkFacade)
    }
    
    func recalculate(field: FocusedField) {}
}

extension SwapViewModel: PolkaswapMainInteractorOutputProtocol {
    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) {
        guard !firstAssetId.isEmpty, !secondAssetId.isEmpty else { return }

        if !isAvailable {
            view?.setupButton(isEnabled: false)
        } else {
            view?.setupMarketButton(isLoadingState: true)
            interactor.loadMarketSources(fromAssetId: fromAssetId, toAssetId: toAssetId)
        }
    }
    
    func didLoadMarketSources(_ serverMarketSources: [String], fromAssetId: String, toAssetId: String) {
        guard !firstAssetId.isEmpty, !secondAssetId.isEmpty, let marketSourcer = marketSourcer else { return }

        marketSourcer.didLoad(serverMarketSources)
        view?.setupMarketButton(isLoadingState: false)
        updateSelectedMarketSourceIfNecessary()
        subscribeToPoolUpdates()
        loadQuote()
    }
    
    func didLoadQuote(_ quote: SwapValues?, dexId: UInt32, params: PolkaswapMainInteractorQuoteParams) {
        guard updateButtonState()  else {
            view?.update(isNeedLoadingState: false)
            return
        }

        guard let quote = quote else {
            view?.setupButton(isEnabled: false)
            view?.update(isNeedLoadingState: false)
            view?.updateReviewButton(title: R.string.localizable.polkaswapNoSuchPool(preferredLanguages: .currentLocale))
            return
        }

        guard updateButtonState() else {
            view?.update(isNeedLoadingState: false)
            return
        }

        guard params.fromAssetId == firstAssetId, params.toAssetId == secondAssetId else {
            view?.update(isNeedLoadingState: false)
            return
        }
        
        updateDetails(params: params, quote: quote, dexId: dexId) { [weak self] in
            guard let self = self, self.checkBalances() else {
                self?.view?.update(isNeedLoadingState: false)
                return
            }

            // check if exchanging to XOR, we'll receive enough XOR to pay nework fee from it
            if let toAsset = self.assetManager?.assetInfo(for: self.secondAssetId),
               toAsset.isFeeAsset {
                let xorAmount = self.swapVariant == .desiredInput ? self.minBuy : self.inputedSecondAmount
                let xorAmountFuture = self.secondAssetBalance.balance.decimalValue + xorAmount
                guard xorAmountFuture > self.fee else {
                    self.view?.update(isNeedLoadingState: false)
                    self.view?.setupButton(isEnabled: false)
                    return
                }
            }

            self.view?.setupButton(isEnabled: true)
        }
    }
    
    func didUpdatePoolSubscription() {
        loadQuote()
    }
}

extension SwapViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        updateAssetsBalance()
    }
}

extension SwapViewModel {
    
    func updateAssetsBalance() {
        if !firstAssetId.isEmpty, let firstAssetBalance = assetsProvider?.getBalances(with: [firstAssetId]).first {
            self.firstAssetBalance = firstAssetBalance
        }
        
        if !secondAssetId.isEmpty, let secondAssetBalance = assetsProvider?.getBalances(with: [secondAssetId]).first {
            self.secondAssetBalance = secondAssetBalance
        }
    }
    
    func setupFullBalanceText(from balanceData: BalanceData) -> String {
        let balance = NumberFormatter.polkaswapBalance.stringFromDecimal(balanceData.balance.decimalValue) ?? ""
        var fiatBalanceText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * usdPrice
            fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return fiatBalanceText.isEmpty ? "\(balance)" : "\(balance) (\(fiatBalanceText))"
    }
    
    func setupInputedFiatText(from inputedAmount: Decimal, assetId: String) -> String {
        guard let asset = assetManager?.assetInfo(for: assetId) else { return "" }
        
        var fiatText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = inputedAmount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return fiatText
    }
    
    func updateDetails(params: PolkaswapMainInteractorQuoteParams? = nil,
                       quote: SwapValues? = nil,
                       dexId: UInt32 = 0,
                       completion: (() -> Void)? = nil) {
        let group = DispatchGroup()
        
        group.enter()
        fiatService?.getFiat { [weak self] fiatData in
            self?.fiatData = fiatData
            group.leave()
        }
        
        group.enter()
        feeProvider.getFee(for: .swap) { [weak self] fee in
            self?.fee = fee
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            self.quote = quote
            self.quoteParams = params
            self.dexId = dexId
            
            guard let params = params,
                  let quote = quote,
                  let fromAsset = self.assetManager?.assetInfo(for: self.firstAssetId),
                  let toAsset = self.assetManager?.assetInfo(for: self.secondAssetId) else { return }
            
            
            guard let amounts = SwapQuoteAmountsFactory().createAmounts(fromAsset: fromAsset,
                                                                        toAsset: toAsset,
                                                                        params: params,
                                                                        quote: quote) else { return }
            self.amounts = amounts
            
            let amount = self.swapVariant == .desiredInput ? self.inputedFirstAmount : self.inputedSecondAmount
            let route = self.quote?.route.compactMap({ self.assetManager?.assetInfo(for: $0)?.symbol }).joined(separator: " → ")
            
            self.minBuy = amounts.toAmount * (1 - Decimal(Double(self.slippageTolerance)) / 100.0)
            self.details = self.detailsFactory.createSwapViewModels(fromAsset: fromAsset,
                                                                    toAsset: toAsset,
                                                                    slippage: Decimal(Double(self.slippageTolerance)),
                                                                    amount: amount,
                                                                    quote: amounts,
                                                                    direction: self.swapVariant,
                                                                    fiatData: self.fiatData,
                                                                    swapFee: self.fee,
                                                                    route: route ?? "",
                                                                    viewModel: self)
            self.view?.update(isNeedLoadingState: false)
            completion?()
        }
    }
    
    func updateSelectedMarketSourceIfNecessary() {
        guard let marketSourcer = marketSourcer else { return }

        if !marketSourcer.contains(selectedMarket) {
            selectedMarket = marketSourcer.getMarketSources().last ?? .smart
        }
    }

    func loadQuote() {
        view?.updateReviewButton(title: R.string.localizable.review(preferredLanguages: .currentLocale))

        let amount: String
        if swapVariant == .desiredInput {
            let assetInfo = assetManager?.assetInfo(for: firstAssetId)
            amount = String(inputedFirstAmount.toSubstrateAmount(precision: Int16(assetInfo?.precision ?? 0)) ?? 0)
        } else {
            let assetInfo = assetManager?.assetInfo(for: secondAssetId)
            amount = String(inputedSecondAmount.toSubstrateAmount(precision: Int16(assetInfo?.precision ?? 0)) ?? 0)
        }

        // request quote
        guard let marketSourcer = marketSourcer,
                marketSourcer.isLoaded() else {
            return
        }

        let filterMode: FilterMode = selectedMarket == .smart ? .disabled : .allowSelected
        let liquiditySources = marketSourcer.getServerMarketSources()
        let params = PolkaswapMainInteractorQuoteParams(fromAssetId: firstAssetId,
                                                        toAssetId: secondAssetId,
                                                        amount: amount,
                                                        swapVariant: swapVariant,
                                                        liquiditySources: liquiditySources,
                                                        filterMode: filterMode)

        debouncer.perform { [weak self] in
            self?.view?.update(isNeedLoadingState: true)
            
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                self?.interactor.quote(params: params)
            }
        }
    }
    
    func subscribeToPoolUpdates() {
        let xorID = WalletAssetId.xor.rawValue
        guard !firstAssetId.isEmpty, !secondAssetId.isEmpty else { return }

        interactor.unsubscribePoolXYK()
        interactor.unsubscribePoolTBC()

        if selectedMarket == .smart || selectedMarket == .xyk {
            if xorID != firstAssetId {
                interactor.subscribePoolXYK(assetId1: xorID, assetId2: firstAssetId)
            }
            if xorID != secondAssetId {
                interactor.subscribePoolXYK(assetId1: xorID, assetId2: secondAssetId)
            }
        }

        if selectedMarket == .smart || selectedMarket == .tbc {
            interactor.subscribePoolTBC(assetId: xorID)
            if xorID != firstAssetId {
                interactor.subscribePoolTBC(assetId: firstAssetId)
            }
            if xorID != secondAssetId {
                interactor.subscribePoolTBC(assetId: secondAssetId)
            }
        }
    }
    
    func updateButtonState() -> Bool {
        guard !firstAssetId.isEmpty && !secondAssetId.isEmpty else {
            view?.setupButton(isEnabled: false)
            return false
        }

        if let marketSourcer = marketSourcer, marketSourcer.isLoaded() && marketSourcer.isEmpty() {
            view?.setupButton(isEnabled: false)
            return false
        }

        if swapVariant == .desiredInput && inputedFirstAmount == 0.0 {
            view?.setupButton(isEnabled: false)
            return false
        } else if swapVariant == .desiredOutput && inputedSecondAmount == 0.0 {
            view?.setupButton(isEnabled: false)
            return false
        }

        return true
    }
    
    func checkBalances() -> Bool {
        // check if balance is enough
        if inputedFirstAmount > firstAssetBalance.balance.decimalValue {
            view?.setupButton(isEnabled: false)
            return false
        }

        // check if exchanging from XOR, and have not enough XOR to pay the fee
        if let fromAsset = assetManager?.assetInfo(for: firstAssetId),
           fromAsset.isFeeAsset,
           inputedFirstAmount + fee > firstAssetBalance.balance.decimalValue {
            view?.setupButton(isEnabled: false)
            return false
        }

        return true
    }
    
    func updateWarningModel() {
        guard let feeAsset = assetManager?.getAssetList()?.first(where: { $0.isFeeAsset }),
              let feeAssetBalance = assetsProvider?.getBalances(with: [feeAsset.assetId]).first else { return }

        var isDisclamerHidden = true

        if feeAsset.assetId == firstAssetId {
            isDisclamerHidden = firstAssetBalance.balance.decimalValue - inputedFirstAmount - fee > fee
        } else {
            isDisclamerHidden = feeAssetBalance.balance.decimalValue - fee > fee
        }
        
        if firstAssetId.isEmpty ||
            secondAssetId.isEmpty ||
            inputedFirstAmount == 0 ||
            inputedSecondAmount == 0 ||
            firstAssetBalance.balance.decimalValue == 0 {
            isDisclamerHidden = true
        }

        warningViewModel = warningViewModelFactory.insufficientBalanceViewModel(
            feeAssetSymbol: feeAsset.symbol,
            feeAmount: fee,
            isHidden: isDisclamerHidden
        )
    }
}


extension SwapViewModel: DetailViewModelDelegate {
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
