/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol WebPresentable: class {
    func showWeb(url: URL, from view: ControllerBackedProtocol, secondaryTitle: String)
}

extension WebPresentable {
    func showWeb(url: URL, from view: ControllerBackedProtocol, secondaryTitle: String) {
        let webViewController = WebViewController(url: url, secondaryTitle: secondaryTitle)
        webViewController.logger = Logger.shared

        let navigationController = SoraNavigationController()
        navigationController.viewControllers = [webViewController]

        view.controller.present(navigationController, animated: true, completion: nil)
    }
}
