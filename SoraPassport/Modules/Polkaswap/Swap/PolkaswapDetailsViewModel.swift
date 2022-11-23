import Foundation

class PolkaswapDetailsViewModel {
    let firstToSecondAssetRateTitle: String
    let secondToFirstAssetRateTitle: String
    let minBuyOrMaxSellTitle: String
    let lpFeeTitle: String
    let networkFeeTitle: String

    let firstToSecondAssetRateValue: Decimal
    let secondToFirstAssetRateValue: Decimal
    let minBuyOrMaxSellValue: Decimal
    let lpFeeValue: Decimal
    let networkFeeValue: Decimal
    
    let minBuyOrMaxSellToken: String
    let minBuyOrMaxSellHelpTitle: String
    let minBuyOrMaxSellHelpText: String

    init(firstToSecondAssetRateTitle: String,
         secondToFirstAssetRateTitle: String,
         minBuyOrMaxSellTitle: String,
         lpFeeTitle: String,
         networkFeeTitle: String,
         firstToSecondAssetRateValue: Decimal,
         secondToFirstAssetRateValue: Decimal,
         minBuyOrMaxSellValue: Decimal,
         lpFeeValue: Decimal,
         networkFeeValue: Decimal,
         minBuyOrMaxSellToken: String,
         minBuyOrMaxSellHelpTitle: String,
         minBuyOrMaxSellHelpText: String
    ) {
        self.firstToSecondAssetRateTitle  = firstToSecondAssetRateTitle
        self.secondToFirstAssetRateTitle  = secondToFirstAssetRateTitle
        self.minBuyOrMaxSellTitle         = minBuyOrMaxSellTitle
        self.lpFeeTitle                   = lpFeeTitle
        self.networkFeeTitle              = networkFeeTitle
        self.firstToSecondAssetRateValue  = firstToSecondAssetRateValue
        self.secondToFirstAssetRateValue  = secondToFirstAssetRateValue
        self.minBuyOrMaxSellValue         = minBuyOrMaxSellValue
        self.lpFeeValue                   = lpFeeValue
        self.networkFeeValue              = networkFeeValue
        self.minBuyOrMaxSellToken         = minBuyOrMaxSellToken
        self.minBuyOrMaxSellHelpTitle     = minBuyOrMaxSellTitle
        self.minBuyOrMaxSellHelpText      = minBuyOrMaxSellHelpText
    }
}
