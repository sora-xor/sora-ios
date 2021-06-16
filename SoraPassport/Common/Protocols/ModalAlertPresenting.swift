/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol ModalAlertPresenting {
    func presentSuccessNotification(
        _ title: String,
        from view: ControllerBackedProtocol?,
        completion closure: (() -> Void)?
    )
}

extension ModalAlertPresenting {
    func presentSuccessNotification(_ title: String, from view: ControllerBackedProtocol?) {
        presentSuccessNotification(title, from: view, completion: nil)
    }

    func presentSuccessNotification(
        _ title: String,
        from view: ControllerBackedProtocol?,
        completion closure: (() -> Void)?
    ) {
        presentSuccessNotification(
            title,
            from: view?.controller,
            completion: closure
        )
    }

    func presentSuccessNotification(
        _ title: String,
        from presenter: UIViewController?,
        completion closure: (() -> Void)?
    ) {
        let controller = ModalAlertFactory.createSuccessAlert(title)
        presenter?.present(controller, animated: true, completion: closure)
    }
}
