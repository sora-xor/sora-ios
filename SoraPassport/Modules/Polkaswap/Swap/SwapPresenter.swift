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
    var marketSources: [LiquiditySourceType]?
    var selectedLiquiditySourceType: LiquiditySourceType = .smart {
        didSet {
            view?.setMarket(type: selectedLiquiditySourceType)
        }
    }

    enum DetailsState {
        case disabled
        case expanded
        case collapsed
    }

    var detailsState = DetailsState.disabled

    private let assets: [WalletAsset]
    var assetList: [WalletAsset] {
        return assetManager.sortedAssets(self.assets, onlyVisible: true)
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
    let networkFeeValue: Decimal = 0.0007

    var fromAmount: Decimal?
    var toAmount: Decimal?
    var fromBalance: Decimal?
    var toBalance: Decimal?

    var fromAsset: WalletAsset?
    var toAsset: WalletAsset?
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

    init(assets: [WalletAsset], assetManager: AssetManagerProtocol,
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

    func filteredAssetList(isFrom: Bool) -> [WalletAsset] {
        return assetList.filter { asset in
            let assetToExclude: WalletAsset? = isFrom ? toAsset : fromAsset
            return asset != assetToExclude
        }
    }
}

extension SwapPresenter: SwapPresenterProtocol {
    func setup(preferredLocalizations languages: [String]?) {
        if fromAsset == nil {
            fromAsset = assetList.filter({ $0.isFeeAsset }).first
            interactor.loadBalance(asset: fromAsset!)
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

        interactor.loadPools()
        view?.setSwapButton(isEnabled: nextButtonState == .enabled,
                            isLoading: nextButtonState == .loading,
                            title: nextButtonTitle(for: nextButtonState))
    }

    func didSelectAsset(atIndex index: Int, isFrom: Bool) {
        let filteredAssetList = filteredAssetList(isFrom: isFrom)
        guard index < filteredAssetList.count else { return }
        let selectedAsset = filteredAssetList[index]
        didSelectAsset(selectedAsset, isFrom: isFrom)
    }

    func didSelectAsset(_ selectedAsset: WalletAsset?, isFrom: Bool) {
        invalidateQuoteAndParams()
        marketSources = nil
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
              let fromInfo = assetManager.assetInfo(for: fromAsset.identifier),
              let toInfo = assetManager.assetInfo(for: toAsset.identifier) else {
            return
        }

        var minReceivedTitle: String = ""
        var directExchangeRateValue: Decimal = 0.0
        var inversedExchangeRateValue: Decimal = 0.0

        var minMaxToken: String = ""
        var minMaxAlertTitle: String = ""
        var minMaxAlertText: String = ""

        if let quote = quote, let params = params {
            if let fromAmountBig = BigUInt(params.amount),
               let toAmountBig = BigUInt(quote.amount),
               let feeBig = BigUInt(quote.fee),
               let fromAmount = Decimal.fromSubstrateAmount(fromAmountBig, precision: fromAsset.precision),
               let toAmount = Decimal.fromSubstrateAmount(toAmountBig, precision: toAsset.precision),
               let lpAmount = Decimal.fromSubstrateAmount(feeBig, precision: 18) {
                if params.swapVariant == .desiredInput {
                    view?.setToAmount(toAmount)
                    self.toAmount = toAmount
                    minMaxValue = toAmount * Decimal(1 - slippage / 100.0)
                    minMaxToken = toInfo.symbol
                    minReceivedTitle = R.string.localizable.polkaswapMinimumReceived(preferredLanguages: languages).uppercased()
                    minMaxAlertTitle = R.string.localizable.polkaswapMinimumReceived(preferredLanguages: languages)
                    minMaxAlertText = R.string.localizable.polkaswapMinimumReceivedInfo(preferredLanguages: languages)
                } else {
                    view?.setFromAmount(toAmount)
                    self.fromAmount = toAmount
                    minMaxValue = toAmount * Decimal(1 + slippage / 100.0)
                    minMaxToken = fromInfo.symbol
                    minReceivedTitle = R.string.localizable.polkaswapMaximumSold(preferredLanguages: languages).uppercased()
                    minMaxAlertTitle = R.string.localizable.polkaswapMaximumSold(preferredLanguages: languages)
                    minMaxAlertText = R.string.localizable.polkaswapMaximumSoldInfo(preferredLanguages: languages)
                }
                directExchangeRateValue = fromAmount / toAmount
                inversedExchangeRateValue = toAmount / fromAmount
                lpFeeValue = lpAmount
            }
        }

        let model = PolkaswapDetailsViewModel(
            directExchangeRateTitle: fromInfo.symbol + "/" + toInfo.symbol,
            inversedExchangeRateTitle: toInfo.symbol + "/" + fromInfo.symbol,
            minReceivedTitle: minReceivedTitle,
            lpFeeTitle: R.string.localizable.polkaswapLiqudityFee(preferredLanguages: languages).uppercased(),
            networkFeeTitle: R.string.localizable.polkaswapNetworkFee(preferredLanguages: languages).uppercased(),
            directExchangeRateValue: directExchangeRateValue,
            inversedExchangeRateValue: inversedExchangeRateValue,
            minReceivedTitleValue: minMaxValue,
            lpFeeTitleValue: lpFeeValue,
            networkFeeTitleValue: networkFeeValue,
            minMaxToken: minMaxToken,
            minMaxAlertTitle: minMaxAlertTitle,
            minMaxAlertText: minMaxAlertText
        )
        view?.didReceiveDetails(viewModel: model)
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
        if let fromAssetId = fromAsset?.identifier, let toAssetId = toAsset?.identifier {
            if marketSources == nil || nextButtonState == .poolNotCreated {
                interactor.checkIsPathAvailable(fromAssetId: fromAssetId, toAssetId: toAssetId)
            } else {
                loadQuote()
            }
        }
    }

    func didSelectPredefinedPercentage(_ percent: Decimal, isFrom: Bool) {
        guard isFrom, let fromBalance = fromBalance else {
            return
        }
        var newAmount = fromBalance * percent / 100
        newAmount = min(newAmount, fromBalance - networkFeeValue)
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

    func showAssetSelectionController(isFrom: Bool, filteredAssetList: [WalletAsset], assetManager: AssetManagerProtocol) {
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
              quote != nil
        else {
            return
        }

        let marketType = selectedLiquiditySourceType.rawValue

        let networkFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                   assetId: WalletAssetId.xor.rawValue,
                                                   type: "",
                                                   parameters: [],
                                                   accountId: nil,
                                                   minValue: nil,
                                                   maxValue: nil,
                                                   context: nil)
        let networkFee = Fee(value: AmountDecimal(value: networkFeeValue),
                             feeDescription: networkFeeDescription)
        let liquidityProviderFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                             assetId: WalletAssetId.xor.rawValue,
                                                             type: "",
                                                             parameters: [],
                                                             accountId: nil,
                                                             minValue: nil,
                                                             maxValue: nil,
                                                             context: ["type": TransactionType.swap.rawValue])
        let liquidityProviderFee = Fee(value: AmountDecimal(value: lpFeeValue),
                                       feeDescription: liquidityProviderFeeDescription)
        let transferInfo = TransferInfo(source: fromAsset.identifier,
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

    func needsUpdateDetails() {
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
        let view = R.nib.polkaswapLiquiditySourceSelectorView(owner: nil, options: nil)!
        view.localizationManager = LocalizationManager.shared
        view.liquiditySourceTypes = sourceTypes
        view.selectedLiquiditySourceType = selected
        view.delegate = self

        let viewController = UIViewController()
        viewController.preferredContentSize = CGSize(width: 0.0, height: view.frame.height)
        viewController.view = view

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.neu)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom

        self.view?.controller.present(viewController, animated: true, completion: nil)
//        try commandFactory.preparePresentationCommand(for: viewController).execute()
    }

    func didPressMarket() {
        guard fromAsset != nil,
              toAsset != nil,
              nextButtonState != .poolNotCreated,
              nextButtonState != .loading
        else { return }
        guard let marketSources = marketSources, marketSources.count > 0 else { return }
        showLiquiditySourceSelector(sourceTypes: marketSources, selected: selectedLiquiditySourceType)
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

extension SwapPresenter: PolkaswapMainInteractorOutputProtocol {

    func didLoadBalance(_ balance: Decimal, asset: WalletAsset) {
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

    func didLoadMarketSources(_ marketSources: [String], fromAssetId: String, toAssetId: String) {
        guard fromAssetId == fromAsset?.identifier, toAssetId == toAsset?.identifier else {
            return
        }
        self.marketSources = marketSources.compactMap({ sourceRawValue in
            PolkaswapLiquiditySourceType(rawValue: sourceRawValue)
        }).compactMap({ sourceType in
            switch sourceType {
            case .tbc:
                return LiquiditySourceType.tbc
            case .xyk:
                return LiquiditySourceType.xyk
            }
        })
        guard self.marketSources != nil else { return }
        applyXSTUSDhack(fromAssetId: fromAssetId, toAssetId: toAssetId)
        if !self.marketSources!.isEmpty && !self.marketSources!.contains(.smart) {
            self.marketSources!.append(.smart)
        }

        if !self.marketSources!.contains(selectedLiquiditySourceType) {
            selectedLiquiditySourceType = self.marketSources!.last ?? .smart
        }

        subscribeToPoolUpdates()
        loadQuote()
    }

    func checkEnteredData() -> Bool {
        // check if tokens selected
        guard fromAsset != nil && toAsset != nil else {
            nextButtonState = .chooseTokens
            return false
        }

        // check if pool created
        if let marketSources = marketSources, marketSources.isEmpty {
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
           fromAsset.isFeeAsset,
           fromAmount + networkFeeValue > fromBalance {
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
            amount = String(fromAmount!.toSubstrateAmount(precision: fromAsset!.precision)!)
        } else {
            amount = String(toAmount!.toSubstrateAmount(precision: toAsset!.precision)!)
        }

        // request quote
        guard let fromAssetId = fromAsset?.identifier,
                let toAssetId = toAsset?.identifier,
                let marketSources = marketSources else {
            return
        }
        
        let filterMode: FilterMode = selectedLiquiditySourceType == .smart ? .disabled : .allowSelected
        let liquiditySourceTypes: [PolkaswapLiquiditySourceType] = marketSources.compactMap { liquiditySourceType in
            switch liquiditySourceType {
            case .smart:
                return nil
            case .xyk:
                return .xyk
            case .tbc:
                return .tbc
            }
        }
        let params = PolkaswapMainInteractorQuoteParams(fromAssetId: fromAssetId,
                                                        toAssetId: toAssetId,
                                                        amount: amount,
                                                        swapVariant: swapVariant,
                                                        liquiditySourceTypes: liquiditySourceTypes,
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

    func applyXSTUSDhack(fromAssetId: String, toAssetId: String) {
        let valId = WalletAssetId.val.rawValue
        let pswapId = WalletAssetId.pswap.rawValue
        let daiId = "0x0200060000000000000000000000000000000000000000000000000000000000"
        let ethId = "0x0200070000000000000000000000000000000000000000000000000000000000"
        let xstusdId = WalletAssetId.xstusd.rawValue
        let hackTokenIds = [valId, pswapId, daiId, ethId]
        guard let marketSources = marketSources else { return }
        if marketSources.isEmpty {
            if fromAssetId == xstusdId && hackTokenIds.contains(toAssetId) ||
                toAssetId == xstusdId && hackTokenIds.contains(fromAssetId) {
                self.marketSources?.append(.smart)
            }
        }
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
           let toAmount = toAmount {
            let xorAmountFuture = toBalance + (swapVariant == .desiredInput ? minMaxValue : toAmount)
            guard xorAmountFuture > networkFeeValue else {
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
        if let fromAsset = fromAsset {
            interactor.loadBalance(asset: fromAsset)
        }
        if let toAsset = toAsset {
            interactor.loadBalance(asset: toAsset)
        }
        // TODO:
        // coudn't use toast here because this method triggers after successful swap
        // and we don't know exactly if confirmation is on screen
        dismissConfirmation(withToast: false)
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
        marketSources = nil
        fromBalance = nil
        toBalance = nil
        nextButtonState = .chooseTokens
    }
}

extension SwapPresenter: PolkaswapLiquiditySourceSelectorViewDelegate {
    func didSelectLiquiditySourceType(_ type: LiquiditySourceType) {
        invalidateQuoteAndParams()
        selectedLiquiditySourceType = type
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
