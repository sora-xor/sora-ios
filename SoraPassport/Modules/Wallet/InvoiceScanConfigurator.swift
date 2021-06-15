import Foundation
import CommonWallet
import IrohaCrypto

final class InvoiceScanConfigurator {
    let searchEngine: InvoiceLocalSearchEngineProtocol

    init(networkType: SNAddressType) {
        searchEngine = InvoiceScanLocalSearchEngine(networkType: networkType)
    }

    let style: InvoiceScanViewStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph2), color: R.color.brandWhite()!)
        let message = WalletTextStyle(font: UIFont.styled(for: .paragraph2), color: R.color.brandWhite()!)

        let uploadTitle = WalletTextStyle(font: UIFont.styled(for: .button), color: R.color.brandWhite()!)
        let upload = WalletRoundedButtonStyle(background: R.color.themeAccent()!, title: uploadTitle)

        return InvoiceScanViewStyle(
            background: R.color.brandWhite()!,
            title: title,
            message: message,
            maskBackground: R.color.brandPMSBlack()!.withAlphaComponent(0.8),
            upload: upload
        )
    }()

    func configure(builder: InvoiceScanModuleBuilderProtocol) {
        builder
            .with(viewStyle: style)
            .with(localSearchEngine: searchEngine)
    }
}
