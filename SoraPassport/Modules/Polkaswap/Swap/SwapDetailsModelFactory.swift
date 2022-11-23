import Foundation

protocol SwapDetailsModelFactoryProtocol {
    func createDetailsViewModel() -> PolkaswapDetailsViewModel
}

class SwapDetailsModelFactory: SwapDetailsModelFactoryProtocol {
    let fromAsset: AssetInfo
    let toAsset: AssetInfo
    let slippage: Decimal
    let languages: [String]?
    let quote: SwapQuoteAmounts
    let direction: SwapVariant
    let swapFee: Decimal

    init(fromAsset: AssetInfo, toAsset: AssetInfo, slippage: Decimal, languages: [String]?, quote: SwapQuoteAmounts, direction: SwapVariant, swapFee: Decimal) {
        self.fromAsset = fromAsset
        self.toAsset = toAsset
        self.slippage = slippage
        self.languages = languages
        self.quote = quote
        self.direction = direction
        self.swapFee = swapFee
    }

    func createDetailsViewModel() -> PolkaswapDetailsViewModel {
        switch direction {
        case .desiredInput:
            return createDirectDetailsViewModel()
        case .desiredOutput:
            return createInversedDetailsViewModel()
        }
    }

    func createDirectDetailsViewModel() -> PolkaswapDetailsViewModel {
        let minBuyTitle = R.string.localizable.polkaswapMinimumReceived(preferredLanguages: languages).uppercased()
        let minBuyToken = toAsset.symbol
        let minBuyValue = quote.toAmount * (1 - slippage / 100.0)
        let minBuyHelpTitle = R.string.localizable.polkaswapMinimumReceived(preferredLanguages: languages)
        let minBuyHelpText = R.string.localizable.polkaswapMinimumReceivedInfo(preferredLanguages: languages)

        return PolkaswapDetailsViewModel(firstToSecondAssetRateTitle: directSwapAssetRateTitle(),
                                         secondToFirstAssetRateTitle: inversedSwapAssetRateTitle(),
                                         minBuyOrMaxSellTitle: minBuyTitle,
                                         lpFeeTitle: lpFeeTitle(),
                                         networkFeeTitle: networkFeeTitle(),
                                         firstToSecondAssetRateValue: directSwapAssetRateValue(),
                                         secondToFirstAssetRateValue: inversedSwapAssetRateValue(),
                                         minBuyOrMaxSellValue: minBuyValue,
                                         lpFeeValue: lpFeeValue(),
                                         networkFeeValue: swapFee,
                                         minBuyOrMaxSellToken: minBuyToken,
                                         minBuyOrMaxSellHelpTitle: minBuyHelpTitle,
                                         minBuyOrMaxSellHelpText: minBuyHelpText)
    }

    func createInversedDetailsViewModel() -> PolkaswapDetailsViewModel {
        let maxSellTitle = R.string.localizable.polkaswapMaximumSold(preferredLanguages: languages).uppercased()
        let maxSellToken = fromAsset.symbol
        let maxSellValue = quote.toAmount * (1 + slippage / 100.0)
        let maxSellHelpTitle = R.string.localizable.polkaswapMaximumSold(preferredLanguages: languages)
        let maxSellHelpText = R.string.localizable.polkaswapMaximumSoldInfo(preferredLanguages: languages)

        return PolkaswapDetailsViewModel(firstToSecondAssetRateTitle: directSwapAssetRateTitle(),
                                         secondToFirstAssetRateTitle: inversedSwapAssetRateTitle(),
                                         minBuyOrMaxSellTitle: maxSellTitle,
                                         lpFeeTitle: lpFeeTitle(),
                                         networkFeeTitle: networkFeeTitle(),
                                         firstToSecondAssetRateValue: inversedSwapAssetRateValue(),
                                         secondToFirstAssetRateValue: directSwapAssetRateValue(),
                                         minBuyOrMaxSellValue: maxSellValue,
                                         lpFeeValue: lpFeeValue(),
                                         networkFeeValue: swapFee,
                                         minBuyOrMaxSellToken: maxSellToken,
                                         minBuyOrMaxSellHelpTitle: maxSellHelpTitle,
                                         minBuyOrMaxSellHelpText: maxSellHelpText)
    }

    func directSwapAssetRateTitle() -> String {
        return fromAsset.symbol + "/" + toAsset.symbol
    }

    func inversedSwapAssetRateTitle() -> String {
        toAsset.symbol + "/" + fromAsset.symbol
    }

    func lpFeeTitle() -> String {
        R.string.localizable.polkaswapLiqudityFee(preferredLanguages: languages).uppercased()
    }

    func networkFeeTitle() -> String {
        R.string.localizable.polkaswapNetworkFee(preferredLanguages: languages).uppercased()
    }

    func directSwapAssetRateValue() -> Decimal {
        quote.fromAmount / quote.toAmount
    }

    func inversedSwapAssetRateValue() -> Decimal {
        quote.toAmount / quote.fromAmount
    }

    func lpFeeValue() -> Decimal {
        quote.lpAmount
    }
}
