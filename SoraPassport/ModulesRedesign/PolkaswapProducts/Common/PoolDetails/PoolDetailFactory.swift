import Foundation
import CommonWallet
import SoraUIKit
import UIKit
import XNetworking
import SoraFoundation

protocol DetailViewModelDelegate: AnyObject {
    func networkFeeInfoButtonTapped()
    func lpFeeInfoButtonTapped()
    func minMaxReceivedInfoButtonTapped()
}

protocol DetailViewModelFactoryProtocol {
    func createPoolDetailViewModels(with poolInfo: PoolInfo, apy: SbApyInfo?, viewModel: PoolDetailsViewModelProtocol) -> [DetailViewModel]
    func createSupplyLiquidityViewModels(with baseAssetAmount: Decimal,
                                         targetAssetAmount: Decimal,
                                         pool: PoolInfo?,
                                         apy: SbApyInfo?,
                                         fiatData: [FiatData],
                                         focusedField: FocusedField,
                                         slippageTolerance: Float,
                                         isPresented: Bool,
                                         isEnabled: Bool,
                                         fee: Decimal,
                                         viewModel: LiquidityViewModelProtocol) -> [DetailViewModel]
    
    func createRemoveLiquidityViewModels(with baseAssetAmount: Decimal,
                                         targetAssetAmount: Decimal,
                                         pool: PoolInfo,
                                         apy: SbApyInfo?,
                                         fiatData: [FiatData],
                                         focusedField: FocusedField,
                                         slippageTolerance: Float,
                                         isPresented: Bool,
                                         isEnabled: Bool,
                                         fee: Decimal,
                                         viewModel: LiquidityViewModelProtocol) -> [DetailViewModel]
    
    func createSwapViewModels(fromAsset: AssetInfo,
                              toAsset: AssetInfo,
                              slippage: Decimal,
                              amount: Decimal,
                              quote: SwapQuoteAmounts,
                              direction: SwapVariant,
                              fiatData: [FiatData],
                              swapFee: Decimal,
                              route: String,
                              viewModel: DetailViewModelDelegate) -> [DetailViewModel]
    
    func createSendingAssetViewModels(fee: Decimal,
                                      fiatData: [FiatData],
                                      viewModel: ConfirmSendingViewModelProtocol) -> [DetailViewModel]
}

final class DetailViewModelFactory {
    let assetManager: AssetManagerProtocol

    let formatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()
    
    let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.selectedLocale
        return formatter
    }()
    
    init(assetManager: AssetManagerProtocol) {
        self.assetManager = assetManager
    }
}

extension DetailViewModelFactory: DetailViewModelFactoryProtocol {
    func createPoolDetailViewModels(with poolInfo: PoolInfo, apy: SbApyInfo?, viewModel: PoolDetailsViewModelProtocol) -> [DetailViewModel] {
        var viewModels: [DetailViewModel] = []
        
        let baseAsset = assetManager.assetInfo(for: poolInfo.baseAssetId)
        let targetAsset = assetManager.assetInfo(for: poolInfo.targetAssetId)
        let rewardAsset = assetManager.assetInfo(for: WalletAssetId.pswap.rawValue)
        
        let baseAssetSymbol = baseAsset?.symbol.uppercased() ?? ""
        let targetAssetSymbol = targetAsset?.symbol.uppercased() ?? ""
        
        var rewardAssetImage: WalletImageViewModelProtocol?
        if let iconString = rewardAsset?.icon {
            rewardAssetImage = WalletSvgImageViewModel(svgString: iconString)
        }
        
        if let apyValue = apy?.sbApy {
            let apyText = "\(self.percentFormatter.stringFromDecimal(apyValue.decimalValue * 100) ?? "")% APY"
            let assetAmountText = SoramitsuTextItem(text: apyText,
                                                    fontData: FontType.textBoldS,
                                                    textColor: .fgPrimary,
                                                    alignment: .right)
            let apyDetailsViewModel = DetailViewModel(title: R.string.localizable.poolApyTitle(preferredLanguages: .currentLocale),
                                                      assetAmountText: assetAmountText)
            apyDetailsViewModel.infoHandler = { [weak viewModel] in
                viewModel?.apyInfoButtonTapped()
            }
            viewModels.append(apyDetailsViewModel)
        }

        let rewardText = SoramitsuTextItem(text: rewardAsset?.symbol ?? "",
                                           fontData: FontType.textS,
                                           textColor: .fgPrimary,
                                           alignment: .right)
        let rewardDetailsViewModel = DetailViewModel(title: "Rewards payout in",
                                                     rewardAssetImage: rewardAssetImage,
                                                     assetAmountText: rewardText)
        viewModels.append(rewardDetailsViewModel)
        
        let basePooledAmount = formatter.stringFromDecimal(poolInfo.baseAssetPooledByAccount ?? 0) ?? ""
        let baseAssetPooledText = SoramitsuTextItem(text: "\(basePooledAmount) \(baseAssetSymbol)",
                                                    fontData: FontType.textS,
                                                    textColor: .fgPrimary,
                                                    alignment: .right)
        let basePooledAmountDetailsViewModel = DetailViewModel(title: "Your \(baseAssetSymbol) pooled",
                                                               assetAmountText: baseAssetPooledText)
        viewModels.append(basePooledAmountDetailsViewModel)
        
        let targetPooledAmount = formatter.stringFromDecimal(poolInfo.targetAssetPooledByAccount ?? 0) ?? ""
        let targetAssetPooledText = SoramitsuTextItem(text: "\(targetPooledAmount) \(targetAssetSymbol)",
                                                      fontData: FontType.textS,
                                                      textColor: .fgPrimary,
                                                      alignment: .right)
        let targetPooledAmountDetailsViewModel = DetailViewModel(title: "Your \(targetAssetSymbol) pooled",
                                                                 assetAmountText: targetAssetPooledText)
        viewModels.append(targetPooledAmountDetailsViewModel)
        
        return viewModels
    }
    
    func createSupplyLiquidityViewModels(with baseAssetAmount: Decimal,
                                         targetAssetAmount: Decimal,
                                         pool: PoolInfo?,
                                         apy: SbApyInfo?,
                                         fiatData: [FiatData],
                                         focusedField: FocusedField,
                                         slippageTolerance: Float,
                                         isPresented: Bool,
                                         isEnabled: Bool,
                                         fee: Decimal,
                                         viewModel: LiquidityViewModelProtocol) -> [DetailViewModel] {
        var viewModels: [DetailViewModel] = []
        
        let resultAmount = !isPresented ? targetAssetAmount : calculateAddLiquidityAmount(
            baseAmount: baseAssetAmount,
            reservesFirst: pool?.baseAssetReserves ?? 0,
            reservesSecond: pool?.targetAssetReserves ?? 0,
            focusedField: focusedField)

        let poolShareDecimal = estimateAddingShareOfPool(amount: focusedField == .one ? resultAmount : baseAssetAmount,
                                                      pooled: pool?.targetAssetPooledByAccount ?? 0,
                                                      reserves: pool?.targetAssetReserves ?? 0)

        let poolShareText = NumberFormatter.apy.stringFromDecimal(poolShareDecimal) ?? ""
        let yourPoolShareText = SoramitsuTextItem(text: "\(poolShareText)%",
                                                      fontData: FontType.textS,
                                                      textColor: .fgPrimary,
                                                      alignment: .right)
        let yourPoolShareViewModel = DetailViewModel(title: R.string.localizable.poolShareTitle1(preferredLanguages: .currentLocale),
                                                                 assetAmountText: yourPoolShareText)
        viewModels.append(yourPoolShareViewModel)
        
        if let apy = apy {
            let apyValue = apy.sbApy ?? 0
            let apyText = "\(percentFormatter.stringFromDecimal(apyValue.decimalValue * 100) ?? "")% APY"
            let assetAmountText = SoramitsuTextItem(text: apyText,
                                                    fontData: FontType.textBoldS,
                                                    textColor: .fgPrimary,
                                                    alignment: .right)
            let apyDetailsViewModel = DetailViewModel(title: R.string.localizable.poolApyTitle(preferredLanguages: .currentLocale),
                                                      assetAmountText: assetAmountText)
            apyDetailsViewModel.infoHandler = {
                viewModel.apyInfoButtonTapped()
            }
            viewModels.append(apyDetailsViewModel)
        }
        
        
        let rewardAsset = assetManager.assetInfo(for: WalletAssetId.pswap.rawValue)
        
        var rewardAssetImage: WalletImageViewModelProtocol?
        if let iconString = rewardAsset?.icon {
            rewardAssetImage = WalletSvgImageViewModel(svgString: iconString)
        }
        
        let rewardText = SoramitsuTextItem(text: rewardAsset?.symbol ?? "",
                                           fontData: FontType.textS,
                                           textColor: .fgPrimary,
                                           alignment: .right)
        let rewardDetailsViewModel = DetailViewModel(title: "Rewards payout in",
                                                     rewardAssetImage: rewardAssetImage,
                                                     assetAmountText: rewardText)
        viewModels.append(rewardDetailsViewModel)
        
        let feeText = SoramitsuTextItem(text: "\(NumberFormatter.cryptoAssets.stringFromDecimal(fee) ?? "") XOR",
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let feeAssetId = assetManager.getAssetList()?.first { $0.isFeeAsset }?.assetId
        let usdPrice = (fiatData.first { $0.id == feeAssetId }?.priceUsd ?? 0).decimalValue
        let fiatFeeText = SoramitsuTextItem(text: "$\(NumberFormatter.fiat.stringFromDecimal(usdPrice * fee) ?? "")" ,
                                            fontData: FontType.textBoldXS,
                                            textColor: .fgSecondary,
                                            alignment: .right)
        let feeViewModel = DetailViewModel(title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                                                               assetAmountText: feeText,
                                                               fiatAmountText: fiatFeeText)
        viewModels.append(feeViewModel)
        
        return viewModels
    }
    
    func createRemoveLiquidityViewModels(with baseAssetAmount: Decimal,
                                         targetAssetAmount: Decimal,
                                         pool: PoolInfo,
                                         apy: SbApyInfo?,
                                         fiatData: [FiatData],
                                         focusedField: FocusedField,
                                         slippageTolerance: Float,
                                         isPresented: Bool,
                                         isEnabled: Bool,
                                         fee: Decimal,
                                         viewModel: LiquidityViewModelProtocol) -> [DetailViewModel] {
        let poolShareDecimal = estimateRemoveShareOfPool(amount: targetAssetAmount,
                                                         pooled: pool.targetAssetPooledByAccount ?? 0,
                                                         reserves: pool.targetAssetReserves ?? 0)

        let poolShareText = NumberFormatter.apy.stringFromDecimal(poolShareDecimal) ?? ""
        let yourPoolShareText = SoramitsuTextItem(text: "\(poolShareText)%",
                                                      fontData: FontType.textS,
                                                      textColor: .fgPrimary,
                                                      alignment: .right)
        let yourPoolShareViewModel = DetailViewModel(title: R.string.localizable.poolShareTitle1(preferredLanguages: .currentLocale),
                                                                 assetAmountText: yourPoolShareText)
        
        let apyValue = apy?.sbApy ?? 0
        let apyText = "\(percentFormatter.stringFromDecimal(apyValue.decimalValue * 100) ?? "")% APY"
        let assetAmountText = SoramitsuTextItem(text: apyText,
                                                fontData: FontType.textBoldS,
                                                textColor: .fgPrimary,
                                                alignment: .right)
        let apyDetailsViewModel = DetailViewModel(title: R.string.localizable.poolApyTitle(preferredLanguages: .currentLocale),
                                                  assetAmountText: assetAmountText)
        apyDetailsViewModel.infoHandler = {
            viewModel.apyInfoButtonTapped()
        }
        
        let feeText = SoramitsuTextItem(text: "\(NumberFormatter.cryptoAssets.stringFromDecimal(fee) ?? "") XOR",
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let feeAssetId = assetManager.getAssetList()?.first { $0.isFeeAsset }?.assetId
        let usdPrice = (fiatData.first { $0.id == feeAssetId }?.priceUsd ?? 0).decimalValue
        let fiatFeeText = SoramitsuTextItem(text: "$\(NumberFormatter.fiat.stringFromDecimal(usdPrice * fee) ?? "")" ,
                                            fontData: FontType.textBoldXS,
                                            textColor: .fgSecondary,
                                            alignment: .right)
        let feeViewModel = DetailViewModel(title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                                                               assetAmountText: feeText,
                                                               fiatAmountText: fiatFeeText)
        
        return [ yourPoolShareViewModel,
                 apyDetailsViewModel,
                 feeViewModel]
    }
    
    func createSwapViewModels(fromAsset: AssetInfo,
                              toAsset: AssetInfo,
                              slippage: Decimal,
                              amount: Decimal,
                              quote: SwapQuoteAmounts,
                              direction: SwapVariant,
                              fiatData: [FiatData],
                              swapFee: Decimal,
                              route: String,
                              viewModel: DetailViewModelDelegate) -> [DetailViewModel] {
        let minMaxValue = direction == .desiredInput ? quote.toAmount * (1 - slippage / 100.0) : quote.toAmount * (1 + slippage / 100.0)
        let minMaxReceivedViewModel = minMaxReceivedViewModel(asset: direction == .desiredInput ? toAsset : fromAsset,
                                                              title: direction.title,
                                                              minBuyValue: minMaxValue,
                                                              slippage: slippage,
                                                              fiatData: fiatData,
                                                              viewModel: viewModel)
        
        let fromAssetToAssetAmount = amount / quote.toAmount
        let fromAssetToAssetAmountText = NumberFormatter.cryptoAssets.stringFromDecimal(fromAssetToAssetAmount) ?? ""
        let fromAssetToAssetAmountTextItem = SoramitsuTextItem(text: fromAssetToAssetAmountText,
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let fromAssetToAsset = DetailViewModel(title: "\(fromAsset.symbol) / \(toAsset.symbol)",
                                               assetAmountText: fromAssetToAssetAmountTextItem)
        
        let toAssetFromAssetAmount =  quote.toAmount / amount
        let toAssetFromAssetAmountText = NumberFormatter.cryptoAssets.stringFromDecimal(toAssetFromAssetAmount) ?? ""
        let toAssetFromAssetTextItem = SoramitsuTextItem(text: toAssetFromAssetAmountText,
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let toAssetFromAsset = DetailViewModel(title: "\(toAsset.symbol) / \(fromAsset.symbol)",
                                               assetAmountText: toAssetFromAssetTextItem)
        
        let routeTextItem = SoramitsuTextItem(text: route,
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let routeModel = DetailViewModel(title: R.string.localizable.route(preferredLanguages: .currentLocale),
                                         assetAmountText: routeTextItem)
        
        let feeText = SoramitsuTextItem(text: "\(NumberFormatter.cryptoAssets.stringFromDecimal(swapFee) ?? "") XOR",
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let feeAssetId = assetManager.getAssetList()?.first { $0.isFeeAsset }?.assetId
        let usdPrice = (fiatData.first { $0.id == feeAssetId }?.priceUsd ?? 0).decimalValue
        let fiatFeeText = SoramitsuTextItem(text: "$\(NumberFormatter.fiat.stringFromDecimal(usdPrice * swapFee) ?? "")" ,
                                            fontData: FontType.textBoldXS,
                                            textColor: .fgSecondary,
                                            alignment: .right)
        let feeViewModel = DetailViewModel(title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                                                               assetAmountText: feeText,
                                                               fiatAmountText: fiatFeeText)
        
        feeViewModel.infoHandler = { [weak viewModel] in
            viewModel?.networkFeeInfoButtonTapped()
        }
        
        let lpFeeText = SoramitsuTextItem(text: "\(NumberFormatter.cryptoAssets.stringFromDecimal(quote.lpAmount) ?? "") XOR",
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let fiatLpFeeText = SoramitsuTextItem(text: "$\(NumberFormatter.fiat.stringFromDecimal(usdPrice * quote.lpAmount) ?? "")" ,
                                            fontData: FontType.textBoldXS,
                                            textColor: .fgSecondary,
                                            alignment: .right)
        let lpFeeViewModel = DetailViewModel(title: R.string.localizable.polkaswapLiqudityFee(preferredLanguages: .currentLocale),
                                             assetAmountText: lpFeeText,
                                             fiatAmountText: fiatLpFeeText)
        
        lpFeeViewModel.infoHandler = { [weak viewModel] in
            viewModel?.lpFeeInfoButtonTapped()
        }
        
        return [minMaxReceivedViewModel, fromAssetToAsset, toAssetFromAsset, routeModel, feeViewModel, lpFeeViewModel]
    }
    
    func createSendingAssetViewModels(fee: Decimal,
                                      fiatData: [FiatData],
                                      viewModel: ConfirmSendingViewModelProtocol) -> [DetailViewModel] {
        let feeText = SoramitsuTextItem(text: "\(NumberFormatter.cryptoAssets.stringFromDecimal(fee) ?? "") XOR",
                                        fontData: FontType.textS,
                                        textColor: .fgPrimary,
                                        alignment: .right)
        let feeAssetId = assetManager.getAssetList()?.first { $0.isFeeAsset }?.assetId
        let usdPrice = (fiatData.first { $0.id == feeAssetId }?.priceUsd ?? 0).decimalValue
        let fiatFeeText = SoramitsuTextItem(text: "$\(NumberFormatter.fiat.stringFromDecimal(usdPrice * fee) ?? "")" ,
                                            fontData: FontType.textBoldXS,
                                            textColor: .fgSecondary,
                                            alignment: .right)
        let feeViewModel = DetailViewModel(title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                                                               assetAmountText: feeText,
                                                               fiatAmountText: fiatFeeText)
        feeViewModel.infoHandler = { [weak viewModel] in
            viewModel?.networkFeeInfoButtonTapped()
        }
        return [feeViewModel]
    }
}

private extension DetailViewModelFactory {
    
    func estimateAddingShareOfPool(amount: Decimal, pooled: Decimal, reserves: Decimal) -> Decimal {
        return (pooled + amount) / (amount + reserves) * 100
    }
    
    func calculateAddLiquidityAmount(
        baseAmount: Decimal,
        reservesFirst: Decimal,
        reservesSecond: Decimal,
        focusedField: FocusedField
    ) -> Decimal {
        guard focusedField == .one else {
            return baseAmount * reservesFirst / reservesSecond
        }
        
        return baseAmount * reservesSecond / reservesFirst
    }
    
    func estimateRemoveShareOfPool(amount: Decimal, pooled: Decimal, reserves: Decimal) -> Decimal {
        if (amount - reserves) == 0 {
            return 0
        }
        return abs((pooled - amount) / (amount - reserves) * 100) 
    }
    
    func minMaxReceivedViewModel(asset: AssetInfo,
                                 title: String,
                                 minBuyValue: Decimal,
                                 slippage: Decimal,
                                 fiatData: [FiatData],
                                 viewModel: DetailViewModelDelegate) -> DetailViewModel {
        let minBuyToken = asset.symbol
        let minBuyText = NumberFormatter.cryptoAssets.stringFromDecimal(minBuyValue) ?? ""
        let minBuyValueText = SoramitsuTextItem(text: "\(minBuyText) \(minBuyToken)",
                                                fontData: FontType.textS,
                                                textColor: .fgPrimary,
                                                alignment: .right)
        
        let minBuyUsdPrice = (fiatData.first { $0.id == asset.identifier }?.priceUsd ?? 0).decimalValue
        let minBuyFiatText = SoramitsuTextItem(text: "~$\(NumberFormatter.fiat.stringFromDecimal(minBuyUsdPrice * minBuyValue) ?? "")" ,
                                               fontData: FontType.textBoldXS,
                                               textColor: .fgSecondary,
                                               alignment: .right)
        
        let minMaxReceivedViewModel = DetailViewModel(title: title,
                                                      assetAmountText: minBuyValueText,
                                                      fiatAmountText: minBuyFiatText)
        
        minMaxReceivedViewModel.infoHandler = { [weak viewModel] in
            viewModel?.minMaxReceivedInfoButtonTapped()
        }
        
        return minMaxReceivedViewModel
    }
}

