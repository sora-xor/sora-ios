/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

struct AlertPresentableAction {
    var title: String
    var handler: (() -> Void)?

    init(title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }

    init(title: String) {
        self.title = title
    }
}

protocol AlertPresentable: class {
    func present(message: String?, title: String?,
                 closeAction: String?, from view: ControllerBackedProtocol?)
    func present(message: String?, title: String?,
                 actions: [AlertPresentableAction],
                 from view: ControllerBackedProtocol?)
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

    func present(message: String?, title: String?,
                 actions: [AlertPresentableAction],
                 from view: ControllerBackedProtocol?) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        actions.forEach { action in
            let alertAction = UIAlertAction(title: action.title, style: .default) { _ in
                action.handler?()
            }

            alertView.addAction(alertAction)
        }

        controller.present(alertView, animated: true, completion: nil)
    }
}
