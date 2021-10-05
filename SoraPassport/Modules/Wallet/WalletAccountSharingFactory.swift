import Foundation
import CommonWallet
import SoraFoundation

struct WalletAccountSharingFactory: AccountShareFactoryProtocol {
    let assets: [WalletAsset]
    let numberFactory: NumberFormatterFactoryProtocol
    let localizationManager: LocalizationManagerProtocol

    func createSources(for receiveInfo: ReceiveInfo, qrImage: UIImage) -> [Any] {
        var title: String
        var optionalAssetTitle: String?
        var optionalAmountTitle: String?
        var asset: WalletAsset?

        let locale = localizationManager.selectedLocale
        let languages = locale.rLanguages

        if let assetId = receiveInfo.assetId {
            asset = assets.first(where: { $0.identifier == assetId })
        }

        optionalAssetTitle = asset?.name.value(for: locale)

        let amountFormatter = numberFactory.createDisplayFormatter(for: asset)

        if let amountDecimal = receiveInfo.amount?.decimalValue,
            let formattedAmount = amountFormatter.value(for: locale)
                .stringFromDecimal(amountDecimal) {
            optionalAmountTitle = formattedAmount
        }

        let platform = R.string.localizable.assetXorPlatform(preferredLanguages: languages)

        if let assetTitle = optionalAssetTitle, let amountTitle = optionalAmountTitle {
            title = R.string.localizable
                .walletAccountShareAssetAmountMessage(platform, amountTitle, assetTitle, preferredLanguages: languages)
        } else if let assetTitle = optionalAssetTitle {
            title = R.string.localizable
                .walletAccountShareAssetOrAmountMessage(platform, assetTitle, preferredLanguages: languages)
        } else if let amountTitle = optionalAmountTitle {
            title = R.string.localizable
                .walletAccountShareAssetOrAmountMessage(platform, amountTitle, preferredLanguages: languages)
        } else {
            title = R.string.localizable
                .walletAccountShareMessage(preferredLanguages: languages)
        }

        return [qrImage, title, receiveInfo.accountId]
    }
}
