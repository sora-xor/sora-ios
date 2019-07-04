/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol AlertPresentable: class {
    func present(message: String?, title: String?,
                 closeAction: String?, from view: ControllerBackedProtocol?)
}

extension AlertPresentable {
    func present(message: String?, title: String?,
                 closeAction: String?,
                 from view: ControllerBackedProtocol?) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        UIAlertController.present(message: message,
                                  title: title,
                                  closeAction: closeAction,
                                  with: controller)
    }
}
