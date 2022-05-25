import Foundation

class PoolDetailsViewModel {
    let firstAsset: AssetInfo
    let firstAssetValue: String
    let secondAsset: AssetInfo
    let secondAssetValue: String
    let shareOfPoolValue: Decimal

    let directExchangeRateTitle: String
    let directExchangeRateValue: Decimal
    let inversedExchangeRateTitle: String
    let inversedExchangeRateValue: Decimal
    let sbApyValue: Decimal
    let networkFeeValue: Decimal

    init(
        firstAsset: AssetInfo,
        firstAssetValue: String,
        secondAsset: AssetInfo,
        secondAssetValue: String,
        shareOfPoolValue: Decimal,
        directExchangeRateTitle: String,
        directExchangeRateValue: Decimal,
        inversedExchangeRateTitle: String,
        inversedExchangeRateValue: Decimal,
        sbApyValue: Decimal,
        networkFeeValue: Decimal
    ) {
        self.firstAsset = firstAsset
        self.firstAssetValue = firstAssetValue
        self.secondAsset = secondAsset
        self.secondAssetValue = secondAssetValue
        self.shareOfPoolValue = shareOfPoolValue
        self.directExchangeRateTitle = directExchangeRateTitle
        self.directExchangeRateValue = directExchangeRateValue
        self.inversedExchangeRateTitle = inversedExchangeRateTitle
        self.inversedExchangeRateValue = inversedExchangeRateValue
        self.sbApyValue = sbApyValue
        self.networkFeeValue = networkFeeValue
    }
}
