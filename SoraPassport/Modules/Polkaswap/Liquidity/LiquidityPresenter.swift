import UIKit
import CommonWallet
import SoraKeystore

final class LiquidityPresenter {
    
    weak var view: LiquidityViewProtocol?
    var wireframe: LiquidityWireframeProtocol!
    var interactor: LiquidityInteractorInputProtocol!

    var amountFormatterFactory: AmountFormatterFactoryProtocol?
    let assetManager: AssetManagerProtocol
    let commandFactory: WalletCommandFactoryProtocol

    let mode: TransactionType
    let pool: PoolDetails
    var firstAsset: WalletAsset!
    var secondAsset: WalletAsset!
    
    var viewModel: PoolDetailsViewModel!
    
    var firstAmount: Decimal?
    var secondAmount: Decimal?
    var firstBalance: Decimal?
    var secondBalance: Decimal?
    var networkFeeValue: Decimal = 0.0
    
    private var _slippage: Double = 0.5
    
    var slippage: Double {
        get { return _slippage }
        set { _slippage = newValue > 0.01 ? newValue : 0.01 }
    }
    
    var removePercentageValue: Int = 0
    
    var detailsState: DetailsState = .collapsed
    var nextButtonState: NextButtonState = .enterAmount
    
    var locale: Locale {
        localizationManager?.selectedLocale ?? Locale.current
    }

    init(assetManager: AssetManagerProtocol,
         mode: TransactionType, pool: PoolDetails,
         commandFactory: WalletCommandFactoryProtocol) {
        self.assetManager = assetManager
        self.mode = mode
        self.commandFactory = commandFactory
        self.pool = pool
    }


    private func updateDetailsViewModel() {
        guard
            let firstAssetInfo = assetManager.assetInfo(for: firstAsset.identifier),
            let secondAssetInfo = assetManager.assetInfo(for: secondAsset.identifier)
        else { return }

        let sbApyValueRaw = pool.sbAPYL ?? 0
        let sbApyValue = Decimal(sbApyValueRaw * 100)

        viewModel = PoolDetailsViewModel(
            firstAsset: firstAssetInfo,
            firstAssetValue: "",
            secondAsset: secondAssetInfo,
            secondAssetValue: "",
            shareOfPoolValue: 0,
            directExchangeRateTitle: "\(firstAsset.symbol)/\(secondAsset.symbol)",
            directExchangeRateValue: 0,
            inversedExchangeRateTitle: "\(secondAsset.symbol)/\(firstAsset.symbol)",
            inversedExchangeRateValue: 0,
            sbApyValue: sbApyValue,
            networkFeeValue: 0.0007
        )
        view?.didReceiveDetails(viewModel: viewModel)
    }
    
    private func provideViewModel(_ selectedAsset: WalletAsset?, amount: Decimal? = nil, isFirstAsset: Bool) {
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

        let assetManager: AssetManagerProtocol = AssetManager.shared
        let assetName = selectedAsset?.name.value(for: locale)
        guard let identifier = selectedAsset?.identifier else { return }
        let assetInfo = assetManager.assetInfo(for: identifier)
        var assetImageViewModel: WalletImageViewModelProtocol
        if let iconString = assetInfo?.icon {
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
}

extension LiquidityPresenter: LiquidityPresenterProtocol {
    func setup() {
        provideViewModel(firstAsset, amount: firstAmount, isFirstAsset: true)
        provideViewModel(secondAsset, amount: secondAmount, isFirstAsset: false)
        view?.setPercentage(removePercentageValue)
        view?.setDetailsEnabled(nextButtonState == .removeEnabled)
        view?.setDetails(detailsState)
        view?.setNextButton(
            isEnabled: nextButtonState == .removeEnabled,
            title: nextButtonState.title(preferredLanguages: view?.localizationManager?.preferredLocalizations)
        )
        updateDetailsViewModel()
    }
    
    func didSliderMove(_ value: Float) {
        removePercentageValue = Int(value)
        if removePercentageValue > 0 {
            nextButtonState = self.mode == .liquidityRemoval ? .removeEnabled : .poolEnabled
        } else {
            nextButtonState = .enterAmount
        }
        view?.setPercentage(removePercentageValue)
        view?.setDetails(detailsState)
        view?.setNextButton(
            isEnabled: nextButtonState == .removeEnabled,
            title: nextButtonState.title(preferredLanguages: view?.localizationManager?.preferredLocalizations)
        )
    }
    
    func activateInfo() {
        if mode == .liquidityAdd {
            wireframe.present(
                message: R.string.localizable.addLiquidityAlertText(),
                title: R.string.localizable.addLiquidityTitle(),
                closeAction: R.string.localizable.commonOk(),
                from: view
            )
        } else {
            wireframe.present(
                message: R.string.localizable.removeLiquidityInfoText(),
                title: R.string.localizable.removeLiquidityTitle(),
                closeAction: R.string.localizable.commonOk(),
                from: view
            )
        }
    }

    func didSelectAmount(_ amount: Decimal?, isFirstAsset: Bool) {
        if isFirstAsset {
            firstAmount = amount
        } else {
            secondAmount = amount
        }
        if firstAmount != nil && secondAmount != nil {
            view?.setDetailsEnabled(true)
            detailsState = .collapsed
            view?.setDetails(detailsState)
            interactor.checkIsAvailable(
                firstAssetId: firstAsset!.identifier,
                secondAssetId: secondAsset!.identifier
            )
            updateDetailsViewModel()
        } else {
            view?.setDetailsEnabled(false)
            detailsState = .disabled
            view?.setDetails(detailsState)
        }
    }

    func didSelectPredefinedPercentage(_ percent: Decimal, isFirstAsset: Bool) {
        if isFirstAsset {
            guard let firstBalance = firstBalance else { return }
            var newAmount = firstBalance * percent / 100
            view?.setFirstAmount(newAmount)
            didSelectAmount(newAmount, isFirstAsset: isFirstAsset)
        } else {
            guard let secondBalance = secondBalance else { return }
            var newAmount = secondBalance * percent / 100
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
        guard let firstAsset = firstAsset,
              let secondAsset = secondAsset,
              let firstAmount = firstAmount,
              let secondAmount = secondAmount
        else { return }
        let networkFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                   assetId: WalletAssetId.xor.rawValue,
                                                   type: "",
                                                   parameters: [],
                                                   accountId: nil,
                                                   minValue: nil,
                                                   maxValue: nil,
                                                   context: nil)
        let networkFee = Fee(
            value: AmountDecimal(value: networkFeeValue),
            feeDescription: networkFeeDescription
        )

        let context: [String: String] = [
            TransactionContextKeys.transactionType: self.mode.rawValue,
            TransactionContextKeys.firstAssetAmount: AmountDecimal(value: firstAmount).stringValue,
            TransactionContextKeys.secondAssetAmount: AmountDecimal(value: secondAmount).stringValue,
            TransactionContextKeys.slippage: String(slippage),
            TransactionContextKeys.sbApy: AmountDecimal(value: viewModel.sbApyValue).stringValue
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
}

extension LiquidityPresenter: LiquidityInteractorOutputProtocol {
    func didCheckAvailable(firstAssetId: String, secondAssetId: String, isAvailable: Bool) {
        if isAvailable {
            nextButtonState = self.mode == .liquidityRemoval ? .removeEnabled : .poolEnabled
            view?.setNextButton(
                isEnabled: true,
                title: nextButtonState.title(preferredLanguages: view?.localizationManager?.preferredLocalizations)
            )
        } else {
            nextButtonState = .insufficientLiquidity
            view?.setNextButton(
                isEnabled: false,
                title: nextButtonState.title(preferredLanguages: view?.localizationManager?.preferredLocalizations)
            )
        }
    }

    func didLoadBalance(_ balance: Decimal, asset: WalletAsset) {
        let formatter = amountFormatterFactory!.createTokenFormatter(for: asset, maxPrecision: 8).value(for: locale)
        if let firstAsset = firstAsset, asset.identifier == firstAsset.identifier {
            firstBalance = balance
            view?.setFirstAssetBalance(formatter.stringFromDecimal(balance))
        } else if let secondAsset = secondAsset, asset.identifier == secondAsset.identifier {
            secondBalance = balance
            view?.setSecondAssetBalance(formatter.stringFromDecimal(balance))
        }
    }
}
