import Foundation
import CommonWallet
import SoraFoundation

protocol AmountFormatterFactoryProtocol: NumberFormatterFactoryProtocol {
    func createTokenFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<TokenFormatter>
    func createDisplayFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<NumberFormatter>
    func createPercentageFormatter(maxPrecision: Int) -> LocalizableResource<NumberFormatter>
    func createPolkaswapAmountFormatter() -> LocalizableResource<NumberFormatter>
}

struct AmountFormatterFactory: AmountFormatterFactoryProtocol {
    let assetPrecision: Int
    let usdPrecision: Int

    init(assetPrecision: Int = 10,
         usdPrecision: Int = 2) {
        self.assetPrecision = assetPrecision
        self.usdPrecision = usdPrecision
    }

    func createInputFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        if let asset = asset {
            formatter.maximumFractionDigits = Int(asset.precision)
        }

        return formatter.localizableResource()
    }

    func createDisplayFormatter(for asset: WalletAsset?) -> LocalizableResource<NumberFormatter> {
        let precision = precision(for: asset)
        return createAssetNumberFormatter(for: precision).localizableResource()
    }

    func createDisplayFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<NumberFormatter> {
        var precision = precision(for: asset)
        precision = min(precision, maxPrecision)
        return createAssetNumberFormatter(for: precision).localizableResource()
    }

    func precision(for asset: WalletAsset?) -> Int {
        guard let asset = asset else {
            return assetPrecision
        }
        return Int(asset.precision)
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenFormatter> {
        let precision = asset != nil ? Int(asset!.precision) : Int.max
        return createTokenFormatter(for: asset, maxPrecision: precision)
    }

    func createTokenFormatter(for asset: WalletAsset?, maxPrecision: Int) -> LocalizableResource<TokenFormatter> {
        var precision = asset != nil  ? Int(asset!.precision) : assetPrecision
        precision = min(precision, maxPrecision)
        let numberFormatter = createTokenNumberFormatter(for: precision)
        let tokenFormatter = TokenFormatter(decimalFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: " ",
                                        position: .suffix)
        return LocalizableResource { locale in
            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }

    func createShortFormatter(for asset: WalletAsset?)  -> LocalizableResource<TokenFormatter> {
        let precision = 4
        let numberFormatter = createTokenNumberFormatter(for: precision)
        let tokenFormatter = TokenFormatter(decimalFormatter: numberFormatter,
                                        tokenSymbol: asset?.symbol ?? "",
                                        separator: " ",
                                        position: .suffix)
        return LocalizableResource { locale in
            tokenFormatter.locale = locale
            return tokenFormatter
        }
    }

    private func createUsdNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.maximumFractionDigits = precision

        return formatter
    }

    private func createAssetNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision

        return formatter
    }

    private func createTokenNumberFormatter(for precision: Int) -> NumberFormatter {
        let formatter = NumberFormatter.amount
        formatter.roundingMode = .floor

        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = precision

        return formatter
    }

    func createPercentageFormatter(maxPrecision: Int = 2) -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.percent
        formatter.maximumFractionDigits = maxPrecision
        return formatter.localizableResource()
    }

    func createPolkaswapAmountFormatter() -> LocalizableResource<NumberFormatter> {
        let formatter = NumberFormatter.amount
        formatter.maximumFractionDigits = 8
        return formatter.localizableResource()
    }

}
