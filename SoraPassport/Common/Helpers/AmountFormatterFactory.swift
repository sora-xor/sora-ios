import Foundation
import CommonWallet
import SoraFoundation

struct AmountFormatterFactory: NumberFormatterFactoryProtocol {
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
        let precision = asset != nil  ? Int(asset!.precision) : assetPrecision
        return createAssetNumberFormatter(for: precision).localizableResource()
    }

    func createTokenFormatter(for asset: WalletAsset?) -> LocalizableResource<TokenFormatter> {
        let precision = asset != nil  ? Int(asset!.precision) : assetPrecision
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
}
