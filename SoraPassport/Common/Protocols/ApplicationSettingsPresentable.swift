/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol ApplicationSettingsPresentable {
    func askOpenApplicationSettins(with message: String, title: String?, from view: ControllerBackedProtocol?)
}

extension ApplicationSettingsPresentable {
    func askOpenApplicationSettins(with message: String, title: String?, from view: ControllerBackedProtocol?) {
        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: R.string.localizable.notNow(), style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: R.string.localizable.goSettings(), style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.openURL(url)
            }
        }

        alert.addAction(closeAction)
        alert.addAction(settingsAction)

        controller.present(alert, animated: true, completion: nil)
    }
}
