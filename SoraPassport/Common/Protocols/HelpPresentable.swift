/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol HelpPresentable: class {
    func presentHelp(from view: ControllerBackedProtocol?)
}

extension HelpPresentable {
    func presentHelp(from view: ControllerBackedProtocol?) {
        guard let helpView = HelpViewFactory.createView() else {
            return
        }

        if let nagivationController = view?.controller.navigationController {
            helpView.controller.hidesBottomBarWhenPushed = true
            nagivationController.pushViewController(helpView.controller, animated: true)
        }
    }
}
