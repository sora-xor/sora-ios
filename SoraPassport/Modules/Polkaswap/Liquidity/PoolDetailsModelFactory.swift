import Foundation

protocol PoolDetailsModelFactoryProtocol {
    func createDetailsViewModel(pool: PoolDetails?) -> PoolDetailsViewModel?
}

class PoolDetailsModelFactory: PoolDetailsModelFactoryProtocol {
    
    let firstAsset: AssetInfo
    let secondAsset: AssetInfo
    let firstAmount: Decimal
    let secondAmount: Decimal
    let languages: [String]?
    let fee: Decimal

    init(firstAsset: AssetInfo, secondAsset: AssetInfo, firstAmount: Decimal, secondAmount: Decimal, languages: [String]?, fee: Decimal) {
        self.firstAsset = firstAsset
        self.secondAsset = secondAsset
        self.firstAmount = firstAmount
        self.secondAmount = secondAmount
        self.languages = languages
        self.fee = fee
    }

    func createDetailsViewModel(pool: PoolDetails?) -> PoolDetailsViewModel? {
        if let pool = pool {
            return createDetailsViewModelForExistingPool(pool)
        } else {
            return createDetailsViewModelForNewPool()
        }
    }

    func createDetailsViewModelForExistingPool(_ pool: PoolDetails) -> PoolDetailsViewModel? {
        guard pool.targetAssetPooledTotal > 0, pool.baseAssetPooledTotal > 0 else {
            return nil
        }

        let sbApyValue = Decimal(pool.sbAPYL * 100)
        let directExchangeRateValue = pool.baseAssetPooledTotal/pool.targetAssetPooledTotal
        let inversedExchangeRateValue = pool.targetAssetPooledTotal/pool.baseAssetPooledTotal
        let shareOfPoolValue = pool.yourPoolShare
        let firstAssetValue = pool.baseAssetPooledByAccount + firstAmount
        let secondAssetValue = pool.targetAssetPooledByAccount + secondAmount

        return PoolDetailsViewModel(firstAsset: firstAsset,
                                    firstAssetValue: firstAssetValue,
                                    secondAsset: secondAsset,
                                    secondAssetValue: secondAssetValue,
                                    shareOfPoolValue: shareOfPoolValue,
                                    directExchangeRateTitle: directExchangeRateTitle(),
                                    directExchangeRateValue: directExchangeRateValue,
                                    inversedExchangeRateTitle: inversedExchangeRateTitle(),
                                    inversedExchangeRateValue: inversedExchangeRateValue,
                                    sbApyValue: sbApyValue,
                                    networkFeeValue: fee)
    }

    func createDetailsViewModelForNewPool() -> PoolDetailsViewModel? {
        guard firstAmount > 0, secondAmount > 0 else {
            return nil
        }

        let directExchangeRateValue = firstAmount/secondAmount
        let inversedExchangeRateValue = secondAmount/firstAmount
        let sbApyValue: Decimal = 0

        return PoolDetailsViewModel(firstAsset: firstAsset,
                                    firstAssetValue: firstAmount,
                                    secondAsset: secondAsset,
                                    secondAssetValue: secondAmount,
                                    shareOfPoolValue: 100,
                                    directExchangeRateTitle: directExchangeRateTitle(),
                                    directExchangeRateValue: directExchangeRateValue,
                                    inversedExchangeRateTitle: inversedExchangeRateTitle(),
                                    inversedExchangeRateValue: inversedExchangeRateValue,
                                    sbApyValue: sbApyValue,
                                    networkFeeValue: fee)
    }

    func directExchangeRateTitle() -> String {
        firstAsset.symbol + "/" + secondAsset.symbol
    }

    func inversedExchangeRateTitle() -> String {
        secondAsset.symbol + "/" + firstAsset.symbol
    }
}
