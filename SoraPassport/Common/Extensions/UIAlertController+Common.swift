/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

extension UIAlertController {
    public static func present(message: String?, title: String?,
                               closeAction: String?, with presenter: UIViewController) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: closeAction, style: .cancel, handler: nil)
        alertView.addAction(action)
        presenter.present(alertView, animated: true, completion: nil)
    }
}
