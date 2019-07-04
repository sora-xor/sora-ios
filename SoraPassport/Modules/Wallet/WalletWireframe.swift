/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol WalletWireframeProtocol {
    func presentHelp(in navigationController: UINavigationController)
}

final class WalletWireframe: WalletWireframeProtocol {
    func presentHelp(in navigationController: UINavigationController) {
        guard let helpView = HelpViewFactory.createView() else {
            return
        }

        helpView.controller.hidesBottomBarWhenPushed = true
        navigationController.pushViewController(helpView.controller, animated: true)
    }
}
