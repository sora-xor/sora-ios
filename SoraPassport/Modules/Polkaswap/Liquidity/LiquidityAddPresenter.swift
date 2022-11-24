/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import CommonWallet
import SoraKeystore
import SoraFoundation
import SoraUI

enum LiquidityDirection {
    case direct
    case inverse
}

final class LiquidityAddPresenter {

    weak var view: LiquidityViewProtocol?
    var wireframe: LiquidityWireframeProtocol!
    var interactor: LiquidityInteractorInputProtocol!

    var amountFormatterFactory: AmountFormatterFactoryProtocol?
    let assetManager: AssetManagerProtocol
    let commandFactory: WalletCommandFactoryProtocol

    let isAddingLiquidity: Bool = true

    var transactionType: TransactionType? {
        guard let state = poolLoader?.state else { return nil }

        switch state {
        case .unknown:
            return nil
        case .addToExistingPool:
            return .liquidityAdd
        case .addToExistingPoolFirstTime:
            return .liquidityAddToExistingPoolFirstTime
        case .createNewPair:
            return .liquidityAddNewPool
        }
    }

    var poolLoader: PoolLoaderProtocol?

    var pool: PoolDetails? {
        poolLoader?.poolDetails
    }
    var activePoolsList: [PoolDetails]
    var firstAsset: AssetInfo
    var secondAsset: AssetInfo?

    var viewModel: PoolDetailsViewModel!

    var firstAmount: Decimal?
    var secondAmount: Decimal?
    var firstBalance: Decimal?
    var secondBalance: Decimal?

    private var _slippage: Double = 0.5
    private var isFrom = false

    var liquidityDirection: LiquidityDirection = .direct

    var languages: [String]? {
        view?.localizationManager?.preferredLocalizations
    }

    var slippage: Double {
        get { return _slippage }
        set { _slippage = newValue > 0.01 ? newValue : 0.01 }
    }

    var removePercentageValue: Int = 0

    var detailsState: DetailsState = .collapsed

    var nextButtonState: NextButtonState = .enterAmount {
        didSet {
            view?.setNextButton(isEnabled: nextButtonState == .poolEnabled,
                                isLoading: interactor.isLoading,
                                title: nextButtonState.title(preferredLanguages: view?.localizationManager?.preferredLocalizations))
        }
    }

    var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private let assets: [AssetInfo]
    private var transactionFee: Decimal?

    var assetList: [AssetInfo] {
        assets//return assetManager.sortedAssets(self.assets, onlyVisible: true)
    }

    init(
        assets: [AssetInfo],
        assetManager: AssetManagerProtocol,
        pool: PoolDetails?,
        commandFactory: WalletCommandFactoryProtocol,
        firstAsset: AssetInfo,
        secondAsset: AssetInfo?,
        activePoolsList: [PoolDetails]
    ) {
        self.assets = assets
        self.assetManager = assetManager
        self.commandFactory = commandFactory
        self.firstAsset = firstAsset
        self.secondAsset = secondAsset
        self.activePoolsList = activePoolsList
        if let secondAsset = secondAsset, let poolDetails = pool {
            self.poolLoader = PoolLoader(baseAsset: firstAsset, toAsset: secondAsset, activePoolsList: activePoolsList, poolDetails: poolDetails)
            self.poolLoader?.delegate = self
            self.poolLoader?.setInitialPool(poolDetails)
        }
    }

    fileprivate func updateButtonState() {

        // check if tokens are selected
        guard let secondAsset = secondAsset else {
            nextButtonState = .chooseTokens
            return
        }

        // check if amount is entered
        guard let state = poolLoader?.state else { return }

        if state == .createNewPair {
            if firstAmount == nil || secondAmount == nil || firstAmount == 0 || secondAmount == 0 {
                nextButtonState = .enterAmount
                return
            }
        } else {
            if liquidityDirection == .direct {
                guard let firstAmount = firstAmount, firstAmount > 0 else {
                    nextButtonState = .enterAmount
                    return
                }
            }
            if liquidityDirection == .inverse {
                guard let secondAmount = secondAmount, secondAmount > 0 else {
                    nextButtonState = .enterAmount
                    return
                }
            }
        }

        // check if balance is enough
        if !checkBalance() {
            nextButtonState = .insufficientBalance(token: "")
            return
        }

        // all tests OK
        nextButtonState = .poolEnabled
    }

    private func updateDetailsViewModel() {
        guard let secondAsset = secondAsset, let firstAmount = firstAmount, let secondAmount = secondAmount, let fee = transactionFee else { return }

        let factory = PoolDetailsModelFactory(firstAsset: firstAsset, secondAsset: secondAsset, firstAmount: firstAmount, secondAmount: secondAmount, languages: languages, fee: fee)
        viewModel = factory.createDetailsViewModel(pool: poolLoader?.poolDetails)
        if let detailsViewModel = viewModel {
            view?.didReceiveDetails(viewModel: detailsViewModel)
        }
    }

    private func provideViewModel(_ selectedAsset: AssetInfo?, amount: Decimal? = nil, isFirstAsset: Bool) {
        guard selectedAsset != nil else {
            let viewModel = PolkaswapAssetViewModel(
                isEmpty: true,
                assetImageViewModel: nil,
                amountInputViewModel: nil,
                assetName: nil
            )
            if isFirstAsset {
                view?.setFirstAsset(viewModel: viewModel)
            } else {
                view?.setSecondAsset(viewModel: viewModel)
            }
            return
        }

        let assetName = selectedAsset?.symbol
        guard let assetInfo = selectedAsset else { return }

        var assetImageViewModel: WalletImageViewModelProtocol
        if let iconString = assetInfo.icon {
            assetImageViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            assetImageViewModel = WalletStaticImageViewModel(staticImage: R.image.assetUnkown()!)
        }
        let formatter = amountFormatterFactory!.createInputFormatter(for: selectedAsset).value(for: locale)
        let amountInputViewModel = PolkaswapAmountInputViewModel(
            symbol: "",
            amount: amount,
            limit: Decimal(Int.max),
            formatter: formatter, precision: 18
        )
        let assetViewModel = PolkaswapAssetViewModel(
            isEmpty: false,
            assetImageViewModel: assetImageViewModel,
            amountInputViewModel: amountInputViewModel,
            assetName: assetName
        )
        if isFirstAsset {
            view?.setFirstAsset(viewModel: assetViewModel)
        } else {
            view?.setSecondAsset(viewModel: assetViewModel)
        }
    }

    func userPoolDetails(targetAsset: String) -> PoolDetails? {
        activePoolsList.first(where: { $0.targetAsset == targetAsset })
    }

    func recalcAmounts() {
        if let poolDetails = poolLoader?.poolDetails {
            recalcAmounts(pool: poolDetails)
        }
    }

    fileprivate func recalcAmounts(pool: PoolDetails) {
        if liquidityDirection == .direct,
           let firstAmount = firstAmount {
            let scale = pool.targetAssetPooledTotal / pool.baseAssetPooledTotal
            secondAmount = firstAmount * scale
            view?.setSecondAmount(secondAmount!)
        } else if liquidityDirection == .inverse, let secondAmount = secondAmount {
            let scale = pool.baseAssetPooledTotal / pool.targetAssetPooledTotal
            firstAmount = secondAmount * scale
            view?.setFirstAmount(firstAmount!)
        }
    }

    func checkBalance() -> Bool {
        guard let firstAmount = firstAmount,
              let secondAmount = secondAmount,
              secondAsset != nil,
              let firstBalance = firstBalance,
              let secondBalance = secondBalance,
              let fee = transactionFee
        else {
            return false
        }

        return firstAmount + fee <= firstBalance && secondAmount <= secondBalance
    }

    func updateFee() {
        guard let type = transactionType else { return }
        interactor?.networkFeeValue(with: type, completion: { [weak self] fee in
            self?.transactionFee = fee
        })
    }

}

extension LiquidityAddPresenter: LiquidityPresenterProtocol {
    func setup() {
        provideViewModel(firstAsset, amount: firstAmount, isFirstAsset: true)
        provideViewModel(secondAsset, amount: secondAmount, isFirstAsset: false)
        view?.setPercentage(removePercentageValue)
        view?.setDetailsVisible(nextButtonState == .removeEnabled)
        view?.setDetails(detailsState)
        view?.setNextButton(
            isEnabled: false,
            isLoading: false,
            title: nextButtonState.title(preferredLanguages: view?.localizationManager?.preferredLocalizations)
        )
        updateDetailsViewModel()
        updateFirstProviderMessageVisibility()
        startPoolLoader()
        interactor.loadBalance(asset: firstAsset)
        if let secondAsset = secondAsset {
            didSelectAsset(secondAsset, isFrom: false)
        }
    }

    func didSliderMove(_ value: Float) {
        // makes sense only for LiquidityRemovePresenter
    }

    func activateInfo() {
        wireframe.present(
            message: R.string.localizable.addLiquidityAlertText(preferredLanguages: .currentLocale),
            title: R.string.localizable.addLiquidityTitle(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }

    fileprivate func onTokenAndAmountSelected() {
        recalcAmounts()
        updateDetails()
    }

    fileprivate func updateDetails() {
        updateDetailsVisibility()
        updateDetailsExpendability()
        updateDetailsViewModel()

        if firstAmount != nil && secondAmount != nil {
            view?.setDetailsVisible(true)
            detailsState = .collapsed
            view?.setDetails(detailsState)
            updateDetailsViewModel()
        } else {
            view?.setDetailsVisible(false)
            detailsState = .disabled
            view?.setDetails(detailsState)
        }
    }

    func updateDetailsVisibility() {
        view?.setDetailsVisible(isDetailsVisible())
    }

    func isDetailsVisible() -> Bool {
        let secondAssetSelected = secondAsset != nil
        let firstAmountEntered = firstAmount != nil
        let secondAmountEntered = secondAmount != nil
        let feeReceived = transactionFee != nil

        return secondAssetSelected && firstAmountEntered && secondAmountEntered && feeReceived
    }

    func updateDetailsExpendability() {
        if !isDetailsVisible() {
            detailsState = .collapsed
        }
        view?.setDetails(detailsState)
    }

    func didSelectAmount(_ amount: Decimal?, isFirstAsset: Bool) {
        if isFirstAsset {
            liquidityDirection = .direct
            firstAmount = amount
        } else {
            liquidityDirection = .inverse
            secondAmount = amount
        }
        onTokenAndAmountSelected()
        updateButtonState()
    }

    func didPressAsset(isFrom: Bool) {
        if isFrom {
            showSelectionFromAsset()
        } else {
            showSelectionToAsset()
        }
    }

    func showSelectionFromAsset() {
        showAssetSelectionController(isFrom: true, filteredAssetList: filteredBaseAssets(), assetManager: assetManager)
    }

    func showSelectionToAsset() {
        showAssetSelectionController(isFrom: false,
                                     filteredAssetList: filteredTargetAssets(),
                                     assetManager: assetManager)
    }

    func showAssetSelectionController(isFrom: Bool, filteredAssetList: [AssetInfo], assetManager: AssetManagerProtocol) {
        self.isFrom = isFrom

        guard let viewController = ModalPickerFactory.createPickerForAssetList(
            filteredAssetList,
            selectedType: nil,
            delegate: self,
            context: assetManager
        ) else { return }
        viewController.title = R.string.localizable.commonSelectAsset(preferredLanguages: view?.localizationManager?.preferredLocalizations)

        let presentationCommand = commandFactory.preparePresentationCommand(for: viewController)
        presentationCommand.presentationStyle = .modal(inNavigation: true)
        try? presentationCommand.execute()
    }

    func baseAssets() -> [AssetInfo] {
        let baseAssetsId = [WalletAssetId.xor.rawValue, WalletAssetId.xstusd.rawValue]
        return baseAssetsId.compactMap { assetId in
            assetManager.assetInfo(for: assetId)
        }
    }

    func filteredBaseAssets() -> [AssetInfo] {
        baseAssets().filter { asset in
            return asset != secondAsset
        }
    }

    func filteredTargetAssets() -> [AssetInfo] {
        assetList.filter { asset in
            return asset != firstAsset
        }
    }

    func didSelectAsset(atIndex index: Int, isFrom: Bool) {
        if isFrom {
            didSelectBaseAsset(atIndex: index)
        } else {
            didSelectTargetAsset(atIndex: index)
        }
    }

    func didSelectBaseAsset(atIndex index: Int) {
        guard index < filteredBaseAssets().count else { return }
        let selectedAsset = filteredBaseAssets()[index]
        didSelectAsset(selectedAsset, isFrom: true)
    }

    func didSelectTargetAsset(atIndex index: Int) {
        guard index < filteredTargetAssets().count else { return }
        let selectedAsset = filteredTargetAssets()[index]
        didSelectAsset(selectedAsset, isFrom: false)
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

    func didSelectAsset(_ selectedAsset: AssetInfo, isFrom: Bool) {
        if isFrom {
            firstAsset = selectedAsset
        } else {
            secondAsset = selectedAsset
        }

        if let secondAsset = secondAsset {
            firstBalance = nil
            secondBalance = nil
            interactor.loadBalance(asset: firstAsset)
            interactor.loadBalance(asset: secondAsset)
            interactor.subscribePoolReserves(asset: selectedAsset.identifier)
        }
        startPoolLoader()
        provideViewModel(selectedAsset, amount: nil, isFirstAsset: isFrom)
        updateButtonState()
    }

    func startPoolLoader() {
        poolLoader?.delegate = nil
        poolLoader = nil
        if let secondAsset = secondAsset {
            poolLoader = PoolLoader(baseAsset: firstAsset, toAsset: secondAsset, activePoolsList: activePoolsList)
            poolLoader?.delegate = self
            poolLoader?.getPoolState()
        }
    }

    func didSelectPredefinedPercentage(_ percent: Decimal, isFirstAsset: Bool) {
        if isFirstAsset {
            guard let firstBalance = firstBalance else { return }
            let newAmount = firstBalance * percent / 100
            view?.setFirstAmount(newAmount)
            didSelectAmount(newAmount, isFirstAsset: isFirstAsset)
        } else {
            guard let secondBalance = secondBalance else { return }
            let newAmount = secondBalance * percent / 100
            view?.setSecondAmount(newAmount)
            didSelectAmount(newAmount, isFirstAsset: isFirstAsset)
        }
    }

    func didPressDetails() {
        updateDetailsViewModel()
        if detailsState == .expanded {
            detailsState = .collapsed
        } else if detailsState == .collapsed {
            detailsState = .expanded
        }
        view?.setDetails(detailsState)
    }

    func didPressSbApyButton() {
        wireframe.present(
            message: R.string.localizable.polkaswapSbApyInfo(),
            title: R.string.localizable.poolApyTitle(),
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }

    func didPressNetworkFee() {
        wireframe.present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(),
            title: R.string.localizable.polkaswapNetworkFee(),
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }

    func didPressNextButton() {
        guard let secondAsset = secondAsset,
              let firstAmount = firstAmount,
              let secondAmount = secondAmount,
              let fee = transactionFee
        else { return }

        let networkFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                   assetId: WalletAssetId.xor.rawValue,
                                                   type: "fee",
                                                   parameters: [],
                                                   accountId: nil,
                                                   minValue: nil,
                                                   maxValue: nil,
                                                   context: nil)
        let networkFee = Fee(
            value: AmountDecimal(value: fee),
            feeDescription: networkFeeDescription
        )

        guard let transactionType = transactionType else { return }

        let dexId = firstAsset.isFeeAsset ? "0" : "1"
        var context: [String: String] = [
            TransactionContextKeys.transactionType: transactionType.rawValue,
            TransactionContextKeys.firstAssetAmount: AmountDecimal(value: firstAmount).stringValue,
            TransactionContextKeys.secondAssetAmount: AmountDecimal(value: secondAmount).stringValue,
            TransactionContextKeys.slippage: String(slippage),
            TransactionContextKeys.dex: dexId
        ]
        if let viewModel = viewModel {
            context[TransactionContextKeys.directExchangeRateValue] = AmountDecimal(value: viewModel.directExchangeRateValue).stringValue
            context[TransactionContextKeys.inversedExchangeRateValue] = AmountDecimal(value: viewModel.inversedExchangeRateValue).stringValue
            context[TransactionContextKeys.shareOfPool] = AmountDecimal(value: viewModel.shareOfPoolValue).stringValue
            context[TransactionContextKeys.sbApy] = AmountDecimal(value: viewModel.sbApyValue).stringValue
        } else {
            // new pair
            context[TransactionContextKeys.directExchangeRateValue] = AmountDecimal(value: secondAmount/firstAmount).stringValue
            context[TransactionContextKeys.inversedExchangeRateValue] = AmountDecimal(value: firstAmount/secondAmount).stringValue
            context[TransactionContextKeys.shareOfPool] = AmountDecimal(value: Decimal(100)).stringValue
            context[TransactionContextKeys.sbApy] = AmountDecimal(value: Decimal(0)).stringValue
        }

        let transferInfo = TransferInfo(
            source: firstAsset.identifier,
            destination: secondAsset.identifier,
            amount: AmountDecimal(value: firstAmount),
            asset: firstAsset.identifier,
            details: "",
            fees: [networkFee],
            context: context
        )
        let payload = ConfirmationPayload(transferInfo: transferInfo, receiverName: "")
        let confirmation = commandFactory.prepareConfirmation(with: payload)
        confirmation.presentationStyle = .modal(inNavigation: true)
        try? confirmation.execute()
    }

    func didLoadPools(_ pools: [PoolDetails]) {
        self.activePoolsList = pools
    }
}

extension LiquidityAddPresenter: PolkaswapSlippageSelectorViewDelegate {
    func didSelect(slippage: Double) {
        self.slippage = slippage
        let dismiss = commandFactory.prepareHideCommand(with: .dismiss)
        try? dismiss.execute()
        view?.setSlippageAmount(Decimal(self.slippage))
    }
}

extension LiquidityAddPresenter: LiquidityInteractorOutputProtocol {
    func didCheckIsPairExists(baseAsset: String, targetAsset: String, isExists: Bool) {
        poolLoader?.didCheckIsPairExists(isExists, baseAsset: baseAsset, targetAsset: targetAsset)
    }

    func didLoadBalance(_ balance: Decimal, asset: AssetInfo) {
        let formatter = amountFormatterFactory!.createTokenFormatter(for: nil, maxPrecision: 8).value(for: locale)
        if asset.identifier == firstAsset.identifier {
            firstBalance = balance
            view?.setFirstAssetBalance(formatter.stringFromDecimal(balance))
        } else if let secondAsset = secondAsset, asset.identifier == secondAsset.identifier {
            secondBalance = balance
            view?.setSecondAssetBalance(formatter.stringFromDecimal(balance))
        }
        updateButtonState()
        onTokenAndAmountSelected()
    }

    func didLoadPoolDetails(_ poolDetails: PoolDetails?, baseAsset: String, targetAsset: String) {
        guard baseAsset == firstAsset.identifier, targetAsset == secondAsset?.identifier else { return }
        poolLoader?.didLoadPoolDetails(poolDetails, baseAsset: baseAsset, targetAsset: targetAsset)
        recalcAmounts()
        updateButtonState()
    }

    func didUpdatePoolSubscription(asset: String) {
        guard asset == secondAsset?.identifier else { return }
        interactor.loadPool(baseAsset: firstAsset.identifier, targetAsset: asset)
    }

    func updateFirstProviderMessageVisibility() {
        let isVisible = poolLoader?.state == .createNewPair
        view?.setFirstProviderView(isHidden: !isVisible)
    }
}

extension LiquidityAddPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        didSelectAsset(atIndex: index, isFrom: isFrom)
    }
}

extension LiquidityAddPresenter: PoolLoaderDelegate {
    func loadPoolDetails(baseAsset: String, targetAsset: String) {
        interactor.loadPool(baseAsset: baseAsset, targetAsset: targetAsset)
    }

    func checkIsPairExists(baseAsset: String, targetAsset: String) {
        interactor.checkIsPairExists(baseAsset: baseAsset, targetAsset: targetAsset)
    }

    func didGetPoolState(_ poolState: PoolState, poolDetails: PoolDetails?) {
        if let pool = poolDetails {
            recalcAmounts(pool: pool)
        }
        updateButtonState()
        updateDetails()
        updateFirstProviderMessageVisibility()
        updateFee()
    }
}
