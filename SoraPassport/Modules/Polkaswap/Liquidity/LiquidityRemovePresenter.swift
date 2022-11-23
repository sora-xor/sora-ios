/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import CommonWallet
import SoraKeystore
import SoraFoundation
import SoraUI

final class LiquidityRemovePresenter {

    weak var view: LiquidityViewProtocol?
    var wireframe: LiquidityWireframeProtocol!
    var interactor: LiquidityInteractorInputProtocol!

    var amountFormatterFactory: AmountFormatterFactoryProtocol?
    let assetManager: AssetManagerProtocol
    let commandFactory: WalletCommandFactoryProtocol

    let isAddingLiquidity: Bool = false
    let transactionType: TransactionType = .liquidityRemoval
    var pool: PoolDetails
    var activePoolsList: [PoolDetails]
    var firstAsset: AssetInfo
    var secondAsset: AssetInfo

    var viewModel: PoolDetailsViewModel!

    var firstAmount: Decimal = 0 {
        didSet {
            guard oldValue != firstAmount else { return }
            view?.setFirstAmount(firstAmount)
        }
    }
    var firstBalance: Decimal?
    var secondAmount: Decimal = 0 {
        didSet {
            guard oldValue != secondAmount else { return }
            view?.setSecondAmount(secondAmount)
        }
    }

    private var _slippage: Double = 0.5
    private var isFrom = false

    var slippage: Double {
        get { return _slippage }
        set { _slippage = newValue > 0.01 ? newValue : 0.01 }
    }

    var removePercentageValue: Int = 0

    var detailsState: DetailsState = .collapsed

    var nextButtonState: NextButtonState = .enterAmount {
        didSet {
            view?.setNextButton(isEnabled: nextButtonState == .removeEnabled,
                                isLoading: interactor.isLoading,
                                title: nextButtonState.title(preferredLanguages: view?.localizationManager?.preferredLocalizations))
        }
    }

    var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    private let assets: [AssetInfo]
    private var removeLiquidityFee: Decimal?

    var assetList: [AssetInfo] {
       assets
    }

    init(
        assets: [AssetInfo],
        assetManager: AssetManagerProtocol,
        pool: PoolDetails,
        commandFactory: WalletCommandFactoryProtocol,
        firstAsset: AssetInfo,
        secondAsset: AssetInfo,
        activePoolsList: [PoolDetails]
    ) {
        self.assets = assets
        self.assetManager = assetManager
        self.commandFactory = commandFactory
        self.pool = pool
        self.firstAsset = firstAsset
        self.secondAsset = secondAsset
        self.activePoolsList = activePoolsList
    }

    fileprivate func updateButtonState() {

        // check if amount is entered
        guard firstAmount > 0 || secondAmount > 0 else {
            nextButtonState = .enterAmount
            return
        }

        // check if balance is enough
        if !checkBalance() {
            nextButtonState = .insufficientBalance(token: "")
            return
        }

        // all tests OK
        nextButtonState = .removeEnabled
    }

    private func updateDetailsViewModel() {
        guard
            let fee = removeLiquidityFee
        else { return }

        let sbApyValueRaw = pool.sbAPYL
        let sbApyValue = Decimal(sbApyValueRaw * 100)
        var directExchangeRateValue: Decimal = 0.0
        var inversedExchangeRateValue: Decimal = 0.0
        let firstAssetValue: Decimal = pool.baseAssetPooledByAccount - firstAmount
        let secondAssetValue: Decimal = pool.targetAssetPooledByAccount - secondAmount
        let shareOfPoolValue: Decimal = firstAssetValue/pool.baseAssetPooledTotal * 100
        directExchangeRateValue = pool.baseAssetPooledTotal/pool.targetAssetPooledTotal
        inversedExchangeRateValue = pool.targetAssetPooledTotal/pool.baseAssetPooledTotal

        viewModel = PoolDetailsViewModel(
            firstAsset: firstAsset,
            firstAssetValue: firstAssetValue,
            secondAsset: secondAsset,
            secondAssetValue: secondAssetValue,
            shareOfPoolValue: shareOfPoolValue,
            directExchangeRateTitle: "\(firstAsset.symbol)/\(secondAsset.symbol)",
            directExchangeRateValue: directExchangeRateValue,
            inversedExchangeRateTitle: "\(secondAsset.symbol)/\(firstAsset.symbol)",
            inversedExchangeRateValue: inversedExchangeRateValue,
            sbApyValue: sbApyValue,
            networkFeeValue: fee
        )
        view?.didReceiveDetails(viewModel: viewModel)
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

        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
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

    func userPoolDetails(baseAsset: String, targetAsset: String) -> PoolDetails? {
        activePoolsList.first(where: { $0.baseAsset == baseAsset && $0.targetAsset == targetAsset })
    }

    func checkBalance() -> Bool {
        guard let firstBalance = firstBalance,
              let fee = removeLiquidityFee else {
            return false
        }
        return firstAmount + firstBalance >= fee
    }
}

extension LiquidityRemovePresenter: LiquidityPresenterProtocol {
    func setup() {
        provideViewModel(firstAsset, isFirstAsset: true)
        provideViewModel(secondAsset, isFirstAsset: false)
        view?.setPercentage(removePercentageValue)
        view?.setDetailsVisible(true)
        view?.setDetails(.collapsed)
        updateDetailsViewModel()
        view?.setFirstProviderView(isHidden: true)
        interactor.subscribePoolReserves(asset: secondAsset.identifier)
        interactor.loadBalance(asset: firstAsset)
        interactor.networkFeeValue(with: .liquidityRemoval) { [weak self] fee in
            self?.removeLiquidityFee = fee
        }
        updateButtonState()
    }

    func didSliderMove(_ value: Float) {
        removePercentageValue = Int(value)
        nextButtonState = removePercentageValue > 0 ? .removeEnabled : .enterAmount
        view?.setPercentage(removePercentageValue)
        view?.setDetails(detailsState)
        let scale: Decimal = Decimal(removePercentageValue) / 100
        firstAmount = pool.baseAssetPooledByAccount * scale
        secondAmount = pool.targetAssetPooledByAccount * scale
        updateDetailsViewModel()
    }

    func activateInfo() {
        wireframe.present(
            message: R.string.localizable.removeLiquidityInfoText(),
            title: R.string.localizable.removeLiquidityTitle(),
            closeAction: R.string.localizable.commonOk(),
            from: view
        )
    }

    func didSelectAmount(_ amount: Decimal?, isFirstAsset: Bool) {
        guard let amount = amount else {
            return
        }
        
        if isFirstAsset {
            firstAmount = min(amount, pool.baseAssetPooledByAccount)
            secondAmount = firstAmount * pool.targetAssetPooledByAccount / pool.baseAssetPooledByAccount
        } else {
            secondAmount = min(amount, pool.targetAssetPooledByAccount)
            firstAmount = secondAmount * pool.baseAssetPooledByAccount / pool.targetAssetPooledByAccount
        }
        removePercentageValue = Int(NSDecimalNumber(decimal: firstAmount / pool.baseAssetPooledByAccount).doubleValue * 100)
        view?.setSliderAmount(removePercentageValue)
        view?.setPercentage(removePercentageValue)

        updateButtonState()
        updateDetailsViewModel()
    }

    func didPressAsset(isFrom: Bool) {
        showAssetSelectionController(isFrom: isFrom, filteredAssetList: filteredAssetList(isFrom: isFrom), assetManager: assetManager)
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

    func filteredAssetList(isFrom: Bool) -> [AssetInfo] {
        return assets.filter { asset in
            return asset.identifier != WalletAssetId.xor.rawValue
        }
    }

    func didSelectAsset(atIndex index: Int, isFrom: Bool) {
        let filteredAssetList = filteredAssetList(isFrom: isFrom)
        guard index < filteredAssetList.count else { return }
        let selectedAsset = filteredAssetList[index]
        didSelectAsset(selectedAsset, isFrom: isFrom)
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
        // doesn't make sense for remove liquidity
    }

    func didSelectPredefinedPercentage(_ percent: Decimal, isFirstAsset: Bool) {
        // doesn't make sence for remove liquidity
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
        guard firstAmount > 0, secondAmount > 0, let fee = removeLiquidityFee else { return }

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

        let dexId = firstAsset.isFeeAsset ? "0" : "1"
        let context: [String: String] = [
            TransactionContextKeys.transactionType: transactionType.rawValue,
            TransactionContextKeys.firstAssetAmount: AmountDecimal(value: firstAmount).stringValue,
            TransactionContextKeys.secondAssetAmount: AmountDecimal(value: secondAmount).stringValue,
            TransactionContextKeys.firstReserves: pool.reserves.description,
            TransactionContextKeys.totalIssuances: pool.totalIssuances.description,
            TransactionContextKeys.directExchangeRateValue: AmountDecimal(value: viewModel.directExchangeRateValue).stringValue,
            TransactionContextKeys.inversedExchangeRateValue: AmountDecimal(value: viewModel.inversedExchangeRateValue).stringValue,
            TransactionContextKeys.shareOfPool: AmountDecimal(value: viewModel.shareOfPoolValue).stringValue,
            TransactionContextKeys.slippage: String(slippage),
            TransactionContextKeys.sbApy: AmountDecimal(value: viewModel.sbApyValue).stringValue,
            TransactionContextKeys.dex: dexId
        ]

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
        updateDetailsViewModel()
    }
}

extension LiquidityRemovePresenter: PolkaswapSlippageSelectorViewDelegate {
    func didSelect(slippage: Double) {
        self.slippage = slippage
        let dismiss = commandFactory.prepareHideCommand(with: .dismiss)
        try? dismiss.execute()
        view?.setSlippageAmount(Decimal(self.slippage))
    }
}

extension LiquidityRemovePresenter: LiquidityInteractorOutputProtocol {
    func didCheckIsPairExists(baseAsset: String, targetAsset: String, isExists: Bool) {
        // doesn't make sence for removing liquidity
    }

    func didLoadBalance(_ balance: Decimal, asset: AssetInfo) {
        if asset.identifier == firstAsset.identifier {
            firstBalance = balance
            updateButtonState()
        }
    }

    func didLoadPoolDetails(_ poolDetails: PoolDetails?, baseAsset: String, targetAsset: String) {
        guard baseAsset == firstAsset.identifier, targetAsset == secondAsset.identifier, let poolDetails = poolDetails  else { return }
        self.pool = poolDetails
        updateDetailsViewModel()
    }

    func didUpdatePoolSubscription(asset: String) {
        guard asset == secondAsset.identifier else { return }
        //TODO: baseAsset
        let baseAsset = WalletAssetId.xor.rawValue
        interactor.loadPool(baseAsset: baseAsset, targetAsset: asset)
    }
}

extension LiquidityRemovePresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        didSelectAsset(atIndex: index, isFrom: isFrom)
    }
}
