/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import CommonWallet

protocol WalletWireframeProtocol {
    func presentHelp(in context: CommonWalletContextProtocol)
}

final class WalletWireframe: WalletWireframeProtocol {
    let applicationConfig: ApplicationConfigProtocol

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
