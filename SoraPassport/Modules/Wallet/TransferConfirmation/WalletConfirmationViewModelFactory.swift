import Foundation
import CommonWallet
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class WalletConfirmationViewModelFactory {
    private let iconGenerator = PolkadotIconGenerator()
    weak var commandFactory: WalletCommandFactoryProtocol?
    
    let assets: [WalletAsset]
    let assetManager: AssetManagerProtocol
    let amountFormatterFactory: AmountFormatterFactoryProtocol
    
    init(assets: [WalletAsset], assetManager: AssetManagerProtocol, amountFormatterFactory: AmountFormatterFactoryProtocol) {
        self.assets = assets
        self.assetManager = assetManager
        self.amountFormatterFactory = amountFormatterFactory
    }

    func populateAsset(in viewModelList: inout [WalletFormViewBindingProtocol],
                       payload: ConfirmationPayload,
                       locale: Locale) {
        let headerTitle = R.string.localizable.transactionToken(preferredLanguages: locale.rLanguages)

        guard let asset = self.assets.first(where: {$0.identifier == payload.transferInfo.asset}),
              let context = payload.transferInfo.context else {
                  return
              }
        let symbolViewModel: WalletImageViewModelProtocol?

        if  let assetInfo = assetManager.assetInfo(for: asset.identifier),
            let iconString = assetInfo.icon {
            symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            symbolViewModel = nil
        }

        let balanceData = BalanceContext(context: context)
        let title: String =  asset.name.value(for: locale)
        let subtitle: String = asset.identifier

        let formatter = amountFormatterFactory.createDisplayFormatter(for: asset, maxPrecision: 8)

        let details = formatter.value(for: locale).stringFromDecimal(balanceData.available) ?? ""

        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)
        
        let tokenViewModel = WalletTokenViewModel(
            state: selectedState,
            header: headerTitle,
            title: title,
            subtitle: subtitle,
            details: details,
            icon: nil,
            iconViewModel: symbolViewModel
        )

        viewModelList.append(WalletFormSeparatedViewModel(content: tokenViewModel, borderType: [.bottom]))
    }

    func populateReceiver(in viewModelList: inout [WalletFormViewBindingProtocol],
                          payload: ConfirmationPayload,
                          locale: Locale) {
        
        let name = payload.receiverName
        let title = R.string.localizable.commonRecipient(preferredLanguages: locale.rLanguages)
        let icon = try? iconGenerator.generateFromAddress(payload.receiverName)
            .imageWithFillColor(.white,
                                size: CGSize(width: 24.0, height: 24.0),
                                contentScale: UIScreen.main.scale)
        let command = SendToContactCommand(nextAction: {
            UIPasteboard.general.string = name
            let success = ModalAlertFactory.createSuccessAlert(R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages))
            try? self.commandFactory?.preparePresentationCommand(for: success).execute()
        })

        let viewModel = WalletSoraReceiverViewModel(text: name, icon: icon, title: title, command: command)
        
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }

    func populateSendingAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                               payload: ConfirmationPayload,
                               locale: Locale) {
        guard let asset = assets.first(where: { $0.identifier == payload.transferInfo.asset }) else {
            return
        }

        let formatter = amountFormatterFactory.createDisplayFormatter(for: asset)
        
        let decimalAmount = payload.transferInfo.amount.decimalValue
        
        guard let amount = formatter.value(for: locale).stringFromDecimal(decimalAmount) else {
            return
        }
        
        let title = R.string.localizable.transactionAmountTitle(preferredLanguages: locale.rLanguages)
        let viewModel = WalletFormSpentAmountModel(title: title,
                                                   amount: amount)
        viewModelList.append(viewModel)
    }
    
    func populateMainFeeAmount(in viewModelList: inout [WalletFormViewBindingProtocol],
                               payload: ConfirmationPayload,
                               locale: Locale) {
        guard let asset = assets.first(where: { $0.isFeeAsset }) else {
            return
        }

        let formatter = amountFormatterFactory.createTokenFormatter(for: asset).value(for: locale)

        for fee in payload.transferInfo.fees
        where fee.feeDescription.identifier == asset.identifier {

            let decimalAmount = fee.value.decimalValue

            guard let amount = formatter.stringFromDecimal(decimalAmount) else {
                return
            }

            let lpFee = fee.feeDescription.context?["type"] == TransactionType.swap.rawValue
            let title = lpFee ?
                R.string.localizable.polkaswapLiqudityFee(preferredLanguages: locale.rLanguages) :
                R.string.localizable.polkaswapNetworkFee(preferredLanguages: locale.rLanguages)

            let viewModel = FeeViewModel(title: title, details: amount, isLoading: false, allowsEditing: false)

            viewModelList.append(viewModel)
        }
    }

    func populateSwapHeader(in viewModelList: inout [WalletFormViewBindingProtocol],
                            payload: ConfirmationPayload,
                            locale: Locale) {
        let formatter = amountFormatterFactory.createDisplayFormatter(for: WalletAsset.dummyAsset)

        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)

        let transferInfo = payload.transferInfo
        let sourceAsset = transferInfo.asset
        let targetAsset = transferInfo.destination
        
        guard transferInfo.type == .swap,
              let sourceAssetInfo = assetManager.assetInfo(for: sourceAsset),
              let targetAssetInfo = assetManager.assetInfo(for: targetAsset),
              let context = transferInfo.context,
              let desire = SwapVariant(rawValue: context[TransactionContextKeys.desire] ?? ""),
              let estimated =  context[TransactionContextKeys.estimatedAmount],
              let estimatedAmount = AmountDecimal(string: estimated),
              let minMax = context[TransactionContextKeys.minMaxValue],
              let minMaxAmount = AmountDecimal(string: minMax)  else {
                  return
              }

        let sourceSymbolViewModel: WalletImageViewModelProtocol?
        if  let iconString = sourceAssetInfo.icon {
            sourceSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            sourceSymbolViewModel = nil
            
        }

        let sdetails = payload.transferInfo.amount

        let sourceVM = WalletTokenViewModel(state: selectedState,
                                            header: "",
                                            title: sourceAssetInfo.symbol,
                                            subtitle: "",
                                            details: formatter.value(for: locale).stringFromDecimal(sdetails.decimalValue) ?? "-",
                                            icon: nil,
                                            iconViewModel: sourceSymbolViewModel)
        let targetSymbolViewModel: WalletImageViewModelProtocol?
        if let iconString = targetAssetInfo.icon {
            targetSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            targetSymbolViewModel = nil
        }

        let targetVM = WalletTokenViewModel(state: selectedState,
                                            header: "",
                                            title: targetAssetInfo.symbol,
                                            subtitle: "",
                                            details: formatter.value(for: locale).stringFromDecimal(estimatedAmount.decimalValue) ?? "-",
                                            icon: nil,
                                            iconViewModel: targetSymbolViewModel)

        let estimationText =
            desire == .desiredInput ?
                R.string.localizable.polkaswapOutputEstimated(
                    formatter.value(for: locale)
                        .stringFromDecimal(minMaxAmount.decimalValue) ?? "-",
                    preferredLanguages: locale.rLanguages)
            :
                R.string.localizable.polkaswapInputEstimated(
                    formatter.value(for: locale)
                        .stringFromDecimal(minMaxAmount.decimalValue) ?? "-",
                    preferredLanguages: locale.rLanguages)

        let viewModel = SoraSwapHeaderViewModel(sourceAsset: sourceVM,
                                                targetAsset: targetVM,
                                                estimate: estimationText)

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }

    func populateSwapValues(in viewModelList: inout [WalletFormViewBindingProtocol],
                            payload: ConfirmationPayload,
                            locale: Locale) {
        let transferInfo = payload.transferInfo
        let sourceAsset = transferInfo.asset
        let targetAsset = transferInfo.destination

        guard transferInfo.type == .swap,
              let sourceAssetInfo = assetManager.assetInfo(for: sourceAsset),
              let targetAssetInfo = assetManager.assetInfo(for: targetAsset),
              let context = transferInfo.context,
              let desire = SwapVariant(rawValue: context[TransactionContextKeys.desire] ?? ""),
              let estimated =  context[TransactionContextKeys.estimatedAmount],
              let estimatedAmount = AmountDecimal(string: estimated),
              let minMax = context[TransactionContextKeys.minMaxValue],
              let minMaxAmount = AmountDecimal(string: minMax) else {
                  return
              }

        let formatter = amountFormatterFactory.createDisplayFormatter(for: WalletAsset.dummyAsset)

        let title1 = sourceAssetInfo.symbol + " / " + targetAssetInfo.symbol
        let amount1 = transferInfo.amount.decimalValue / estimatedAmount.decimalValue
        let details1 = formatter.value(for: locale).stringFromDecimal(amount1) ?? "-"
        let viewModel1 = FeeViewModel(title: title1, details: details1, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel1, borderType: [.bottom]))

        let title2 = targetAssetInfo.symbol + " / " + sourceAssetInfo.symbol
        let amount2 = estimatedAmount.decimalValue / transferInfo.amount.decimalValue
        let details2 = formatter.value(for: locale).stringFromDecimal(amount2) ?? "-"
        let viewModel2 = FeeViewModel(title: title2, details: details2, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel2, borderType: [.bottom]))

        let viewModelMinMax: FeeViewModel
        switch desire {
        case .desiredInput:
            let titleMin = R.string.localizable.polkaswapMinimumReceived(preferredLanguages: locale.rLanguages)
            let amountMin = minMaxAmount.decimalValue
            let detailsMin = formatter.value(for: locale).stringFromDecimal(amountMin) ?? "-"
            viewModelMinMax = FeeViewModel(title: titleMin, details: detailsMin, isLoading: false, allowsEditing: false)
        case .desiredOutput:
            let titleMin = R.string.localizable.polkaswapMaximumSold(preferredLanguages: locale.rLanguages)
            let amountMin = minMaxAmount.decimalValue
            let detailsMin = formatter.value(for: locale).stringFromDecimal(amountMin) ?? "-"
            viewModelMinMax = FeeViewModel(title: titleMin, details: detailsMin, isLoading: false, allowsEditing: false)
        }

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModelMinMax, borderType: [.bottom]))
    }

    func populateAddLiquidityValues(in viewModelList: inout [WalletFormViewBindingProtocol],
                            payload: ConfirmationPayload,
                            locale: Locale) {
        let transferInfo = payload.transferInfo
        let sourceAsset = transferInfo.source
        let targetAsset = transferInfo.destination

        guard
              let firstAssetInfo = assetManager.assetInfo(for: sourceAsset),
              let secondAssetInfo = assetManager.assetInfo(for: targetAsset),
              let context = transferInfo.context,
              let firstValue = context[TransactionContextKeys.firstAssetAmount],
              let secondValue = context[TransactionContextKeys.secondAssetAmount],
              let firstAmount = AmountDecimal(string: firstValue),
              let secondAmount = AmountDecimal(string: secondValue),
              let apyValue = context[TransactionContextKeys.sbApy],
              let slippage = context[TransactionContextKeys.slippage],
              let directPriceValue = context[TransactionContextKeys.directExchangeRateValue],
              let inversedPriceValue = context[TransactionContextKeys.inversedExchangeRateValue],
              let directPrice = AmountDecimal(string: directPriceValue),
              let inversedPrice = AmountDecimal(string: inversedPriceValue)
        else { return }

        let formatter = amountFormatterFactory.createDisplayFormatter(for: WalletAsset.dummyAsset)
        let percentageFormatter = amountFormatterFactory.createPercentageFormatter(maxPrecision: 8)

        let title1 =  R.string.localizable.commonDepositSymbol(firstAssetInfo.symbol, preferredLanguages: locale.rLanguages).uppercased()

        let details1 = formatter.value(for: locale).stringFromDecimal(firstAmount.decimalValue) ?? "-"
        let viewModel1 = FeeViewModel(title: title1, details: details1, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel1, borderType: [.bottom]))

        let title2 = R.string.localizable.commonDepositSymbol(secondAssetInfo.symbol, preferredLanguages: locale.rLanguages).uppercased()
        let details2 = formatter.value(for: locale).stringFromDecimal(secondAmount.decimalValue) ?? "-"
        let viewModel2 = FeeViewModel(title: title2, details: details2, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel2, borderType: [.bottom]))

        let price1 = R.string.localizable.polkaswapPriceForOne(preferredLanguages: locale.rLanguages).uppercased() + " " + firstAssetInfo.symbol
        let priceDetails1 = (formatter.value(for: locale).stringFromDecimal(directPrice.decimalValue) ?? "-") + " " + secondAssetInfo.symbol
        let viewModel3 = FeeViewModel(title: price1, details: priceDetails1, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel3, borderType: [.bottom]))

        let price2 = R.string.localizable.polkaswapPriceForOne(preferredLanguages: locale.rLanguages).uppercased() + " " + secondAssetInfo.symbol
        let priceDetails2 = (formatter.value(for: locale).stringFromDecimal(inversedPrice.decimalValue) ?? "-") + " " + firstAssetInfo.symbol
        let viewModel4 = FeeViewModel(title: price2, details: priceDetails2, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel4, borderType: [.bottom]))

        let amount = AmountDecimal(string: apyValue)?.decimalValue ?? 0
        if amount > 0 {
            let apy = R.string.localizable.poolApyTitle(preferredLanguages: locale.rLanguages).uppercased()
            let amount = AmountDecimal(string: apyValue)?.decimalValue ?? 0
            let apyDetails = percentageFormatter.value(for: locale).stringFromDecimal(amount) ?? "-"
            let viewModel5 = FeeViewModel(title: apy, details: apyDetails, isLoading: false, allowsEditing: false)
            viewModelList.append(WalletFormSeparatedViewModel(content: viewModel5, borderType: [.bottom]))
        }
    }

    func populateRemoveLiquidityValues(in viewModelList: inout [WalletFormViewBindingProtocol],
                            payload: ConfirmationPayload,
                            locale: Locale) {
        let transferInfo = payload.transferInfo
        let sourceAsset = transferInfo.source
        let targetAsset = transferInfo.destination

        guard
              let firstAssetInfo = assetManager.assetInfo(for: sourceAsset),
              let secondAssetInfo = assetManager.assetInfo(for: targetAsset),
              let context = transferInfo.context,
              let firstAmount = context[TransactionContextKeys.firstAssetAmount],
              let secondAmount = context[TransactionContextKeys.secondAssetAmount],
              let directExchangeRateValue = context[TransactionContextKeys.directExchangeRateValue],
              let inversedExchangeRateValue = context[TransactionContextKeys.inversedExchangeRateValue],
              let poolShare = context[TransactionContextKeys.shareOfPool],
              let slippage = context[TransactionContextKeys.slippage]
        else { return }

        let formatter = amountFormatterFactory.createDisplayFormatter(for: WalletAsset.dummyAsset)

        let title1 = firstAssetInfo.symbol + " / " + secondAssetInfo.symbol
        let details1 = directExchangeRateValue//formatter.value(for: locale).stringFromDecimal(amount1) ?? "-"
        let viewModel1 = FeeViewModel(title: title1, details: details1, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel1, borderType: [.bottom]))

        let title2 = secondAssetInfo.symbol + " / " + firstAssetInfo.symbol
        let details2 = inversedExchangeRateValue//formatter.value(for: locale).stringFromDecimal(amount2) ?? "-"
        let viewModel2 = FeeViewModel(title: title2, details: details2, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel2, borderType: [.bottom]))

        let titleShare = R.string.localizable.poolShareAfterTx(preferredLanguages: locale.rLanguages).uppercased()
        let detailsShare = poolShare//formatter.value(for: locale).stringFromDecimal(amount2) ?? "-"
        let viewModel3 = FeeViewModel(title: titleShare, details: detailsShare, isLoading: false, allowsEditing: false)
        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel3, borderType: [.bottom]))
    }

    func populateRemoveLiquidityHeader(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        let transferInfo = payload.transferInfo
        let sourceAsset = transferInfo.source
        let targetAsset = transferInfo.destination

        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)

        guard
              let firstAssetInfo = assetManager.assetInfo(for: sourceAsset),
              let secondAssetInfo = assetManager.assetInfo(for: targetAsset),
              let context = transferInfo.context,
              let firstAmount = context[TransactionContextKeys.firstAssetAmount],
              let secondAmount = context[TransactionContextKeys.secondAssetAmount],
              let slippage = context[TransactionContextKeys.slippage]
        else { return }

        let sourceSymbolViewModel: WalletImageViewModelProtocol?
        if  let iconString = firstAssetInfo.icon {
            sourceSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            sourceSymbolViewModel = nil

        }

        let sdetails = payload.transferInfo.amount

        let sourceVM = WalletTokenViewModel(state: selectedState,
                                            header: "",
                                            title: firstAssetInfo.symbol,
                                            subtitle: "",
                                            details: firstAmount,
                                            icon: nil,
                                            iconViewModel: sourceSymbolViewModel)
        let targetSymbolViewModel: WalletImageViewModelProtocol?
        if let iconString = secondAssetInfo.icon {
            targetSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            targetSymbolViewModel = nil
        }

        let targetVM = WalletTokenViewModel(state: selectedState,
                                            header: "",
                                            title: secondAssetInfo.symbol,
                                            subtitle: "",
                                            details: secondAmount,
                                            icon: nil,
                                            iconViewModel: targetSymbolViewModel)

        let estimationText = R.string.localizable.addLiquidityPoolShareDescription(slippage, preferredLanguages: locale.rLanguages)

        let viewModel = SoraRemoveLiquidityHeaderViewModel(sourceAsset: sourceVM,
                                                targetAsset: targetVM,
                                                        estimate: estimationText)

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }
    
    func populateAddLiquidityHeader(
        in viewModelList: inout [WalletFormViewBindingProtocol],
        payload: ConfirmationPayload,
        locale: Locale
    ) {
        let transferInfo = payload.transferInfo
        let sourceAsset = transferInfo.source
        let targetAsset = transferInfo.destination
        let selectedState = SelectedAssetState(isSelecting: false, canSelect: false)
        let percentFormatter = AmountFormatterFactory().createPercentageFormatter(maxPrecision: 8).value(for: locale)

        guard 
              let firstAssetInfo = assetManager.assetInfo(for: sourceAsset),
              let secondAssetInfo = assetManager.assetInfo(for: targetAsset),
              let context = transferInfo.context,
              let firstAmount = context[TransactionContextKeys.firstAssetAmount],
              let secondAmount = context[TransactionContextKeys.secondAssetAmount],
              let poolShare = context[TransactionContextKeys.shareOfPool],
              let slippage = context[TransactionContextKeys.slippage]
        else { return }

        let sourceSymbolViewModel: WalletImageViewModelProtocol?
        if  let iconString = firstAssetInfo.icon {
            sourceSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            sourceSymbolViewModel = nil

        }

        let sdetails = payload.transferInfo.amount

        let sourceVM = WalletTokenViewModel(state: selectedState,
                                            header: "",
                                            title: firstAssetInfo.symbol,
                                            subtitle: "",
                                            details: "-",
                                            icon: nil,
                                            iconViewModel: sourceSymbolViewModel)
        let targetSymbolViewModel: WalletImageViewModelProtocol?
        if let iconString = secondAssetInfo.icon {
            targetSymbolViewModel = WalletSvgImageViewModel(svgString: iconString)
        } else {
            targetSymbolViewModel = nil
        }

        let targetVM = WalletTokenViewModel(state: selectedState,
                                            header: "",
                                            title: secondAssetInfo.symbol,
                                            subtitle: "",
                                            details: "-",
                                            icon: nil,
                                            iconViewModel: targetSymbolViewModel)

        let poolShareValue = Decimal(string: poolShare, locale: locale)
        let poolShareText = percentFormatter.stringFromDecimal(poolShareValue ?? 0) ?? "?"
        let poolText = R.string.localizable.addLiquidityPoolShareTitle(preferredLanguages: locale.rLanguages) + "\n" + poolShareText
        let poolDecorated = poolText.decoratedWith( [.font: UIFont.styled(for: .paragraph1),
                                                     .foregroundColor: R.color.neumorphism.textDark()!,
                                                     ], adding:  [.font: UIFont.styled(for: .display1),
                                                                  .foregroundColor: R.color.neumorphism.textDark()!,
                                                                ], to: [poolShareText])

        let estimationText = R.string.localizable.addLiquidityPoolShareDescription(slippage, preferredLanguages: locale.rLanguages)

        let viewModel = SoraAddLiquidityHeaderViewModel(sourceAsset: sourceVM,
                                                targetAsset: targetVM,
                                                        estimate: estimationText, poolShare: poolDecorated)

        viewModelList.append(WalletFormSeparatedViewModel(content: viewModel, borderType: [.bottom]))
    }
}

extension WalletConfirmationViewModelFactory: TransferConfirmationViewModelFactoryOverriding {
    func createViewModelsFromPayload(_ payload: ConfirmationPayload,
                                     locale: Locale) -> [WalletFormViewBindingProtocol]? {
        var viewModelList: [WalletFormViewBindingProtocol] = []
        let locale = LocalizationManager.shared.selectedLocale

        switch payload.transferInfo.type {
        case .swap:
            populateSwapHeader(in: &viewModelList, payload: payload, locale: locale)
            populateSwapValues(in: &viewModelList, payload: payload, locale: locale)
            populateMainFeeAmount(in: &viewModelList, payload: payload, locale: locale)
        case .liquidityAdd, .liquidityAddToExistingPoolFirstTime, .liquidityAddNewPool:
            populateAddLiquidityHeader(in: &viewModelList, payload: payload, locale: locale)
            populateAddLiquidityValues(in: &viewModelList, payload: payload, locale: locale)
        case .liquidityRemoval:
            populateRemoveLiquidityHeader(in: &viewModelList, payload: payload, locale: locale)
            populateRemoveLiquidityValues(in: &viewModelList, payload: payload, locale: locale)
        default:
            populateAsset(in: &viewModelList, payload: payload, locale: locale)
            populateReceiver(in: &viewModelList, payload: payload, locale: locale)
            populateSendingAmount(in: &viewModelList, payload: payload, locale: locale)
            populateMainFeeAmount(in: &viewModelList, payload: payload, locale: locale)
        }
        return viewModelList
    }

    func createAccessoryViewModelFromPayload(_ payload: ConfirmationPayload,
                                             locale: Locale) -> AccessoryViewModelProtocol? {
        let locale = LocalizationManager.shared.selectedLocale
        let title: String
        switch payload.transferInfo.type {
        case .swap:
            title = R.string.localizable.polkaswapConfirmSwap(preferredLanguages: locale.rLanguages)
        case .outgoing:
            title = R.string.localizable.transactionConfirm(preferredLanguages: locale.rLanguages)
        case .liquidityAdd:
            title = R.string.localizable.addLiquidityConfirmationTitle(preferredLanguages: locale.rLanguages)
        case .liquidityRemoval:
            title = R.string.localizable.removePoolConfirmationTitle(preferredLanguages: locale.rLanguages)
        default:
            title = R.string.localizable.commonConfirm(preferredLanguages: locale.rLanguages)
        }
        return AccessoryViewModel(title: "",
                                  action: title.uppercased())
    }
}
