import Foundation
import CommonWallet
import SoraUI
import SoraFoundation

final class ReceiveConfigurator: AdaptiveDesignable {
    let receiveFactory: ReceiveViewFactory

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            receiveFactory.commandFactory
        }

        set {
            receiveFactory.commandFactory = newValue
        }
    }

    let shareFactory: AccountShareFactoryProtocol

    init(account: AccountItem, chain: Chain, assets: [WalletAsset], localizationManager: LocalizationManagerProtocol) {
        receiveFactory = ReceiveViewFactory(account: account,
                                            chain: chain,
                                            localizationManager: localizationManager)
        shareFactory = AccountShareFactory(address: account.address,
                                           assets: assets,
                                           localizationManager: localizationManager)
    }

    func configure(builder: ReceiveAmountModuleBuilderProtocol) {
        let margin: CGFloat = 24.0
        let qrSize: CGFloat = 280.0 * designScaleRatio.width + 2.0 * margin
        let style = ReceiveStyle(qrBackgroundColor: R.color.baseBackground()!,
                                 qrMode: .scaleAspectFit,
                                 qrSize: CGSize(width: 260, height: 260),
                                 qrMargin: 3)

        let title = LocalizableResource { locale in
            return R.string.localizable.commonReceive(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(style: style)
            .with(fieldsInclusion: [])
            .with(title: title)
            .with(viewFactory: receiveFactory)
            .with(accountShareFactory: shareFactory)
    }
}
