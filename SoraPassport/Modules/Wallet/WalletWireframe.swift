import UIKit
import CommonWallet
import SoraFoundation

protocol WalletWireframeProtocol {
    func presentHelp(in context: CommonWalletContextProtocol)
}

final class WalletWireframe: WalletWireframeProtocol {
    
    let applicationConfig: ApplicationConfigProtocol

    var logger: LoggerProtocol?

    init(applicationConfig: ApplicationConfigProtocol) {
        self.applicationConfig = applicationConfig
    }

    func presentHelp(in context: CommonWalletContextProtocol) {
        let url = applicationConfig.faqURL
        let webViewController = WebViewFactory.createWebViewController(for: url,
                                                                       style: .automatic)

        let command = context.preparePresentationCommand(for: webViewController)
        command.presentationStyle = .modal(inNavigation: false)
        try? command.execute()
    }
}
