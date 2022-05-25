import Foundation

class PolkaswapDetailsViewModel {
    let directExchangeRateTitle: String
    let inversedExchangeRateTitle: String
    let minReceivedTitle: String
    let lpFeeTitle: String
    let networkFeeTitle: String

    let directExchangeRateValue: Decimal
    let inversedExchangeRateValue: Decimal
    let minReceivedValue: Decimal
    let lpFeeValue: Decimal
    let networkFeeValue: Decimal
    
    let minMaxToken: String
    let minMaxAlertTitle: String
    let minMaxAlertText: String

    init(directExchangeRateTitle: String,
         inversedExchangeRateTitle: String,
         minReceivedTitle: String,
         lpFeeTitle: String,
         networkFeeTitle: String,
         directExchangeRateValue: Decimal,
         inversedExchangeRateValue: Decimal,
         minReceivedTitleValue: Decimal,
         lpFeeTitleValue: Decimal,
         networkFeeTitleValue: Decimal,
         minMaxToken: String,
         minMaxAlertTitle: String,
         minMaxAlertText: String
    ) {
        self.directExchangeRateTitle    = directExchangeRateTitle
        self.inversedExchangeRateTitle  = inversedExchangeRateTitle
        self.minReceivedTitle           = minReceivedTitle
        self.lpFeeTitle                 = lpFeeTitle
        self.networkFeeTitle            = networkFeeTitle
        self.directExchangeRateValue    = directExchangeRateValue
        self.inversedExchangeRateValue  = inversedExchangeRateValue
        self.minReceivedValue           = minReceivedTitleValue
        self.lpFeeValue                 = lpFeeTitleValue
        self.networkFeeValue            = networkFeeTitleValue
        self.minMaxToken                = minMaxToken
        self.minMaxAlertTitle           = minMaxAlertTitle
        self.minMaxAlertText            = minMaxAlertText
    }
}
