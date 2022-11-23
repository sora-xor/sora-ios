import BigInt
import CommonWallet
import Foundation
import SoraKeystore
import UIKit
import SoraUI
import SoraFoundation

final class SwapPresenter {
    weak var view: SwapViewProtocol?
    var networkFacade: WalletNetworkOperationFactoryProtocol
    var polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol
    var commandFactory: WalletCommandFactoryProtocol
    var confirmation: WalletPresentationCommandProtocol?
    var wireframe: PolkaswapMainWireframeProtocol!
    var interactor: PolkaswapMainInteractorInputProtocol!
    var isDetailsExpanded: Bool = false
    var marketSourcer: SwapMarketSourcerProtocol?
    var selectedLiquiditySourceType: LiquiditySourceType = .smart {
        didSet {
            view?.setMarket(type: selectedLiquiditySourceType)
        }
    }
    let tab: PolkaswapTab = .swap

    enum DetailsState {
        case disabled
        case expanded
        case collapsed
    }

    var detailsState = DetailsState.disabled

    private let assets: [AssetInfo]
    var assetList: [AssetInfo] {
        return assets//assetManager.sortedAssets(self.assets, onlyVisible: true)
    }

    var poolsDetails: [PoolDetails] = []

    let assetManager: AssetManagerProtocol
    let disclaimerViewFactory: DisclaimerViewFactoryProtocol
    var isFrom: Bool = true

    private var _slippage: Double = 0.5
    var slippage: Double {
        get {
            return _slippage
        }
        set {
            _slippage = newValue > 0.01 ? newValue : 0.01
        }
    }

    var minMaxValue: Decimal = 0.0
    var lpFeeValue: Decimal = 0.0

    var fromAmount: Decimal?
    var toAmount: Decimal?
    var fromBalance: Decimal?
    var toBalance: Decimal?

    var fromAsset: AssetInfo?
    var toAsset: AssetInfo?
    var languages: [String]? {
        view?.localizationManager?.preferredLocalizations
    }

    private var quote: SwapValues?
    private var quoteParams: PolkaswapMainInteractorQuoteParams?

    var nextButtonState: NextButtonState = .chooseTokens {
        didSet {
            view?.setSwapButton(isEnabled: nextButtonState == .enabled,
                                isLoading: nextButtonState == .loading,
                                title: nextButtonTitle(for: nextButtonState))

        }
    }

    var settingsManager: SettingsManagerProtocol
    var isDisclaimerHidden: Bool {
        settingsManager.disclaimerHidden ?? false
    }

    var swapVariant: SwapVariant = .desiredInput

    var debounceTimer: Timer?
    private var swapFee: Decimal?

    init(assets: [AssetInfo], assetManager: AssetManagerProtocol,
         disclaimerViewFactory: DisclaimerViewFactoryProtocol,
         settingsManager: SettingsManagerProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol,
         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
         commandFactory: WalletCommandFactoryProtocol
    ) {
        self.assets = assets
        self.assetManager = assetManager
        self.disclaimerViewFactory = disclaimerViewFactory
        self.settingsManager = settingsManager
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.commandFactory = commandFactory
    }

    func filteredAssetList(isFrom: Bool) -> [AssetInfo] {
        return assetList.filter { asset in
            let assetToExclude: AssetInfo? = isFrom ? toAsset : fromAsset
            return asset != assetToExclude
        }
    }
}

extension SwapPresenter: SwapPresenterProtocol {
    func setup(preferredLocalizations languages: [String]?) {
        if fromAsset == nil, let feeAsset = assetList.filter({ $0.isFeeAsset }).first {
            fromAsset = feeAsset
            interactor.loadBalance(asset: feeAsset)
        }

        // TODO: group all the data to viewModel or combine it to one call
        view?.setToAsset(toAsset, amount: toAmount)
        view?.setFromAsset(fromAsset, amount: fromAmount)
        view?.setMarket(type: selectedLiquiditySourceType)
        view?.setSwapButton(isEnabled: nextButtonState == .enabled,
                            isLoading: nextButtonState == .loading,
                            title: nextButtonTitle(for: nextButtonState))
        updateDetailsViewModel(params: quoteParams, quote: quote)
        view?.setDetailsExpanded(isDetailsExpanded)
        view?.setSwapButton(isEnabled: nextButtonState == .enabled,
                            isLoading: nextButtonState == .loading,
                            title: nextButtonTitle(for: nextButtonState))
         interactor.networkFeeValue(completion: { [weak self] fee in
             self?.swapFee = fee
        })
    }

    func didSelectAsset(atIndex index: Int, isFrom: Bool) {
        let filteredAssetList = filteredAssetList(isFrom: isFrom)
        guard index < filteredAssetList.count else { return }
        let selectedAsset = filteredAssetList[index]
        didSelectAsset(selectedAsset, isFrom: isFrom)
    }

    func didSelectAsset(_ selectedAsset: AssetInfo?, isFrom: Bool) {
        invalidateQuoteAndParams()
        if isFrom {
            fromAsset = selectedAsset
            view?.setFromAsset(fromAsset, amount: fromAmount)
        } else {
            toAsset = selectedAsset
            view?.setToAsset(toAsset, amount: toAmount)
        }

        checkTokenAndAmount()
        updateDetailsState()
        if let fromAssetId = fromAsset?.identifier, let toAssetId = toAsset?.identifier {
            marketSourcer = SwapMarketSourcer(fromAssetId: fromAssetId, toAssetId: toAssetId)
            interactor.checkIsPathAvailable(fromAssetId: fromAssetId, toAssetId: toAssetId)
        }
        if let asset = selectedAsset {
            interactor.loadBalance(asset: asset)
        }
    }

    func updateDetailsViewModel(params: PolkaswapMainInteractorQuoteParams? = nil, quote: SwapValues? = nil) {
        self.quote = quote
        quoteParams = params

        guard let fromAsset = fromAsset,
              let toAsset = toAsset,
              let swapFee = swapFee,
              let params = params,
              let quote = quote else {
            return
        }

        guard let amounts = SwapQuoteAmountsFactory().createAmounts(fromAsset: fromAsset, toAsset: toAsset, params: params, quote: quote) else { return }

        setAndDisplayAmount(direction: params.swapVariant, amounts: amounts)

        let detailsViewModelFactory = SwapDetailsModelFactory(fromAsset: fromAsset, toAsset: toAsset, slippage: Decimal(slippage), languages: languages, quote: amounts, direction: params.swapVariant, swapFee: swapFee)
        let detailsViewModel = detailsViewModelFactory.createDetailsViewModel()
        minMaxValue = detailsViewModel.minBuyOrMaxSellValue
        view?.didReceiveDetails(viewModel: detailsViewModel)
    }

    func setAndDisplayAmount(direction: SwapVariant, amounts: SwapQuoteAmounts) {
        switch direction {
        case .desiredInput:
            setAndDisplayToAmount(amounts.toAmount)
        case .desiredOutput:
            setAndDisplayFromAmount(amounts.toAmount)
        }
    }

    func setAndDisplayToAmount(_ newAmount: Decimal) {
        view?.setToAmount(newAmount)
        self.toAmount = newAmount
    }

    func setAndDisplayFromAmount(_ newAmount: Decimal) {
        view?.setFromAmount(newAmount)
        self.fromAmount = newAmount
    }

    var currentButtonTitle: String {
        nextButtonTitle(for: nextButtonState)
    }

    func nextButtonTitle(for state: NextButtonState) -> String {
        state.title(preferredLanguages: languages)
    }

    func checkTokenAndAmount() {
        if fromAsset == nil || toAsset == nil {
            nextButtonState = .chooseTokens
        }
        if nextButtonState == .poolNotCreated { return }
        if fromAmount == 0.0 && toAmount == 0.0 {
            nextButtonState = .enterAmount
        }
    }

    func showSlippageController() {
        let view = R.nib.polkaswapSlippageSelectorView(owner: nil, options: nil)!
        view.localizationManager = LocalizationManager.shared
        view.delegate = self
        let presenter = PolkaswapSlippageSelectorPresenter(amountFormatterFactory: AmountFormatterFactory())
        presenter.view = view
        presenter.slippage = self.slippage
        view.presenter = presenter
        presenter.setup(preferredLocalizations: LocalizationManager.shared.preferredLocalizations)
        let controller = UIViewController()
        controller.view = view
        controller.preferredContentSize = CGSize(width: 0.0, height: view.frame.height)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.neu)
        controller.modalTransitioningFactory = factory
        controller.modalPresentationStyle = .custom

        let presentationCommand = commandFactory.preparePresentationCommand(for: controller)
        presentationCommand.presentationStyle = .modal(inNavigation: false)
        try? presentationCommand.execute()
    }

    func didPressAsset(isFrom: Bool) {
        showAssetSelectionController(isFrom: isFrom, filteredAssetList: filteredAssetList(isFrom: isFrom), assetManager: assetManager)
    }

    func didSelectAmount(_ amount: Decimal?, isFrom: Bool) {
        invalidateQuoteAndParams()

        if isFrom {
            fromAmount = amount ?? 0.0
            swapVariant = .desiredInput
            toAmount = nil
            if fromAmount == 0.0 {
                view?.setToAmount(0)
            }
        } else {
            toAmount = amount ?? 0.0
            swapVariant = .desiredOutput
            fromAmount = nil
            if toAmount == 0.0 {
                view?.setFromAmount(0)
            }
        }
        if let fromAssetId = fromAsset?.identifier, let toAssetId = toAsset?.identifier, let marketSourcer = marketSourcer {
            if !marketSourcer.isLoaded() || nextButtonState == .poolNotCreated {
                interactor.checkIsPathAvailable(fromAssetId: fromAssetId, toAssetId: toAssetId)
            } else {
                loadQuote()
            }
        }
    }

    func didSelectPredefinedPercentage(_ percent: Decimal, isFrom: Bool) {
        guard isFrom, let fromBalance = fromBalance, let swapFee = swapFee, let fromAsset = fromAsset else {
            return
        }
        var newAmount = fromBalance * percent / 100
        let minFromAmount = fromAsset.isFeeAsset ? fromBalance - swapFee : fromBalance
        newAmount = min(newAmount, minFromAmount)
        newAmount = max(newAmount, 0)
        view?.setFromAmount(newAmount)
        didSelectAmount(newAmount, isFrom: isFrom)
    }

    func invalidateQuoteAndParams() {
        quoteParams = nil
        quote = nil
    }

    func updateDetailsState() {
        guard fromAsset != nil, toAsset != nil, let fromAmount = fromAmount, let toAmount = toAmount, fromAmount > 0.0 || toAmount > 0.0 else {
            detailsState = .disabled
            return
        }
        if detailsState == .disabled {
            detailsState = .collapsed
        }
    }

    func showAssetSelectionController(isFrom: Bool, filteredAssetList: [AssetInfo], assetManager: AssetManagerProtocol) {
        self.isFrom = isFrom

        guard let viewController = ModalPickerFactory.createPickerForAssetList(
            filteredAssetList,
            selectedType: nil,
            delegate: self,
            context: assetManager
        ) else { return }
        viewController.title = R.string.localizable.commonSelectAsset(preferredLanguages: languages)

        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController)
        presentationCommand.presentationStyle = .modal(inNavigation: true)
        try? presentationCommand.execute()
    }

    func didPressNext() {
        guard let fromAsset = fromAsset,
              let toAsset = toAsset,
              let fromAmount = fromAmount,
              let toAmount = toAmount,
              let swapFee = swapFee,
              quote != nil
        else {
            return
        }

        let marketType = selectedLiquiditySourceType.rawValue

        let networkFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                   assetId: WalletAssetId.xor.rawValue,
                                                   type: "fee",
                                                   parameters: [],
                                                   accountId: nil,
                                                   minValue: nil,
                                                   maxValue: nil,
                                                   context: nil)
        let networkFee = Fee(value: AmountDecimal(value: swapFee),
                             feeDescription: networkFeeDescription)
        let liquidityProviderFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                             assetId: WalletAssetId.xor.rawValue,
                                                             type: "lp",
                                                             parameters: [],
                                                             accountId: nil,
                                                             minValue: nil,
                                                             maxValue: nil,
                                                             context: ["type": TransactionType.swap.rawValue])
        let liquidityProviderFee = Fee(value: AmountDecimal(value: lpFeeValue),
                                       feeDescription: liquidityProviderFeeDescription)
        let transferInfo = TransferInfo(source: "",
                                        destination: toAsset.identifier,
                                        amount: AmountDecimal(value: fromAmount),
                                        asset: fromAsset.identifier,
                                        details: "",
                                        fees: [liquidityProviderFee, networkFee],
                                        context: [TransactionContextKeys.transactionType: TransactionType.swap.rawValue,
                                                  TransactionContextKeys.estimatedAmount: AmountDecimal(value: toAmount).stringValue,
                                                  TransactionContextKeys.marketType: marketType,
                                                  TransactionContextKeys.slippage: String(slippage),
                                                  TransactionContextKeys.desire: swapVariant.rawValue,
                                                  TransactionContextKeys.minMaxValue: AmountDecimal(value: minMaxValue).stringValue
                                        ])
        showConfirmation(transferInfo: transferInfo)
    }

    func showConfirmation(transferInfo: TransferInfo) {
        let payload = ConfirmationPayload(transferInfo: transferInfo, receiverName: "")

        confirmation = commandFactory.prepareConfirmation(with: payload)
        confirmation?.presentationStyle = .modal(inNavigation: true)
        try? confirmation?.execute()
    }

    func dismissConfirmation(withToast: Bool = false) {
        let dismiss = commandFactory.prepareHideCommand(with: .dismiss)
        try? dismiss.execute()

        if withToast {
            let alertTitle = R.string.localizable.polkaswapSwapDetailsHaveChanged(preferredLanguages: languages)
            let alert = ModalAlertFactory.createAlert(alertTitle, image: R.image.iconRetry())
            try? commandFactory.preparePresentationCommand(for: alert).execute()
        }
    }

    func didUpdateLocale() {
        // Must recreate viewModels, as they have their own formatters with locales
        view?.setFromAsset(fromAsset, amount: fromAmount)
        if let fromBalance = fromBalance, let fromAsset = fromAsset {
            view?.setBalance(fromBalance, asset: fromAsset, isFrom: true)
        }
        view?.setToAsset(toAsset, amount: toAmount)
        if let toBalance = toBalance, let toAsset = toAsset {
            view?.setBalance(toBalance, asset: toAsset, isFrom: false)
        }
        didSelect(slippage: self.slippage)
        view?.setMarket(type: selectedLiquiditySourceType)
        updateDetailsViewModel(params: quoteParams, quote: quote)
    }

    func didPressDetails() {
        updateDetailsState()
        if detailsState == .expanded {
            detailsState = .collapsed
        } else if detailsState == .collapsed {
            detailsState = .expanded
        }
        view?.setDetailsExpanded(detailsState == .expanded)
    }

    func toggleSwapDirection() {
        if swapVariant == .desiredInput {
            swapVariant = .desiredOutput
        } else {
            swapVariant = .desiredInput
        }
    }

    func didPressInverse() {
        guard let fromAsset = fromAsset,
              let toAsset = toAsset,
              nextButtonState != .loading
        else { return }

        invalidateQuoteAndParams()

        self.fromAsset = toAsset
        self.toAsset = fromAsset

        let oldFromBalance = fromBalance
        fromBalance = toBalance
        toBalance = oldFromBalance
        view?.setBalance(fromBalance ?? 0, asset: fromAsset, isFrom: true)
        view?.setBalance(toBalance ?? 0, asset: toAsset, isFrom: false)

        let oldFromAmount = fromAmount
        fromAmount = toAmount
        toAmount = oldFromAmount

        view?.setFromAsset(self.fromAsset, amount: fromAmount)
        view?.setToAsset(self.toAsset, amount: toAmount)
        guard let fromAssetId = self.fromAsset?.identifier, let toAssetId = self.toAsset?.identifier else {
            return
        }
        toggleSwapDirection()
        interactor.checkIsPathAvailable(fromAssetId: fromAssetId, toAssetId: toAssetId)
        interactor.loadBalance(asset: fromAsset)
        interactor.loadBalance(asset: toAsset)
    }

    func didPressDisclaimer() {
        if let disclaimerView = disclaimerViewFactory.createView() {
            view?.controller.navigationController?.pushViewController(disclaimerView.controller, animated: true)
        }
    }

    func showLiquiditySourceSelector(sourceTypes: [LiquiditySourceType], selected: LiquiditySourceType) {
        guard let selectedIndex = marketSourcer?.index(of: selected) else { return }

        let locale = LocalizationManager.shared.selectedLocale

        let view = R.nib.sourceSelectorView(owner: nil, options: nil)!
        view.localizationManager = LocalizationManager.shared
        view.titleText = R.string.localizable.polkaswapMarketTitle(preferredLanguages: locale.rLanguages).uppercased()
        view.sourceTypes = sourceTypes
        view.selectedSourceTypeIndex = selectedIndex
        view.delegate = self

        let viewController = UIViewController()
        viewController.preferredContentSize = CGSize(width: 0.0, height: view.frame.height)
        viewController.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.neu)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom

        self.view?.controller.present(viewController, animated: true, completion: nil)

    }

    func didPressMarket() {
        guard fromAsset != nil,
              toAsset != nil,
              nextButtonState != .poolNotCreated,
              nextButtonState != .loading
        else { return }
        guard let marketSourcer = marketSourcer, !marketSourcer.isEmpty() else { return }
        showLiquiditySourceSelector(sourceTypes: marketSourcer.getMarketSources(), selected: selectedLiquiditySourceType)
    }

    func subscribeToPoolUpdates() {
        let xorID = WalletAssetId.xor.rawValue
        guard let fromAsset = fromAsset, let toAsset = toAsset else { return }

        interactor.unsubscribePoolXYK()
        interactor.unsubscribePoolTBC()

        if selectedLiquiditySourceType == .smart || selectedLiquiditySourceType == .xyk {
            if xorID != fromAsset.identifier {
                interactor.subscribePoolXYK(assetId1: xorID, assetId2: fromAsset.identifier)
            }
            if xorID != toAsset.identifier {
                interactor.subscribePoolXYK(assetId1: xorID, assetId2: toAsset.identifier)
            }
        }

        if selectedLiquiditySourceType == .smart || selectedLiquiditySourceType == .tbc {
            interactor.subscribePoolTBC(assetId: xorID)
            if xorID != fromAsset.identifier {
                interactor.subscribePoolTBC(assetId: fromAsset.identifier)
            }
            if xorID != toAsset.identifier {
                interactor.subscribePoolTBC(assetId: toAsset.identifier)
            }
        }
    }
}

extension SwapPresenter: PolkaswapSlippageSelectorViewDelegate {
    func didSelect(slippage: Double) {
        self.slippage = slippage
        let dismiss = commandFactory.prepareHideCommand(with: .dismiss)
        try? dismiss.execute()
        view?.setSlippageAmount(Decimal(self.slippage))
        loadQuote()
    }
}

extension SwapPresenter: PolkaswapMainPresenterOutputProtocol {

    func didLoadBalance(_ balance: Decimal, asset: AssetInfo) {
        if asset.identifier == fromAsset?.identifier {
            fromBalance = balance
            view?.setBalance(balance, asset: asset, isFrom: true)
        } else if asset.identifier == toAsset?.identifier {
            toBalance = balance
            view?.setBalance(balance, asset: asset, isFrom: false)
        }

        _ = checkEnteredData()
        _ = checkBalances()
    }

    func didLoadMarketSources(_ serverMarketSources: [String], fromAssetId: String, toAssetId: String) {
        guard fromAssetId == fromAsset?.identifier, toAssetId == toAsset?.identifier, let marketSourcer = marketSourcer else { return }

        marketSourcer.didLoad(serverMarketSources)
        updateSelectedMarketSourceIfNecessary()
        subscribeToPoolUpdates()
        loadQuote()
    }

    func updateSelectedMarketSourceIfNecessary() {
        guard let marketSourcer = marketSourcer else { return }

        if !marketSourcer.contains(selectedLiquiditySourceType) {
            selectedLiquiditySourceType = marketSourcer.getMarketSources().last ?? .smart
        }
    }

    func checkEnteredData() -> Bool {
        // check if tokens selected
        guard fromAsset != nil && toAsset != nil else {
            nextButtonState = .chooseTokens
            return false
        }

        // check if pool created
        if let marketSourcer = marketSourcer, marketSourcer.isLoaded() && marketSourcer.isEmpty() {
            nextButtonState = .poolNotCreated
            return false
        }

        // check if amount entered
        if swapVariant == .desiredInput && ( fromAmount == nil || fromAmount == 0.0 ) {
            nextButtonState = .enterAmount
            return false
        } else if swapVariant == .desiredOutput && ( toAmount == nil || toAmount == 0.0 ) {
            nextButtonState = .enterAmount
            return false
        }

        return true
    }

    func checkBalances() -> Bool {
        // check if balance is enough
        if let fromBalance = fromBalance,
           let fromAmount = fromAmount,
           let fromAsset = fromAsset,
           fromAmount > fromBalance {
            nextButtonState = .insufficientBalance(token: fromAsset.symbol)
            return false
        }

        // check if exchanging from XOR, and have not enough XOR to pay the fee
        if let fromBalance = fromBalance,
           let fromAmount = fromAmount,
           let fromAsset = fromAsset,
           let swapFee = swapFee,
           fromAsset.isFeeAsset,
           fromAmount + swapFee > fromBalance {
            nextButtonState = .insufficientBalance(token: fromAsset.symbol)
            return false
        }

        return true
    }

    func loadQuote() {
        guard checkEnteredData() else {
            return
        }

        let amount: String
        if swapVariant == .desiredInput {
            amount = String(fromAmount!.toSubstrateAmount(precision: Int16(fromAsset!.precision))!)
        } else {
            amount = String(toAmount!.toSubstrateAmount(precision: Int16(toAsset!.precision))!)
        }

        // request quote
        guard let fromAssetId = fromAsset?.identifier,
                let toAssetId = toAsset?.identifier,
                let marketSourcer = marketSourcer,
                marketSourcer.isLoaded() else {
            return
        }

        let filterMode: FilterMode = selectedLiquiditySourceType == .smart ? .disabled : .allowSelected
        let liquiditySources = marketSourcer.getServerMarketSources()
        let params = PolkaswapMainInteractorQuoteParams(fromAssetId: fromAssetId,
                                                        toAssetId: toAssetId,
                                                        amount: amount,
                                                        swapVariant: swapVariant,
                                                        liquiditySources: liquiditySources,
                                                        filterMode: filterMode)

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { [weak self] _ in
            DispatchQueue.global(qos: .userInteractive).async { [weak self] in
                DispatchQueue.main.async {
                    self?.nextButtonState = .loading
                }
                self?.interactor.quote(params: params)
            }
        })
    }

    func didCheckPath(fromAssetId: String, toAssetId: String, isAvailable: Bool) {
        guard fromAssetId == fromAsset?.identifier, toAssetId == toAsset?.identifier else {
            return
        }

        if !isAvailable {
            nextButtonState = .poolNotCreated
            view?.setSwapButton(isEnabled: false,
                                isLoading: nextButtonState == .loading,
                                title: nextButtonTitle(for: .poolNotCreated))
        } else {
            checkTokenAndAmount()
            interactor.loadMarketSources(fromAssetId: fromAssetId, toAssetId: toAssetId)
        }
    }

    func didLoadQuote(_ quote: SwapValues?, params: PolkaswapMainInteractorQuoteParams) {
        guard let quote = quote else {
            nextButtonState = .insufficientLiquidity
            return
        }

        guard checkEnteredData() else {
            return
        }

        guard params.fromAssetId == fromAsset?.identifier, params.toAssetId == toAsset?.identifier else {
            return
        }
        updateDetailsViewModel(params: params, quote: quote)

        guard checkBalances() else {
            return
        }

        // check if exchanging to XOR, we'll receive enough XOR to pay nework fee from it
        if let toAsset = toAsset,
           toAsset.isFeeAsset,
           let toBalance = toBalance,
           let swapFee = swapFee,
           let toAmount = toAmount {
            let xorAmountFuture = toBalance + (swapVariant == .desiredInput ? minMaxValue : toAmount)
            guard xorAmountFuture > swapFee else {
                nextButtonState = .insufficientBalance(token: toAsset.symbol)
                return
            }
        }

        nextButtonState = .enabled
    }

    func didLoadPools(_ pools: [PoolDetails]) {
    }

    func didUpdatePoolSubscription() {
        if checkEnteredData() {
            loadQuote()
        }
//        changes in pools happen so frequently that users barely can swap something
//        view?.dismissConfirmationWithToast()
    }

    func didUpdateBalance() {
        didUpdateBalance(isActiveTab: false)
    }

    func didUpdateBalance(isActiveTab: Bool) {
        if let fromAsset = fromAsset {
            interactor.loadBalance(asset: fromAsset)
        }
        if let toAsset = toAsset {
            interactor.loadBalance(asset: toAsset)
        }
        // TODO:
        // coudn't use toast here because this method triggers after successful swap
        // and we don't know exactly if confirmation is on screen
        // isActiveTab is workaround to prevent closing "Add liquidity" screen
        if isActiveTab {
            dismissConfirmation(withToast: false)
        }
    }

    func didCreateTransaction() {
        reset()
    }

    func reset() {
        interactor.unsubscribePoolXYK()
        interactor.unsubscribePoolTBC()
        quote = nil
        quoteParams = nil
        fromAmount = nil
        toAmount = nil
        toAsset = nil
        view?.setFromAmount(0)
        view?.setToAmount(0)
        view?.setToAsset(nil, amount: 0)
        marketSourcer = nil
        fromBalance = nil
        toBalance = nil
        nextButtonState = .chooseTokens
    }
}

extension SwapPresenter: SourceSelectorViewDelegate {
    func didSelectSourceType(with index: Int) {
        selectedLiquiditySourceType = marketSourcer?.getMarketSource(at: index) ?? .smart
        invalidateQuoteAndParams()
        subscribeToPoolUpdates()
        loadQuote()
        view?.controller.dismiss(animated: true)
    }
}

extension SwapPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        didSelectAsset(atIndex: index, isFrom: isFrom)
    }
}
